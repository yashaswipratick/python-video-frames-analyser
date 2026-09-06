#!/usr/bin/env python3
"""Build the current editorial assembly inside a running DaVinci Resolve Free instance.

Run this script from Resolve's built-in Workspace > Scripts menu or Console.
It intentionally uses the in-process `app.GetResolve()` connection, which is the
Free-compatible internal scripting route. It does not use scriptapp() or any
external Resolve connection.

The script reads resolve_free_native_config.json for this machine's paths and
resolve_assembly.json for the executable editorial assembly. It imports the
actual source media into the current Resolve project's Media Pool and creates
V1/V2/A1/A2 using explicit source and record frame ranges.

It never modifies source media, edit_timeline.json, or resolve_assembly.json.
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import traceback
from fractions import Fraction
from pathlib import Path

DEFAULT_CONFIG = Path("/Users/yashaswipratick/projects/python-video-frames-analyser/resolve_free_native_config.json")


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


def frame_number(seconds: Fraction, fps: Fraction) -> int:
    return max(0, int(round(float(seconds * fps))))


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


def prop_int(item, key: str, default: int = 0) -> int:
    try:
        value = item.GetClipProperty(key)
        if isinstance(value, dict):
            value = value.get(key)
        return int(value)
    except Exception:
        return default


def source_bounds(media_item, start_seconds: Fraction, end_seconds: Fraction, media_path: Path):
    fps = probe_fps(media_path)
    rel_start = frame_number(start_seconds, fps)
    rel_end = frame_number(end_seconds, fps)
    if rel_end <= rel_start:
        raise ValueError(f"Non-positive source range: {start_seconds} -> {end_seconds}")

    # Resolve's MediaPool clip properties expose the media's source Start frame.
    # Use it when available so clips with camera timecode remain addressable by
    # Resolve's own native source-frame coordinate system.
    source_base = prop_int(media_item, "Start", 0)
    return source_base + rel_start, source_base + rel_end - 1, rel_end - rel_start, fps


def append_checked(media_pool, clip_info, label: str):
    result = media_pool.AppendToTimeline([clip_info])
    if not result:
        raise RuntimeError(f"Resolve failed to place {label}")
    return result


def ensure_track(timeline, track_type: str, desired_count: int):
    # New Resolve timelines normally start with one video and one audio track.
    # Add tracks until the requested count is reached.
    try:
        current = int(timeline.GetTrackCount(track_type))
    except Exception:
        current = 1
    while current < desired_count:
        if not timeline.AddTrack(track_type):
            raise RuntimeError(f"Could not add {track_type} track")
        current += 1


def main():
    config_path = DEFAULT_CONFIG
    config = json.loads(config_path.read_text(encoding="utf-8"))
    assembly_path = Path(config["assembly"])
    media_dir = Path(config["mediaDir"])
    music_file = Path(config["musicFile"])
    timeline_name = str(config.get("timelineName", "Kaiwara_Kailasagiri_Final_Edit"))
    timeline_fps = int(config.get("timelineFrameRate", 30))
    width = int(config.get("timelineWidth", 1920))
    height = int(config.get("timelineHeight", 1080))

    assembly = json.loads(assembly_path.read_text(encoding="utf-8"))
    main_items = assembly.get("mainTimeline")
    if not isinstance(main_items, list) or not main_items:
        raise ValueError("resolve_assembly.json must contain non-empty mainTimeline[]")

    # Free-compatible internal connection: Resolve provides `app` to scripts
    # launched from its Scripts/Console environment.
    if "app" not in globals():
        raise RuntimeError("This script must be run from DaVinci Resolve's Workspace > Scripts or Console, not from Terminal.")
    resolve = app.GetResolve()  # type: ignore[name-defined]
    if resolve is None:
        raise RuntimeError("Could not obtain the running DaVinci Resolve instance")

    project_manager = resolve.GetProjectManager()
    project = project_manager.GetCurrentProject()
    if project is None:
        raise RuntimeError("Open a Resolve project first, then run this script again.")

    project.SetSetting("timelineFrameRate", str(timeline_fps))
    project.SetSetting("timelineResolutionWidth", str(width))
    project.SetSetting("timelineResolutionHeight", str(height))

    media_pool = project.GetMediaPool()
    root_folder = media_pool.GetRootFolder()
    media_pool.SetCurrentFolder(root_folder)

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
    if music_file.is_file() and music_file.name not in seen:
        filenames.append(music_file.name)

    paths = []
    for name in filenames:
        paths.append(str(music_file if name == music_file.name else find_media(media_dir, name)))

    imported = media_pool.ImportMedia(paths)
    if not imported:
        raise RuntimeError("Resolve imported no media. Check the Media Storage permission and source folder.")

    # Resolve may omit already-imported items from ImportMedia's return. Rebuild
    # the lookup from the root folder after import, recursively where available.
    by_name = {}
    for item in root_folder.GetClipList() or []:
        by_name[item.GetName()] = item
    for item in imported:
        by_name[item.GetName()] = item

    missing = [name for name in filenames if name not in by_name]
    if missing:
        raise RuntimeError("Resolve Media Pool is missing: " + ", ".join(missing))

    timeline = media_pool.CreateEmptyTimeline(timeline_name)
    if timeline is None:
        raise RuntimeError(f"Could not create timeline {timeline_name!r}")
    project.SetCurrentTimeline(timeline)

    ensure_track(timeline, "video", 2)
    ensure_track(timeline, "audio", 2)

    record_frame = 0
    placed_main = 0
    placed_audio = 0

    # Main story: V1 + matching source audio on A1, both sharing the exact
    # source range and record position.
    for idx, item in enumerate(main_items, start=1):
        name = str(item["sourceFile"])
        media_item = by_name[name]
        path = find_media(media_dir, name)
        source_start, source_end, duration_frames, _ = source_bounds(
            media_item,
            ts(item["sourceStart"]),
            ts(item["sourceEnd"]),
            path,
        )

        append_checked(media_pool, {
            "mediaPoolItem": media_item,
            "startFrame": source_start,
            "endFrame": source_end,
            "recordFrame": record_frame,
            "trackIndex": 1,
            "mediaType": 1,
        }, f"V1 mainTimeline[{idx}]")
        placed_main += 1

        append_checked(media_pool, {
            "mediaPoolItem": media_item,
            "startFrame": source_start,
            "endFrame": source_end,
            "recordFrame": record_frame,
            "trackIndex": 1,
            "mediaType": 2,
        }, f"A1 mainTimeline[{idx}]")
        placed_audio += 1

        record_frame += int(round(duration_frames * timeline_fps / float(probe_fps(path))))

    # V2 explicit B-roll. recordFrame is in timeline frames.
    placed_broll = 0
    for b in assembly.get("brollOverlays", []):
        source = str(b["sourceFile"])
        media_item = by_name.get(source)
        if media_item is None:
            continue
        path = find_media(media_dir, source)
        source_start, source_end, _, _ = source_bounds(
            media_item,
            ts(b["sourceStart"]),
            ts(b["sourceEnd"]),
            path,
        )
        record = frame_number(ts(b["timelineStart"]), Fraction(timeline_fps, 1))
        append_checked(media_pool, {
            "mediaPoolItem": media_item,
            "startFrame": source_start,
            "endFrame": source_end,
            "recordFrame": record,
            "trackIndex": 2,
            "mediaType": 1,
        }, f"V2 {b.get('id', 'BROLL')}")
        placed_broll += 1

    # A2 music-only cues. Music is independent of source-video timecode.
    placed_music = 0
    if music_file.is_file() and music_file.name in by_name:
        music_item = by_name[music_file.name]
        try:
            music_duration = int(music_item.GetDuration())
        except Exception:
            music_duration = 0
        for cue in assembly.get("musicCues", []):
            start = frame_number(ts(cue["timelineStart"]), Fraction(timeline_fps, 1))
            duration = frame_number(ts(cue["duration"]), Fraction(timeline_fps, 1))
            if duration <= 0:
                continue
            end = min(duration - 1, max(0, music_duration - 1)) if music_duration else duration - 1
            if end < 0:
                continue
            append_checked(media_pool, {
                "mediaPoolItem": music_item,
                "startFrame": 0,
                "endFrame": end,
                "recordFrame": start,
                "trackIndex": 2,
                "mediaType": 2,
            }, f"A2 {cue.get('id', 'MUSIC')}")
            placed_music += 1

    report = {
        "status": "RESOLVE_NATIVE_BUILD_COMPLETE",
        "project": project.GetName(),
        "timeline": timeline.GetName(),
        "mainClipsPlaced": placed_main,
        "mainAudioClipsPlaced": placed_audio,
        "brollClipsPlaced": placed_broll,
        "musicCuesPlaced": placed_music,
        "sourceAssetsImported": len(filenames),
        "timelineFrameRate": timeline_fps,
        "resolution": f"{width}x{height}",
        "editorialSource": str(assembly_path),
        "sourceMediaDirectory": str(media_dir),
        "originalMediaModified": False,
    }
    print(json.dumps(report, indent=2))
    return report


try:
    main()
except Exception as exc:
    print("RESOLVE_NATIVE_BUILD_ERROR:")
    print(str(exc))
    traceback.print_exc()
