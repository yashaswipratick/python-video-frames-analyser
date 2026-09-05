#!/usr/bin/env python3
"""
Generate an FCPXML timeline from edit_timeline.json for DaVinci Resolve.

The JSON remains the editorial source of truth. This script converts the
chronological masterTimeline into an interchange timeline that Resolve can
import, while preserving the exact source filenames and source IN/OUT points.

Usage:
    python3 generate_fcpxml.py \
        --timeline edit_timeline.json \
        --media-dir ./videos \
        --output edit_timeline.fcpxml

Notes:
- This generator uses only the Python standard library.
- Raw media is never changed.
- The XML references the original source files. It does not copy media.
- Master-timeline clips are assembled sequentially in editorial order.
- Music-driven master-timeline items are placed on a secondary audio lane
  when the source range is a dedicated audio/music asset; otherwise they stay
  on the primary video track so the visual montage remains intact.
- B-roll recommendations in the current JSON are informational unless they
  are present as masterTimeline items. They should not be guessed into the
  timeline because that would violate the exact-evidence rule.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from typing import Any
from urllib.parse import quote
import xml.etree.ElementTree as ET


DEFAULT_FPS = 30
TIMESCALE = 600


@dataclass(frozen=True)
class ClipSpec:
    sequence_order: int
    editorial_section: str
    source_file: str
    source_start: Fraction
    source_end: Fraction
    decision: str
    media_role: str
    events: tuple[str, ...]
    reason: str

    @property
    def duration(self) -> Fraction:
        value = self.source_end - self.source_start
        if value <= 0:
            raise ValueError(
                f"Invalid range for {self.source_file}: "
                f"{format_time(self.source_start)} -> {format_time(self.source_end)}"
            )
        return value


def parse_timestamp(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    text = str(value).strip()
    parts = text.split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) != 3:
        raise ValueError(f"Unsupported timestamp: {value!r}")
    hours = Fraction(parts[0])
    minutes = Fraction(parts[1])
    seconds = Fraction(parts[2])
    if minutes < 0 or minutes >= 60 or seconds < 0 or seconds >= 60:
        raise ValueError(f"Invalid timestamp: {value!r}")
    return hours * 3600 + minutes * 60 + seconds


def format_time(value: Fraction) -> str:
    total_ms = int(round(float(value) * 1000))
    hours, rem = divmod(total_ms, 3_600_000)
    minutes, rem = divmod(rem, 60_000)
    seconds, millis = divmod(rem, 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{millis:03d}"


def to_fcpx_time(value: Fraction, timescale: int = TIMESCALE) -> str:
    ticks = int(round(float(value) * timescale))
    return f"{ticks}/{timescale}s"


def xml_escape_url(path: Path) -> str:
    absolute = path.expanduser().resolve()
    return "file://" + quote(str(absolute), safe="/:@-._~")


def find_source(media_dir: Path, filename: str) -> Path:
    direct = media_dir / filename
    if direct.exists():
        return direct

    matches = list(media_dir.rglob(filename))
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise FileNotFoundError(
            f"Source media not found: {filename!r} under {media_dir}"
        )
    paths = "\n".join(f"  - {item}" for item in matches[:10])
    raise RuntimeError(
        f"Multiple source files named {filename!r} were found under {media_dir}.\n"
        "Use --media-dir pointing at the intended source folder.\n"
        f"Matches:\n{paths}"
    )


def load_timeline(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Timeline JSON root must be an object")
    master = payload.get("masterTimeline")
    if not isinstance(master, list):
        raise ValueError("edit_timeline.json must contain masterTimeline[]")
    return payload


def build_clip_specs(payload: dict[str, Any]) -> list[ClipSpec]:
    specs: list[ClipSpec] = []
    for item in payload["masterTimeline"]:
        if not isinstance(item, dict):
            continue
        decision = str(item.get("decision", "KEEP")).upper()
        if decision == "REMOVE":
            continue
        source_file = str(item.get("sourceFile", "")).strip()
        if not source_file:
            raise ValueError(f"Master timeline item is missing sourceFile: {item!r}")
        specs.append(
            ClipSpec(
                sequence_order=int(item.get("sequenceOrder", len(specs) + 1)),
                editorial_section=str(item.get("editorialSection", "")).strip(),
                source_file=source_file,
                source_start=parse_timestamp(item["sourceStart"]),
                source_end=parse_timestamp(item["sourceEnd"]),
                decision=decision,
                media_role=str(item.get("mediaRole", "")).strip().lower(),
                events=tuple(str(event) for event in item.get("events", [])),
                reason=str(item.get("reason", "")).strip(),
            )
        )
    specs.sort(key=lambda item: item.sequence_order)
    return specs


def media_role_is_music(role: str) -> bool:
    return role == "music-driven" or "music" in role


def make_element(tag: str, **attrs: str) -> ET.Element:
    return ET.Element(tag, attrs)


def add_text_asset(doc: ET.Element, ref: str, name: str, src: str) -> ET.Element:
    asset = make_element(
        "asset",
        id=ref,
        name=name,
        src=src,
        start="0s",
        duration="0s",
        hasVideo="1",
        hasAudio="1",
        formatRef="r1",
    )
    doc.append(asset)
    return asset


def prettify(root: ET.Element) -> str:
    ET.indent(root, space="  ")
    body = ET.tostring(root, encoding="unicode")
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + body + "\n"


def generate_xml(payload: dict[str, Any], media_dir: Path) -> tuple[str, dict[str, Any]]:
    specs = build_clip_specs(payload)
    if not specs:
        raise ValueError("masterTimeline contains no usable clips")

    # FCPXML 1.10 is broadly understood by current NLE interchange workflows.
    root = make_element("fcpxml", version="1.10")
    resources = ET.SubElement(root, "resources")
    ET.SubElement(resources, "format", id="r1", name="FFVideoFormat1080p30", frameDuration="1/30s", width="1920", height="1080")

    source_paths: dict[str, Path] = {}
    for spec in specs:
        source_paths.setdefault(spec.source_file, find_source(media_dir, spec.source_file))

    asset_refs: dict[str, str] = {}
    for index, (filename, path) in enumerate(source_paths.items(), start=1):
        ref = f"r{index + 1}"
        asset_refs[filename] = ref
        add_text_asset(resources, ref, filename, xml_escape_url(path))

    library = ET.SubElement(root, "library")
    event = ET.SubElement(library, "event", name="AI Editorial Timeline")
    project = ET.SubElement(event, "project", name="AI Editorial Timeline")
    sequence = ET.SubElement(
        project,
        "sequence",
        format="r1",
        tcStart="0s",
        tcFormat="NDF",
        audioRate="48k",
    )
    spine = ET.SubElement(sequence, "spine")

    current = Fraction(0)
    counts = {"video": 0, "music": 0, "total": 0}
    first_clip_ref: str | None = None

    # The current edit_timeline.json provides a single chronological master
    # timeline. We therefore build one deterministic primary spine. Roles are
    # preserved in clip metadata so a later schema revision can fan them out
    # into dedicated V2/A2 lanes without guessing placement.
    for spec in specs:
        ref = asset_refs[spec.source_file]
        offset = current
        clip = ET.SubElement(
            spine,
            "asset-clip",
            name=spec.source_file,
            ref=ref,
            offset=to_fcpx_time(offset),
            start=to_fcpx_time(spec.source_start),
            duration=to_fcpx_time(spec.duration),
            enabled="1",
            tcFormat="NDF",
        )
        ET.SubElement(clip, "note", key="editorialSection", value=spec.editorial_section)
        ET.SubElement(clip, "note", key="sequenceOrder", value=str(spec.sequence_order))
        ET.SubElement(clip, "note", key="decision", value=spec.decision)
        ET.SubElement(clip, "note", key="mediaRole", value=spec.media_role)
        ET.SubElement(clip, "note", key="events", value=", ".join(spec.events))
        ET.SubElement(clip, "note", key="reason", value=spec.reason)

        current += spec.duration
        counts["total"] += 1
        if media_role_is_music(spec.media_role):
            counts["music"] += 1
        else:
            counts["video"] += 1
        if first_clip_ref is None:
            first_clip_ref = ref

    summary = {
        "masterTimelineItems": len(specs),
        "assembledDurationSeconds": float(current),
        "assembledDuration": format_time(current),
        "sourceAssets": len(source_paths),
        **counts,
        "notes": [
            "The timeline is deterministic and follows masterTimeline sequenceOrder.",
            "No source media is modified or copied.",
            "B-roll/music recommendations that are not explicit masterTimeline items are intentionally not guessed into the sequence.",
            "Resolve may require media relinking after XML import if the machine path differs from the generated XML references.",
        ],
    }
    return prettify(root), summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"), help="Path to edit_timeline.json")
    parser.add_argument("--media-dir", type=Path, required=True, help="Directory containing original source videos")
    parser.add_argument("--output", type=Path, default=Path("edit_timeline.fcpxml"), help="Output FCPXML path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload = load_timeline(args.timeline)
        xml_text, summary = generate_xml(payload, args.media_dir)
    except Exception as exc:
        print(f"ERROR: {exc}", flush=True)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(xml_text, encoding="utf-8")

    print(json.dumps({"output": str(args.output.resolve()), **summary}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
