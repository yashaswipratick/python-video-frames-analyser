-- Kaiwara / Kailasagiri first-clip A/V diagnostic
-- Run in a fresh Resolve project.
-- Creates a tiny test timeline with ONLY the first spoken camera clip.
-- No B-roll, no music, no effects.
-- Purpose: isolate source A/V speed, sync, and distortion from the full edit.

local MEDIA_FILE = "/Users/yashaswipratick/Documents/video-analyser/videos/DJI_20260830123104_0221_D.MP4"
local TIMELINE_NAME = "Kaiwara_First_Clip_Audio_Test"
local FPS = "29.97"
local WIDTH = "1920"
local HEIGHT = "1080"

local function popup(title, text)
    print("KAIWARA AUDIO TEST: " .. text)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser(title, {{"Message", "Text", Text = text}})
        end)
    end
end

local function resolveAPI()
    local ok, r = pcall(function()
        if app and app.GetResolve then return app:GetResolve() end
        return nil
    end)
    if ok and r then return r end
    return nil
end

local function findClip(root, name)
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == name then return item end
    end
    return nil
end

local function prop(item, key)
    local ok, value = pcall(function() return item:GetClipProperty(key) end)
    if ok then return tostring(value or "") end
    return "<unavailable>"
end

local ok, err = xpcall(function()
    popup("Kaiwara Audio Test", "STARTING\n\nFresh one-clip A/V diagnostic is running...")

    local resolve = assert(resolveAPI(), "Could not obtain Resolve API")
    popup("Kaiwara Audio Test", "1/6 Resolve API acquired")

    local pm = assert(resolve:GetProjectManager(), "Project Manager unavailable")
    local project = assert(pm:GetCurrentProject(), "No current Resolve project is open")
    popup("Kaiwara Audio Test", "2/6 Project detected: " .. tostring(project:GetName()))

    pcall(function() project:SetSetting("timelineFrameRate", FPS) end)
    pcall(function() project:SetSetting("timelineResolutionWidth", WIDTH) end)
    pcall(function() project:SetSetting("timelineResolutionHeight", HEIGHT) end)
    pcall(function() project:SetSetting("audioSampleRate", "48000") end)

    local mediaPool = assert(project:GetMediaPool(), "Media Pool unavailable")
    local root = assert(mediaPool:GetRootFolder(), "Media Pool root unavailable")
    mediaPool:SetCurrentFolder(root)

    local mediaItem = findClip(root, "DJI_20260830123104_0221_D.MP4")
    if not mediaItem then
        local imported = mediaPool:ImportMedia({MEDIA_FILE})
        if not imported or #imported == 0 then
            error("Could not import: " .. MEDIA_FILE)
        end
        for _, item in ipairs(imported) do
            if item:GetName() == "DJI_20260830123104_0221_D.MP4" then
                mediaItem = item
                break
            end
        end
    end
    assert(mediaItem, "First source clip was not found after import")
    popup("Kaiwara Audio Test", "3/6 Source clip ready\n\nFPS: " .. prop(mediaItem, "FPS") .. "\nAudio sample rate: " .. prop(mediaItem, "Audio Sample Rate") .. "\nAudio channels: " .. prop(mediaItem, "Audio Channels") .. "\nCodec: " .. prop(mediaItem, "Video Codec"))

    local timeline = mediaPool:CreateEmptyTimeline(TIMELINE_NAME)
    if not timeline then
        for i = 2, 99 do
            timeline = mediaPool:CreateEmptyTimeline(TIMELINE_NAME .. "_Run" .. tostring(i))
            if timeline then break end
        end
    end
    assert(timeline, "Could not create test timeline")

    local startOK = false
    pcall(function() startOK = timeline:SetStartTimecode("00:00:00:00") == true end)
    if not startOK then
        error("Could not set test timeline start timecode to 00:00:00:00")
    end

    project:SetCurrentTimeline(timeline)
    local tc = prop(mediaItem, "Start TC")
    popup("Kaiwara Audio Test", "4/6 Test timeline ready\n\nStart TC reported by source: " .. tc)

    local fps = 30000 / 1001
    local sourceIn = math.floor(4.560 * fps + 0.5)
    local sourceOut = math.floor(24.120 * fps + 0.5) - 1

    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem = mediaItem,
        startFrame = sourceIn,
        endFrame = sourceOut,
        recordFrame = 0,
        trackIndex = 1,
        mediaType = 3
    }})

    assert(result and #result == 1, "Resolve did not place the test A/V clip")

    local first = result[1]
    local itemStart = "<unknown>"
    local itemEnd = "<unknown>"
    pcall(function() itemStart = tostring(first:GetStart()) end)
    pcall(function() itemEnd = tostring(first:GetEnd()) end)

    popup("Kaiwara Audio Test", string.format([[5/6 A/V CLIP INSERTED

Timeline: %s
Source: DJI_20260830123104_0221_D.MP4
Source range: 00:04.560 → 00:24.120
Record frame: 0
Timeline item start: %s
Timeline item end: %s

There is NO B-roll and NO MUSIC in this test.
Play this clip at normal 1x speed.]], timeline:GetName(), itemStart, itemEnd))

    popup("Kaiwara Audio Test", [[6/6 TEST READY

Play the clip from the Edit page at normal 1x.

Check three things:
1. Voice speed
2. Voice/video synchronization
3. Any distortion/vibration

Do NOT press L multiple times.
Do NOT run the main builder yet.]])
end, debug.traceback)

if not ok then
    popup("Kaiwara Audio Test ERROR", tostring(err))
end
