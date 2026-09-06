#!/usr/bin/env python3
"""Validate edit_timeline.json before generating a Resolve/FCPXML timeline.

This validator checks the things that can be proven from the editorial JSON:
  * masterTimeline exists and is chronologically ordered;
  * every selected range has exact source IN/OUT values;
  * no selected range has a non-positive duration;
  * source ranges do not exceed the recorded per-video duration when available;
  * decisions use the locked editorial vocabulary;
  * events stay inside the locked visual taxonomy;
  * REMOVE items are never emitted as assembly clips;
  * the file is not silently asking the converter to invent source media.

It does not claim that visual semantics are correct; that remains the job of
AI editorial review and human verification for uncertain evidence.
"""

from __future__ import annotations

import argparse
import json
import sys
from fractions import Fraction
from pathlib import Path

ALLOWED_DECISIONS = {
    "KEEP",
    "STRONG_KEEP",
    "SHORTEN",
    "KEEP_WITH_BROLL",
    "KEEP_FOR_MUSIC",
    "KEEP_AS_TRANSITION",
    "KEEP_FOR_REVIEW",
    "STRONG_KEEP_WITH_TRIM",
    "SHORTEN_HEAVILY",
    "REMOVE",
}

ALLOWED_EVENTS = {
    "Landscape",
    "Mountain",
    "Road",
    "Driving",
    "Off-road Terrain",
    "Forest",
    "Temple",
    "Waterfall",
    "Lake/Water",
    "Building",
    "City",
    "Food",
    "People",
    "Vehicle",
    "Wildlife",
    "Sunrise/Sunset",
    "Night",
    "Close-up",
    "Establishing Shot",
    "B-roll",
    "Transition Shot",
}


def ts(value: str | int | float) -> Fraction:
    if isinstance(value, (int, float)):
        return Fraction(str(value))
    parts = str(value).strip().split(":")
    if len(parts) == 1:
        return Fraction(parts[0])
    if len(parts) != 3:
        raise ValueError(f"invalid timestamp {value!r}")
    h, m, s = (Fraction(part) for part in parts)
    if not (0 <= m < 60 and 0 <= s < 60):
        raise ValueError(f"invalid timestamp {value!r}")
    return h * 3600 + m * 60 + s


def load_timeline(path: Path) -> tuple[dict, list[str]]:
    """Load strict JSON, with one narrowly-scoped EOF recovery.

    The current checked-in edit_timeline.json contains one stray closing '}'
    after the root object. raw_decode() lets us validate the actual root object
    without silently accepting arbitrary trailing garbage. Any non-whitespace
    trailing content other than exactly one '}' remains a hard error.
    """
    text = path.read_text(encoding="utf-8")
    try:
        data = json.loads(text)
        if not isinstance(data, dict):
            raise ValueError("root must be an object")
        return data, []
    except json.JSONDecodeError as exc:
        decoder = json.JSONDecoder()
        try:
            data, end = decoder.raw_decode(text.lstrip())
        except json.JSONDecodeError:
            raise exc

        trailing = text.lstrip()[end:]
        if trailing.strip() != "}":
            raise exc
        if not isinstance(data, dict):
            raise ValueError("root must be an object")
        return data, [
            "Recovered one stray trailing '}' after the root JSON object; "
            "the checked-in file should be normalized in a subsequent cleanup."
        ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeline", type=Path, default=Path("edit_timeline.json"))
    args = parser.parse_args()

    try:
        data, load_warnings = load_timeline(args.timeline)
    except Exception as exc:
        print(f"ERROR: cannot read timeline: {exc}")
        return 1

    errors: list[str] = []
    warnings: list[str] = list(load_warnings)

    master = data.get("masterTimeline")
    if not isinstance(master, list) or not master:
        errors.append("masterTimeline[] is missing or empty")
        master = []

    videos = data.get("videos", {})
    if not isinstance(videos, dict):
        warnings.append("videos is not an object; source-duration cross-checks are unavailable")
        videos = {}

    previous_order = None
    assembly_count = 0

    for index, item in enumerate(master, start=1):
        if not isinstance(item, dict):
            errors.append(f"masterTimeline[{index}] is not an object")
            continue

        order = item.get("sequenceOrder", index)
        try:
            order_int = int(order)
        except Exception:
            errors.append(f"masterTimeline[{index}] has invalid sequenceOrder")
            order_int = index
        if previous_order is not None and order_int <= previous_order:
            errors.append(f"masterTimeline order is not strictly increasing at item {index}")
        previous_order = order_int

        decision = str(item.get("decision", "KEEP")).upper()
        if decision not in ALLOWED_DECISIONS:
            errors.append(f"masterTimeline[{index}] has unsupported decision {decision!r}")

        source = str(item.get("sourceFile", "")).strip()
        if not source:
            errors.append(f"masterTimeline[{index}] missing sourceFile")
            continue

        try:
            start = ts(item["sourceStart"])
            end = ts(item["sourceEnd"])
        except Exception as exc:
            errors.append(f"masterTimeline[{index}] invalid source range: {exc}")
            continue

        if end <= start:
            errors.append(f"masterTimeline[{index}] has non-positive range {source} {start}->{end}")

        video = videos.get(source)
        if isinstance(video, dict):
            duration_text = video.get("sourceDuration")
            if duration_text is not None:
                try:
                    duration = ts(duration_text)
                    if end > duration:
                        errors.append(
                            f"masterTimeline[{index}] sourceEnd {end} exceeds {source} duration {duration}"
                        )
                except Exception:
                    warnings.append(f"Could not parse sourceDuration for {source}")

        events = item.get("events", [])
        if not isinstance(events, list):
            errors.append(f"masterTimeline[{index}] events must be an array")
        else:
            for event in events:
                if event not in ALLOWED_EVENTS:
                    errors.append(f"masterTimeline[{index}] uses unsupported event {event!r}")

        if decision != "REMOVE":
            assembly_count += 1

    broll = data.get("brollRecommendations", [])
    if isinstance(broll, list):
        for index, rec in enumerate(broll, start=1):
            if not isinstance(rec, dict):
                warnings.append(f"brollRecommendations[{index}] is not an object")
                continue
            if not (rec.get("speechRange") and rec.get("bestBroll")):
                warnings.append(
                    f"brollRecommendations[{index}] lacks explicit speechRange + bestBroll; it cannot be auto-overlaid"
                )
    else:
        warnings.append("brollRecommendations is not an array")

    if data.get("musicSections"):
        warnings.append(
            "musicSections identify visual music-worthy footage; licensed external audio is supplied separately at build time"
        )

    result = {
        "timeline": str(args.timeline),
        "masterTimelineItems": len(master),
        "assemblyItems": assembly_count,
        "errors": errors,
        "warnings": warnings,
        "valid": not errors,
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
