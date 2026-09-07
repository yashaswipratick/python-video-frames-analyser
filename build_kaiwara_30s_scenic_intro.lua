-- Kaiwara / Kailasagiri Hills - 30 SECOND SCENIC INTRO
--
-- Standalone intro builder.
-- Creates a separate 30s Resolve timeline made ONLY from scenic visuals:
-- landscape, mountain, scenic roads, destination reveals and off-road.
-- Source audio is intentionally excluded; Mortals.mp3 is placed on A1.
--
-- This does NOT modify the Human Story timeline or any source media.
-- The visual sequence is edited as a cinematic cold-open with progression:
-- ROAD -> LANDSCAPE -> HILL -> REVEAL -> OFF-ROAD -> MOUNTAIN PAYOFF.
--
-- The source ranges are taken from the reviewed footage pool already analyzed.
-- The sequence deliberately samples different source videos so the intro feels
-- like a trailer for the day's journey rather than one long road shot.

local MEDIA_DIR = "/Users/yashaswipratick/Documents/video-analyser/videos"
local MUSIC_FILE = "Warriyo-Laura Brehm-Mortals.mp3"
local TIMELINE_BASE = "Kaiwara_30s_Scenic_Intro"
local FPSN, FPSD = 30000, 1001

-- IMPORTANT: these durations total exactly 30.0 seconds.
-- label, sourceFile, sourceStartSec, sourceEndSec, visualRole
local SHOTS = {
    {"01_SCENIC_ROAD_OPEN", "DJI_20260830141219_0232_D.MP4", 4.820, 7.320, "SCENIC ROAD"},
    {"02_ROAD_PROGRESS", "DJI_20260830141434_0233_D.MP4", 61.500, 64.500, "ROAD / JOURNEY"},
    {"03_HILL_APPROACH", "DJI_20260830150748_0245-1_D.MP4", 0.620, 3.620, "MOUNTAIN APPROACH"},
    {"04_HILL_REVEAL", "DJI_20260830150748_0245_D.MP4", 0.000, 3.000, "LANDSCAPE REVEAL"},
    {"05_MOUNTAIN_ESTABLISHING", "DJI_20260830151054_0246_D.MP4", 0.000, 3.000, "MOUNTAIN / ESTABLISHING"},
    {"06_DESTINATION_SCENERY", "DJI_20260830160147_0267_D.MP4", 68.690, 71.190, "DESTINATION SCENERY"},
    {"07_OFFROAD_TERRAIN", "DJI_20260830165231_0284-1_D.MOV", 28.430, 31.430, "OFF-ROAD"},
    {"08_OFFROAD_CLIMB", "DJI_20260830165745_0285_D.MP4", 3.860, 6.860, "OFF-ROAD CLIMB"},
    {"09_HIGHER_ROUTE", "DJI_20260830173839_0290_D.MP4", 20.140, 23.140, "ADVENTURE / HIGHER"},
    {"10_MOUNTAIN_VIEW_PAYOFF", "DJI_20260830165231_0284-2_D.MOV", 0.000, 4.000, "MOUNTAIN PAYOFF"}
}

local function popup(title, text)
    print("KAIWARA 30S SCENIC INTRO: " .. text)
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
    local n = tonumber(clipProp(item, "Frames"))
    if n and n > 0 then return math.floor(n) end

    local duration = tostring(clipProp(item, "Duration") or "")
    local h, m, s, f = duration:match("^(%d+):(%d+):(%d+):(%d+)$")
    if h then
        return math.floor(((tonumber(h) * 3600) + (tonumber(m) * 60) + tonumber(s)) * (FPSN / FPSD) + tonumber(f) + 0.5)
    end
    return nil
end

local function secondsToFrames(seconds)
    return math.floor(seconds * (FPSN / FPSD) + 0.5)
end

local function ensureMedia(root, mediaPool, filename)
    local item = findRootClip(root, filename)
    if item then return item end

    local imported = mediaPool:ImportMedia({MEDIA_DIR .. "/" .. filename})
    if imported then
        for _, candidate in ipairs(imported) do
            if candidate:GetName() == filename then return candidate end
        end
    end
    return nil
end

local function createUniqueTimeline(mediaPool, baseName)
    local timeline = mediaPool:CreateEmptyTimeline(baseName)
    if timeline then return timeline, baseName end

    for i = 2, 99 do
        local name = baseName .. "_Run" .. tostring(i)
        timeline = mediaPool:CreateEmptyTimeline(name)
        if timeline then return timeline, name end
    end

    error("Could not create timeline: " .. baseName)
end

local function validateRange(item, startSec, endSec)
    local total = assert(numericFrames(item), "Could not determine frames for " .. item:GetName())
    local startFrame = math.max(0, secondsToFrames(startSec))
    local endFrame = math.min(total - 1, math.max(startFrame, secondsToFrames(endSec) - 1))
    if endFrame < startFrame then
        error(string.format("Invalid range %.3f-%.3f for %s", startSec, endSec, item:GetName()))
    end
    return startFrame, endFrame, endFrame - startFrame + 1
end

