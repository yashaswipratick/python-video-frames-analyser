# Video Analysis → Editorial Timeline Architecture

## Objective

This project is not only a video-analysis pipeline. Its final purpose is to turn a collection of raw travel-vlog videos into an evidence-grounded editorial blueprint that can be assembled manually in DaVinci Resolve.

The target outcome is a strong, natural travel-vlog story with high retention. The system must behave like an editor/story producer, not merely a media metadata analyzer.

## Locked end-to-end architecture

```text
RAW DJI VIDEOS
      |
      v
VIDEO ANALYSIS PIPELINE
  - metadata + SHA-256
  - analysis proxy
  - extracted audio
  - speech transcription
  - scene detection
  - representative frames
  - per-video analysis.json
      |
      v
analysis_bundle.zip
      |
      v
AI EDITORIAL ANALYSIS
  - identify story material
  - remove dead time/repetition
  - preserve natural reactions and real events
  - detect problems, discoveries and unresolved questions
  - classify visible events using the closed event taxonomy
  - identify speech-led, B-roll-led and music-led sections
  - recommend exact B-roll from exact source ranges
  - assemble all source videos into one chronological story
      |
      v
edit_timeline.json
      |
      v
DAVINCI RESOLVE
      |
      v
FINAL VLOG
```

## Final-duration policy — LOCKED

The finished vlog is **not forced to be 12 minutes**.

The preferred target is **8–12 minutes**, with **10–12 minutes preferred when the available story material genuinely supports it**.

Examples:

- Strong story material = 7:40 → final vlog may remain ~7:40.
- Strong story material = 11:20 → final vlog may remain ~11:20.
- Strong story material = 18:00 → remove repetition, dead time and weak material; aim for ~10–12 minutes.

The primary objective is **story quality and viewer retention**, not filling a duration quota.

The editor must never add weak footage merely to reach the target duration.

## Editorial priorities

1. Strong hook and immediate curiosity.
2. Clear reason for the trip / plan.
3. Journey as story, not filler.
4. Real observations, reactions, conversations and unexpected events.
5. Problems, discoveries and unresolved questions should create forward momentum.
6. Use exact B-roll to support speech and hide repetitive/static talking-head footage.
7. Preserve visually strong sequences that work with music.
8. Remove repeated explanations, dead air, weak greetings, redundant road footage and anything that does not advance the story.
9. Keep the tone natural, casual and human; do not turn the vlog into a memorized script.
10. Prefer a shorter strong cut over a longer padded cut.

## Story model

The default story model is flexible, not a rigid timestamp template:

```text
HOOK
→ PLAN / DESTINATION
→ JOURNEY
→ OBSERVATION / SMALL DISCOVERY
→ STOP / FOOD / LOCAL MOMENT
→ PROBLEM OR UNEXPECTED EVENT
→ SOLUTION / ADVENTURE
→ DESTINATION
→ EXPERIENCE / WOW MOMENT
→ VERDICT / USEFUL INFO
→ OUTRO
```

Not every vlog must contain every stage. The footage determines the actual story.

## Editorial evidence rules

- Source files remain untouched.
- Every selected edit range must reference the exact source filename and exact source start/end timestamps.
- B-roll recommendations must also reference exact source filenames and exact timestamps.
- Visible event labels must use only the closed taxonomy defined in `edit_timeline.json`.
- Spoken topics must not be treated as visible events unless the corresponding visual is actually present.
- Do not invent locations, objects, actions or events that are not supported by the analysis bundle.
- Re-analysis of an existing source filename replaces that video's editorial entry while preserving unrelated video entries.

## `edit_timeline.json` responsibility

`edit_timeline.json` is the editorial source of truth produced after AI analysis. It must contain:

- global editorial/duration policy;
- per-video decisions and exact source ranges;
- speech and visual assessments;
- exact B-roll recommendations;
- music-worthy footage recommendations;
- DaVinci assembly guidance;
- a master chronological timeline when multiple source videos are present.

The JSON is a blueprint, not a rendered video. It tells the editor what to use, what to remove, what to shorten, and how the selected footage should be assembled into the strongest story supported by the available evidence.

## Multi-video assembly rule

When multiple raw videos are available, editorial ordering is based on **story logic**, not raw filename order or camera recording order alone.

The AI may move clips between source videos when doing so creates a clearer story, while preserving exact source references so the editor can locate every clip in DaVinci Resolve.

## Music / B-roll rule

The final timeline must explicitly distinguish:

- speech-driven clips;
- speech with B-roll coverage;
- music-driven montage/event sections.

Music-driven sections must contain exact source ranges and event labels so the editor knows exactly which original footage to place under music.

## Quality gate before finalizing a timeline

Before producing the final `edit_timeline.json`, verify:

- no invented visual events;
- no missing source filenames;
- no approximate B-roll references when exact timestamps are available;
- no unnecessary repetition;
- hook appears early;
- story has forward momentum;
- long talking-head sections are covered or shortened when matching visuals exist;
- useful real-life interruptions/problems are preserved;
- music-friendly footage is not accidentally discarded;
- final duration follows the 8–12 minute policy rather than a forced 12-minute quota.
