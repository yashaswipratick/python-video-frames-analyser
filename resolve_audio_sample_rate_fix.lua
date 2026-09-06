-- Kaiwara / Kailasagiri Resolve audio environment diagnostic + fix
-- Purpose: force the current project/timeline audio sample rate to 48 kHz,
-- report the before/after value, and inspect the first camera clip's audio metadata.

local function getResolve()
    local ok, result = pcall(function()
        if app and app.GetResolve then return app:GetResolve() end
        return nil
    end)
    if ok and result then return result end
    return nil
end

local function show(title, msg)
    print("KAIWARA AUDIO FIX: " .. tostring(msg))
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser(title, {{"Message", "Text", Text = msg}})
        end)
    end
end

local function safeGetSetting(obj, key)
    local ok, v = pcall(function() return obj:GetSetting(key) end)
    if ok then return v end
    return nil
end

local function main()
    show("Kaiwara Audio Fix", "STARTED\n\nChecking current Resolve project and Fairlight sample rate...")

    local resolve = getResolve()
    assert(resolve, "Could not obtain Resolve API")

    local pm = assert(resolve:GetProjectManager(), "Project Manager unavailable")
    local project = assert(pm:GetCurrentProject(), "No current Resolve project is open")
    local timeline = project:GetCurrentTimeline()
    assert(timeline, "No current timeline is open")

    local before = safeGetSetting(project, "timelineSampleRate")
    local frameRate = safeGetSetting(project, "timelineFrameRate")
    local timelineAudioRate = safeGetSetting(timeline, "timelineSampleRate")

    show("Kaiwara Audio Fix", string.format(
        "PROJECT DETECTED\n\nProject: %s\nTimeline: %s\nProject audio sample rate: %s\nTimeline audio sample rate: %s\nFrame rate: %s\n\nForcing project audio sample rate to 48000 Hz...",
        tostring(project:GetName()), tostring(timeline:GetName()), tostring(before), tostring(timelineAudioRate), tostring(frameRate)
    ))

    local setOk = false
    local setErr = nil
    local ok, result = pcall(function()
        return project:SetSetting("timelineSampleRate", "48000")
    end)
    if ok and result == true then
        setOk = true
    else
        setErr = tostring(result)
    end

    local after = safeGetSetting(project, "timelineSampleRate")

    -- Inspect first V1 clip and its underlying MediaPool item properties.
    local first = nil
    local items = timeline:GetItemListInTrack("video", 1) or {}
    if #items > 0 then first = items[1] end

    local clipName = "N/A"
    local mediaAudioRate = "N/A"
    local mediaAudioChannels = "N/A"
    if first then
        pcall(function()
            clipName = tostring(first:GetName())
        end)
        local mpi = nil
        pcall(function()
            mpi = first:GetMediaPoolItem()
        end)
        if mpi then
            mediaAudioRate = tostring(safeGetSetting(mpi, "Audio Sample Rate") or mpi:GetClipProperty("Audio Sample Rate") or "N/A")
            mediaAudioChannels = tostring(mpi:GetClipProperty("Audio Channels") or "N/A")
        end
    end

    local message = string.format(
        "KAIWARA AUDIO ENVIRONMENT\n\nProject: %s\nTimeline: %s\n\nBefore sample rate: %s\nAfter sample rate: %s\nSetSetting success: %s\n\nFirst V1 clip: %s\nSource audio sample rate: %s\nSource audio channels: %s\n\n%s\n\nNEXT: rebuild the first-clip test timeline after this setting is applied. Do not change clip speed or pitch.",
        tostring(project:GetName()), tostring(timeline:GetName()), tostring(before), tostring(after), tostring(setOk),
        clipName, mediaAudioRate, mediaAudioChannels,
        setOk and "48 kHz setting applied." or ("Could not change the setting: " .. tostring(setErr))
    )

    show("Kaiwara Audio Fix", message)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    show("Kaiwara Audio Fix ERROR", tostring(err))
end
