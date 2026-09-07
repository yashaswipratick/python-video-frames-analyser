-- Kaiwara / Kailasagiri Hills HUMAN EDIT timeline builder
--
-- Purpose:
--   Build a near-finished, human-editable vlog timeline instead of a selects reel.
--
-- Editorial model:
--   HOOK -> WELCOME/PLAN -> BREAKFAST SEARCH -> FOOD -> SUGARCANE ->
--   SCENIC JOURNEY -> DESTINATION -> CAVE/TEMPLE -> LOCAL INFO ->
--   OFFROAD SETUP -> OFFROAD ESCALATION -> MOUNTAIN PAYOFF -> SECOND CLIMB ->
--   RETURN/REFLECTION -> VERDICT/OUTRO
--
-- Design rules:
--   * Use selected source ranges where prior review established strong material.
--   * Protect the user's required scenes, but trim them to useful story beats
--     when a reviewed range exists.
--   * Use V2 for scenic/B-roll overlays and A2 for music on visual breathing sections.
--   * Keep original source files untouched.
--   * No speed changes, no effects, no destructive media edits.
--   * Timeline markers explain the editorial purpose of each section.
--
-- IMPORTANT:
--   Some newly required clips were identified by scene description but do not
--   have a reviewed timestamp range in the repository. Those are inserted as
--   FULL SOURCE CLIPS with a marker saying "TRIM MANUALLY" so the scene is never
--   silently omitted. Everything else uses reviewed editorial ranges.

local MEDIA_DIR = "/Users/yashaswipratick/Documents/video-analyser/videos"
local MUSIC_FILE = MEDIA_DIR .. "/Warriyo-Laura Brehm-Mortals.mp3"
local TIMELINE_BASE = "Kaiwara_Human_Story_Edit"
local FPS = "29.97"
local WIDTH = "1920"
local HEIGHT = "1080"

