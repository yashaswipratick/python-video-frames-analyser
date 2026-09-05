#!/usr/bin/env python3
"""Run the existing parallel analyzer and split its analysis output into upload-safe ZIP bundles.

This wrapper intentionally reuses prepare_video_analysis_parallel.py for all analysis work.
Only the final packaging step is replaced.

ZIP policy:
  - Uses a conservative 500 MiB hard ceiling (below the 512 MB upload limit).
  - Packs complete per-video analysis directories together whenever possible.
  - If a single video package is too large, its files are split across bundles.
  - Every generated ZIP is validated after creation and must be below the ceiling.
  - Old analysis_bundle_*.zip files next to the analysis directory are removed first.

Example:
  python3 prepare_video_analysis_parallel_bundled.py \
      --input-dir /Users/yashaswipratick/Documents/video-analyser/videos \
      --output-dir /Users/yashaswipratick/Documents/video-analyser/parallel/analysis \
      --whisper-model large-v3-turbo \
      --workers 3
"""

from __future__ import annotations

import math
import os
import tempfile
import zipfile
from pathlib import Path

import prepare_video_analysis_parallel as base

# Keep a safety margin below the documented 512 MB upload limit.
MAX_ZIP_BYTES = 500 * 1024 * 1024
TARGET_RAW_BYTES = 480 * 1024 * 1024


def _iter_files(root: Path) -> list[Path]:
    return sorted(
        p for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() != ".zip"
    )


def _video_package_groups(output_dir: Path) -> list[list[Path]]:
    """Group all files belonging to each per-video analysis directory."""
    analysis_files = sorted(output_dir.rglob("analysis.json"))
    groups: list[list[Path]] = []
    assigned: set[Path] = set()

    for analysis_file in analysis_files:
        package_root = analysis_file.parent
        files = _iter_files(package_root)
        if files:
            groups.append(files)
            assigned.update(files)

    leftovers = [p for p in _iter_files(output_dir) if p not in assigned]
    if leftovers:
        groups.append(leftovers)

    return groups


def _raw_size(files: list[Path]) -> int:
    return sum(p.stat().st_size for p in files)


def _write_zip(files: list[Path], output_dir: Path, zip_path: Path) -> int:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(
        zip_path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
    ) as zf:
        for path in files:
            zf.write(path, arcname=path.relative_to(output_dir.parent))

    size = zip_path.stat().st_size
    if size >= MAX_ZIP_BYTES:
        raise RuntimeError(
            f"Generated bundle exceeds safety ceiling: {zip_path} = {size} bytes"
        )
    return size


def _split_files(files: list[Path]) -> list[list[Path]]:
    """Split a file list deterministically around the middle by raw size."""
    if len(files) <= 1:
        return [files]

    total = _raw_size(files)
    target = total / 2
    running = 0
    split_at = 1
    for i, path in enumerate(files[:-1], start=1):
        running += path.stat().st_size
        if running >= target:
            split_at = i
            break

    return [files[:split_at], files[split_at:]]


def _pack_group(files: list[Path], output_dir: Path, bundle_files: list[Path]) -> list[list[Path]]:
    """Return one or more final bundles for a group, recursively splitting if necessary."""
    if not files:
        return []

    if _raw_size(files) <= TARGET_RAW_BYTES:
        candidate = bundle_files + files
        if _raw_size(candidate) <= TARGET_RAW_BYTES:
            return [candidate]

    if bundle_files:
        return _pack_group(files, output_dir, []) + [bundle_files]

    # The group itself is too large for the conservative target. Split it.
    if len(files) == 1:
        size = files[0].stat().st_size
        raise RuntimeError(
            f"A single analysis artifact is too large to upload safely: "
            f"{files[0]} = {size / (1024 * 1024):.1f} MiB. "
            "Reduce proxy/frame sizes before running the analyzer."
        )

    left, right = _split_files(files)
    return _pack_group(left, output_dir, []) + _pack_group(right, output_dir, [])


def build_split_bundles(output_dir: Path) -> list[Path]:
    parent = output_dir.parent
    existing = sorted(parent.glob("analysis_bundle_*.zip"))
    for path in existing:
        path.unlink()

    groups = _video_package_groups(output_dir)
    if not groups:
        raise RuntimeError(f"No analysis files found under {output_dir}")

    # First-pack complete video packages. If the next package would cross the
    # conservative raw-size target, start a new bundle.
    bundles: list[list[Path]] = []
    current: list[Path] = []

    for group in groups:
        group_size = _raw_size(group)
        if group_size <= TARGET_RAW_BYTES and current and _raw_size(current) + group_size > TARGET_RAW_BYTES:
            bundles.append(current)
            current = []

        if group_size <= TARGET_RAW_BYTES:
            current.extend(group)
            continue

        if current:
            bundles.append(current)
            current = []

        bundles.extend(_pack_group(group, output_dir, []))

    if current:
        bundles.append(current)

    paths: list[Path] = []
    for index, files in enumerate(bundles, start=1):
        zip_path = parent / f"analysis_bundle_{index:03d}.zip"
        size = _write_zip(files, output_dir, zip_path)
        print(
            f"Created bundle {index:03d}: {zip_path.resolve()} "
            f"({base.format_bytes(size)}) | files: {len(files)}",
            flush=True,
        )
        paths.append(zip_path)

    # Defensive post-check: no bundle may reach the configured hard ceiling.
    oversized = [p for p in paths if p.stat().st_size >= MAX_ZIP_BYTES]
    if oversized:
        names = ", ".join(str(p) for p in oversized)
        raise RuntimeError(f"Bundle size validation failed: {names}")

    print(f"Total upload bundles: {len(paths)}", flush=True)
    return paths


def _patched_make_zip(output_dir: Path, zip_path: Path) -> None:
    """Drop-in replacement for the base module's make_zip function."""
    build_split_bundles(output_dir)


def main() -> int:
    # The base analyzer calls make_zip(output_dir, zip_path) after all workers finish.
    # Monkey-patching keeps its existing CLI, resume behavior, and processing logic intact.
    base.make_zip = _patched_make_zip
    return base.main()


if __name__ == "__main__":
    raise SystemExit(main())
