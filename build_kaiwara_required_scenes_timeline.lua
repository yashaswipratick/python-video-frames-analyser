-- Kaiwara / Kailasagiri REQUIRED-SCENES SELECTS timeline builder
--
-- Purpose: build a scene-complete manual-edit timeline containing every
-- user-mandated scene identified during review.
--
-- IMPORTANT:
--   * This is NOT the polished final edit.
--   * The listed source files are inserted as FULL source clips so no
--     required moment is silently trimmed or omitted.
--   * The user can manually trim non-required / excess portions afterward.
--   * Main clips are inserted as linked A/V (mediaType=3).
--   * No music, B-roll overlays, speed changes, effects, or audio processing.
--   * Original media is never modified.

local MEDIA_DIR = "/Users/yashaswipratick/Documents/video-analyser/videos"
local TIMELINE_BASE = "Kaiwara_REQUIRED_SCENES_Selects"
local FPS = "29.97"
local WIDTH = "1920"
local HEIGHT = "1080"

-- Ordered according to the user's requested story flow.
local REQUIRED = {
    {"01_LUNCH_RESTAURANT_ARRIVAL", "DJI_20260830125616_0226_D.MP4"},
    {"02_LUNCH_WHAT_WE_ATE", "DJI_20260830125616_0227_D.MOV"},
    {"03_SUGARCANE_PARKING", "DJI_20260830143533_0239_D.MP4"},
    {"04_SUGARCANE_PRICE_AND_ORDER", "DJI_20260830125616_0239-1_D.MOV"},
    {"05_FRIEND_SUGARCANE_REACTION", "DJI_20260830125616_0239-2_D.MOV"},
    {"06_REACH_TEMPLE_AND_EXPLAIN", "DJI_20260830153327_0251_D.MP4"},
    {"07_SPYSS_LADY_INFORMATION", "DJI_20260830154154_0255_D.MP4"},
    {"08_LORD_VISHNU_IDOL", "DJI_20260830154604_0256_D.MP4"},
    {"09_INSIDE_CAVE_VISUALS", "DJI_20260830154840_0263_D.MP4"},
    {"10_CAVE_TEMPLE_SURROUNDINGS", "DJI_20260830160147_0267_D.MP4"},
    {"11_ANNA_PRASAD_TIMINGS", "DJI_20260830162420_0278_D.MP4"},
    {"12_SPYSS_PERSON_INFORMATION", "DJI_20260830162845_0280_D.MP4"},
    {"13_PARKING_AND_OFFROAD_EXPLANATION", "DJI_20260830163649_0281_D.MP4"},
    {"14_OFFROAD_HANDOFF", "DJI_20260830164511_0283_D.MP4"},
    {"15_MANDATORY_OFFROAD_SCENE", "DJI_20260830165231_0284-1_D.MOV"},
    {"16_MOUNTAIN_VIEW", "DJI_20260830165231_0284-2_D.MOV"},
    {"17_TIMELAPSE", "DJI_20260830171102_0288_D.MP4"},
    {"18_NEXT_OFFROAD_DESTINATION_HIGHER", "DJI_20260830173839_0290_D.MP4"},
    {"19_OFFROAD_SITUATION_EXPLANATION", "DJI_20260830181824_0294_D.MP4"},
    {"20_OFFROAD_STEEPNESS", "DJI_20260830182058_0295_D.MP4"}
}

local function popup(title, text)
    print("KAIWARA REQUIRED SCENES: " .. text)
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

    -- Fallback: Resolve may expose duration as HH:MM:SS:FF.
    local duration = tostring(clipProp(item, "Duration") or "")
    local h, m, s, f = duration:match("^(%d+):(%d+):(%d+):(%d+)$")
    if h then
        local fps = 30000 / 1001
        return math.floor((tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)) * fps + tonumber(f) + 0.5)
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