-- Main story. start/end are source seconds where reviewed. nil/nil = full source.
-- music=true means a music cue is added during this sequence section.
local MAIN = {
    {"HOOK_01_OFFROAD_TEASE", "DJI_20260830165231_0284-1_D.MOV", 0, nil, true,  "Cold open: tease the later adventure; trim to a strong 3-5s visual."},
    {"HOOK_02_MOUNTAIN_PAYOFF", "DJI_20260830165231_0284-2_D.MOV", 0, nil, true,  "Fast scenic payoff before the welcome."},

    {"WELCOME_INTRO", "DJI_20260830123104_0221_D.MP4", 4.560, 29.300, false, "Natural welcome + destination/offroad promise."},
    {"JOURNEY_START", "DJI_20260830124910_0224_D.MP4", 3.660, 16.820, false, "Trip starts; establish distance and traffic."},
    {"BREAKFAST_SEARCH", "DJI_20260830124910_0224_D.MP4", 17.700, 38.400, false, "Small problem: finding breakfast."},

    {"BREAKFAST_RESTAURANT", "DJI_20260830125616_0226_D.MP4", 6.000, 39.630, false, "Restaurant arrival and natural interaction."},
    {"BREAKFAST_WHAT_WE_ATE", "DJI_20260830125616_0227_D.MOV", nil, nil, false, "Show what we actually ate; trim to strongest lines/visuals."},

    {"JOURNEY_AFTER_FOOD", "DJI_20260830141434_0233_D.MP4", 1.500, 29.500, false, "Leave food stop and transition back to the road."},
    {"SUGARCANE_PARKING", "DJI_20260830143533_0239_D.MP4", nil, nil, false, "Spontaneous roadside stop; full source only because timing was not reviewed."},
    {"SUGARCANE_PRICE_ORDER", "DJI_20260830125616_0239-1_D.MOV", nil, nil, false, "Ask price and watch it being made; trim manually if any dead air."},
    {"SUGARCANE_FRIEND_REACTION", "DJI_20260830125616_0239-2_D.MOV", nil, nil, false, "Human/funny reaction with friend; keep the strongest exchange."},

    {"SCENIC_JOURNEY", "DJI_20260830141219_0232_D.MP4", 4.820, 58.690, true, "Compress repetitive road footage; keep narration and change visuals."},
    {"HILL_APPROACH", "DJI_20260830150748_0245-1_D.MP4", 0.620, 11.500, true, "First strong hill approach/reveal."},
    {"DESTINATION_REVEAL_A", "DJI_20260830150748_0245_D.MP4", 0, nil, true, "Use only strongest 3-6s fragments from this reveal pool."},
    {"DESTINATION_REVEAL_B", "DJI_20260830151054_0246_D.MP4", 0, nil, true, "Secondary speechless establishing view."},

    {"DESTINATION_EXPLAIN", "DJI_20260830153327_0251_D.MP4", 6.360, 28.720, false, "Arrival + explanation of temple/hill."},
    {"TREK_REACTION", "DJI_20260830153327_0251_D.MP4", 29.960, 65.960, false, "Walking/trek reaction; preserve genuine effort, cut repetition."},
    {"SPYSS_LADY", "DJI_20260830154154_0255_D.MP4", 11.180, 17.680, false, "Local interaction; keep only if the exchange is clear."},
    {"VISHNU_IDOL", "DJI_20260830154604_0256_D.MP4", nil, nil, false, "Required idol scene; trim to clean reveal if long."},
    {"CAVE_INSIDE", "DJI_20260830154840_0263_D.MP4", 33.370, 157.010, false, "Main cave exploration; shorten aggressively to discoveries/reactions."},
    {"CAVE_SURROUNDINGS", "DJI_20260830160147_0267_D.MP4", 68.690, 71.810, true, "Short exterior/scenic punctuation."},

    {"PRASAD_TIMINGS", "DJI_20260830162420_0278_D.MP4", 0, 10.800, false, "Useful prasadam/timing information."},
    {"SPYSS_INFORMATION", "DJI_20260830162845_0280_D.MP4", nil, nil, false, "Required local information; full source because timing was not reviewed."},
    {"PARKING_OFFROAD_INFO", "DJI_20260830163649_0281_D.MP4", 2.030, 22.110, false, "Parking/offroad setup."},

    {"OFFROAD_HANDOFF", "DJI_20260830164511_0283_D.MP4", 100.860, 123.050, false, "Humorous handoff / adventure starts."},
    {"MANDATORY_OFFROAD", "DJI_20260830165231_0284-1_D.MOV", nil, nil, false, "Mandatory scene; use strongest offroad moments."},
    {"MOUNTAIN_VIEW", "DJI_20260830165231_0284-2_D.MOV", nil, nil, true, "Scenic payoff after the first climb."},
    {"OFFROAD_TIME_LAPSE", "DJI_20260830171102_0288_D.MP4", 0, 10.043, true, "Fast transition/time-lapse connector."},

    {"NEXT_OFFROAD_DESTINATION", "DJI_20260830173839_0290_D.MP4", 20.140, 83.570, false, "Story turn: we're going even higher."},
    {"OFFROAD_PAYOFF", "DJI_20260830173839_0290_D.MP4", 88.750, 189.990, false, "Escalate the second climb; cut repeated terrain."},
    {"OFFROAD_SITUATION_INFO", "DJI_20260830181824_0294_D.MP4", 18.580, 76.780, false, "Explain what the offroad is actually like."},
    {"OFFROAD_STEEPNESS", "DJI_20260830182058_0295_D.MP4", 0.620, 27.140, false, "Steep section + authentic reaction; keep concise."},

    {"RETURN_MUSIC", "DJI_20260830182900_0292_D.MP4", 0, 8.141, true, "Short descent/return breathing space."},
    {"RETURN_NATURAL", "DJI_20260830182950_0293_D.MP4", 5.770, 21.970, false, "Natural wrap-up conversation."},
    {"REFLECTION_SUNSET", "DJI_20260830190000_0300_D.MP4", 144.000, 202.660, true, "Late-day reflection/sunset; verify visually if exact source differs."},
    {"FINAL_VERDICT", "DJI_20260830192000_0302_D.MP4", 7.150, 30.070, false, "Concise verdict / useful takeaway."},
    {"OUTRO", "DJI_20260830192000_0302_D.MP4", 30.070, 51.040, false, "Natural ending and CTA."}
}

