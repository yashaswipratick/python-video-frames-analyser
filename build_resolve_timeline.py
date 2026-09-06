#!/usr/bin/env python3
"""Validate and build the DaVinci Resolve FCPXML in one command.

Music is intentionally supplied only through --music-file. The assembly JSON
stores music cues and roles, but never a machine-specific music path.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

SUPPORTED_MUSIC_EXTENSIONS = {".mp3", ".m4a", ".wav", ".aac", ".flac"}
TIMESTAMP_KEYS = {"sourceStart", "sourceEnd", "timelineStart", "duration"}


def normalize_timestamp(value: Any) -> Any:
    """Convert MM:SS timestamps to the HH:MM:SS form expected by the FCPXML generator."""
    if not isinstance(value, str):
        return value
    parts = value.strip().split(":")
    if len(parts) != 2:
        return value
    minutes, seconds = parts
    return f"00:{int(minutes):02d}:{seconds}"


def normalize_assembly_timestamps(value: Any, key: str | None = None) -> Any:
    """Recursively normalize only known timestamp fields without changing other strings."""
    if isinstance(value, dict):
        return {
            item_key: normalize_assembly_timestamps(item_value, item_key)
            for item_key, item_value in value.items()
        }
    if isinstance(value, list):
        return [normalize_assembly_timestamps(item) for item in value]
    if key in TIMESTAMP_KEYS:
        return normalize_timestamp(value)
    return value


def prepare_assembly_for_generator(assembly_path: Path, temp_dir: Path) -> Path:
    """Write a generator-compatible temporary assembly file, preserving the source file."""
    data = json.loads(assembly_path.read_text(encoding="utf-8"))
    normalized = normalize_assembly_timestamps(data)
    output = temp_dir / assembly_path.name
    output.write_text(json.dumps(normalized, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"))
    parser.add_argument("--assembly", type=Path, default=Path("resolve_assembly.json"))
    parser.add_argument("--media-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("edit_timeline.fcpxml"))
    parser.add_argument("--fps", type=int, default=30, choices=(24, 25, 30, 50, 60))
    parser.add_argument(
        "--music-file",
        type=Path,
        required=True,
        help="External music file to place on A2. Supports MP3 and other common audio formats.",
    )
    args = parser.parse_args()

    if not args.music_file.is_file():
        print(f"Music file not found: {args.music_file}")
        return 1
    if args.music_file.suffix.lower() not in SUPPORTED_MUSIC_EXTENSIONS:
        print(
            "Unsupported music extension: "
            f"{args.music_file.suffix}. Supported: "
            f"{', '.join(sorted(SUPPORTED_MUSIC_EXTENSIONS))}"
        )
        return 1

    validation = subprocess.run(
        [sys.executable, "validate_edit_timeline.py", "--timeline", str(args.timeline)],
        text=True,
    )
    if validation.returncode != 0:
        print("Validation failed; FCPXML was not generated.")
        return validation.returncode

    print(f"Using music: {args.music_file}")

    # The editorial/assembly JSON uses MM:SS timestamps, while the current
    # FCPXML generator expects HH:MM:SS. Normalize only the temporary copy
    # passed to the generator; never mutate resolve_assembly.json itself.
    with tempfile.TemporaryDirectory(prefix="resolve-assembly-") as temp_dir:
        try:
            generator_assembly = prepare_assembly_for_generator(args.assembly, Path(temp_dir))
        except Exception as exc:
            print(f"ERROR: could not prepare assembly for FCPXML generation: {exc}")
            return 1

        cmd = [
            sys.executable,
            "generate_fcpxml.py",
            "--timeline", str(args.timeline),
            "--assembly", str(generator_assembly),
            "--media-dir", str(args.media_dir),
            "--output", str(args.output),
            "--fps", str(args.fps),
            "--music-file", str(args.music_file),
        ]

        built = subprocess.run(cmd, text=True)
        if built.returncode != 0:
            return built.returncode

    print(json.dumps({
        "status": "READY_FOR_DAVINCI_IMPORT",
        "fcpxml": str(args.output.resolve()),
        "musicFile": str(args.music_file.resolve()),
        "nextStep": "Import the generated FCPXML into DaVinci Resolve and relink to the original videos if Resolve asks.",
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
