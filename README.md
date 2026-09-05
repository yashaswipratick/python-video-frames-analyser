# Travel Vlog Video Analysis → Editorial Timeline

## Purpose

This repository is a local video-analysis pipeline for turning raw travel-vlog footage into an **evidence-grounded editorial blueprint** for manual assembly in DaVinci Resolve.

The system is not intended to be only a metadata/transcription tool. The final goal is to help produce a **natural, story-driven, high-retention travel vlog** from a collection of raw videos.

The AI editorial stage must behave like an **editor + story producer**. It should decide what is worth keeping, what should be removed, where the story should move, which visuals should cover speech, which moments deserve background music, and how footage from multiple source files should be assembled.

---

# 1. Locked End-to-End Architecture

```text
RAW DJI VIDEOS
      |
      v
VIDEO ANALYSIS PIPELINE
      |
      +-- Metadata / technical information
      +-- SHA-256 source identity
      +-- Proxy video
      +-- Extracted audio
      +-- Speech transcription + timestamps
      +-- Scene detection
      +-- Representative video frames
      +-- Per-video analysis.json
      |
      v
analysis_bundle.zip
      |
      v
AI EDITORIAL ANALYSIS
      |
      +-- Understand the story in all source videos
      +-- Find the strongest hook
      +-- Identify useful speech
      +-- Identify visible events
      +-- Identify reactions / discoveries / problems
      +-- Remove dead time and repetition
      +-- Find B-roll candidates
      +-- Find music-driven moments
      +-- Build the story in editorial order
      +-- Assign exact source timestamps
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

The raw videos are **never modified** by the analysis pipeline.

---

# 2. Two Separate Responsibilities

The architecture has two distinct stages.

## Stage A — Video Analysis

The Python pipeline answers:

> **What is present in the footage?**

It extracts objective evidence such as:

- source metadata;
- source duration;
- SHA-256 hash;
- proxy video;
- audio;
- speech transcript;
- word timestamps;
- detected scene boundaries;
- representative frames;
- technical information.

## Stage B — AI Editorial Analysis

The AI answers:

> **How should the footage be used to tell the strongest story?**

It evaluates:

- hook strength;
- story value;
- speech value;
- visual value;
- emotional/reaction value;
- problems and unexpected events;
- discoveries;
- B-roll opportunities;
- background-music opportunities;
- repetition/dead time;
- chronological/story order;
- final duration.

The second stage must never invent information that is not supported by the analysis bundle.

---

# 3. Final Duration Policy — LOCKED

The finished vlog is **not forced to be 12 minutes**.

The accepted target is:

**8–12 minutes**, with **10–12 minutes preferred when the available strong story material genuinely supports it**.

Examples:

```text
Strong story material = 07:40
→ Final vlog ≈ 07:40

Strong story material = 11:20
→ Final vlog ≈ 11:20

Strong story material = 18:00
→ Cut repetition, dead time and weak material
→ Final vlog ≈ 10:00–12:00
```

Rules:

- Never pad a vlog just to reach 12 minutes.
- Never keep weak footage solely because the final cut is short.
- A shorter strong story is better than a longer weak story.
- The primary objective is **story quality and viewer retention**, not filling a duration quota.
- Duration is an editorial outcome, not an input constraint.

---

# 4. Editorial Philosophy

The desired vlog style is:

- natural;
- casual;
- human;
- observational;
- lightly humorous;
- conversational;
- journey-driven;
- relatable.

The AI must **not** convert the vlog into a memorized/scripted presentation.

The creator may speak naturally in Hindi, Hinglish or English. The final edit should preserve authentic reactions, mistakes, pauses that add personality, local conversations, unexpected situations and genuine observations when they advance the story.

The guiding principle is:

> **Do not chase the script. Chase the story.**

The viewer should feel like they are sitting in the passenger seat experiencing the trip with the creator.

---

# 5. Story Model

The default story model is flexible and is **not a rigid timestamp template**.

```text
HOOK
  ↓
PLAN / DESTINATION
  ↓
JOURNEY
  ↓
OBSERVATION / SMALL DISCOVERY
  ↓
STOP / FOOD / LOCAL MOMENT
  ↓
PROBLEM / UNEXPECTED EVENT
  ↓
SOLUTION / ADVENTURE
  ↓
DESTINATION
  ↓
EXPERIENCE / WOW MOMENT
  ↓
