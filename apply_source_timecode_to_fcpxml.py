#!/usr/bin/env python3
"""Apply embedded camera source timecode to an existing FCPXML timeline.

The editorial ranges remain relative to each source clip. This pass translates
those relative source positions into the actual source-media timecode Resolve
uses when conforming footage.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import xml.etree.ElementTree as ET
from fractions import Fraction
from pathlib import Path


def tc_to_seconds(value: str, fps: int) -> Fraction:
    parts = value.strip().split(":")
    if len(parts) != 4:
        raise ValueError(f"Unsupported source timecode {value!r}; expected HH:MM:SS:FF")
    hours, minutes, seconds, frames = (int(part) for part in parts)
    if not (0 <= minutes < 60 and 0 <= seconds < 60 and 0 <= frames < fps):
        raise ValueError(f"Invalid source timecode {value!r} for {fps} fps")
    return Fraction(hours * 3600 + minutes * 60 + seconds) + Fraction(frames, fps)


def probe_timecode(path: Path) -> str | None:
    command = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format_tags=timecode:stream_tags=timecode",
        "-of", "json",
        str(path),
    ]
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    data = json.loads(completed.stdout or "{}")

    streams = data.get("streams") or []
    for stream in streams:
        tags = stream.get("tags") or {}
        value = tags.get("timecode")
        if value:
            return str(value)

    tags = (data.get("format") or {}).get("tags") or {}
    value = tags.get("timecode")
    return str(value) if value else None


def seconds_attr(value: str) -> Fraction:
    text = value.strip()
    if text.endswith("s"):
        text = text[:-1]
    if "/" in text:
        numerator, denominator = text.split("/", 1)
        return Fraction(numerator) / Fraction(denominator)
    return Fraction(text)


def fx(value: Fraction, timescale: int = 600) -> str:
    return f"{int(round(float(value) * timescale))}/{timescale}s"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fcpxml", type=Path, required=True)
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--fps", type=int, default=30)
    args = parser.parse_args()

    tree = ET.parse(args.fcpxml)
    root = tree.getroot()
    resources = root.find("resources")
    if resources is None:
        raise ValueError("FCPXML has no resources element")

    assets: dict[str, tuple[str, Path, Fraction]] = {}
    warnings: list[str] = []

    for asset in resources.findall("asset"):
        ref = asset.get("id")
        if not ref or asset.get("hasVideo") != "1":
            continue
        media_rep = asset.find("media-rep")
        src = media_rep.get("src") if media_rep is not None else None
        if not src:
            warnings.append(f"{ref}: no original-media src; left unchanged")
            continue

        # FCPXML stores a file URL. Use the decoded path only for the local
        # source lookup; the XML src itself is preserved.
        path_text = src
        if path_text.startswith("file://"):
            path_text = path_text[7:]
        path = Path(path_text)
        if not path.is_file():
            candidate = args.media_dir / path.name
            if candidate.is_file():
                path = candidate
            else:
                warnings.append(f"{ref}: source file not found: {path}")
                continue

        tc = probe_timecode(path)
        if not tc:
            warnings.append(f"{path.name}: no embedded timecode; left unchanged")
            continue

        offset = tc_to_seconds(tc, args.fps)
        asset.set("start", fx(offset))
        assets[ref] = (path.name, path, offset)

    changed_clips = 0
    for clip in root.iter("asset-clip"):
        ref = clip.get("ref")
        if ref not in assets:
            continue
        _, _, offset = assets[ref]
        current = seconds_attr(clip.get("start", "0s"))
        clip.set("start", fx(offset + current))
        changed_clips += 1

    ET.indent(root, space="  ")
    tree.write(args.fcpxml, encoding="utf-8", xml_declaration=True)

    print(json.dumps({
        "status": "SOURCE_TIMECODE_APPLIED",
        "fcpxml": str(args.fcpxml.resolve()),
        "assetsAdjusted": len(assets),
        "clipsAdjusted": changed_clips,
        "warnings": warnings,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
