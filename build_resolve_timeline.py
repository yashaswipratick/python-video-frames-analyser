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
from pathlib import Path

SUPPORTED_MUSIC_EXTENSIONS = {".mp3", ".m4a", ".wav", ".aac", ".flac"}


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

    cmd = [
        sys.executable,
        "generate_fcpxml.py",
        "--timeline", str(args.timeline),
        "--assembly", str(args.assembly),
        "--media-dir", str(args.media_dir),
        "--output", str(args.output),
        "--fps", str(args.fps),
        "--music-file", str(args.music_file),
    ]
    print(f"Using music: {args.music_file}")

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
