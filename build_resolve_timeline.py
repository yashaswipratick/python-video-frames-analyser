#!/usr/bin/env python3
"""Validate and build the DaVinci Resolve FCPXML in one command.

If --music-file is omitted and ./music contains exactly one supported audio
file, that file is automatically used as the A2 music bed. This keeps the
normal build command free from a music-path argument.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SUPPORTED_MUSIC_EXTENSIONS = {".mp3", ".m4a", ".wav", ".aac", ".flac"}


def discover_music(music_dir: Path) -> Path | None:
    if not music_dir.exists():
        return None
    if not music_dir.is_dir():
        raise NotADirectoryError(f"Music directory is not a directory: {music_dir}")
    candidates = sorted(
        path for path in music_dir.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_MUSIC_EXTENSIONS
    )
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        names = "\n".join(f"  - {path.name}" for path in candidates)
        raise RuntimeError(
            "Multiple supported music files were found in "
            f"{music_dir}. Keep exactly one automatic music file or pass "
            "--music-file explicitly.\n" + names
        )
    return None


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
        default=None,
        help="Optional music file. Supports MP3 and other common audio formats.",
    )
    parser.add_argument(
        "--music-dir",
        type=Path,
        default=Path("music"),
        help="Directory used for automatic single-track music discovery (default: ./music).",
    )
    args = parser.parse_args()

    music_file = args.music_file
    if music_file is not None:
        if not music_file.is_file():
            print(f"Music file not found: {music_file}")
            return 1
    else:
        try:
            music_file = discover_music(args.music_dir)
        except Exception as exc:
            print(f"Music discovery failed: {exc}")
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
    ]
    if music_file is not None:
        cmd.extend(["--music-file", str(music_file)])
        print(f"Using music: {music_file}")
    else:
        print(f"No automatic music track found in {args.music_dir}; building without A2 music.")

    built = subprocess.run(cmd, text=True)
    if built.returncode != 0:
        return built.returncode

    print(json.dumps({
        "status": "READY_FOR_DAVINCI_IMPORT",
        "fcpxml": str(args.output.resolve()),
        "music": str(music_file.resolve()) if music_file is not None else None,
        "nextStep": "Import the generated FCPXML into DaVinci Resolve and relink to the original videos if Resolve asks.",
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
