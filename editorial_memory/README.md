# Editorial Memory Layer

## Purpose

`edit_timeline.json` is the final editorial blueprint, but it must not be the only place where AI reasoning is stored.

Large `analysis_bundle_XXX.zip` files are evidence packages. They are expensive to reopen and re-analyse. After a bundle is reviewed, the important editorial reasoning must be persisted in this repository as a lightweight, human-readable and machine-readable memory layer.

The workflow is therefore:

```text
RAW DJI VIDEOS
    |
    v
prepare_video_analysis.py
    |
    v
analysis_bundle_XXX.zip
    |
    v
AI EDITORIAL REVIEW OF THIS BUNDLE
    |
    +--> editorial_memory/bundle_XXX_editorial_memory.json
    |
    v
MASTER EDITORIAL CONSOLIDATION
    |
    v
edit_timeline.json
```

## Golden Rule

**Never make the next editorial decision by reopening and re-analysing an older bundle when the required reasoning already exists in `editorial_memory/`.**

Use the persisted editorial memory as the first source. Reopen an old bundle only when:

1. the required evidence is missing from memory;
2. a source hash/timestamp conflict is detected;
3. the user explicitly requests re-analysis;
4. a previous editorial conclusion is proven inconsistent with new evidence.

## One memory file per bundle

Each completed bundle should result in:

```text
editorial_memory/bundle_001_editorial_memory.json
editorial_memory/bundle_002_editorial_memory.json
editorial_memory/bundle_003_editorial_memory.json
...
```

The file must be lightweight. Do **not** copy proxy video, audio, frames or raw bundle contents into the repository.

## Required memory detail

Each bundle memory file should capture the reasoning needed to construct the final edit without reopening the bundle unnecessarily.

For every source video, preserve:

- exact source filename;
- source duration;
- source identity/hash when available;
- visual observations grounded in the supplied frames;
- visible event labels using the closed taxonomy only;
- shot type / visual character;
- speech summary and important speech excerpts when available;
- exact speech ranges;
- exact selected source ranges;
- exact removed/rejected ranges when known;
- editorial decision per range;
- story role;
- retention value;
- emotional/reaction value;
- problem, discovery or unexpected-event value;
- continuity role;
- whether the range is speech-driven, speech+B-roll or music-driven;
- exact B-roll candidates and what speech they can cover;
- exact music candidates and recommended music role;
- natural sound/ambient value;
- risks or ambiguity in interpretation;
- relationship to other clips in the same bundle;
- relationship to clips already reviewed in earlier bundles;
- confidence/evidence notes.

For the bundle as a whole, preserve:

- what happened in this part of the trip;
- new story beats introduced;
- old story beats strengthened or weakened;
- strongest new hook candidates;
- strongest problems/unexpected moments;
- strongest destination/reveal moments;
- strongest adventure moments;
- strongest local/human moments;
- strongest music montage candidates;
- strongest cross-bundle B-roll relationships;
- repetition identified against earlier bundles;
- editorial risks and unresolved questions;
- what should happen when this bundle is merged into the master story.

## Exact timestamp rule

Memory must preserve milliseconds whenever supplied. Never replace exact source timestamps with vague descriptions such as `road section`, `later clip`, or `around the hill`.

## Evidence boundary

Memory is a record of evidence and editorial reasoning. It must never invent:

- visual events not visible in the supplied evidence;
- permissions;
- safety claims;
- locations not supported by the source;
- dialogue that was not available in the transcript;
- timestamps that were not observed.

## Closed visual event taxonomy

Only these labels are permitted:

```text
Landscape
Mountain
Road
Driving
Off-road Terrain
Forest
Temple
Waterfall
Lake/Water
Building
City
Food
People
Vehicle
Wildlife
Sunrise/Sunset
Night
Close-up
Establishing Shot
B-roll
Transition Shot
```

## Editorial decisions

Use the same locked decisions used by `edit_timeline.json`:

```text
KEEP
STRONG_KEEP
SHORTEN
KEEP_WITH_BROLL
KEEP_FOR_MUSIC
KEEP_AS_TRANSITION
REMOVE
```

## Relationship to `edit_timeline.json`

`editorial_memory/` is the **persistent reasoning layer**.

`edit_timeline.json` is the **final assembly source of truth**.

The final timeline should be derived from the memory layer, not reconstructed from scratch each time a new bundle arrives.

A later bundle can therefore be processed like this:

```text
1. Read editorial_memory/INDEX.json
2. Read only the newly arrived bundle evidence
3. Write/update the new bundle memory file
4. Compare new memory against earlier memory files
5. Resolve cross-bundle story relationships
6. Build/update edit_timeline.json
7. Run the editorial quality gate
```

## Re-analysis rule

If the same source filename is analysed again, replace that video's memory entry with the new evidence and mark the previous conclusion as superseded. Do not silently merge incompatible old and new timestamps.

## Why this exists

The bundles can be hundreds of megabytes. The editorial memory files are intentionally compact so a future ChatGPT session can understand the entire editorial reasoning quickly from GitHub without reopening every ZIP.
