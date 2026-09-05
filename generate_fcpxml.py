#!/usr/bin/env python3
"""Generate an FCPXML timeline from edit_timeline.json for DaVinci Resolve."""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from urllib.parse import quote
import xml.etree.ElementTree as ET

TIMESCALE = 600

@dataclass(frozen=True)
class ClipSpec:
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

def ts(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    parts = str(value).strip().split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) != 3:
        raise ValueError(f"Invalid timestamp: {value!r}")
    h, m, s = (Fraction(part) for part in parts)
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

def find_media(media_dir: Path, name: str) -> Path:
    direct = media_dir / name
    if direct.is_file():
        return direct
    matches = [p for p in media_dir.rglob(name) if p.is_file()]
    if not matches:
        raise FileNotFoundError(f"Source media not found: {name} under {media_dir}")
    if len(matches) > 1:
        raise RuntimeError("Multiple source files found for " + name + ":\n" + "\n".join(f"  {p}" for p in matches[:10]))
    return matches[0]

def load(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("masterTimeline"), list):
        raise ValueError("edit_timeline.json must contain masterTimeline[]")
    return data

def clips(data: dict) -> list[ClipSpec]:
    result: list[ClipSpec] = []
    for index, item in enumerate(data["masterTimeline"], 1):
        if not isinstance(item, dict):
            continue
        if str(item.get("decision", "KEEP")).upper() == "REMOVE":
            continue
        source = str(item.get("sourceFile", "")).strip()
        if not source:
            raise ValueError(f"masterTimeline[{index}] missing sourceFile")
        result.append(ClipSpec(
            order=int(item.get("sequenceOrder", index)),
            section=str(item.get("editorialSection", "")),
            source=source,
            start=ts(item["sourceStart"]),
            end=ts(item["sourceEnd"]),
            decision=str(item.get("decision", "KEEP")),
            role=str(item.get("mediaRole", "")),
            events=tuple(str(x) for x in item.get("events", [])),
            reason=str(item.get("reason", "")),
        ))
    return sorted(result, key=lambda x: x.order)

def note(parent: ET.Element, text: str) -> None:
    ET.SubElement(parent, "note").text = text

def generate(data: dict, media_dir: Path, fps: int) -> tuple[str, dict]:
    items = clips(data)
    if not items:
        raise ValueError("masterTimeline has no usable items")

    root = ET.Element("fcpxml", {"version": "1.10"})
    resources = ET.SubElement(root, "resources")
    ET.SubElement(resources, "format", {
        "id": "r1",
        "name": f"FFVideoFormat{fps}p",
        "frameDuration": f"1/{fps}s",
        "width": "1920",
        "height": "1080",
    })

    media: dict[str, Path] = {}
    for item in items:
        media.setdefault(item.source, find_media(media_dir, item.source))

    refs: dict[str, str] = {}
    for i, (name, path) in enumerate(media.items(), start=2):
        ref = f"r{i}"
        refs[name] = ref
        duration = max((x.end for x in items if x.source == name), default=Fraction(1))
        ET.SubElement(resources, "asset", {
            "id": ref,
            "name": name,
            "src": file_url(path),
            "start": "0s",
            "duration": fx(duration),
            "hasVideo": "1",
            "hasAudio": "1",
            "format": "r1",
        })

    library = ET.SubElement(root, "library")
    event = ET.SubElement(library, "event", {"name": "AI Editorial Timeline"})
    project = ET.SubElement(event, "project", {"name": "AI Editorial Timeline"})
    sequence = ET.SubElement(project, "sequence", {
        "format": "r1",
        "tcStart": "0s",
        "tcFormat": "NDF",
        "audioRate": "48k",
    })
    spine = ET.SubElement(sequence, "spine")

    cursor = Fraction(0)
    for item in items:
        clip = ET.SubElement(spine, "asset-clip", {
            "name": item.source,
            "ref": refs[item.source],
            "offset": fx(cursor),
            "start": fx(item.start),
            "duration": fx(item.duration),
            "enabled": "1",
        })
        note(clip, " | ".join([
            f"sequenceOrder={item.order}",
            f"editorialSection={item.section}",
            f"decision={item.decision}",
            f"mediaRole={item.role}",
            f"events={','.join(item.events)}",
            f"reason={item.reason}",
        ]))
        cursor += item.duration

    metadata = ET.SubElement(root, "metadata")
    note(metadata, f"Generated from edit_timeline.json schemaVersion={data.get('schemaVersion')}")
    note(metadata, "Exact masterTimeline source IN/OUT values preserved.")
    note(metadata, "B-roll/music recommendations without explicit timeline placement were not guessed into the XML.")

    ET.indent(root, space="  ")
    xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode") + "\n"
    summary = {
        "masterTimelineItems": len(items),
        "sourceAssets": len(media),
        "timelineDuration": fmt(cursor),
        "timelineDurationSeconds": float(cursor),
        "fps": fps,
        "sourceMediaModified": False,
        "brollOverlayPlacement": "NOT_GUESSED_FROM_CURRENT_SCHEMA",
        "musicAsset": None,
        "warnings": [
            "Current edit_timeline.json does not provide timelineStart/lane coordinates for B-roll overlays.",
            "Current music sections identify footage suitable for music but do not identify a separate music audio file.",
            "This converter therefore builds the exact master story spine; a schema upgrade is needed for fully automatic V2/A2 placement.",
        ],
    }
    return xml, summary

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"))
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("edit_timeline.fcpxml"))
    parser.add_argument("--fps", type=int, default=30, choices=(24, 25, 30, 50, 60))
    args = parser.parse_args()
    try:
        xml, summary = generate(load(args.timeline), args.media_dir, args.fps)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(xml, encoding="utf-8")
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1
    print(json.dumps({"output": str(args.output.resolve()), **summary}, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
