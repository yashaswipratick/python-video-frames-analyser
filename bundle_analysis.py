#!/usr/bin/env python3
"""
Create upload-safe ZIP chunks from an accumulated analysis directory.

This file is intentionally separate from prepare_video_analysis.py.

The analysis runner only creates analysis artifacts. This utility packages the
already-created analysis directory into one or more ZIP files, keeping each ZIP
below the configured size limit.

Example:
  python3 bundle_analysis.py \
      --analysis-dir /Users/yashaswipratick/Documents/video-analyser/analysis

Default output:
  /Users/yashaswipratick/Documents/video-analyser/
      analysis_bundle_001.zip
      analysis_bundle_002.zip
      ...

The default limit is 500 MiB, leaving a safety margin below a 512 MB upload
limit. Source analysis files are never modified.
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path
from typing import Iterable

DEFAULT_MAX_MIB = 500
ZIP_OVERHEAD_RESERVE_BYTES = 2 * 1024 * 1024


def format_bytes(value: int) -> str:
    if value < 1024:
        return f"{value} B"
    if value < 1024**2:
        return f"{value / 1024:.1f} KB"
    if value < 1024**3:
        return f"{value / 1024**2:.1f} MB"
    return f"{value / 1024**3:.2f} GB"


def collect_files(analysis_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in analysis_dir.rglob("*")
        if path.is_file()
    )


def group_by_top_level(analysis_dir: Path, files: Iterable[Path]) -> list[list[Path]]:
    """Keep each video's analysis folder together whenever it fits."""
    top_level_groups: dict[str, list[Path]] = {}
    loose_files: list[Path] = []

    for path in files:
        relative = path.relative_to(analysis_dir)
        parts = relative.parts
        if len(parts) <= 1:
            loose_files.append(path)
            continue
        top_level_groups.setdefault(parts[0], []).append(path)

    groups = [sorted(paths) for _, paths in sorted(top_level_groups.items())]
    if loose_files:
        groups.append(sorted(loose_files))
    return groups


def group_size(group: list[Path]) -> int:
    return sum(path.stat().st_size for path in group)


def split_group(group: list[Path], safe_payload_limit: int) -> list[list[Path]]:
    """Split an oversized video package at file boundaries."""
    chunks: list[list[Path]] = []
    current: list[Path] = []
    current_size = 0

    for path in sorted(group):
        size = path.stat().st_size
        if size > safe_payload_limit:
            raise RuntimeError(
                f"Single analysis file is too large for one ZIP: "
                f"{path} ({format_bytes(size)} > {format_bytes(safe_payload_limit)})"
            )

        if current and current_size + size > safe_payload_limit:
            chunks.append(current)
            current = []
            current_size = 0

        current.append(path)
        current_size += size

    if current:
        chunks.append(current)
    return chunks


def build_groups(analysis_dir: Path, max_bundle_bytes: int) -> list[list[Path]]:
    files = collect_files(analysis_dir)
    if not files:
        return []

    safe_payload_limit = max_bundle_bytes - ZIP_OVERHEAD_RESERVE_BYTES
    if safe_payload_limit <= 0:
        raise ValueError("ZIP size limit must be larger than the overhead reserve.")

    final_groups: list[list[Path]] = []
    pending: list[Path] = []
    pending_size = 0

    def flush_pending() -> None:
        nonlocal pending, pending_size
        if pending:
            final_groups.append(pending)
            pending = []
            pending_size = 0

    for package in group_by_top_level(analysis_dir, files):
        package_size = group_size(package)

        if package_size > safe_payload_limit:
            # Keep any already accumulated complete packages together, then
            # split only this oversized package at individual file boundaries.
            flush_pending()
            final_groups.extend(split_group(package, safe_payload_limit))
            continue

        if pending and pending_size + package_size > safe_payload_limit:
            flush_pending()

        pending.extend(package)
        pending_size += package_size

    flush_pending()
    return final_groups


def write_zip(
    analysis_dir: Path,
    files: list[Path],
    destination: Path,
    max_bundle_bytes: int,
) -> int:
    if destination.exists():
        destination.unlink()

    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
    ) as archive:
        for path in files:
            archive.write(path, arcname=str(Path(analysis_dir.name) / path.relative_to(analysis_dir)))

    actual_size = destination.stat().st_size
    if actual_size > max_bundle_bytes:
        destination.unlink(missing_ok=True)
        raise RuntimeError(
            f"Generated ZIP exceeded the configured limit: "
            f"{destination.name} = {format_bytes(actual_size)} > {format_bytes(max_bundle_bytes)}"
        )
    return actual_size


def remove_old_bundles(output_parent: Path) -> None:
    for path in sorted(output_parent.glob("analysis_bundle_*.zip")):
        path.unlink()
    legacy = output_parent / "analysis_bundle.zip"
    if legacy.exists():
        legacy.unlink()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Bundle an accumulated video-analysis directory into upload-safe ZIP chunks."
    )
    parser.add_argument("--analysis-dir", type=Path, default=Path("analysis"))
    parser.add_argument("--output-dir", type=Path, default=None,
                        help="Directory for ZIP files. Defaults to the parent of --analysis-dir.")
    parser.add_argument("--max-mib", type=int, default=DEFAULT_MAX_MIB,
                        help="Maximum ZIP size in MiB. Default: 500.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    analysis_dir = args.analysis_dir.resolve()
    if not analysis_dir.exists() or not analysis_dir.is_dir():
        print(f"Analysis directory does not exist or is not a directory: {analysis_dir}", file=sys.stderr)
        return 2

    if args.max_mib < 50:
        print("--max-mib must be at least 50 MiB", file=sys.stderr)
        return 2

    output_dir = (args.output_dir.resolve() if args.output_dir else analysis_dir.parent)
    output_dir.mkdir(parents=True, exist_ok=True)

    max_bundle_bytes = args.max_mib * 1024 * 1024
    remove_old_bundles(output_dir)

    try:
        groups = build_groups(analysis_dir, max_bundle_bytes)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if not groups:
        print(f"No analysis files found under {analysis_dir}", file=sys.stderr)
        return 1

    created: list[Path] = []
    try:
        for index, group in enumerate(groups, start=1):
            destination = output_dir / f"analysis_bundle_{index:03d}.zip"
            actual_size = write_zip(analysis_dir, group, destination, max_bundle_bytes)
            created.append(destination)
            print(
                f"Created {destination.name}: {format_bytes(actual_size)} "
                f"({len(group)} files)",
                flush=True,
            )
    except Exception as exc:
        for path in created:
            path.unlink(missing_ok=True)
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    total = sum(path.stat().st_size for path in created)
    print(
        f"Created {len(created)} upload-safe ZIP bundle(s), "
        f"{format_bytes(total)} total compressed.",
        flush=True,
    )
    for path in created:
        print(f"  {path.resolve()} ({format_bytes(path.stat().st_size)})", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