-- V2 scenic overlays. They intentionally overlap the audio-driven main story.
-- Only use clips with known strong visual ranges from prior review.
local BROLL = {
    {"HILL_BROLL_1", "DJI_20260830150748_0245_D.MP4", 0, 6.0, 0.0, "Destination reveal overlay."},
    {"HILL_BROLL_2", "DJI_20260830151054_0246_D.MP4", 0, 5.0, 6.0, "Secondary establishing overlay."},
    {"WIDE_CAVE_SURROUNDINGS", "DJI_20260830160147_0267_D.MP4", 1.0, 3.1, 0.0, "Exterior atmosphere over destination speech."}
}

-- Music cues are placed as independent A2 clips in story sections.
-- start/end are timeline seconds; the music source is reused with different slices.
local MUSIC = {
    {"HOOK_MUSIC", 0.0, 10.0, 0.0, 10.0, -18.0},
    {"SCENIC_MUSIC", 210.0, 245.0, 10.0, 45.0, -20.0},
    {"DESTINATION_REVEAL_MUSIC", 250.0, 280.0, 45.0, 75.0, -19.0},
    {"OFFROAD_MUSIC", 390.0, 470.0, 75.0, 155.0, -17.0},
    {"MOUNTAIN_PAYOFF_MUSIC", 470.0, 505.0, 155.0, 190.0, -19.0},
    {"RETURN_SUNSET_MUSIC", 585.0, 630.0, 190.0, 235.0, -21.0}
}

local function popup(title, text)
    print("KAIWARA HUMAN EDIT: " .. text)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser(title, {{"Message", "Text", Text = text}})
        end)
    end
end

local function getResolve()
    local ok, result = pcall(function()
        if app and app.GetResolve then return app:GetResolve() end
        return nil
    end)
    if ok and result then return result end
    return nil
end

local function findRootClip(root, name)
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == name then return item end
    end
    return nil
end

local function clipProp(item, key)
    local ok, value = pcall(function() return item:GetClipProperty(key) end)
    if ok then return value end
    return nil
end

local function numericFrames(item)
    local value = clipProp(item, "Frames")
    local n = tonumber(value)
    if n and n > 0 then return math.floor(n) end
    local duration = tostring(clipProp(item, "Duration") or "")
    local h, m, s, f = duration:match("^(%d+):(%d+):(%d+):(%d+)$")
    if h then
        local fps = 30000 / 1001
        return math.floor((tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)) * fps + tonumber(f) + 0.5)
    end
    return nil
end

local function secondsToFrames(sec)
    return math.floor(sec * (30000 / 1001) + 0.5)
end

local function ensureMedia(root, mediaPool, name)
    local item = findRootClip(root, name)
    if item then return item end
    local imported = mediaPool:ImportMedia({MEDIA_DIR .. "/" .. name})
    if imported then
        for _, candidate in ipairs(imported) do
            if candidate:GetName() == name then return candidate end
        end
    end
    return nil
end

local function uniqueTimeline(mediaPool, base)
    local timeline = mediaPool:CreateEmptyTimeline(base)
    if timeline then return timeline, base end
    for i = 2, 99 do
        local name = base .. "_Run" .. tostring(i)
        timeline = mediaPool:CreateEmptyTimeline(name)
        if timeline then return timeline, name end
    end
    error("Could not create timeline: " .. base)
end

local function sourceRangeFrames(item, startSec, endSec)
    local total = assert(numericFrames(item), "Could not determine frames for " .. item:GetName())
    if startSec == nil or endSec == nil then
        return 0, total - 1, total
    end
    local startF = math.max(0, secondsToFrames(startSec))
    local endF = math.min(total - 1, math.max(startF, secondsToFrames(endSec) - 1))
    return startF, endF, endF - startF + 1
