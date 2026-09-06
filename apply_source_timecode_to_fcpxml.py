#!/usr/bin/env python3
"""Apply embedded camera source timecode to FCPXML media assets.

The editorial ranges remain relative to each source clip. This pass sets each
video asset's media start to the embedded camera timecode so Resolve can conform
against the source file's actual timecode. Clip-local starts are intentionally
left unchanged; changing them as well would double-apply the source offset.

DJI footage may use 29.97 drop-frame timecode written as HH:MM:SS;FF. The
conversion below handles that representation using the media's actual frame
rate rather than assuming integer 30 fps.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import xml.etree.ElementTree as ET
from fractions import Fraction
from pathlib import Path


def parse_rate(value: str | None) -> Fraction | None:
    if not value or value in {"0/0", "0", "N/A"}:
        return None
    if "/" in value:
        numerator, denominator = value.split("/", 1)
        if denominator == "0":
            return None
        rate = Fraction(int(numerator), int(denominator))
    else:
        rate = Fraction(value)
    return rate if rate > 0 else None


def probe_media_metadata(path: Path) -> tuple[str | None, Fraction | None]:
    command = [
        "ffprobe",
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=avg_frame_rate,r_frame_rate:stream_tags=timecode",
        "-of", "json",
        str(path),
    ]
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    data = json.loads(completed.stdout or "{}")
    streams = data.get("streams") or []
    if not streams:
        return None, None

    stream = streams[0]
    tags = stream.get("tags") or {}
    timecode = tags.get("timecode")
    rate = parse_rate(stream.get("avg_frame_rate")) or parse_rate(stream.get("r_frame_rate"))
    return (str(timecode) if timecode else None), rate


def tc_to_seconds(value: str, frame_rate: Fraction) -> Fraction:
    """Convert HH:MM:SS[:;]FF to elapsed media seconds.

    A semicolon denotes drop-frame timecode. For 29.97 fps, this is the
    standard 30 fps nominal counting system with 2 frames dropped at the start
    of every minute except each tenth minute.
    """
    separator = ";" if ";" in value else ":"
    normalized = value.strip().replace(";", ":")
    parts = normalized.split(":")
    if len(parts) != 4:
        raise ValueError(
            f"Unsupported source timecode {value!r}; expected HH:MM:SS:FF or HH:MM:SS;FF"
        )

    hours, minutes, seconds, frames = (int(part) for part in parts)
    if not (hours >= 0 and 0 <= minutes < 60 and 0 <= seconds < 60):
        raise ValueError(f"Invalid source timecode {value!r}")

    if frame_rate == Fraction(30000, 1001) and separator == ";":
        if not 0 <= frames < 30:
            raise ValueError(f"Invalid drop-frame count in {value!r}")
        nominal_frames = ((hours * 3600) + (minutes * 60) + seconds) * 30 + frames
        total_minutes = hours * 60 + minutes
        dropped = 2 * (total_minutes - total_minutes // 10)
        real_frames = nominal_frames - dropped
        return Fraction(real_frames, 30) / frame_rate * 30

    # Non-drop frame or another frame rate: frame count advances at the
    # actual media rate.
    if frames < 0 or Fraction(frames, 1) >= frame_rate:
        # Most timecode systems use an integer frame number even when the
        # physical frame rate is fractional (29.97 uses 0..29).
        nominal_fps = int(round(float(frame_rate)))
        if not 0 <= frames < nominal_fps:
            raise ValueError(f"Invalid frame count in {value!r} for {frame_rate}")
    total_seconds = hours * 3600 + minutes * 60 + seconds
    return Fraction(total_seconds) + Fraction(frames, 1) / frame_rate


def fx(value: Fraction, timescale: int = 600) -> str:
    return f"{int(round(float(value) * timescale))}/{timescale}s"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fcpxml", type=Path, required=True)
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--fps", type=int, default=30,
                        help="Fallback nominal fps for media whose frame rate cannot be probed")
    args = parser.parse_args()

    tree = ET.parse(args.fcpxml)
    root = tree.getroot()
    resources = root.find("resources")
    if resources is None:
        raise ValueError("FCPXML has no resources element")

    adjusted_assets = 0
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

        try:
            tc, frame_rate = probe_media_metadata(path)
            if not tc:
                warnings.append(f"{path.name}: no embedded timecode; left unchanged")
                continue
            if frame_rate is None:
                frame_rate = Fraction(args.fps, 1)
                warnings.append(
                    f"{path.name}: frame rate unavailable; using fallback {args.fps} fps"
                )
            offset = tc_to_seconds(tc, frame_rate)
        except (subprocess.CalledProcessError, json.JSONDecodeError, ValueError) as exc:
            warnings.append(f"{path.name}: could not read timecode ({exc}); left unchanged")
            continue

        # The asset's start establishes the media's real source-timecode base.
        # Keep every asset-clip's existing relative start untouched.
        asset.set("start", fx(offset))
        adjusted_assets += 1

    ET.indent(root, space="  ")
    tree.write(args.fcpxml, encoding="utf-8", xml_declaration=True)

    print(json.dumps({
        "status": "SOURCE_TIMECODE_APPLIED",
        "fcpxml": str(args.fcpxml.resolve()),
        "assetsAdjusted": adjusted_assets,
        "clipsAdjusted": 0,
        "warnings": warnings,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