VERDICT / USEFUL INFO
  ↓
OUTRO
```

Not every vlog must contain every stage.

The available footage determines the actual narrative.

Editorial ordering should follow **story logic**, not simply the order in which files were recorded.

---

# 6. Retention Rules

The editor should prioritize footage that creates or maintains viewer curiosity.

## Strong retention material

Prefer:

- strong hooks;
- unanswered questions;
- unexpected events;
- real problems;
- discoveries;
- reactions;
- local interactions;
- visual reveals;
- destination payoffs;
- humor that comes naturally from the situation;
- visually changing sequences.

## Weak retention material

Aggressively trim or remove:

- dead air;
- repeated sentences;
- repeated explanations;
- long static talking-head sections;
- repetitive driving footage;
- generic filler B-roll;
- weak greetings/openings;
- explanations that do not change the viewer's understanding;
- footage that does not advance the story, mood or visual experience.

A clip can be technically good and still be editorially unnecessary.

---

# 7. Closed Visual Event Taxonomy — LOCKED

Visual events are used to describe **what is actually visible in the footage**.

Only the following labels may be used:

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

Multiple labels are allowed for the same range.

There is **no `primaryEvent` field**.

### Important event rule

`events` describe what is visibly present.

Speech does not automatically create a visual event.

For example:

```text
Speech: "We are going to a mountain temple."
Visual: talking-head indoors
```

Correct visual events:

```text
People
Close-up
```

Not automatically:

```text
Mountain
Temple
```

Those labels may only be assigned when the corresponding visuals are actually visible in the source evidence.

Never invent an event because the speaker mentions it.

---

# 8. Event Analysis Has an Editorial Purpose

Events are not only descriptive metadata. They are used to construct the edit.

Examples:

```text
Road + Driving
→ journey/B-roll sequence

Mountain + Landscape
→ scenic reveal / establishing material

Temple + Building
→ destination reveal

Food
→ food stop / human moment

People
→ interaction / reaction / story moment

Wildlife
→ unexpected discovery / curiosity moment

Sunrise/Sunset
→ emotional or music-led payoff

Off-road Terrain + Vehicle
→ adventure sequence
```

The event taxonomy therefore acts as a **controlled vocabulary for editorial retrieval and assembly**.

---

# 9. Three Editorial Media Roles

Every useful section should be thought of in one of three major roles.

## A. Speech-driven

The creator's speech carries the story.

Example:

```text
Creator explains the plan
→ keep original speech
→ keep or minimally cover the talking-head shot
```

## B. Speech + B-roll

The speech is useful, but the original visual is repetitive/static.

Example:

```text
Creator says:
"We found an off-road route toward the hill."

Original visual:
Talking head

Better edit:
Keep speech
+ show exact matching off-road/vehicle footage
```

This can be implemented using a J-cut or L-cut.

## C. Music-driven

There is little or no useful speech and the visuals themselves create the experience.

Example:

```text
Driving
→ landscape
→ village
→ mountain
→ temple exterior
→ sunset
```

Music becomes the narrative glue while the visuals tell the story.

---

# 10. Background Music / Music-Driven Editing — LOCKED

Background music is a first-class part of the architecture, not an afterthought.

The AI editorial analysis must identify footage that is suitable for a music-driven section.

A music candidate should usually have one or more of these qualities:

- visually attractive;
- movement-rich;
- atmospheric;
- scenic;
- emotionally meaningful;
- a reveal;
- a transition;
- travel progression;
- adventure progression;
- destination arrival;
- sunset/sunrise payoff;
- food/market montage;
- walking/exploration sequence.

## Music sections must use exact source footage

A music recommendation is not valid if it merely says:

> "Use some road B-roll."

It must identify:

```text
sourceFile
sourceStart
sourceEnd
events
reason
recommendedMusicRole
```

Example:

```text
sourceFile: DJI_20260830150000_0240_D.MP4
sourceStart: 00:12.400
sourceEnd:   00:18.900

events:
  - Road
  - Driving
  - Landscape
  - B-roll

recommendedMusicRole:
  JOURNEY_MONTAGE

reason:
  Strong continuous movement and changing scenery suitable for a short
  music-led travel transition.