local function main()
    popup("Kaiwara Required Scenes", "STARTED\n\nBuilding a scene-complete manual-edit timeline with all 20 required source files.")

    local resolve = assert(getResolve(), "Could not obtain Resolve API")
    popup("Kaiwara Required Scenes", "1/6 Resolve API acquired")

    local pm = assert(resolve:GetProjectManager(), "Project Manager unavailable")
    local project = assert(pm:GetCurrentProject(), "No current Resolve project is open")
    popup("Kaiwara Required Scenes", "2/6 Project detected: " .. tostring(project:GetName()))

    pcall(function() project:SetSetting("timelineFrameRate", FPS) end)
    pcall(function() project:SetSetting("timelineResolutionWidth", WIDTH) end)
    pcall(function() project:SetSetting("timelineResolutionHeight", HEIGHT) end)

    local mediaPool = assert(project:GetMediaPool(), "Media Pool unavailable")
    local root = assert(mediaPool:GetRootFolder(), "Media Pool root unavailable")
    mediaPool:SetCurrentFolder(root)

    local items = {}
    local missing = {}
    for _, row in ipairs(REQUIRED) do
        local label = row[1]
        local name = row[2]
        local item = findRootClip(root, name)
        if not item then
            local imported = mediaPool:ImportMedia({MEDIA_DIR .. "/" .. name})
            if imported then
                for _, candidate in ipairs(imported) do
                    if candidate:GetName() == name then
                        item = candidate
                        break
                    end
                end
            end
        end
        if item then
            items[#items + 1] = {label = label, name = name, item = item}
        else
            missing[#missing + 1] = name
        end
    end

    if #missing > 0 then
        error("Required source files missing:\n" .. table.concat(missing, "\n"))
    end

    popup("Kaiwara Required Scenes", "3/6 All 20 required source files are available")

    local timeline, timelineName = uniqueTimeline(mediaPool, TIMELINE_BASE)
    local startOK = false
    pcall(function() startOK = timeline:SetStartTimecode("00:00:00:00") == true end)
    if not startOK then
        error("Could not set timeline start timecode to 00:00:00:00")
    end

    project:SetCurrentTimeline(timeline)

    -- Ensure dedicated video/audio tracks.
    local videoCount = tonumber(timeline:GetTrackCount("video")) or 0
    while videoCount < 1 do
        if not timeline:AddTrack("video") then error("Could not add V1") end
        videoCount = videoCount + 1
    end
    local audioCount = tonumber(timeline:GetTrackCount("audio")) or 0
    while audioCount < 1 do
        if not timeline:AddTrack("audio") then error("Could not add A1") end
        audioCount = audioCount + 1
    end

    popup("Kaiwara Required Scenes", "4/6 Timeline created: " .. timelineName)

    local recordFrame = 0
    local placed = 0
    local details = {}

    for index, row in ipairs(items) do
        local frames = numericFrames(row.item)
        if not frames then
            error("Could not determine source frame count for: " .. row.name)
        end

        local result = mediaPool:AppendToTimeline({{
            mediaPoolItem = row.item,
            startFrame = 0,
            endFrame = frames - 1,
            recordFrame = recordFrame,
            trackIndex = 1,
            mediaType = 3
        }})

        if not result or #result == 0 then
            error("Failed to place required scene: " .. row.name)
        end

        pcall(function()
            timeline:AddMarker(recordFrame, "Blue", row.label, row.name .. " (FULL SOURCE CLIP - trim manually)", math.max(1, math.floor(frames)), "REQUIRED_SCENE")
        end)

        placed = placed + 1
        recordFrame = recordFrame + frames
        details[#details + 1] = string.format("%02d  %-36s %s  (%d frames)", index, row.label, row.name, frames)
        print("KAIWARA REQUIRED SCENES: PLACED " .. tostring(index) .. "/20 " .. row.name)
    end

    project:SetCurrentTimeline(timeline)

    popup("Kaiwara Required Scenes", string.format([[5/6 ALL REQUIRED SCENES PLACED

Timeline: %s
Required scenes: %d/20
Track structure: V1 + A1 linked A/V
Music: NONE
B-roll overlays: NONE
Speed/effects: NONE

Every required source clip was inserted as its FULL source duration.
The intended use is to manually trim non-required portions after review.
]], timelineName, placed))

    popup("Kaiwara Required Scenes", string.format([[6/6 READY

Timeline: %s
Total required scenes placed: %d/20

Resolve is now on the scene-complete timeline.
Review from the beginning and manually trim anything unnecessary.
No original media was modified.

The 20 required scenes are represented by timeline markers named 01-20.]], timelineName, placed))
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    popup("Kaiwara Required Scenes ERROR", tostring(err))
end
