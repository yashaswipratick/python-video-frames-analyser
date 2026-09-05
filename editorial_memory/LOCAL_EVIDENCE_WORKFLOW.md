# Local Evidence Generation → LLM Editorial Reasoning

This project intentionally separates **local evidence generation** from **LLM editorial reasoning**.

## Locked architecture

```text
RAW DJI VIDEO
      |
      v
Local Python pipeline
      |
      +-- FFmpeg / ffprobe
      +-- faster-whisper
      +-- PySceneDetect
      +-- frame extraction
      +-- deterministic frame metrics
      |
      v
analysis/
      |
      v
analysis_bundle_XXX.zip
      |
      v
LLM / ChatGPT
      |
      +-- story
      +-- hook
      +-- retention
      +-- clip selection
      +-- B-roll
      +-- music
      +-- exact timestamps
      +-- master timeline
      |
      v
editorial_memory/
      |
      v
edit_timeline.json
      |
      v
DaVinci Resolve
```

## What runs locally

`prepare_video_analysis.py` remains responsible for creating the evidence artifacts from raw videos. It does not modify raw source files and does not perform editorial reasoning.

`generate_editorial_evidence.py` reads the completed `analysis/` tree and creates a lightweight, repository-friendly representation of the evidence. It copies no video, audio or frame bytes into Git.

The generated evidence contains:

- exact source filenames and durations;
- source SHA-256 when available;
- technical metadata;
- transcript and word/segment timestamps;
- scene boundaries;
- frame timestamps and frame file references;
- deterministic image metrics such as dimensions, luminance and edge density;
- pipeline status and provenance.

The deterministic image metrics are only supporting signals. They do **not** identify objects, people, locations or editorial meaning.

## What must remain with the LLM

The LLM/ChatGPT editorial stage remains responsible for interpretation and decisions, including:

- what actually matters to the story;
- strongest hook;
- retention value;
- useful vs repetitive speech;
- clip selection;
- story roles;
- B-roll matching;
- music sections;
- visual progression;
- cross-video story order;
- exact editorial timestamps;
- final `MASTER_EDITORIAL_MEMORY.json` and `edit_timeline.json` decisions.

The LLM must use evidence rather than infer visual events from filenames or unsupported assumptions.

## Recommended local commands

Run the existing analysis pipeline first:

```bash
python3 prepare_video_analysis.py \
  --input-dir /Users/yashaswipratick/Documents/video-analyser/videos \
  --output-dir /Users/yashaswipratick/Documents/video-analyser/analysis \
  --whisper-model large-v3-turbo
```

Then generate the lightweight LLM-ready evidence:

```bash
python3 generate_editorial_evidence.py \
  --analysis-dir /Users/yashaswipratick/Documents/video-analyser/analysis \
  --output-dir /Users/yashaswipratick/Documents/video-analyser/editorial_memory/generated
```

To commit the generated evidence locally:

```bash
python3 generate_editorial_evidence.py \
  --analysis-dir /Users/yashaswipratick/Documents/video-analyser/analysis \
  --output-dir /Users/yashaswipratick/Documents/video-analyser/editorial_memory/generated \
  --git-commit
```

To commit and push to the current branch:

```bash
python3 generate_editorial_evidence.py \
  --analysis-dir /Users/yashaswipratick/Documents/video-analyser/analysis \
  --output-dir /Users/yashaswipratick/Documents/video-analyser/editorial_memory/generated \
  --git-push
```

Normal Git authentication is used by the local `git push`; no OpenAI API call is made by this evidence-generation script.

## Persistent memory workflow

After ChatGPT/LLM performs the editorial review of a bundle, persist the reasoning as:

```text
editorial_memory/bundle_001_editorial_memory.json
editorial_memory/bundle_002_editorial_memory.json
editorial_memory/bundle_003_editorial_memory.json
...
```

Then consolidate:

```text
editorial_memory/MASTER_EDITORIAL_MEMORY.json
```

Finally derive:

```text
edit_timeline.json
```

The heavy bundle remains evidence. The repository memory remains the persistent editorial reasoning layer. Older bundles should not be reopened merely to reconstruct reasoning that is already present in the memory files.