local function appendVideoOnly(mediaPool, timeline, root, row, recordFrame)
    local label, filename, startSec, endSec, role = row[1], row[2], row[3], row[4], row[5]
    local item = assert(ensureMedia(root, mediaPool, filename), "Missing source: " .. filename)
    local startFrame, endFrame, frames = validateRange(item, startSec, endSec)

    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem = item,
        startFrame = startFrame,
        endFrame = endFrame,
        recordFrame = recordFrame,
        trackIndex = 1,
        mediaType = 1
    }})

    if not result or #result == 0 then
        error("Failed to append scenic shot: " .. filename)
    end

    pcall(function()
        timeline:AddMarker(
            recordFrame,
            "Blue",
            label,
            string.format("%s | %s | source %s %.3f-%.3f", role, label, filename, startSec, endSec),
            math.max(1, frames),
            "SCENIC_INTRO"
        )
    end)

    return recordFrame + frames, frames
end

local function addMusic(mediaPool, timeline, root, durationFrames)
    local musicItem = assert(ensureMedia(root, mediaPool, MUSIC_FILE), "Missing music: " .. MUSIC_FILE)
    local totalMusicFrames = assert(numericFrames(musicItem), "Could not determine music duration")
    local remaining = durationFrames
    local record = 0
    local source = 0
    local guard = 0

    while remaining > 0 and guard < 50 do
        guard = guard + 1
        local available = totalMusicFrames - source
        if available <= 0 then
            source = 0
            available = totalMusicFrames
        end

        local take = math.min(remaining, available)
        local result = mediaPool:AppendToTimeline({{
            mediaPoolItem = musicItem,
            startFrame = source,
            endFrame = source + take - 1,
            recordFrame = record,
            trackIndex = 1,
            mediaType = 2
        }})

        if not result or #result == 0 then
            error("Failed to append music")
        end

        record = record + take
        remaining = remaining - take
        source = source + take
    end

    pcall(function()
        timeline:AddMarker(
            0,
            "Green",
            "MUSIC_MORTALS",
            "Warriyo - Laura Brehm - Mortals | full 30s scenic intro music bed",
            math.max(1, durationFrames),
            "MUSIC"
        )
    end)
end

local function main()
    popup("Kaiwara 30s Scenic Intro", "STARTED\n\nBuilding a separate 30-second scenic cold-open from the reviewed video pool.")

    local resolve = assert(getResolve(), "Resolve API unavailable")
    local projectManager = assert(resolve:GetProjectManager(), "Project Manager unavailable")
    local project = assert(projectManager:GetCurrentProject(), "No active Resolve project")

    pcall(function()
        project:SetSetting("timelineFrameRate", "29.97")
        project:SetSetting("timelineResolutionWidth", "1920")
        project:SetSetting("timelineResolutionHeight", "1080")
    end)

    local mediaPool = assert(project:GetMediaPool(), "Media Pool unavailable")
    local root = assert(mediaPool:GetRootFolder(), "Media Pool root unavailable")
    mediaPool:SetCurrentFolder(root)

    local timeline, timelineName = createUniqueTimeline(mediaPool, TIMELINE_BASE)
    assert(timeline:SetStartTimecode("00:00:00:00") == true, "Could not set timeline start timecode")
    project:SetCurrentTimeline(timeline)

    while (tonumber(timeline:GetTrackCount("video")) or 0) < 1 do
        assert(timeline:AddTrack("video"), "Could not create V1")
    end
    while (tonumber(timeline:GetTrackCount("audio")) or 0) < 1 do
        assert(timeline:AddTrack("audio"), "Could not create A1")
    end

    local recordFrame = 0
    local totalFrames = 0
    local shotCount = 0

    for _, row in ipairs(SHOTS) do
        local nextFrame, frames = appendVideoOnly(mediaPool, timeline, root, row, recordFrame)
        recordFrame = nextFrame
        totalFrames = totalFrames + frames
        shotCount = shotCount + 1
    end

    -- With the exact ranges above, totalFrames should represent 30.00 seconds.
    -- Music is added underneath for the complete intro duration.
    addMusic(mediaPool, timeline, root, totalFrames)

    project:SetCurrentTimeline(timeline)

    local durationSeconds = totalFrames / (FPSN / FPSD)
    local withinTolerance = math.abs(durationSeconds - 30.0) < 0.08
    if not withinTolerance then
        error(string.format("Intro duration validation failed: %.3fs (expected ~30s)", durationSeconds))
    end

    popup(
        "Kaiwara 30s Scenic Intro",
        string.format([[COMPLETE

Timeline: %s
Scenic shots: %d
Visual duration: %.2f seconds

V1 = video-only scenic footage
A1 = Mortals music bed
Original camera audio: EXCLUDED
Speed changes: NONE
Effects: NONE
Source media modified: NO

VISUAL ARC
Road -> road progression -> mountain approach -> hill reveal ->
mountain establishing -> destination scenery -> off-road -> rocky climb ->
higher route -> mountain payoff

This timeline is completely separate from the main vlog edit.]], timelineName, shotCount, durationSeconds)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    popup("Kaiwara 30s Scenic Intro ERROR", tostring(err))
end
