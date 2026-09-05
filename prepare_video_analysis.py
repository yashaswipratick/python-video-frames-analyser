#!/usr/bin/env python3
"""
Final sequential video-analysis pipeline for AI-assisted travel-vlog editing.

This file is the ONLY analysis runner. It processes videos sequentially and
produces the complete evidence package needed by the AI editorial stage.

What it does for EVERY video under --input-dir:
  analysis/<relative-video-folder>/<video-stem>/
      proxy.mp4              # 720p/1080p H.264 proxy for visual review
      audio.m4a              # compressed mono speech/reference audio
      transcript.json        # faster-whisper timestamps + word timestamps
      scenes.json             # PySceneDetect scene boundaries
      frames/
          frame_0001.jpg ... # scene-aware representative frames
      analysis.json           # one merged master JSON

At the end it creates one or more upload-safe ZIP bundles from the accumulated
analysis directory. Every bundle is kept below the configured maximum size
(default: 500 MiB) so it remains safely under a 512 MB attachment limit.

Bundle behavior:
  - analysis_bundle_001.zip
  - analysis_bundle_002.zip
  - ...
  - Files are packed in complete per-video folders whenever possible.
  - If one video's analysis package alone exceeds the limit, its files are
    split across multiple bundles rather than dropping data.
  - No source video is ever modified.

Design goals:
  - Never modify source videos.
  - Keep upload packages small enough to be practical.
  - Load Whisper ONCE and reuse it for all videos.
  - Use scene-aware frame sampling rather than dumping every few seconds.
  - Preserve source-relative paths so duplicate filenames do not collide.
  - Make analysis.json useful to a later AI editor: speech + scenes + frames + technical data.
  - Resume safely: existing completed artifacts are reused where possible.
  - Be compatible with FFmpeg 9 on macOS when extracting JPEG frames.
  - Keep this as a sequential pipeline; no parallel worker/process code is used.

Dependencies:
  - ffmpeg + ffprobe on PATH
  - faster-whisper
  - scenedetect[opencv]

Install:
  brew install ffmpeg
  python3 -m pip install faster-whisper "scenedetect[opencv]"

Example:
  python3 prepare_video_analysis.py \
      --input-dir ./videos \
      --output-dir ./analysis

Useful options:
  --whisper-model large-v3-turbo
  --proxy-height 720
  --proxy-bitrate 3M
  --frame-every 5
  --max-frames 80
  --scene-threshold 27
  --min-scene-sec 1.0
  --bundle-max-mib 500
  --no-whisper
  --no-scenes
  --no-zip
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path
from typing import Any, Optional

VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}
WHISPER_MODEL_CACHE: dict[tuple[str, str, str], Any] = {}

# Keep a safety margin below the 512 MB attachment limit. 500 MiB is the
# default hard target, leaving room for attachment/UI overhead outside the ZIP.
DEFAULT_BUNDLE_MAX_MIB = 500
ZIP_OVERHEAD_RESERVE_BYTES = 2 * 1024 * 1024


def run(cmd: list[str], *, capture: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def sha256_file(path: Path, chunk_size: int = 4 * 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def json_dump(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    temp.replace(path)


def ffprobe_json(path: Path) -> dict[str, Any]:
    result = run([
        "ffprobe", "-v", "error",
        "-print_format", "json",
        "-show_format", "-show_streams",
        str(path),
    ])
    return json.loads(result.stdout)


def get_video_stream(probe: dict[str, Any]) -> dict[str, Any]:
    return next((s for s in probe.get("streams", []) if s.get("codec_type") == "video"), {})


def get_audio_stream(probe: dict[str, Any]) -> dict[str, Any]:
    return next((s for s in probe.get("streams", []) if s.get("codec_type") == "audio"), {})


def get_duration_ms(probe: dict[str, Any]) -> int:
    value = probe.get("format", {}).get("duration")
    if value is not None:
        try:
            return int(round(float(value) * 1000))
        except (TypeError, ValueError):
            pass
    for stream in probe.get("streams", []):
        if stream.get("duration") is not None:
            try:
                return int(round(float(stream["duration"]) * 1000))
            except (TypeError, ValueError):
                pass
    return 0


def has_audio(probe: dict[str, Any]) -> bool:
    return bool(get_audio_stream(probe))


def parse_ratio(value: Optional[str]) -> Optional[float]:
    if not value or value in {"0/0", "N/A"}:
        return None
    try:
        a, b = value.split("/", 1)
        if float(b) == 0:
            return None
        return float(a) / float(b)
    except Exception:
        return None


def format_bytes(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024**2:
        return f"{n / 1024:.1f} KB"
    if n < 1024**3:
        return f"{n / 1024**2:.1f} MB"
    return f"{n / 1024**3:.2f} GB"


def create_proxy(src: Path, out: Path, height: int, bitrate: str) -> None:
    # Width is automatic and aspect ratio is preserved. Audio is retained because
    # the proxy can be useful for human spot checks and later sync/reference.
    vf = f"scale=-2:{height}:force_original_aspect_ratio=decrease"
    tmp = out.with_suffix(out.suffix + ".tmp.mp4")
    run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-vf", vf,
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-b:v", bitrate,
        "-maxrate", bitrate,
        "-bufsize", bitrate,
        "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "96k",
        "-movflags", "+faststart",
        str(tmp),
    ])
    tmp.replace(out)


def extract_reference_audio(src: Path, out: Path) -> None:
    """Create a compact speech/reference audio file for AI/human review."""
    tmp = out.with_suffix(out.suffix + ".tmp.m4a")
    run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-vn",
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "aac",
        "-b:a", "96k",
        str(tmp),
    ])
    tmp.replace(out)


def extract_whisper_audio(src: Path, out: Path) -> None:
    """WAV is ideal for local Whisper inference; delete it after transcription."""
    tmp = out.with_suffix(out.suffix + ".tmp.wav")
    run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(src),
        "-vn", "-ac", "1", "-ar", "16000",
        "-c:a", "pcm_s16le",
        str(tmp),
    ])
    tmp.replace(out)


def detect_scenes(src: Path, threshold: float, min_scene_sec: float) -> list[dict[str, Any]]:
    from scenedetect import ContentDetector, detect

    scene_list = detect(
        str(src),
        ContentDetector(threshold=threshold),
        show_progress=False,
    )

    scenes: list[dict[str, Any]] = []
    next_id = 1
    for start, end in scene_list:
        start_ms = int(round(start.get_seconds() * 1000))
        end_ms = int(round(end.get_seconds() * 1000))
        if end_ms <= start_ms:
            continue
        if end_ms - start_ms < int(min_scene_sec * 1000):
            continue
        scenes.append({
            "sceneId": next_id,
            "startMs": start_ms,
            "endMs": end_ms,
            "durationMs": end_ms - start_ms,
        })
        next_id += 1
    return scenes


def fallback_scene(duration_ms: int) -> list[dict[str, Any]]:
    if duration_ms <= 0:
        return []
    return [{
        "sceneId": 1,
        "startMs": 0,
        "endMs": duration_ms,
        "durationMs": duration_ms,
    }]


def build_frame_timestamps(
    scenes: list[dict[str, Any]],
    duration_ms: int,
    every_sec: float,
    max_frames: int,
) -> list[int]:
    """Prioritize scene boundaries and midpoints, then fill with uniform samples."""
    if duration_ms <= 0:
        return []

    candidates: set[int] = {0, max(0, duration_ms - 1)}

    # Up to 3 strategic frames per scene: start, midpoint, end.
    for scene in scenes:
        s = int(scene["startMs"])
        e = int(scene["endMs"])
        if e <= s:
            continue
        candidates.add(s)
        candidates.add(s + (e - s) // 2)
        candidates.add(max(s, e - 1))

    # Uniform safety net for long scenes / failed scene detection.
    if every_sec > 0:
        t = 0.0
        while t * 1000 < duration_ms:
            candidates.add(int(round(t * 1000)))
            t += every_sec

    timestamps = sorted(candidates)
    if len(timestamps) <= max_frames:
        return timestamps

    selected: list[int] = []
    for i in range(max_frames):
        idx = round(i * (len(timestamps) - 1) / max(1, max_frames - 1))
        selected.append(timestamps[idx])
    return sorted(set(selected))


def extract_frames(
    proxy: Path,
    frames_dir: Path,
    timestamps_ms: list[int],
) -> list[dict[str, Any]]:
    frames_dir.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, Any]] = []

    for i, ts_ms in enumerate(timestamps_ms, start=1):
        out = frames_dir / f"frame_{i:04d}.jpg"
        if not out.exists() or out.stat().st_size < 1024:
            # FFmpeg 9 on macOS can reject MJPEG when the source carries
            # limited-range YUV metadata. Convert explicitly to full-range
            # JPEG-compatible YUV before encoding.
            run([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-ss", f"{ts_ms / 1000:.3f}",
                "-i", str(proxy),
                "-frames:v", "1",
                "-vf", "format=yuvj420p",
                "-c:v", "mjpeg",
                "-q:v", "4",
                "-strict", "unofficial",
                str(out),
            ])
        manifest.append({
            "frameFile": str(out.relative_to(frames_dir.parent)),
            "timestampMs": ts_ms,
        })
    return manifest


def get_whisper_model(model_name: str, device: str, compute_type: str):
    from faster_whisper import WhisperModel

    key = (model_name, device, compute_type)
    if key not in WHISPER_MODEL_CACHE:
        print(f"Loading Whisper model '{model_name}' ({device}/{compute_type})...", flush=True)
        WHISPER_MODEL_CACHE[key] = WhisperModel(
            model_name,
            device=device,
            compute_type=compute_type,
        )
    return WHISPER_MODEL_CACHE[key]


def transcribe(
    audio_path: Path,
    model_name: str,
    device: str,
    compute_type: str,
    language: Optional[str],
) -> dict[str, Any]:
    model = get_whisper_model(model_name, device, compute_type)

    segments_iter, info = model.transcribe(
        str(audio_path),
        language=language,
        beam_size=5,
        word_timestamps=True,
        vad_filter=True,
        condition_on_previous_text=True,
    )

    segments: list[dict[str, Any]] = []
    for segment in segments_iter:
        words: list[dict[str, Any]] = []
        for word in segment.words or []:
            words.append({
                "startMs": int(round((word.start or 0.0) * 1000)),
                "endMs": int(round((word.end or 0.0) * 1000)),
                "word": word.word,
                "probability": word.probability,
            })
        segments.append({
            "startMs": int(round(segment.start * 1000)),
            "endMs": int(round(segment.end * 1000)),
            "text": segment.text.strip(),
            "avgLogprob": segment.avg_logprob,
            "noSpeechProb": segment.no_speech_prob,
            "compressionRatio": segment.compression_ratio,
            "words": words,
        })

    return {
        "language": getattr(info, "language", None),
        "languageProbability": getattr(info, "language_probability", None),
        "durationSeconds": getattr(info, "duration", None),
        "segments": segments,
    }


def overlap_ms(a_start: int, a_end: int, b_start: int, b_end: int) -> int:
    return max(0, min(a_end, b_end) - max(a_start, b_start))


def build_master_analysis(
    src: Path,
    rel_src: Path,
    probe: dict[str, Any],
    checksum: str,
    duration_ms: int,
    scenes: list[dict[str, Any]],
    transcript: dict[str, Any],
    frame_manifest: list[dict[str, Any]],
    proxy_name: str,
    audio_name: Optional[str],
    source_root: Path,
    processing: dict[str, Any],
) -> dict[str, Any]:
    video = get_video_stream(probe)
    audio = get_audio_stream(probe)
    speech_segments = transcript.get("segments", [])

    enriched_scenes: list[dict[str, Any]] = []
    for scene in scenes:
        speech = []
        for seg in speech_segments:
            ov = overlap_ms(
                int(scene["startMs"]), int(scene["endMs"]),
                int(seg["startMs"]), int(seg["endMs"]),
            )
            if ov > 0:
                speech.append(seg)
        enriched_scenes.append({
            **scene,
            "speechPresent": bool(speech),
            "speechSegmentIds": [i + 1 for i, _ in enumerate(speech)],
        })

    return {
        "schemaVersion": 3,
        "status": "READY_FOR_AI_ANALYSIS",
        "sourceFileName": src.name,
        "sourceRelativePath": str(rel_src),
        "sha256": checksum,
        "sizeBytes": src.stat().st_size,
        "durationMs": duration_ms,
        "artifacts": {
            "proxy": proxy_name,
            "audio": audio_name,
            "transcript": "transcript.json",
            "scenes": "scenes.json",
            "framesDirectory": "frames",
        },
        "analysis": {
            "sourceFileName": src.name,
            "durationMs": duration_ms,
            "scenes": enriched_scenes,
            "speechSegments": speech_segments,
            "audio": {
                "speechPresent": bool(speech_segments),
                "speechClarityScore": None,
                "backgroundNoiseScore": None,
                "musicPresent": None,
            },
            "visualQualityScore": None,
            "aiVisionStatus": "PENDING_AI_VISION",
            "storyAnalysisStatus": "PENDING_AI_EDITOR",
            "frameSamples": frame_manifest,
        },
        "technical": {
            "container": probe.get("format", {}).get("format_name"),
            "videoCodec": video.get("codec_name"),
            "videoCodecLongName": video.get("codec_long_name"),
            "width": video.get("width"),
            "height": video.get("height"),
            "fps": parse_ratio(video.get("r_frame_rate")),
            "pixelFormat": video.get("pix_fmt"),
            "rotation": video.get("tags", {}).get("rotate") if video else None,
            "audioCodec": audio.get("codec_name") if audio else None,
            "audioChannels": audio.get("channels") if audio else None,
            "audioSampleRate": audio.get("sample_rate") if audio else None,
            "bitRate": probe.get("format", {}).get("bit_rate"),
        },
        "processing": processing,
    }


def collect_archive_files(output_dir: Path) -> list[tuple[Path, str, int]]:
    """Return analysis files with a stable archive name and uncompressed size."""
    files: list[tuple[Path, str, int]] = []
    for path in sorted(output_dir.rglob("*")):
        if not path.is_file():
            continue
        arcname = str(Path(output_dir.name) / path.relative_to(output_dir))
        files.append((path, arcname, path.stat().st_size))
    return files


def bundle_groups(
    output_dir: Path,
    max_bundle_bytes: int,
) -> list[list[tuple[Path, str, int]]]:
    """Pack files sequentially while staying below a safe raw-size ceiling.

    ZIP compression cannot make a file larger than its uncompressed payload by
    more than ZIP/container overhead. We therefore reserve a small overhead
    margin and use file sizes as the conservative packing metric. This keeps
    generated archives safely under the configured attachment ceiling.
    """
    files = collect_archive_files(output_dir)
    if not files:
        return []

    safe_payload_limit = max_bundle_bytes - ZIP_OVERHEAD_RESERVE_BYTES
    if safe_payload_limit <= 0:
        raise ValueError("Bundle size limit must be larger than ZIP overhead reserve.")

    groups: list[list[tuple[Path, str, int]]] = []
    current: list[tuple[Path, str, int]] = []
    current_size = 0

    for item in files:
        _, _, size = item
        if size > safe_payload_limit:
            if current:
                groups.append(current)
                current = []
                current_size = 0
            # A single oversized file cannot be safely split without changing
            # the analysis artifact. Fail explicitly rather than creating an
            # attachment that violates the size constraint.
            raise RuntimeError(
                f"Single analysis file is too large for one bundle: {item[0]} "
                f"({format_bytes(size)} > {format_bytes(safe_payload_limit)})"
            )

        if current and current_size + size > safe_payload_limit:
            groups.append(current)
            current = []
            current_size = 0

        current.append(item)
        current_size += size

    if current:
        groups.append(current)
    return groups


def write_bundle(
    group: list[tuple[Path, str, int]],
    zip_path: Path,
    max_bundle_bytes: int,
) -> int:
    """Write one bundle and verify its actual final size."""
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(
        zip_path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
    ) as zf:
        for path, arcname, _ in group:
            zf.write(path, arcname=arcname)

    actual_size = zip_path.stat().st_size
    if actual_size > max_bundle_bytes:
        zip_path.unlink(missing_ok=True)
        raise RuntimeError(
            f"Generated bundle exceeded configured size limit: "
            f"{zip_path.name} = {format_bytes(actual_size)} > {format_bytes(max_bundle_bytes)}"
        )
    return actual_size


def make_bundles(output_dir: Path, bundle_max_mib: int) -> list[Path]:
    """Create analysis_bundle_001.zip, analysis_bundle_002.zip, ..."""
    if bundle_max_mib < 50:
        raise ValueError("--bundle-max-mib must be at least 50 MiB.")

    max_bundle_bytes = bundle_max_mib * 1024 * 1024
    bundle_parent = output_dir.parent

    # Remove only ZIPs generated by this sequential pipeline, never user files.
    for old_zip in sorted(bundle_parent.glob("analysis_bundle_*.zip")):
        old_zip.unlink()

    groups = bundle_groups(output_dir, max_bundle_bytes)
    created: list[Path] = []

    for index, group in enumerate(groups, start=1):
        zip_path = bundle_parent / f"analysis_bundle_{index:03d}.zip"
        actual_size = write_bundle(group, zip_path, max_bundle_bytes)
        created.append(zip_path)
        print(
            f"Created ZIP {index}/{len(groups)}: {zip_path.resolve()} "
            f"({format_bytes(actual_size)}, {len(group)} files)",
            flush=True,
        )

    if not created:
        raise RuntimeError(f"No files found under analysis directory: {output_dir}")
    return created


def safe_output_dir(src: Path, input_dir: Path, output_dir: Path) -> Path:
    rel = src.relative_to(input_dir)
    return output_dir / rel.parent / rel.stem


def process_video(src: Path, input_dir: Path, args: argparse.Namespace) -> None:
    rel_src = src.relative_to(input_dir)
    out_dir = safe_output_dir(src, input_dir, args.output_dir)
    frames_dir = out_dir / "frames"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n=== {rel_src} ===", flush=True)
    started = time.time()

    print("[1/7] Reading metadata + SHA-256...", flush=True)
    probe = ffprobe_json(src)
    duration_ms = get_duration_ms(probe)
    checksum = sha256_file(src)

    proxy = out_dir / "proxy.mp4"
    reference_audio = out_dir / "audio.m4a"
    whisper_audio = out_dir / "_whisper_audio.wav"
    transcript_path = out_dir / "transcript.json"
    scenes_path = out_dir / "scenes.json"
    analysis_path = out_dir / "analysis.json"

    print("[2/7] Creating analysis proxy...", flush=True)
    if not proxy.exists() or proxy.stat().st_size < 1024:
        create_proxy(src, proxy, args.proxy_height, args.proxy_bitrate)

    print("[3/7] Creating compact reference audio...", flush=True)
    if has_audio(probe):
        if not reference_audio.exists() or reference_audio.stat().st_size < 1024:
            extract_reference_audio(src, reference_audio)
    else:
        reference_audio.unlink(missing_ok=True)

    print("[4/7] Detecting scenes...", flush=True)
    scenes: list[dict[str, Any]] = []
    if not args.no_scenes:
        try:
            scenes = detect_scenes(proxy, args.scene_threshold, args.min_scene_sec)
        except Exception as exc:
            print(f"WARNING: scene detection skipped: {exc}", file=sys.stderr, flush=True)
    if not scenes:
        scenes = fallback_scene(duration_ms)

    json_dump(scenes_path, {
        "schemaVersion": 2,
        "sourceFileName": src.name,
        "sceneDetection": {
            "detector": "PySceneDetect ContentDetector" if not args.no_scenes else "disabled/fallback",
            "threshold": args.scene_threshold,
            "minSceneSec": args.min_scene_sec,
        },
        "scenes": scenes,
    })

    print("[5/7] Extracting scene-aware representative frames...", flush=True)
    timestamps = build_frame_timestamps(
        scenes=scenes,
        duration_ms=duration_ms,
        every_sec=args.frame_every,
        max_frames=args.max_frames,
    )
    frame_manifest = extract_frames(proxy, frames_dir, timestamps)

    print("[6/7] Transcribing speech...", flush=True)
    transcript: dict[str, Any] = {
        "language": None,
        "languageProbability": None,
        "durationSeconds": duration_ms / 1000 if duration_ms else None,
        "segments": [],
    }

    if not args.no_whisper and has_audio(probe):
        try:
            extract_whisper_audio(src, whisper_audio)
            transcript = transcribe(
                whisper_audio,
                args.whisper_model,
                args.whisper_device,
                args.whisper_compute_type,
                args.language,
            )
        except Exception as exc:
            print(f"WARNING: transcription skipped: {exc}", file=sys.stderr, flush=True)
        finally:
            whisper_audio.unlink(missing_ok=True)

    json_dump(transcript_path, {
        "schemaVersion": 2,
        "sourceFileName": src.name,
        **transcript,
    })

    print("[7/7] Building master analysis.json...", flush=True)
    analysis = build_master_analysis(
        src=src,
        rel_src=rel_src,
        probe=probe,
        checksum=checksum,
        duration_ms=duration_ms,
        scenes=scenes,
        transcript=transcript,
        frame_manifest=frame_manifest,
        proxy_name=proxy.name,
        audio_name=reference_audio.name if reference_audio.exists() else None,
        source_root=input_dir,
        processing={
            "proxyHeight": args.proxy_height,
            "proxyBitrate": args.proxy_bitrate,
            "frameEverySec": args.frame_every,
            "maxFrames": args.max_frames,
            "whisperModel": args.whisper_model if not args.no_whisper else None,
            "whisperDevice": args.whisper_device if not args.no_whisper else None,
            "whisperComputeType": args.whisper_compute_type if not args.no_whisper else None,
            "languageHint": args.language,
        },
    )
    json_dump(analysis_path, analysis)

    elapsed = time.time() - started
    print(f"Done: {out_dir}", flush=True)
    print(f"  source:     {format_bytes(src.stat().st_size)}", flush=True)
    print(f"  proxy:      {format_bytes(proxy.stat().st_size)}", flush=True)
    if reference_audio.exists():
        print(f"  audio:      {format_bytes(reference_audio.stat().st_size)}", flush=True)
    print(f"  frames:     {len(frame_manifest)}", flush=True)
    print(f"  scenes:     {len(scenes)}", flush=True)
    print(f"  speech:     {len(transcript.get('segments', []))} segments", flush=True)
    print(f"  time:       {elapsed / 60:.1f} min", flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Prepare videos sequentially for AI-assisted editing analysis.")
    p.add_argument("--input-dir", type=Path, default=Path("videos"))
    p.add_argument("--output-dir", type=Path, default=Path("analysis"))
    p.add_argument("--proxy-height", type=int, default=720, choices=[480, 720, 1080])
    p.add_argument("--proxy-bitrate", default="3M")
    p.add_argument("--frame-every", type=float, default=5.0)
    p.add_argument("--max-frames", type=int, default=80)
    p.add_argument("--scene-threshold", type=float, default=27.0)
    p.add_argument("--min-scene-sec", type=float, default=1.0)
    p.add_argument("--whisper-model", default="large-v3-turbo")
    p.add_argument("--whisper-device", default="cpu", choices=["cpu"])
    p.add_argument("--whisper-compute-type", default="int8")
    p.add_argument("--language", default=None, help="Optional language code, e.g. hi or en. Leave unset for auto-detect.")
    p.add_argument("--bundle-max-mib", type=int, default=DEFAULT_BUNDLE_MAX_MIB,
                   help="Maximum ZIP size in MiB. Default: 500 (safe under 512 MB upload limit).")
    p.add_argument("--no-whisper", action="store_true")
    p.add_argument("--no-scenes", action="store_true")
    p.add_argument("--no-zip", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if not args.input_dir.exists() or not args.input_dir.is_dir():
        print(f"Input directory does not exist or is not a directory: {args.input_dir}", file=sys.stderr)
        return 2
    if not command_exists("ffmpeg") or not command_exists("ffprobe"):
        print("ffmpeg and ffprobe are required and must be available on PATH.", file=sys.stderr)
        return 2
    if args.bundle_max_mib < 50:
        print("--bundle-max-mib must be at least 50 MiB", file=sys.stderr)
        return 2

    args.output_dir.mkdir(parents=True, exist_ok=True)
    videos = sorted(
        p for p in args.input_dir.rglob("*")
        if p.is_file() and p.suffix.lower() in VIDEO_EXTENSIONS
    )

    if not videos:
        print(f"No video files found under {args.input_dir}")
        return 0

    print(f"Found {len(videos)} video(s).", flush=True)
    print(f"Input : {args.input_dir.resolve()}", flush=True)
    print(f"Output: {args.output_dir.resolve()}", flush=True)
    print("Original videos will not be modified.", flush=True)
    print("Processing mode: SEQUENTIAL (single worker).", flush=True)

    failures: list[tuple[str, str]] = []
    started = time.time()

    if not args.no_whisper:
        print(f"Whisper: {args.whisper_model} / {args.whisper_device} / {args.whisper_compute_type}", flush=True)

    for src in videos:
        try:
            process_video(src, args.input_dir, args)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or str(exc)).strip()
            failures.append((str(src), detail[-2000:]))
            print(f"ERROR processing {src}: {detail}", file=sys.stderr, flush=True)
        except Exception as exc:
            failures.append((str(src), repr(exc)))
            print(f"ERROR processing {src}: {exc}", file=sys.stderr, flush=True)

    if failures:
        print("\nAnalysis completed with failures; ZIP creation skipped so the partial evidence is not presented as complete.", flush=True)
        for name, reason in failures:
            print(f"  - {name}: {reason}", flush=True)
        return 1

    if not args.no_zip:
        bundles = make_bundles(args.output_dir, args.bundle_max_mib)
        total_bundle_bytes = sum(p.stat().st_size for p in bundles)
        print(
            f"\nCreated {len(bundles)} upload-safe ZIP bundle(s) "
            f"({format_bytes(total_bundle_bytes)} total compressed).",
            flush=True,
        )
        for path in bundles:
            print(f"  - {path.resolve()} ({format_bytes(path.stat().st_size)})", flush=True)

    elapsed = time.time() - started
    print(f"Finished in {elapsed / 60:.1f} minutes.", flush=True)
    print("All videos processed successfully.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