```

The editor must know **exactly which original footage to place under music**.

## Do not discard music-worthy footage simply because there is no speech

Some of the strongest travel-vlog moments may be completely speechless.

These can be more valuable as:

- visual breaths;
- transitions;
- scenic montages;
- destination reveals;
- emotional payoff moments;
- adventure sequences.

---

# 11. Music Section Construction

The AI should create music-driven sections based on **visual/event progression**, not random clips.

A strong montage might be:

```text
Road / Driving
      ↓
Landscape
      ↓
Village / People
      ↓
Mountain
      ↓
Temple / Destination
```

The clips should have enough visual variation to prevent the montage from feeling repetitive.

The AI should prefer complementary clips rather than five nearly identical driving shots.

Music montage duration must also be story-driven. Do not create a 60-second montage when 18 seconds tells the same story better.

---

# 12. Audio Rules

Audio is an editorial signal, not only a technical artifact.

The AI should distinguish:

- useful spoken dialogue;
- repetitive dialogue;
- dialogue that should be shortened;
- dialogue that should remain under B-roll;
- natural ambient moments worth preserving;
- music-driven sections where original dialogue is unnecessary;
- transitions where dialogue bridges two visuals.

Never remove meaningful natural sound automatically if it contributes to the experience.

Examples include:

- vehicle/road ambience;
- crowd sound;
- temple ambience;
- local conversation;
- rain;
- footsteps;
- environmental sounds;
- a genuine reaction.

Where appropriate, natural sound can be layered underneath or between music sections.

---

# 13. B-roll Rules — LOCKED

B-roll recommendations must be **exact and actionable**.

The AI must specify:

```text
source video filename
exact source start timestamp
exact source end timestamp
event labels
what speech it covers
why it is a good match
preferred / alternative ranking when multiple candidates exist
```

Example:

```text
speechRange:
  DJI_20260830123104_0221_D.MP4
  00:07.520–00:15.820

bestBroll:
  DJI_20260830141219_0232_D.MP4
  00:41.200–00:45.800

alternativeBroll:
  DJI_20260830141949_0236_D.MP4
  01:12.500–01:17.100
```

Do not give approximate references such as:

> "Use some footage from the road section."

The editor must be able to locate the footage immediately in DaVinci Resolve.

---

# 14. Exact Timestamp Rule — LOCKED

Every selected piece of footage must have:

- exact source filename;
- exact source start timestamp;
- exact source end timestamp.

This applies to:

- primary story clips;
- B-roll;
- music montage footage;
- transitions;
- destination reveals;
- supporting reaction shots.

Milliseconds should be retained internally. Human-readable timestamps should also be supplied.

---

# 15. Per-Video Editorial Decision Model

For each source video, the AI should evaluate ranges such as:

```text
KEEP
STRONG_KEEP
SHORTEN
KEEP_WITH_BROLL
KEEP_FOR_MUSIC
KEEP_AS_TRANSITION
REMOVE
```

These decisions must be tied to exact source ranges.

A per-video analysis explains:

- what the footage contains;
- its speech role;
- its visual role;
- its story role;
- why it should be kept/removed/shortened;
- what other footage can support it.

---

# 16. Multi-Video Story Assembly

A single vlog may contain many source videos recorded at different times.

The AI must treat them as one **story pool**.

It must not simply concatenate source files.

For example:

```text
Video A = intro
Video B = driving
Video C = food stop
Video D = wrong turn
Video E = off-road
Video F = destination
Video G = sunset
```

The final editorial order could be:

```text
A → D → B → C → E → F → G
```

if that creates the strongest story.

Every reordered clip must still preserve its exact source filename and source timestamps.

---

# 17. Master Timeline

When multiple source videos are analyzed, `edit_timeline.json` must contain a chronological **master timeline**.

The master timeline represents the order in which the editor should assemble the vlog.

Each master timeline item should contain at minimum:

```text
sequenceOrder
editorialSection
sourceFile
sourceStart
sourceEnd
decision
mediaRole
events
speechRole
reason
```

For music sections it should additionally identify:

```text
musicRole
musicSectionId
musicReason
```

The master timeline is the primary assembly blueprint for DaVinci Resolve.

---

# 18. Recommended Story Section Types

The AI may assign useful editorial section labels such as:

```text
HOOK
INTRO
PLAN
JOURNEY
OBSERVATION
FOOD_STOP
LOCAL_INTERACTION
PROBLEM
UNEXPECTED_EVENT
ADVENTURE
DESTINATION_REVEAL
EXPLORATION
WOW_MOMENT
MUSIC_MONTAGE
VERDICT
USEFUL_INFO
OUTRO
```

These are editorial roles, not visual-event taxonomy labels.

The closed visual event taxonomy remains separate and must not be expanded casually.

---

# 19. Natural Solo-Vlogger Storytelling

For solo footage there may be no family/friend chemistry to carry the story.

The equivalent structure is:

```text
Creator
  ↕
