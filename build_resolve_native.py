#!/usr/bin/env python3
"""Build the editorial assembly directly inside a running DaVinci Resolve instance.

This avoids FCPXML conform matching entirely. Source trim positions are interpreted
relative to each source clip's media start, and Resolve is told the exact source
frame range plus record frame.

Requires DaVinci Resolve to be running with scripting enabled and the
DaVinciResolveScript Python module available. The script does not modify source
media or edit_timeline.json / resolve_assembly.json.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import subprocess
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
    return Fraction(int(num), int(den))


def find_media(media_dir: Path, filename: str) -> Path:
    direct = media_dir / filename
    if direct.is_file():
        return direct
    matches = [p for p in media_dir.rglob(filename) if p.is_file()]
    if not matches:
        raise FileNotFoundError(f"Source media not found: {filename}")
    if len(matches) > 1:
        raise RuntimeError("Multiple source files found for " + filename + ":\n" + "\n".join(str(p) for p in matches[:10]))
    return matches[0]


def frame_number(seconds: Fraction, fps: Fraction) -> int:
    # Resolve scripting uses integer source frames. Round to the nearest frame
    # while clamping negative values to the first source frame.
    value = seconds * fps
    return max(0, int(round(float(value))))


def resolve_clip_info(media_item: Any, source_start: int, source_end: int, record_frame: int, track_index: int = 1) -> dict[str, Any]:
    return {
        "mediaPoolItem": media_item,
        "startFrame": source_start,
        "endFrame": source_end,
        "recordFrame": record_frame,
        "trackIndex": track_index,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
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

    filenames = []
    seen = set()
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
        filenames.append(args.music_file.name)

    paths = [str(find_media(args.media_dir, name)) if name != args.music_file.name else str(args.music_file) for name in filenames] if args.music_file else [str(find_media(args.media_dir, name)) for name in filenames]
    imported = media_pool.ImportMedia(paths)
    if not imported:
        raise RuntimeError("Resolve imported no media")

    by_name = {item.GetName(): item for item in imported}
    missing = [name for name in filenames if name not in by_name]
    if missing:
        raise RuntimeError("Resolve did not return imported MediaPoolItem(s): " + ", ".join(missing))

    timeline_name = args.timeline_name or assembly.get("assemblyName", "AI Editorial Timeline")
    existing = media_pool.GetCurrentFolder()
    if existing is not root_folder:
        media_pool.SetCurrentFolder(root_folder)

    timeline = media_pool.CreateEmptyTimeline(timeline_name)
    if timeline is None:
        raise RuntimeError(f"Could not create timeline {timeline_name!r}")
    project.SetCurrentTimeline(timeline)

    # Ensure tracks exist for V1/A1/V2/A2. Adding both media types per clip
    # keeps the source camera audio paired with V1; B-roll and music are placed
    # on higher tracks where Resolve permits connected media placement.
    for _ in range(3):
        try:
            timeline.AddTrack("video")
        except Exception:
            break
    for _ in range(3):
        try:
            timeline.AddTrack("audio")
        except Exception:
            break

    record = 0
    placed_main = []
    for idx, item in enumerate(main_items, start=1):
        name = str(item["sourceFile"])
        media = by_name[name]
        path = find_media(args.media_dir, name)
        fps = probe_fps(path)
        start_seconds = ts(item["sourceStart"])
        end_seconds = ts(item["sourceEnd"])
        start_frame = frame_number(start_seconds, fps)
        end_frame = frame_number(end_seconds, fps)
        if end_frame <= start_frame:
            raise ValueError(f"mainTimeline[{idx}] has non-positive source frame range")
        info = resolve_clip_info(media, start_frame, end_frame, record, 1)
        placed_main.append(info)
        record += end_frame - start_frame

    if not media_pool.AppendToTimeline(placed_main):
        raise RuntimeError("Resolve failed to append main V1 clips")

    placed_broll = 0
    # For explicit V2 overlays, recordFrame is interpreted in timeline frames.
    # Build cumulative V1 record positions from the same source durations.
    spans = []
    record = 0
    for idx, item in enumerate(main_items, start=1):
        path = find_media(args.media_dir, str(item["sourceFile"]))
        fps = probe_fps(path)
        duration = frame_number(ts(item["sourceEnd"]) - ts(item["sourceStart"]), fps)
        spans.append((record, record + duration, item))
        record += duration

    broll_infos = []
    for b in assembly.get("brollOverlays", []):
        source = str(b["sourceFile"])
        if source not in by_name:
            continue
        timeline_start = ts(b["timelineStart"])
        timeline_frame = int(round(float(timeline_start) * args.timeline_fps))
        path = find_media(args.media_dir, source)
        fps = probe_fps(path)
        source_start = frame_number(ts(b["sourceStart"]), fps)
        source_end = frame_number(ts(b["sourceEnd"]), fps)
        if source_end <= source_start:
            continue
        broll_infos.append(resolve_clip_info(by_name[source], source_start, source_end, timeline_frame, 2))
    if broll_infos:
        if not media_pool.AppendToTimeline(broll_infos):
            raise RuntimeError("Resolve failed to append V2 B-roll")
        placed_broll = len(broll_infos)

    music_placed = 0
    if args.music_file:
        music_item = by_name[args.music_file.name]
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
            }
            if media_pool.AppendToTimeline([info]):
                music_placed += 1

    print(json.dumps({
        "status": "READY_IN_DAVINCI",
        "project": project.GetName(),
        "timeline": timeline.GetName(),
        "mainClips": len(main_items),
        "brollPlaced": placed_broll,
        "musicCuesPlaced": music_placed,
        "timelineFps": args.timeline_fps,
        "note": "Source ranges use relative media frames; embedded camera timecode is not used for conforming.",
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
