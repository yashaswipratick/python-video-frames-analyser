# Automated DaVinci Resolve Timeline Assembly

The workflow now separates editorial intelligence from machine assembly:

```text
raw videos
   ↓
analysis bundles
   ↓
AI editorial analysis
   ↓
edit_timeline.json             ← editorial source of truth
   ↓
resolve_assembly.json          ← executable V1/V2/A2 placement plan
   ↓
build_resolve_timeline.py
   ↓
edit_timeline.fcpxml
   ↓
DaVinci Resolve
```

## Current assembly for the Kaiwara/Kailasagiri vlog

`resolve_assembly.json` contains an explicit condensed edit plan built from the consolidated bundles 001-005. It is intentionally more aggressively trimmed than the descriptive `masterTimeline` so the Resolve import starts as an actual edit rather than a 15+ minute string of source selections.

The current executable plan is approximately **09:29** before any additional creative trimming. The duration is a target, not a quota; repeated material should still be removed during review.

## Track model

| Track | Purpose |
|---|---|
| V1 | Primary story spine with exact source IN/OUT ranges |
| V2 | Explicit B-roll overlays at exact timeline positions |
| A1 | Original dialogue and useful natural sound carried by V1 |
| A2 | Optional licensed music bed aligned to music cues |

## One-command build

From the repository root on the editing Mac:

```bash
python3 build_resolve_timeline.py \
  --timeline edit_timeline.json \
  --assembly resolve_assembly.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output edit_timeline.fcpxml
```

The command first validates the editorial JSON. If validation fails, XML generation stops rather than creating a questionable timeline.

With a licensed music track:

```bash
python3 build_resolve_timeline.py \
  --timeline edit_timeline.json \
  --assembly resolve_assembly.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --music-file "/absolute/path/to/licensed-music.m4a" \
  --output edit_timeline.fcpxml
```

## What the XML does automatically

- places the selected source clips on V1 in story order;
- uses exact original source filenames;
- uses exact source IN/OUT ranges;
- places the explicit B-roll overlays on V2 at the specified timeline coordinates;
- mutes B-roll camera audio so A1 dialogue remains clean;
- keeps source audio with the primary footage;
- creates A2 music clips over the defined music cues when a licensed music file is supplied;
- uses deterministic timeline placement;
- leaves the original source media untouched.

## What remains after import

The XML is intended to get the project **very close to an editable first cut**, not to fake a finished human mix.

The remaining work is primarily:

- listen/watch pass and any bad-cut corrections;
- verify the B-roll visual match, especially Bundle-005 sections whose semantic vision evidence was unavailable;
- choose the right licensed music track when one is not supplied;
- tune music/dialogue/ambient levels and ducking;
- final pacing adjustments;
- captions/titles;
- color grade;
- sound design and final review.

The system deliberately refuses to invent a music track. A2 is populated only when `--music-file` is explicitly supplied.

## Import into DaVinci Resolve

1. Generate `edit_timeline.fcpxml` on the Mac that has the original media.
2. Open DaVinci Resolve and import the FCPXML timeline.
3. Relink the media to `/Users/yashaswipratick/Documents/video-analyser/videos` if Resolve asks.
4. Confirm the V1/V2/A1/A2 structure and watch the complete timeline once.
5. Perform the final creative/audio/color/caption pass.

The raw DJI files remain untouched throughout the analysis and assembly pipeline.
