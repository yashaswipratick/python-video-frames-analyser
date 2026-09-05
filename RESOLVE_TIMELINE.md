# Automated DaVinci Resolve Timeline Assembly

The editorial workflow now has two machine-readable layers:

```text
analysis bundles
      ↓
AI editorial analysis
      ↓
edit_timeline.json        ← editorial source of truth
      ↓
generate_fcpxml.py        ← interchange/assembly layer
      ↓
edit_timeline.fcpxml
      ↓
DaVinci Resolve
```

## Track model

| Track | Purpose |
|---|---|
| V1 | Primary story spine in `masterTimeline` order |
| V2 | Connected B-roll overlays when an exact `speechRange` + `bestBroll` recommendation exists |
| A1 | Source audio carried by the V1 clips |
| A2 | Optional external music bed supplied explicitly by the editor |

The converter deliberately does not invent B-roll placement from matching event labels. An overlay is created only when the editorial JSON contains an exact source speech range and an exact best-B-roll source range. This protects against visually plausible but incorrect automatic edits.

## Generate the Resolve XML

From the repository root on the editing Mac:

```bash
python3 validate_edit_timeline.py --timeline edit_timeline.json
```

Then:

```bash
python3 generate_fcpxml.py \
  --timeline edit_timeline.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output edit_timeline.fcpxml
```

If you have a licensed music file ready:

```bash
python3 generate_fcpxml.py \
  --timeline edit_timeline.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --music-file "/absolute/path/to/licensed-music.m4a" \
  --output edit_timeline.fcpxml
```

## What the current converter automates

- exact source filenames;
- exact source IN/OUT ranges;
- chronological story assembly;
- primary V1 story spine;
- exact B-roll connected clips where a mapping is explicitly present;
- source-audio carry-through;
- music-section cue metadata;
- optional A2 music-bed asset;
- deterministic timeline placement;
- validation of timestamps, decisions, and event taxonomy.

## What still requires explicit evidence or creative input

The current editorial JSON contains music-worthy **video footage** but does not contain a separate licensed music track. The converter therefore cannot truthfully invent a song or choose an unknown local music file.

Likewise, B-roll cannot be safely guessed merely because two ranges share labels such as `Road`, `Mountain`, or `Driving`. Exact editorial mappings are required before they are put onto V2.

## Import into Resolve

1. Generate `edit_timeline.fcpxml` on the Mac that has the original footage.
2. Open DaVinci Resolve.
3. Import the FCPXML as a timeline.
4. When Resolve asks for media relinking, point it at `/Users/yashaswipratick/Documents/video-analyser/videos` if required.
5. Review the imported V1/V2/A1/A2 structure.
6. Finish music selection/mix, sound design, captions, color, transitions, and the final creative pass.

The raw videos remain untouched. The XML is only an edit decision/interchange file.

## Important expectation

The goal is **high mechanical completion**, not a claim that XML can replace editorial judgement. When the JSON contains explicit placement information, the converter can assemble it directly. When information is missing, the converter leaves a cue/warning rather than silently making a potentially wrong cut.
