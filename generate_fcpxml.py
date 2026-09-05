#!/usr/bin/env python3
"""Generate a DaVinci Resolve-compatible FCPXML timeline from edit_timeline.json.

The editorial JSON remains the source of truth. This generator turns the
chronological master timeline into a real edit structure and uses explicit
B-roll recommendations when they contain an exact speechRange + bestBroll
mapping. It never invents a B-roll mapping just because two clips share an
event label.

Tracks:
  V1 = primary story / talking-head / source footage
  V2 = connected B-roll overlays when an exact recommendation can be mapped
  A1 = source audio carried by the primary V1 clips
  A2 = optional external music bed(s) when music asset placement is supplied

Usage:
  python3 generate_fcpxml.py \
      --timeline edit_timeline.json \
      --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
      --output edit_timeline.fcpxml

Optional external music:
  --music-file "/path/to/music.m4a"

The current edit_timeline.json contains music-worthy source footage, but does
not contain a separate licensed music asset. Therefore the default output does
NOT invent an audio track. It adds music cue metadata so the editor knows where
a music bed belongs. A real music asset can be supplied explicitly.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote
import xml.etree.ElementTree as ET

TIMESCALE = 600
DEFAULT_FPS = 30


@dataclass(frozen=True)
class Clip:
    order: int
    section: str
    source: str
    start: Fraction
    end: Fraction
    decision: str
    role: str
    events: tuple[str, ...]
    reason: str

    @property
    def duration(self) -> Fraction:
        value = self.end - self.start
        if value <= 0:
            raise ValueError(f"Invalid source range: {self.source} {self.start}->{self.end}")
        return value


@dataclass(frozen=True)
class TimelinePlacement:
    clip: Clip
    timeline_start: Fraction


@dataclass(frozen=True)
class BrollPlacement:
    source: str
    start: Fraction
    duration: Fraction
    timeline_start: Fraction
    parent_order: int
    reason: str


def ts(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    text = str(value).strip()
    parts = text.split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) != 3:
        raise ValueError(f"Invalid timestamp: {value!r}")
    h, m, s = (Fraction(p) for p in parts)
    if not (0 <= m < 60 and 0 <= s < 60):
        raise ValueError(f"Invalid timestamp: {value!r}")
    return h * 3600 + m * 60 + s


def fmt(value: Fraction) -> str:
    total_ms = int(round(float(value) * 1000))
    h, rem = divmod(total_ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def fx(value: Fraction) -> str:
    return f"{int(round(float(value) * TIMESCALE))}/{TIMESCALE}s"


def file_url(path: Path) -> str:
    return "file://" + quote(str(path.expanduser().resolve()), safe="/:@-._~")


def note(parent: ET.Element, key: str, value: Any) -> None:
    child = ET.SubElement(parent, "note")
    child.set("key", key)
    child.set("value", str(value))


def find_media(media_dir: Path, filename: str) -> Path:
    direct = media_dir / filename
    if direct.is_file():
        return direct
    matches = [p for p in media_dir.rglob(filename) if p.is_file()]
    if not matches:
        raise FileNotFoundError(f"Source media not found: {filename!r} under {media_dir}")
    if len(matches) > 1:
        raise RuntimeError(
            "Multiple source files found for " + filename + ":\n" +
            "\n".join(f"  {p}" for p in matches[:10])
        )
    return matches[0]


def parse_range(value: Any) -> tuple[Fraction, Fraction]:
    if isinstance(value, dict):
        return ts(value["start"]), ts(value["end"])
    if isinstance(value, (list, tuple)) and len(value) == 2:
        return ts(value[0]), ts(value[1])
    raise ValueError(f"Unsupported range: {value!r}")


def parse_range_object(value: Any) -> tuple[str, Fraction, Fraction]:
    if not isinstance(value, dict):
        raise ValueError(f"Expected range object, got {value!r}")
    source = str(value.get("sourceFile") or value.get("file") or "").strip()
    start_value = value.get("sourceStart", value.get("start"))
    end_value = value.get("sourceEnd", value.get("end"))
    if not source or start_value is None or end_value is None:
        raise ValueError(f"Incomplete range object: {value!r}")
    return source, ts(start_value), ts(end_value)


def load(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("masterTimeline"), list):
        raise ValueError("edit_timeline.json must contain masterTimeline[]")
    return data


def build_clips(data: dict[str, Any]) -> list[Clip]:
    result: list[Clip] = []
    for index, item in enumerate(data["masterTimeline"], 1):
        if not isinstance(item, dict):
            continue
        decision = str(item.get("decision", "KEEP")).upper()
        if decision == "REMOVE":
            continue
        source = str(item.get("sourceFile", "")).strip()
        if not source:
            raise ValueError(f"masterTimeline[{index}] missing sourceFile")
        result.append(
            Clip(
                order=int(item.get("sequenceOrder", index)),
                section=str(item.get("editorialSection", "")),
                source=source,
                start=ts(item["sourceStart"]),
                end=ts(item["sourceEnd"]),
                decision=decision,
                role=str(item.get("mediaRole", "")),
                events=tuple(str(x) for x in item.get("events", [])),
                reason=str(item.get("reason", "")),
            )
        )
    result.sort(key=lambda x: x.order)
    return result


def build_spine(clips: Iterable[Clip]) -> list[TimelinePlacement]:
    placements: list[TimelinePlacement] = []
    cursor = Fraction(0)
    for clip in clips:
        placements.append(TimelinePlacement(clip=clip, timeline_start=cursor))
        cursor += clip.duration
    return placements


def range_overlap(a_start: Fraction, a_end: Fraction, b_start: Fraction, b_end: Fraction) -> Fraction:
    return max(Fraction(0), min(a_end, b_end) - max(a_start, b_start))


def extract_best_broll(rec: dict[str, Any]) -> tuple[str, Fraction, Fraction] | None:
    candidate = rec.get("bestBroll") or rec.get("best_broll")
    if isinstance(candidate, dict):
        try:
            return parse_range_object(candidate)
        except (KeyError, ValueError):
            return None
    if isinstance(candidate, list) and candidate and isinstance(candidate[0], dict):
        try:
            return parse_range_object(candidate[0])
        except (KeyError, ValueError):
            return None
    return None


def extract_speech_range(rec: dict[str, Any]) -> tuple[str, Fraction, Fraction] | None:
    value = rec.get("speechRange") or rec.get("speech_range")
    if value is None:
        return None
    try:
        return parse_range_object(value)
    except (KeyError, ValueError):
        return None


def build_broll_placements(
    data: dict[str, Any],
    spine: list[TimelinePlacement],
) -> tuple[list[BrollPlacement], list[str]]:
    recommendations = data.get("brollRecommendations", [])
    if not isinstance(recommendations, list):
        return [], ["brollRecommendations is not an array; no automatic B-roll overlays created."]

    placements: list[BrollPlacement] = []
    warnings: list[str] = []

    for rec_index, rec in enumerate(recommendations, 1):
        if not isinstance(rec, dict):
            continue
        speech = extract_speech_range(rec)
        best = extract_best_broll(rec)
        if not speech or not best:
            warnings.append(f"B-roll recommendation #{rec_index} lacks exact speechRange or bestBroll; left as a recommendation only.")
            continue

        speech_source, speech_start, speech_end = speech
        broll_source, broll_start, broll_end = best
        if broll_end <= broll_start:
            warnings.append(f"B-roll recommendation #{rec_index} has an invalid bestBroll range.")
            continue

        target: TimelinePlacement | None = None
        for candidate in spine:
            if candidate.clip.source != speech_source:
                continue
            overlap = range_overlap(
                candidate.clip.start,
                candidate.clip.end,
                speech_start,
                speech_end,
            )
            if overlap > 0:
                target = candidate
                break
        if target is None:
            warnings.append(
                f"B-roll recommendation #{rec_index} speech range does not map to an explicit masterTimeline clip; not auto-placed."
            )
            continue

        target_start = max(candidate for candidate in [speech_start, target.clip.start])
        target_end = min(speech_end, target.clip.end)
        duration = target_end - target_start
        broll_duration = broll_end - broll_start
        duration = min(duration, broll_duration)
        if duration <= 0:
            continue

        timeline_start = target.timeline_start + (target_start - target.clip.start)
        placements.append(
            BrollPlacement(
                source=broll_source,
                start=broll_start,
                duration=duration,
                timeline_start=timeline_start,
                parent_order=target.clip.order,
                reason=str(rec.get("reason") or rec.get("brollReason") or "Exact editorial B-roll recommendation"),
            )
        )

    # Avoid two exact recommendations fighting for the same lane/time.
    placements.sort(key=lambda p: (p.timeline_start, p.parent_order, p.source, p.start))
    accepted: list[BrollPlacement] = []
    occupied: list[tuple[Fraction, Fraction]] = []
    for placement in placements:
        start = placement.timeline_start
        end = start + placement.duration
        if any(range_overlap(start, end, a, b) > 0 for a, b in occupied):
            continue
        accepted.append(placement)
        occupied.append((start, end))
    return accepted, warnings


def build_music_cues(data: dict[str, Any]) -> list[dict[str, Any]]:
    raw = data.get("musicSections", [])
    if not isinstance(raw, list):
        return []
    cues: list[dict[str, Any]] = []
    for index, item in enumerate(raw, 1):
        if not isinstance(item, dict):
            continue
        source = str(item.get("sourceFile") or item.get("file") or "").strip()
        start = item.get("sourceStart", item.get("start"))
        end = item.get("sourceEnd", item.get("end"))
        if not source or start is None or end is None:
            continue
        try:
            source_start = ts(start)
            source_end = ts(end)
        except ValueError:
            continue
        cues.append({
            "id": str(item.get("musicSectionId") or item.get("id") or f"MUSIC_{index:03d}"),
            "sourceFile": source,
            "sourceStart": source_start,
            "sourceEnd": source_end,
            "role": str(item.get("recommendedMusicRole") or item.get("musicRole") or "MUSIC_MONTAGE"),
            "reason": str(item.get("reason") or item.get("musicReason") or "Music-driven visual section"),
        })
    return cues


def add_asset(resources: ET.Element, ref: str, name: str, path: Path, has_video: bool, has_audio: bool) -> None:
    attrs = {
        "id": ref,
        "name": name,
        "src": file_url(path),
        "start": "0s",
        "duration": "0s",
        "hasVideo": "1" if has_video else "0",
        "hasAudio": "1" if has_audio else "0",
    }
    ET.SubElement(resources, "asset", attrs)


def add_clip_notes(element: ET.Element, clip: Clip) -> None:
    note(element, "sequenceOrder", clip.order)
    note(element, "editorialSection", clip.section)
    note(element, "decision", clip.decision)
    note(element, "mediaRole", clip.role)
    note(element, "events", ", ".join(clip.events))
    note(element, "reason", clip.reason)


def generate(
    data: dict[str, Any],
    media_dir: Path,
    fps: int,
    music_file: Path | None,
) -> tuple[str, dict[str, Any]]:
    clips = build_clips(data)
    spine = build_spine(clips)
    if not spine:
        raise ValueError("masterTimeline contains no usable clips")

    broll, broll_warnings = build_broll_placements(data, spine)
    music_cues = build_music_cues(data)

    source_names = {placement.clip.source for placement in spine}
    source_names.update(item.source for item in broll)
    media: dict[str, Path] = {name: find_media(media_dir, name) for name in sorted(source_names)}

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
        add_asset(resources, ref, name, path, has_video=True, has_audio=True)

    music_ref: str | None = None
    if music_file:
        if not music_file.is_file():
            raise FileNotFoundError(f"Music file not found: {music_file}")
        music_ref = f"r{len(refs) + 2}"
        add_asset(resources, music_ref, music_file.name, music_file, has_video=False, has_audio=True)

    library = ET.SubElement(root, "library")
    event = ET.SubElement(library, "event", {"name": "AI Editorial Timeline"})
    project = ET.SubElement(event, "project", {"name": "AI Editorial Timeline"})
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
    spine_element = ET.SubElement(sequence, "spine")

    # Build the V1 spine. Connected V2 B-roll is attached to the main clip
    # containing the exact speechRange it was recommended for.
    for placement in spine:
        clip = ET.SubElement(
            spine_element,
            "asset-clip",
            {
                "name": placement.clip.source,
                "ref": refs[placement.clip.source],
                "offset": fx(placement.timeline_start),
                "start": fx(placement.clip.start),
                "duration": fx(placement.clip.duration),
                "enabled": "1",
            },
        )
        add_clip_notes(clip, placement.clip)
        for br in broll:
            if br.parent_order != placement.clip.order:
                continue
            overlay = ET.SubElement(
                clip,
                "asset-clip",
                {
                    "name": br.source,
                    "ref": refs[br.source],
                    "lane": "1",
                    "offset": fx(br.timeline_start - placement.timeline_start),
                    "start": fx(br.start),
                    "duration": fx(br.duration),
                    "enabled": "1",
                },
            )
            note(overlay, "track", "V2")
            note(overlay, "role", "B-ROLL_OVERLAY")
            note(overlay, "reason", br.reason)

    # Optional A2 music bed. The current JSON contains exact visual music
    # sections, but no licensed audio asset. If the caller supplies a music
    # asset we place it as one continuous bed; the cue list is preserved in
    # metadata so the editor can tune/trim it to the exact sections.
    if music_ref and music_cues:
        music_lane = ET.SubElement(spine_element, "asset-clip", {
            "name": music_file.name,
            "ref": music_ref,
            "lane": "-1",
            "offset": "0s",
            "start": "0s",
            "duration": fx(spine[-1].timeline_start + spine[-1].clip.duration),
            "enabled": "1",
        })
        note(music_lane, "track", "A2")
        note(music_lane, "role", "MUSIC_BED")
        note(music_lane, "mixInstruction", "Lower music under dialogue; keep full-volume only in music-driven sections.")

    metadata = ET.SubElement(root, "metadata")
    note(metadata, "generator", "generate_fcpxml.py")
    note(metadata, "sourceSchemaVersion", data.get("schemaVersion"))
    note(metadata, "v1", "Primary story spine")
    note(metadata, "v2", "Exact B-roll overlays only when speechRange + bestBroll mapping is explicit")
    note(metadata, "a1", "Source audio carried by V1 clips")
    note(metadata, "a2", "Optional external music bed; not invented unless supplied")
    note(metadata, "musicCueCount", len(music_cues))
    note(metadata, "brollOverlayCount", len(broll))

    ET.indent(root, space="  ")
    xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode") + "\n"

    total_duration = spine[-1].timeline_start + spine[-1].clip.duration
    summary = {
        "masterTimelineItems": len(spine),
        "sourceAssets": len(media),
        "brollOverlaysPlaced": len(broll),
        "musicCuesDetected": len(music_cues),
        "externalMusicAsset": str(music_file) if music_file else None,
        "timelineDuration": fmt(total_duration),
        "timelineDurationSeconds": float(total_duration),
        "fps": fps,
        "tracks": {"V1": "primary story", "V2": "exact B-roll overlays", "A1": "source audio", "A2": "optional music bed"},
        "sourceMediaModified": False,
        "warnings": broll_warnings + ([] if music_file or not music_cues else [
            "Music sections are visual cues only because edit_timeline.json does not contain a separate music audio asset.",
            "Pass --music-file to place an actual A2 music bed.",
        ]),
    }
    return xml, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"))
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("edit_timeline.fcpxml"))
    parser.add_argument("--fps", type=int, default=DEFAULT_FPS, choices=(24, 25, 30, 50, 60))
    parser.add_argument("--music-file", type=Path, default=None, help="Optional licensed music asset for the A2 bed")
    args = parser.parse_args()

    try:
        data = load(args.timeline)
        xml, summary = generate(data, args.media_dir, args.fps, args.music_file)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(xml, encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1

    print(json.dumps({"output": str(args.output.resolve()), **summary}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
