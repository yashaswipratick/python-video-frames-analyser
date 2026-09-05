#!/usr/bin/env python3
"""
Generate compact, local, AI-ready editorial evidence from an existing analysis tree.

This script is intentionally NOT an LLM and does NOT perform editorial reasoning.
It converts the heavy per-video analysis artifacts into lightweight JSON files that
can be committed to Git and consumed later by the editorial LLM/ChatGPT stage.

Inputs (produced by prepare_video_analysis.py):
  analysis/<video-package>/analysis.json
  analysis/<video-package>/transcript.json
  analysis/<video-package>/scenes.json
  analysis/<video-package>/frames/frame_*.jpg

Outputs:
  editorial_memory/generated/editorial_evidence_index.json
  editorial_memory/generated/videos/<video-stem>.json

The generated files contain only metadata, transcripts, scene ranges, frame
references and optional deterministic image metrics. Image/audio/video bytes are
never copied into the repository.

Optional Git integration:
  --git-commit       commit generated files
  --git-push         push the selected branch after committing

The script never changes source videos.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageStat, ImageFilter
except ImportError:  # pragma: no cover
    Image = None
    ImageStat = None
    ImageFilter = None

SCHEMA_VERSION = 1
DEFAULT_OUTPUT = Path("editorial_memory/generated")


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def json_dump(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp.replace(path)


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"WARNING: Could not parse {path}: {exc}", file=sys.stderr)
        return default


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def image_metrics(path: Path) -> dict[str, Any]:
    if Image is None:
        return {"available": False}

    try:
        with Image.open(path) as image:
            rgb = image.convert("RGB")
            width, height = rgb.size
            stat = ImageStat.Stat(rgb)
            mean_rgb = [round(float(value), 2) for value in stat.mean]
            grayscale = rgb.convert("L")
            gray_stat = ImageStat.Stat(grayscale)
            mean_luma = round(float(gray_stat.mean[0]), 2)
            std_luma = round(float(gray_stat.stddev[0]), 2)

            # A simple deterministic sharpness proxy. No model involved.
            edges = grayscale.filter(ImageFilter.FIND_EDGES)
            edge_stat = ImageStat.Stat(edges)
            edge_mean = round(float(edge_stat.mean[0]), 2)

            return {
                "available": True,
                "width": width,
                "height": height,
                "meanRgb": mean_rgb,
                "meanLuma": mean_luma,
                "lumaStdDev": std_luma,
                "edgeMean": edge_mean,
            }
    except Exception as exc:
        return {"available": False, "error": str(exc)}


def relative_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def find_video_packages(analysis_dir: Path) -> list[Path]:
    packages: list[Path] = []
    for analysis_json in sorted(analysis_dir.rglob("analysis.json")):
        package = analysis_json.parent
        if package not in packages:
            packages.append(package)
    return packages


def build_video_evidence(package: Path, analysis_root: Path) -> dict[str, Any]:
    analysis = load_json(package / "analysis.json", {})
    transcript = load_json(package / "transcript.json", {})
    scenes = load_json(package / "scenes.json", [])

    source_name = analysis.get("sourceFileName") or analysis.get("source", {}).get("fileName") or package.name
    source_duration_ms = analysis.get("durationMs") or analysis.get("source", {}).get("durationMs")
    source_sha256 = analysis.get("sha256") or analysis.get("source", {}).get("sha256")

    frame_samples = analysis.get("analysis", {}).get("frameSamples", [])
    if not frame_samples:
        frame_samples = analysis.get("frameSamples", [])

    frames: list[dict[str, Any]] = []
    frames_root = package / "frames"
    for item in frame_samples:
        frame_file = item.get("frameFile")
        timestamp_ms = item.get("timestampMs")
        frame_path = package / frame_file if frame_file else None
        record: dict[str, Any] = {
            "timestampMs": timestamp_ms,
            "frameFile": relative_posix(frame_path, analysis_root) if frame_path and frame_path.exists() else frame_file,
            "exists": bool(frame_path and frame_path.exists()),
        }
        if frame_path and frame_path.exists():
            record["sizeBytes"] = frame_path.stat().st_size
            record["visualMetrics"] = image_metrics(frame_path)
        frames.append(record)

    if not frames and frames_root.exists():
        for frame_path in sorted(frames_root.glob("frame_*.jpg")):
            frames.append({
                "timestampMs": None,
                "frameFile": relative_posix(frame_path, analysis_root),
                "exists": True,
                "sizeBytes": frame_path.stat().st_size,
                "visualMetrics": image_metrics(frame_path),
            })

    return {
        "schemaVersion": SCHEMA_VERSION,
        "evidenceType": "LOCAL_EDITORIAL_EVIDENCE",
        "source": {
            "fileName": source_name,
            "relativeAnalysisPackage": relative_posix(package, analysis_root),
            "durationMs": source_duration_ms,
            "sha256": source_sha256,
        },
        "artifacts": {
            "analysisJson": relative_posix(package / "analysis.json", analysis_root),
            "transcriptJson": relative_posix(package / "transcript.json", analysis_root) if (package / "transcript.json").exists() else None,
            "scenesJson": relative_posix(package / "scenes.json", analysis_root) if (package / "scenes.json").exists() else None,
            "framesDirectory": relative_posix(frames_root, analysis_root) if frames_root.exists() else None,
        },
        "technical": analysis.get("technical", {}),
        "processing": analysis.get("processing", {}),
        "speech": {
            "language": transcript.get("language"),
            "languageProbability": transcript.get("languageProbability"),
            "segments": transcript.get("segments", analysis.get("analysis", {}).get("speechSegments", [])),
        },
        "scenes": scenes if isinstance(scenes, list) else analysis.get("analysis", {}).get("scenes", []),
        "frameSamples": frames,
        "pipelineAnalysis": analysis.get("analysis", {}),
        "editorialLLMStatus": "PENDING_EDITORIAL_LLM",
        "deterministicVisualMetricsNote": "Metrics are descriptive signals only (dimensions, luminance, edge density). They do not identify objects, people, locations or story meaning.",
    }


def git_root(output_root: Path) -> Path:
    try:
        result = run(["git", "rev-parse", "--show-toplevel"], cwd=output_root)
        return Path(result.stdout.strip())
    except Exception:
        return output_root


def git_branch(repo_root: Path) -> str:
    result = run(["git", "branch", "--show-current"], cwd=repo_root)
    return result.stdout.strip()


def git_commit_and_push(repo_root: Path, output_dir: Path, commit_message: str, push: bool) -> None:
    rel = output_dir.relative_to(repo_root)
    run(["git", "add", str(rel)], cwd=repo_root)

    status = run(["git", "status", "--porcelain", "--", str(rel)], cwd=repo_root)
    if not status.stdout.strip():
        print("No generated evidence changes to commit.")
        return

    run(["git", "commit", "-m", commit_message], cwd=repo_root)
    print(f"Committed generated evidence on branch {git_branch(repo_root)}.")

    if push:
        run(["git", "push", "origin", git_branch(repo_root)], cwd=repo_root)
        print("Pushed generated evidence to origin.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate lightweight AI-ready editorial evidence from analysis artifacts.")
    parser.add_argument("--analysis-dir", type=Path, default=Path("analysis"), help="Existing analysis root.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT, help="Generated evidence directory.")
    parser.add_argument("--clean", action="store_true", help="Remove old generated evidence before rebuilding.")
    parser.add_argument("--git-commit", action="store_true", help="Commit generated evidence using Git.")
    parser.add_argument("--git-push", action="store_true", help="Push the commit to origin. Implies --git-commit.")
    parser.add_argument("--commit-message", default="Update generated editorial evidence", help="Git commit message.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    analysis_dir = args.analysis_dir.resolve()
    output_dir = args.output_dir.resolve()

    if not analysis_dir.exists() or not analysis_dir.is_dir():
        print(f"ERROR: Analysis directory does not exist: {analysis_dir}", file=sys.stderr)
        return 2

    if args.clean and output_dir.exists():
        shutil.rmtree(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    videos_output = output_dir / "videos"
    videos_output.mkdir(parents=True, exist_ok=True)

    packages = find_video_packages(analysis_dir)
    if not packages:
        print(f"ERROR: No analysis.json files found under {analysis_dir}", file=sys.stderr)
        return 1

    index_videos: list[dict[str, Any]] = []
    generated_files: list[str] = []

    for package in packages:
        evidence = build_video_evidence(package, analysis_dir)
        source_name = evidence["source"]["fileName"]
        safe_name = Path(source_name).stem.replace("/", "_").replace("\\", "_")
        target = videos_output / f"{safe_name}.json"
        json_dump(target, evidence)
        generated_files.append(relative_posix(target, output_dir))

        index_videos.append({
            "sourceFile": source_name,
            "relativeAnalysisPackage": evidence["source"]["relativeAnalysisPackage"],
            "durationMs": evidence["source"]["durationMs"],
            "sha256": evidence["source"]["sha256"],
            "evidenceFile": relative_posix(target, output_dir),
            "frameCount": len(evidence.get("frameSamples", [])),
            "sceneCount": len(evidence.get("scenes", [])),
            "speechSegmentCount": len(evidence.get("speech", {}).get("segments", [])),
            "editorialLLMStatus": evidence["editorialLLMStatus"],
        })

    index = {
        "schemaVersion": SCHEMA_VERSION,
        "evidenceType": "LOCAL_EDITORIAL_EVIDENCE_INDEX",
        "generatedFrom": str(analysis_dir),
        "generatedFileCount": len(generated_files),
        "videos": sorted(index_videos, key=lambda item: item["sourceFile"]),
        "editorialUse": {
            "purpose": "Provide the LLM/ChatGPT with persistent, compact evidence references before editorial reasoning.",
            "notAnEditorialDecision": True,
            "visualMeaningBoundary": "Deterministic image metrics do not establish what an image contains; visual events must remain evidence-grounded.",
        },
    }
    json_dump(output_dir / "editorial_evidence_index.json", index)

    print(f"Generated editorial evidence for {len(index_videos)} video package(s).")
    print(f"Output: {output_dir}")

    if args.git_push:
        args.git_commit = True
    if args.git_commit:
        repo_root = git_root(output_dir)
        try:
            git_commit_and_push(repo_root, output_dir, args.commit_message, args.git_push)
        except subprocess.CalledProcessError as exc:
            print(exc.stderr or str(exc), file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