end

local function appendMain(mediaPool, timeline, row, recordFrame)
    local label, name, startSec, endSec, musicFlag, note = row[1], row[2], row[3], row[4], row[5], row[6]
    local item = ensureMedia(timeline.__root, mediaPool, name)
    if not item then error("Missing source: " .. name) end

    local startF, endF, frames = sourceRangeFrames(item, startSec, endSec)
    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem = item,
        startFrame = startF,
        endFrame = endF,
        recordFrame = recordFrame,
        trackIndex = 1,
        mediaType = 3
    }})
    if not result or #result == 0 then error("Failed to append V1/A1: " .. name) end

    local markerName = label
    local markerNote = note
    if startSec == nil or endSec == nil then
        markerNote = markerNote .. " | FULL SOURCE - TRIM MANUALLY"
    end
    pcall(function()
        timeline:AddMarker(recordFrame, "Blue", markerName, markerNote, math.max(1, math.floor(frames)), "STORY_BEAT")
    end)

    return recordFrame + frames, frames, musicFlag
end

local function appendMusic(mediaPool, timeline, musicItem, startTimelineSec, endTimelineSec, sourceStartSec, sourceEndSec, gainDb, cueName)
    local srcStart = secondsToFrames(sourceStartSec)
    local srcEnd = math.max(srcStart, secondsToFrames(sourceEndSec) - 1)
    local recStart = secondsToFrames(startTimelineSec)
    local recEnd = secondsToFrames(endTimelineSec) - 1
    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem = musicItem,
        startFrame = srcStart,
        endFrame = srcEnd,
        recordFrame = recStart,
        trackIndex = 2,
        mediaType = 2
    }})
    if not result or #result == 0 then
        error("Failed to append music cue: " .. cueName)
    end

    -- Best-effort clip gain. If this Resolve build does not expose the property,
    -- the music remains on A2 and is still easy to adjust manually.
    local ti = result[1]
    pcall(function() ti:SetProperty("Audio Gain", gainDb) end)
    pcall(function() ti:SetProperty("Volume", 10 ^ (gainDb / 20)) end)

    pcall(function()
        timeline:AddMarker(recStart, "Green", cueName, string.format("Music cue %.1fdB", gainDb), math.max(1, recEnd - recStart + 1), "MUSIC")
    end)
end

local function appendBroll(mediaPool, timeline, row)
    local label, name, srcStart, srcEnd, timelineStart, note = row[1], row[2], row[3], row[4], row[5], row[6]
    local item = ensureMedia(timeline.__root, mediaPool, name)
    if not item then error("Missing B-roll source: " .. name) end
    local startF, endF, frames = sourceRangeFrames(item, srcStart, srcEnd)
    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem = item,
        startFrame = startF,
        endFrame = endF,
        recordFrame = secondsToFrames(timelineStart),
        trackIndex = 2,
        mediaType = 1
    }})
    if not result or #result == 0 then error("Failed to append V2 B-roll: " .. name) end
    pcall(function()
        timeline:AddMarker(secondsToFrames(timelineStart), "Yellow", "BROLL_" .. label, note, math.max(1, frames), "BROLL")
    end)
end