Situation
  ↕
Environment
  ↕
Observation
  ↕
Local interaction
  ↕
Reaction
  ↕
Discovery/problem
```

The editor should preserve the creator's personality through:

- genuine reactions;
- observations;
- small mistakes;
- spontaneous humor;
- local conversations;
- reactions to weather/traffic/routes;
- moments of uncertainty;
- moments of discovery.

---

# 20. Hook Rules

The first part of the video should create immediate curiosity.

A strong hook may come from:

- the biggest problem;
- the biggest surprise;
- an unusual destination fact;
- a risky-looking but safe/permitted adventure premise;
- a destination reveal;
- a surprising result;
- an emotional payoff teased early.

Do not waste the opening on:

- long greetings;
- unnecessary setup;
- repeated destination descriptions;
- unrelated talking-head footage.

The hook can use footage from later in the journey when doing so improves curiosity, while preserving truthful context.

---

# 21. Real Problems and Unexpected Events

Real-life interruptions are valuable editorial material.

Examples:

- wrong turn;
- road closure;
- unexpected rain;
- unexpected local interaction;
- route confusion;
- vehicle issue;
- unexpected discovery;
- destination not being what was expected.

Do not automatically remove these because they interrupt the planned itinerary.

They may be the thing that turns a generic travel vlog into a story.

---

# 22. Safety / Evidence Boundaries

The AI must not encourage unsafe or unauthorized activity merely because footage suggests an adventure opportunity.

For off-road, restricted, private or difficult terrain:

- describe what the footage visibly shows;
- preserve the creator's actual experience;
- do not invent permission;
- do not claim a route is safe without evidence;
- do not confuse one trail/location with another.

The editorial system is responsible for storytelling, not for inventing travel facts.

---

# 23. `analysis_bundle.zip`

The Python analysis pipeline should produce a package containing the evidence needed by the editorial stage.

Typical per-video structure:

```text
<video-stem>/
    proxy.mp4
    audio.m4a
    transcript.json
    scenes.json
    frames/
        frame_0001.jpg
        frame_0002.jpg
        ...
    analysis.json
