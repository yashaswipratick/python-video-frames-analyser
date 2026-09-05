# DaVinci Resolve FCPXML Workflow

The repository now has two distinct deliverables:

```text
edit_timeline.json
    ↓
generate_fcpxml.py
    ↓
edit_timeline.fcpxml
    ↓
DaVinci Resolve
```

## Source of truth

`edit_timeline.json` remains the editorial source of truth. It contains the story order, exact source filenames, exact source ranges, editorial decisions, B-roll recommendations and music-driven sections.

`generate_fcpxml.py` converts the chronological `masterTimeline[]` into an FCPXML sequence. The converter never modifies raw media.

## Run it

From the repository root:

```bash
python3 generate_fcpxml.py \
  --timeline ./edit_timeline.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output ./edit_timeline.fcpxml
```

Use `--fps` when the source/timeline frame rate differs from the default:

```bash
python3 generate_fcpxml.py --fps 30 \
  --timeline ./edit_timeline.json \
  --media-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output ./edit_timeline.fcpxml
```

## What the current converter does

The generated XML contains:

- the original source media paths;
- exact source IN/OUT ranges from `masterTimeline[]`;
- deterministic editorial order;
- a Resolve-importable FCPXML sequence;
- clip notes carrying section, decision, media role, events and reason;
- no modification or transcoding of original footage.

## Important current boundary

The existing `edit_timeline.json` was designed first as an editorial blueprint. Its B-roll recommendations and music sections identify useful source footage but do **not** yet give every overlay an explicit `timelineStart`, `timelineEnd`, track/lane and audio asset.

Therefore the converter deliberately does **not** invent B-roll overlay positions or a music file. It builds the exact master story spine only. This is evidence-safe and prevents an apparently automatic timeline from placing arbitrary footage over the wrong speech.

## Target architecture for the next revision

To reach the requested ~90% automatic assembly, the editorial schema should be extended with executable placement instructions:

```text
assembly
  timelineFrameRate
  tracks
    V1 = primary story
    V2 = B-roll
    A1 = dialogue/original sound
    A2 = music
    A3 = ambience/SFX

  clips[]
    sourceFile
    sourceStart
    sourceEnd
    timelineStart
    timelineEnd
    track
    role
    transitionIn
    transitionOut
    audioMode
    audioGainDb
    linkedTo
```

B-roll entries should explicitly reference the speech clip they cover, and music sections should either point to a real music asset or be marked as a placeholder requiring a supplied music library. Once those coordinates exist, the FCPXML generator can place the primary footage, B-roll and audio lanes automatically instead of merely preserving them as recommendations.

## Editing principle

The system should remain evidence-grounded:

> Do not chase the script. Chase the story.

A shorter strong edit is preferred to padding the timeline with repeated driving footage, repeated explanations or weak montage material.
