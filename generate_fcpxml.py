#!/usr/bin/env python3
"""Generate a DaVinci Resolve/FCPXML timeline from the executable assembly.

Preferred input is resolve_assembly.json. edit_timeline.json remains the
editorial source of truth; resolve_assembly.json is the machine-executable
assembly plan with explicit V1/V2/A2 placement.

Tracks:
  V1 = primary story
  V2 = connected B-roll overlays
  A1 = original source audio carried by V1 clips
  A2 = optional licensed external music bed

Example:
  python3 generate_fcpxml.py \
    --timeline edit_timeline.json \
    --assembly resolve_assembly.json \
    --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
    --output edit_timeline.fcpxml

Add licensed music explicitly:
  python3 generate_fcpxml.py ... --music-file "/path/to/track.m4a"

The generator never modifies or copies original source media.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from typing import Any
from urllib.parse import quote
import xml.etree.ElementTree as ET

TIMESCALE = 600
DEFAULT_FPS = 30


@dataclass(frozen=True)
class MainClip:
    order: int
    section: str
    source: str
    start: Fraction
    end: Fraction
    role: str
    reason: str

    @property
    def duration(self) -> Fraction:
        return self.end - self.start


@dataclass(frozen=True)
class Overlay:
    ident: str
    timeline_start: Fraction
    source: str
    source_start: Fraction
    source_end: Fraction
    reason: str

    @property
    def duration(self) -> Fraction:
        return self.source_end - self.source_start


@dataclass(frozen=True)
class MusicCue:
    ident: str
    timeline_start: Fraction
    duration: Fraction
    role: str


@dataclass(frozen=True)
class ParentSpan:
    clip: MainClip
    timeline_start: Fraction

    @property
    def timeline_end(self) -> Fraction:
        return self.timeline_start + self.clip.duration


def ts(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    parts = str(value).strip().split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) != 3:
        raise ValueError(f"Invalid timestamp: {value!r}")
    h, m, s = (Fraction(p) for p in parts)
    if not (0 <= m < 60 and 0 <= s < 60):
        raise ValueError(f"Invalid timestamp: {value!r}")
    return h * 3600 + m * 60 + s


def fx(value: Fraction) -> str:
    return f"{int(round(float(value) * TIMESCALE))}/{TIMESCALE}s"


def fmt(value: Fraction) -> str:
    total_ms = int(round(float(value) * 1000))
    h, rem = divmod(total_ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def file_url(path: Path) -> str:
    return "file://" + quote(str(path.expanduser().resolve()), safe="/:@-._~")


def find_media(media_dir: Path, filename: str) -> Path:
    direct = media_dir / filename
    if direct.is_file():
        return direct
    matches = [p for p in media_dir.rglob(filename) if p.is_file()]
    if not matches:
        raise FileNotFoundError(f"Source media not found: {filename!r} under {media_dir}")
    if len(matches) > 1:
        raise RuntimeError(
            f"Multiple source files found for {filename!r}:\n" +
            "\n".join(f"  {p}" for p in matches[:10])
        )
    return matches[0]


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def build_main_clips(data: dict[str, Any]) -> list[MainClip]:
    result: list[MainClip] = []
    for index, item in enumerate(data.get("mainTimeline", []), start=1):
        if not isinstance(item, dict):
            continue
        start = ts(item["sourceStart"])
        end = ts(item["sourceEnd"])
        if end <= start:
            raise ValueError(f"mainTimeline[{index}] has non-positive source range")
        result.append(
            MainClip(
                order=int(item.get("order", index)),
                section=str(item.get("section", "EDIT")),
                source=str(item["sourceFile"]),
                start=start,
                end=end,
                role=str(item.get("mediaRole", "speech-driven")),
                reason=str(item.get("reason", "")),
            )
        )
    result.sort(key=lambda item: item.order)
    if not result:
        raise ValueError("resolve_assembly.json contains no usable mainTimeline clips")
    return result


def build_spans(clips: list[MainClip]) -> list[ParentSpan]:
    spans: list[ParentSpan] = []
    cursor = Fraction(0)
    for clip in clips:
        spans.append(ParentSpan(clip=clip, timeline_start=cursor))
        cursor += clip.duration
    return spans


def build_overlays(data: dict[str, Any]) -> list[Overlay]:
    raw = data.get("brollOverlays", [])
    if not isinstance(raw, list):
        return []
    result: list[Overlay] = []
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, dict):
            continue
        overlay = Overlay(
            ident=str(item.get("id", f"B{index:03d}")),
            timeline_start=ts(item["timelineStart"]),
            source=str(item["sourceFile"]),
            source_start=ts(item["sourceStart"]),
            source_end=ts(item["sourceEnd"]),
            reason=str(item.get("reason", "Exact editorial B-roll placement")),
        )
        if overlay.duration > 0:
            result.append(overlay)
    return result


def build_music_cues(data: dict[str, Any]) -> list[MusicCue]:
    raw = data.get("musicCues", [])
    if not isinstance(raw, list):
        return []
    result: list[MusicCue] = []
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, dict):
            continue
        cue = MusicCue(
            ident=str(item.get("id", f"M{index:03d}")),
            timeline_start=ts(item["timelineStart"]),
            duration=ts(item["duration"]),
            role=str(item.get("role", "MUSIC")),
        )
        if cue.duration > 0:
            result.append(cue)
    return result


def parent_for_time(spans: list[ParentSpan], timeline_start: Fraction) -> ParentSpan | None:
    for span in spans:
        if span.timeline_start <= timeline_start < span.timeline_end:
            return span
    return None


def add_asset(
    resources: ET.Element,
    ref: str,
    name: str,
    path: Path,
    *,
    video: bool,
    audio: bool,
    duration: Fraction | None,
) -> None:
    attrs = {
        "id": ref,
        "name": name,
        "src": file_url(path),
        "start": "0s",
        "duration": fx(duration) if duration and duration > 0 else "0s",
        "hasVideo": "1" if video else "0",
        "hasAudio": "1" if audio else "0",
    }
    ET.SubElement(resources, "asset", attrs)


def source_duration_requirements(
    main: list[MainClip], overlays: list[Overlay]
) -> dict[str, Fraction]:
    result: dict[str, Fraction] = {}
    for item in main:
        result[item.source] = max(result.get(item.source, Fraction(0)), item.end)
    for item in overlays:
        result[item.source] = max(result.get(item.source, Fraction(0)), item.source_end)
    return result


def attach_overlay(
    parent: ParentSpan,
    overlay: Overlay,
) -> tuple[Fraction, Fraction] | None:
    relative = overlay.timeline_start - parent.timeline_start
    if relative < 0 or relative >= parent.clip.duration:
        return None
    duration = min(overlay.duration, parent.clip.duration - relative)
    if duration <= 0:
        return None
    return relative, duration


def generate(
    assembly: dict[str, Any],
    media_dir: Path,
    fps: int,
    music_file: Path | None,
) -> tuple[str, dict[str, Any]]:
    main = build_main_clips(assembly)
    spans = build_spans(main)
    overlays = build_overlays(assembly)
    music_cues = build_music_cues(assembly)
    warnings: list[str] = []

    durations = source_duration_requirements(main, overlays)
    media = {name: find_media(media_dir, name) for name in sorted(durations)}

    root = ET.Element("fcpxml", {"version": "1.10"})
    resources = ET.SubElement(root, "resources")
    ET.SubElement(
        resources,
        "format",
        {
            "id": "r1",
            "name": f"FFVideoFormat{fps}p",
            "frameDuration": f"1/{fps}s",
            "width": "1920",
            "height": "1080",
        },
    )

    refs: dict[str, str] = {}
    for index, (name, path) in enumerate(media.items(), start=2):
        ref = f"r{index}"
        refs[name] = ref
        add_asset(
            resources,
            ref,
            name,
            path,
            video=True,
            audio=True,
            duration=durations[name],
        )

    music_ref: str | None = None
    if music_file:
        if not music_file.is_file():
            raise FileNotFoundError(f"Music file not found: {music_file}")
        music_ref = f"r{len(refs) + 2}"
        music_duration = max((cue.duration for cue in music_cues), default=Fraction(1))
        add_asset(
            resources,
            music_ref,
            music_file.name,
            music_file,
            video=False,
            audio=True,
            duration=music_duration,
        )

    library = ET.SubElement(root, "library")
    event = ET.SubElement(
        library,
        "event",
        {"name": str(assembly.get("assemblyName", "AI Editorial Timeline"))},
    )
    project = ET.SubElement(
        event,
        "project",
        {"name": str(assembly.get("assemblyName", "AI Editorial Timeline"))},
    )
    sequence = ET.SubElement(
        project,
        "sequence",
        {
            "format": "r1",
            "tcStart": "0s",
            "tcFormat": "NDF",
            "audioRate": "48k",
        },
    )
    spine = ET.SubElement(sequence, "spine")

    placed_overlays = 0
    placed_music = 0

    for span in spans:
        main_clip = ET.SubElement(
            spine,
            "asset-clip",
            {
                "name": f"{span.clip.order:02d} {span.clip.section} | {span.clip.source}",
                "ref": refs[span.clip.source],
                "offset": fx(span.timeline_start),
                "start": fx(span.clip.start),
                "duration": fx(span.clip.duration),
                "enabled": "1",
            },
        )

        # V2 B-roll is connected directly to the V1 clip containing its
        # timelineStart. This creates a real overlay rather than a note for
        # the editor to place manually.
        for overlay in overlays:
            placement = attach_overlay(span, overlay)
            if placement is None:
                continue
            relative_start, duration = placement
            overlay_clip = ET.SubElement(
                main_clip,
                "asset-clip",
                {
                    "name": f"V2 {overlay.ident} | {overlay.source}",
                    "ref": refs[overlay.source],
                    "lane": "1",
                    "offset": fx(relative_start),
                    "start": fx(overlay.source_start),
                    "duration": fx(duration),
                    "enabled": "1",
                },
            )
            # Preserve A1 dialogue; B-roll camera audio is muted.
            ET.SubElement(overlay_clip, "adjust-volume", {"amount": "-96dB"})
            placed_overlays += 1

        # A2 optional music. A music cue starts only when it falls inside
        # this parent V1 clip; crossing cues are truncated at the boundary.
        if music_ref:
            for cue in music_cues:
                if not (span.timeline_start <= cue.timeline_start < span.timeline_end):
                    continue
                relative_start = cue.timeline_start - span.timeline_start
                duration = min(cue.duration, span.timeline_end - cue.timeline_start)
                if duration <= 0:
                    continue
                music_clip = ET.SubElement(
                    main_clip,
                    "asset-clip",
                    {
                        "name": f"A2 {cue.ident} | {music_file.name}",
                        "ref": music_ref,
                        "lane": "-1",
                        "offset": fx(relative_start),
                        "start": "0s",
                        "duration": fx(duration),
                        "enabled": "1",
                    },
                )
                ET.SubElement(music_clip, "adjust-volume", {"amount": "-12dB"})
                placed_music += 1

    total_duration = spans[-1].timeline_end

    for overlay in overlays:
        if overlay.timeline_start < 0 or overlay.timeline_start >= total_duration:
            warnings.append(f"{overlay.ident} lies outside the V1 timeline and was not placed")
            continue
        parent = parent_for_time(spans, overlay.timeline_start)
        if parent and overlay.timeline_start + overlay.duration > parent.timeline_end:
            warnings.append(f"{overlay.ident} crosses a V1 boundary and was truncated")

    if music_cues and not music_ref:
        warnings.append(
            "Music cues are defined but no audio file was supplied. Use --music-file with a licensed track to populate A2."
        )

    metadata = ET.SubElement(root, "metadata")
    for key, value in {
        "assemblyName": assembly.get("assemblyName", "AI Editorial Timeline"),
        "generator": "generate_fcpxml.py",
        "V1": "Primary story spine",
        "V2": "Explicit B-roll overlays",
        "A1": "Original source audio",
        "A2": "Optional licensed music",
        "brollOverlayCount": placed_overlays,
        "musicCueCount": len(music_cues),
        "musicClipsPlaced": placed_music,
    }.items():
        ET.SubElement(metadata, "md", {"key": str(key), "value": str(value)})

    ET.indent(root, space="  ")
    xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode") + "\n"

    return xml, {
        "assemblyName": assembly.get("assemblyName"),
        "mainTimelineItems": len(main),
        "sourceAssets": len(media),
        "brollOverlaysRequested": len(overlays),
        "brollOverlaysPlaced": placed_overlays,
        "musicCues": len(music_cues),
        "musicClipsPlaced": placed_music,
        "musicAssetPlaced": bool(music_ref),
        "timelineDuration": fmt(total_duration),
        "timelineDurationSeconds": float(total_duration),
        "fps": fps,
        "tracks": {"V1": "primary story", "V2": "connected B-roll", "A1": "source dialogue/natural sound", "A2": "optional external music"},
        "rawOriginalsModified": False,
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"))
    parser.add_argument("--assembly", type=Path, default=Path("resolve_assembly.json"))
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("edit_timeline.fcpxml"))
    parser.add_argument("--fps", type=int, default=DEFAULT_FPS, choices=(24, 25, 30, 50, 60))
    parser.add_argument("--music-file", type=Path, default=None)
    args = parser.parse_args()

    try:
        editorial = load_json(args.timeline)
        assembly = load_json(args.assembly)
        if not isinstance(assembly.get("mainTimeline"), list):
            raise ValueError("resolve_assembly.json must contain mainTimeline[]")
        if assembly.get("sourceTimeline") and assembly["sourceTimeline"] != args.timeline.name:
            print(
                f"WARNING: assembly sourceTimeline={assembly['sourceTimeline']!r} differs from {args.timeline.name!r}"
            )
        xml, summary = generate(assembly, args.media_dir, args.fps, args.music_file)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(xml, encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1

    summary["editorialSchemaVersion"] = editorial.get("schemaVersion")
    summary["assemblySchemaVersion"] = assembly.get("schemaVersion")
    print(json.dumps({"output": str(args.output.resolve()), **summary}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
