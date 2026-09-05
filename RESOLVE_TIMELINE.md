# Automated DaVinci Resolve Timeline Assembly

The editorial workflow now has two machine-readable layers:

```text
analysis bundles
      ↓
AI editorial analysis
      ↓
edit_timeline.json        ← editorial source of truth
      ↓
resolve_assembly.json     ← executable V1/V2/A1/A2 plan
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
| V1 | Primary story spine in `mainTimeline` order |
| V2 | Exact B-roll overlays from `brollOverlays` |
| A1 | Source dialogue / natural sound carried by the V1 clips |
| A2 | External music bed placed over `musicCues` |

The converter does not invent B-roll placement. Each V2 overlay must have an exact timeline position and exact source IN/OUT range in `resolve_assembly.json`.

## Music: one MP3 file

The normal workflow no longer requires a `--music-file` argument.

Put your single music file here:

```text
music/
    your-track.mp3
```

Supported automatic formats are `.mp3`, `.m4a`, `.wav`, `.aac`, and `.flac`.

When exactly one supported audio file exists in `./music`, `build_resolve_timeline.py` automatically selects it and passes it to the FCPXML generator as the A2 music asset.

If more than one music file exists, the build stops rather than choosing one arbitrarily. You can still override discovery with an explicit `--music-file`.

## Generate the Resolve XML

From the repository root on the editing Mac:

```bash
python3 build_resolve_timeline.py \
  --timeline edit_timeline.json \
  --assembly resolve_assembly.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output edit_timeline.fcpxml
```

That is now the recommended command.

The script first validates `edit_timeline.json`, automatically discovers the single music file in `./music`, and then generates the FCPXML.

To use a music file from somewhere else, use:

```bash
python3 build_resolve_timeline.py \
  --timeline edit_timeline.json \
  --assembly resolve_assembly.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --music-file "/absolute/path/to/your-track.mp3" \
  --output edit_timeline.fcpxml
```

## What the current converter automates

- exact source filenames;
- exact source IN/OUT ranges;
- chronological story assembly;
- primary V1 story spine;
- exact V2 B-roll placements from the executable assembly plan;
- source-audio carry-through;
- A2 music-bed asset and cue placement when a music file is supplied/discovered;
- deterministic timeline placement;
- validation before XML generation.

## What still requires explicit evidence or creative input

The music file is an external audio asset supplied by the editor; the pipeline does not invent or download one. The system also does not automatically decide a song's creative mix beyond the configured A2 cue placements.

B-roll placement must remain evidence-grounded. The converter will not guess an overlay merely because two clips share labels such as `Road`, `Mountain`, or `Driving`.

## Import into Resolve

1. Put exactly one music file under `./music/`.
2. Generate `edit_timeline.fcpxml`.
3. Open DaVinci Resolve.
4. Import the FCPXML as a timeline.
5. When Resolve asks for media relinking, point it at `/Users/yashaswipratick/Documents/video-analyser/videos` if required.
6. Review V1/V2/A1/A2.
7. Finish music mixing, sound design, captions, color, transitions, and final creative polish.

The raw videos remain untouched. The XML is an edit/interchange file only.