```

The final package is:

```text
analysis_bundle.zip
```

The bundle is an **evidence package**, not the final edit.

---

# 24. `analysis.json` Responsibility

The per-video `analysis.json` should preserve objective information required for later editorial reasoning, including:

- exact source filename;
- source-relative path where applicable;
- source duration;
- source hash;
- technical metadata;
- proxy information;
- transcript reference/content;
- detected scenes;
- frame references;
- other analysis evidence generated by the pipeline.

The editorial AI must use this evidence rather than guessing from filename semantics alone.

---

# 25. `edit_timeline.json` Responsibility

`edit_timeline.json` is the **editorial source of truth** after AI analysis.

It must capture, where applicable:

### Global

- schema version;
- analysis type;
- source/evidence policy;
- locked editorial duration policy;
- closed visual event taxonomy;
- overall story summary;
- final target duration;
- estimated assembled duration.

### Per video

- exact source filename;
- source duration;
- overall editorial decision;
- story role;
- speech assessment;
- visual assessment;
- selected ranges;
- removed ranges;
- shortened ranges;
- exact B-roll relationships;
- music-worthy ranges;
- DaVinci assembly instructions.

### Master timeline

- final chronological assembly order;
- editorial sections;
- exact source ranges;
- speech/media roles;
- event labels;
- B-roll links;
- music section links;
- transition instructions.

The JSON is a **blueprint**, not a rendered video.

---

# 26. Suggested `edit_timeline.json` Conceptual Structure

```json
{
  "schemaVersion": 3,
  "analysisType": "AI_EDITOR_TIMELINE",
  "editorialDurationPolicy": {},
  "eventTaxonomy": [],
  "story": {
    "summary": "...",
    "estimatedFinalDuration": "10:45",
    "durationAssessment": "SUPPORTED_BY_STRONG_STORY_MATERIAL"
  },
  "videos": {},
  "brollRecommendations": [],
  "musicSections": [],
  "masterTimeline": [],
  "daVinciAssembly": {}
}
```

The exact schema may evolve, but the responsibilities described in this README remain locked unless deliberately revised.

---

# 27. Music Section Conceptual Structure

A music section should be represented approximately like:

```json
{
  "musicSectionId": "MUSIC_01",
  "storyRole": "JOURNEY_MONTAGE",
  "sourceRanges": [
    {
      "sourceFile": "DJI_20260830150000_0240_D.MP4",
      "start": "00:12.400",
      "end": "00:18.900",
      "events": [
        "Road",
        "Driving",
        "Landscape",
        "B-roll"
      ]
    }
  ],
  "musicReason": "Creates a short visual journey progression before the destination reveal.",
  "audioPlan": "MUSIC_PRIMARY_WITH_NATURAL_SOUND_OPTIONAL"
}
```

The important requirement is not the exact field spelling; it is that the editor knows **which exact footage forms the music section and why**.

---

# 28. Editing Transitions

Transitions should be motivated by the story, not added as decoration.

Prefer:

- direct cuts;
- J-cuts;
- L-cuts;
- natural sound bridges;
- motivated B-roll transitions;
- visual match/continuity where useful.

Do not add transitions merely because two clips are different.

---

# 29. DaVinci Resolve Assembly Guidance

The AI does not need to render the final video.

It must instead provide enough information for manual assembly:

```text
1. Locate source file
2. Go to exact source timestamp
3. Place the specified range in the specified story position
4. Apply KEEP / SHORTEN / B-ROLL / MUSIC instruction
5. Follow audio guidance
6. Move to next master timeline item
```

A future converter may transform the timeline into FCPXML/EDL or another editing interchange format, but the authoritative editorial model remains `edit_timeline.json`.

---

# 30. Re-analysis Rules

If a source filename is analyzed again:

- replace that video's editorial entry with the new analysis;
- preserve unrelated source-video entries;
- maintain exact filenames and timestamps;
- do not silently mix old and new analysis ranges for the same source file.

When additional videos are uploaded, the AI should extend the same master story rather than treating each bundle as an isolated vlog unless explicitly instructed otherwise.

---

# 31. Quality Gate Before Finalizing `edit_timeline.json`

Before the final timeline is produced, verify all of the following:

### Evidence integrity

- no invented visual events;
- no unsupported locations/objects/actions;
- exact source filenames exist;
- exact timestamps are present;
- B-roll uses exact ranges;
- music sections use exact source ranges.

### Story quality

- hook appears early;
- curiosity is established;
- story has forward momentum;
- journey footage has a purpose;
- real problems/discoveries are preserved;
- destination has a payoff;
- ending gives a satisfying verdict/outro.

### Editing quality

- dead time removed;
- repetitive explanations removed;
- repetitive road footage reduced;
- long static talking-head sections covered when good B-roll exists;
- music-worthy visuals are not discarded;
- transitions are motivated;
- natural sound is preserved where valuable.

### Duration

- 8–12 minutes is the normal acceptable range;
- 10–12 minutes is preferred when strong material supports it;
- shorter is acceptable when the story is genuinely stronger shorter;
- longer material should be cut aggressively for repetition/dead time;
- no padding to hit a quota.

---

# 32. The Core Rule for Future Vlogs

Every future vlog should follow this mental model:

```text
ANALYZE THE FOOTAGE
        ↓
UNDERSTAND WHAT ACTUALLY HAPPENED
        ↓
FIND THE STORY
        ↓
FIND THE STRONGEST HOOK
        ↓
SELECT THE BEST SPEECH
        ↓
SELECT THE BEST VISUAL EVENTS
        ↓
CONNECT SPEECH TO EXACT B-ROLL
        ↓
IDENTIFY MUSIC-DRIVEN VISUAL MOMENTS
        ↓
BUILD THE STORY IN EDITORIAL ORDER
        ↓
CUT REPETITION / DEAD TIME
        ↓
CHECK RETENTION + STORY LOGIC
        ↓
TARGET 8–12 MINUTES ONLY WHEN SUPPORTED
        ↓
WRITE `edit_timeline.json`
        ↓
ASSEMBLE IN DAVINCI RESOLVE
```

The system should optimize for the feeling:

> **“I’m sitting in the passenger seat with you.”**

That is the north-star editorial objective for this project.