local function main()
    popup("Kaiwara Human Edit", "STARTED\n\nBuilding story-driven vlog timeline with selected ranges, scenic music cues and B-roll overlays.")

    local resolve = assert(getResolve(), "Could not obtain Resolve API")
    local pm = assert(resolve:GetProjectManager(), "Project Manager unavailable")
    local project = assert(pm:GetCurrentProject(), "No current Resolve project is open")
    pcall(function() project:SetSetting("timelineFrameRate", FPS) end)
    pcall(function() project:SetSetting("timelineResolutionWidth", WIDTH) end)
    pcall(function() project:SetSetting("timelineResolutionHeight", HEIGHT) end)

    local mediaPool = assert(project:GetMediaPool(), "Media Pool unavailable")
    local root = assert(mediaPool:GetRootFolder(), "Media Pool root unavailable")
    mediaPool:SetCurrentFolder(root)

    local timeline, timelineName = uniqueTimeline(mediaPool, TIMELINE_BASE)
    timeline.__root = root
    pcall(function() assert(timeline:SetStartTimecode("00:00:00:00")) end)
    project:SetCurrentTimeline(timeline)

    local vc = tonumber(timeline:GetTrackCount("video")) or 0
    while vc < 2 do
        if not timeline:AddTrack("video") then error("Could not add video track") end
        vc = vc + 1
    end
    local ac = tonumber(timeline:GetTrackCount("audio")) or 0
    while ac < 2 do
        if not timeline:AddTrack("audio") then error("Could not add audio track") end
        ac = ac + 1
    end

    popup("Kaiwara Human Edit", "1/4 Timeline created: " .. timelineName)

    local needed = {}
    for _, row in ipairs(MAIN) do needed[row[2]] = true end
    for _, row in ipairs(BROLL) do needed[row[2]] = true end
    needed["Warriyo-Laura Brehm-Mortals.mp3"] = true

    local available = {}
    local missing = {}
    for name, _ in pairs(needed) do
        local item = ensureMedia(root, mediaPool, name)
        if item then available[name] = item else missing[#missing + 1] = name end
    end
    if #missing > 0 then
        error("Missing required media:\n" .. table.concat(missing, "\n"))
    end

    popup("Kaiwara Human Edit", "2/4 All source media imported/available")

    local recordFrame = 0
    local mainCount = 0
    for _, row in ipairs(MAIN) do
        local nextFrame, frames = appendMain(mediaPool, timeline, row, recordFrame)
        recordFrame = nextFrame
        mainCount = mainCount + 1
        print(string.format("KAIWARA HUMAN EDIT: %d/%d %s (%d frames)", mainCount, #MAIN, row[1], frames))
    end

    -- Place music after the main story is built. These cues intentionally overlap
    -- selected timeline regions; exact start points can be nudged by the editor.
    for _, cue in ipairs(MUSIC) do
        appendMusic(mediaPool, timeline, available["Warriyo-Laura Brehm-Mortals.mp3"], cue[2], cue[3], cue[4], cue[5], cue[6], cue[1])
    end

    -- Add a few deliberately sparse scenic overlays. These are not meant to turn
    -- every talking section into B-roll; they punctuate the places where visuals
    -- should carry the story.
    for _, row in ipairs(BROLL) do
        appendBroll(mediaPool, timeline, row)
    end

    project:SetCurrentTimeline(timeline)

    popup("Kaiwara Human Edit", string.format([[3/4 STORY TIMELINE BUILT

Timeline: %s
Main story beats: %d
Tracks: V1 + V2 | A1 + A2
Music cues: %d
Scenic/B-roll overlays: %d

Editorial shape:
Hook -> Welcome/Plan -> Breakfast -> Sugarcane -> Scenic Journey ->
Destination -> Cave/Temple -> Useful Info -> Offroad -> Mountain Payoff ->
Second Climb -> Return -> Verdict -> Outro

Selected ranges are used wherever reviewed. Newly required scenes without a
reviewed range are clearly marked FULL SOURCE - TRIM MANUALLY.
]], timelineName, mainCount, #MUSIC, #BROLL))

    popup("Kaiwara Human Edit", [[4/4 READY

Resolve is now on the human-editable story timeline.

First review pass:
1. Watch straight through without editing.
2. Trim only the FULL SOURCE - TRIM MANUALLY markers that contain dead air.
3. Keep dialogue and reactions that move the story.
4. Let music carry scenic sections, then duck/trim it around speech.
5. Remove repeated road/offroad shots, not the meaningful story beats.

Original media was not modified.]] )
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    popup("Kaiwara Human Edit ERROR", tostring(err))
end
