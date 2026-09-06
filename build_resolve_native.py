#!/usr/bin/env python3
"""Build the editorial assembly directly inside a running DaVinci Resolve instance.

This avoids FCPXML conform matching entirely. Source trim positions are interpreted
relative to each source clip's media start, and Resolve receives exact source frame
ranges plus record frames.

Requires DaVinci Resolve to be running with scripting enabled and the
DaVinciResolveScript Python module available. The script does not modify source
media or edit_timeline.json / resolve_assembly.json.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any

MODULE_CANDIDATES = [
    "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules",
    "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion",
]


def load_resolve_module():
    try:
        import DaVinciResolveScript as dvr_script  # type: ignore
        return dvr_script
    except ImportError:
        for candidate in MODULE_CANDIDATES:
            if os.path.isdir(candidate) and candidate not in sys.path:
                sys.path.append(candidate)
        try:
            import DaVinciResolveScript as dvr_script  # type: ignore
            return dvr_script
        except ImportError as exc:
            raise RuntimeError(
                "DaVinciResolveScript module not found. Enable Resolve scripting or configure its Python module path."
            ) from exc


def ts(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    parts = str(value).strip().split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) == 2:
        minutes, seconds = (Fraction(p) for p in parts)
        if minutes < 0 or not (0 <= seconds < 60):
            raise ValueError(f"Invalid timestamp: {value!r}")
        return minutes * 60 + seconds
    if len(parts) == 3:
        hours, minutes, seconds = (Fraction(p) for p in parts)
        if hours < 0 or not (0 <= minutes < 60 and 0 <= seconds < 60):
            raise ValueError(f"Invalid timestamp: {value!r}")
        return hours * 3600 + minutes * 60 + seconds
    raise ValueError(f"Invalid timestamp: {value!r}")


def probe_fps(path: Path) -> Fraction:
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=avg_frame_rate,r_frame_rate",
        "-of", "json", str(path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    data = json.loads(result.stdout or "{}")
    stream = (data.get("streams") or [{}])[0]
    value = stream.get("avg_frame_rate") or stream.get("r_frame_rate") or "30/1"
    num, den = value.split("/", 1)
    fps = Fraction(int(num), int(den))
    if fps <= 0:
        return Fraction(30, 1)
    return fps


def find_media(media_dir: Path, filename: str) -> Path:
    direct = media_dir / filename
    if direct.is_file():
        return direct
    matches = [p for p in media_dir.rglob(filename) if p.is_file()]
    if not matches:
        raise FileNotFoundError(f"Source media not found: {filename}")
    if len(matches) > 1:
        raise RuntimeError(
            "Multiple source files found for " + filename + ":\n" +
            "\n".join(str(p) for p in matches[:10])
        )
    return matches[0]


def frame_at(seconds: Fraction, fps: Fraction) -> int:
    """Convert a source-relative time to the nearest integer source frame."""
    return max(0, int(round(float(seconds * fps))))


def duration_frames(start: Fraction, end: Fraction, fps: Fraction) -> tuple[int, int]:
    """Return an inclusive Resolve source-frame range for [start, end)."""
    source_start = frame_at(start, fps)
    source_end_exclusive = frame_at(end, fps)
    source_end = source_end_exclusive - 1
    if source_end < source_start:
        source_end = source_start
    return source_start, source_end


def clip_info(
    media_item: Any,
    source_start: int,
    source_end: int,
    record_frame: int,
    *,
    track_index: int,
    media_type: int,
) -> dict[str, Any]:
    """Create a Resolve AppendToTimeline clip descriptor.

    mediaType: 1=video, 2=audio, 3=both.
    """
    return {
        "mediaPoolItem": media_item,
        "startFrame": source_start,
        "endFrame": source_end,
        "recordFrame": record_frame,
        "trackIndex": track_index,
        "mediaType": media_type,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assembly", type=Path, default=Path("resolve_assembly.json"))
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--timeline-name", default=None)
    parser.add_argument("--project-name", default="Kaiwara Resolve Native Build")
    parser.add_argument("--music-file", type=Path, required=False)
    parser.add_argument("--timeline-fps", type=int, default=30)
    args = parser.parse_args()

    assembly = json.loads(args.assembly.read_text(encoding="utf-8"))
    main_items = assembly.get("mainTimeline")
    if not isinstance(main_items, list) or not main_items:
        raise ValueError("resolve_assembly.json must contain non-empty mainTimeline[]")

    dvr_script = load_resolve_module()
    resolve = dvr_script.scriptapp("Resolve")
    if resolve is None:
        raise RuntimeError("Could not connect to the running DaVinci Resolve instance")

    pm = resolve.GetProjectManager()
    project = pm.GetCurrentProject()
    if project is None:
        project = pm.CreateProject(args.project_name)
        if project is None:
            raise RuntimeError("Could not create Resolve project")

    project.SetSetting("timelineFrameRate", str(args.timeline_fps))
    project.SetSetting("timelineResolutionWidth", "1920")
    project.SetSetting("timelineResolutionHeight", "1080")

    media_pool = project.GetMediaPool()
    root_folder = media_pool.GetRootFolder()
    if root_folder is None:
        raise RuntimeError("Could not access Resolve Media Pool root folder")
    media_pool.SetCurrentFolder(root_folder)

    filenames: list[str] = []
    seen: set[str] = set()
    for item in main_items:
        name = str(item["sourceFile"])
        if name not in seen:
            seen.add(name)
            filenames.append(name)
    for item in assembly.get("brollOverlays", []):
        name = str(item.get("sourceFile", ""))
        if name and name not in seen:
            seen.add(name)
            filenames.append(name)
    if args.music_file:
        if args.music_file.name not in seen:
            filenames.append(args.music_file.name)

    paths: list[str] = []
    for name in filenames:
        if args.music_file and name == args.music_file.name:
            paths.append(str(args.music_file.resolve()))
        else:
            paths.append(str(find_media(args.media_dir, name).resolve()))

    imported = media_pool.ImportMedia(paths)
    if not imported:
        raise RuntimeError("Resolve imported no media")

    by_name = {item.GetName(): item for item in imported}
    missing = [name for name in filenames if name not in by_name]
    if missing:
        raise RuntimeError("Resolve did not return imported MediaPoolItem(s): " + ", ".join(missing))

    timeline_name = args.timeline_name or str(assembly.get("assemblyName", "AI Editorial Timeline"))
    timeline = media_pool.CreateEmptyTimeline(timeline_name)
    if timeline is None:
        raise RuntimeError(f"Could not create timeline {timeline_name!r}")
    project.SetCurrentTimeline(timeline)

    # Create one additional video and audio track so V2 and A2 can be addressed
    # explicitly. A newly created Resolve timeline already has V1/A1.
    try:
        timeline.AddTrack("video")
    except Exception:
        pass
    try:
        timeline.AddTrack("audio")
    except Exception:
        pass

    # Build V1 using relative source frames. No embedded camera timecode is used.
    record = 0
    placed_main: list[dict[str, Any]] = []
    for idx, item in enumerate(main_items, start=1):
        name = str(item["sourceFile"])
        media = by_name[name]
        path = find_media(args.media_dir, name)
        fps = probe_fps(path)
        source_start, source_end = duration_frames(
            ts(item["sourceStart"]),
            ts(item["sourceEnd"]),
            fps,
        )
        if source_end < source_start:
            raise ValueError(f"mainTimeline[{idx}] has invalid frame range")
        info = clip_info(
            media,
            source_start,
            source_end,
            record,
            track_index=1,
            media_type=3,
        )
        placed_main.append(info)
        record += source_end - source_start + 1

    if not media_pool.AppendToTimeline(placed_main):
        raise RuntimeError("Resolve failed to append main V1 clips")

    # V2: video-only so its camera audio does not occupy A2.
    broll_infos: list[dict[str, Any]] = []
    for b in assembly.get("brollOverlays", []):
        source = str(b["sourceFile"])
        media = by_name.get(source)
        if media is None:
            continue
        path = find_media(args.media_dir, source)
        fps = probe_fps(path)
        source_start, source_end = duration_frames(
            ts(b["sourceStart"]),
            ts(b["sourceEnd"]),
            fps,
        )
        timeline_frame = int(round(float(ts(b["timelineStart"])) * args.timeline_fps))
        broll_infos.append(
            clip_info(
                media,
                source_start,
                source_end,
                timeline_frame,
                track_index=2,
                media_type=1,
            )
        )
    if broll_infos and not media_pool.AppendToTimeline(broll_infos):
        raise RuntimeError("Resolve failed to append V2 B-roll")

    # A2: music-only track, independent of video source timecode.
    music_placed = 0
    if args.music_file:
        music_item = by_name.get(args.music_file.name)
        if music_item is None:
            raise RuntimeError(f"Music file was not imported: {args.music_file.name}")
        for cue in assembly.get("musicCues", []):
            start = int(round(float(ts(cue["timelineStart"])) * args.timeline_fps))
            duration = int(round(float(ts(cue["duration"])) * args.timeline_fps))
            if duration <= 0:
                continue
            info = {
                "mediaPoolItem": music_item,
                "startFrame": 0,
                "endFrame": duration - 1,
                "recordFrame": start,
                "trackIndex": 2,
                "mediaType": 2,
            }
            if media_pool.AppendToTimeline([info]):
                music_placed += 1

    print(json.dumps({
        "status": "READY_IN_DAVINCI",
        "project": project.GetName(),
        "timeline": timeline.GetName(),
        "mainClips": len(main_items),
        "brollPlaced": len(broll_infos),
        "musicCuesPlaced": music_placed,
        "timelineFps": args.timeline_fps,
        "sourceTimecodeConform": False,
        "sourceTimingMode": "relative-media-frames",
        "rawOriginalsModified": False,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
