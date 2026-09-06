-- Verify Resolve timeline audio placement.
-- Run from Workspace > Scripts > Utility inside DaVinci Resolve.

local function out(msg)
    print("RESOLVE AUDIO VERIFY: " .. tostring(msg))
end

local function getResolve()
    local ok, result = pcall(function()
        if app and app.GetResolve then return app:GetResolve() end
        return nil
    end)
    if ok and result then return result end
    return nil
end

local ok, err = xpcall(function()
    local resolve = getResolve()
    assert(resolve, "Could not obtain Resolve API")
    local pm = resolve:GetProjectManager()
    assert(pm, "Project Manager unavailable")
    local project = pm:GetCurrentProject()
    assert(project, "No current project")
    local timeline = project:GetCurrentTimeline()
    assert(timeline, "No current timeline")

    out("Project: " .. tostring(project:GetName()))
    out("Timeline: " .. tostring(timeline:GetName()))

    for _, trackType in ipairs({"video", "audio"}) do
        local count = tonumber(timeline:GetTrackCount(trackType)) or 0
        out(string.format("%s tracks: %d", trackType, count))
        for track = 1, count do
            local items = timeline:GetItemListInTrack(trackType, track) or {}
            out(string.format("%s%d items: %d", trackType == "video" and "V" or "A", track, #items))
            if trackType == "audio" then
                for i, item in ipairs(items) do
                    local name = "?"
                    local start = "?"
                    local duration = "?"
                    pcall(function() name = item:GetName() end)
                    pcall(function() start = item:GetStart() end)
                    pcall(function() duration = item:GetDuration() end)
                    out(string.format("  A%d[%02d] name=%s start=%s duration=%s", track, i, tostring(name), tostring(start), tostring(duration)))
                end
            end
        end
    end

    local musicName = "Warriyo-Laura Brehm-Mortals.mp3"
    local root = project:GetMediaPool():GetRootFolder()
    local found = false
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == musicName then
            found = true
            out("Music in Media Pool: YES")
            local props = item:GetClipProperty() or {}
            out("Music duration: " .. tostring(props["Duration"] or "?"))
            out("Music start: " .. tostring(props["Start"] or "?"))
            out("Music end: " .. tostring(props["End"] or "?"))
            break
        end
    end
    if not found then out("Music in Media Pool: NO") end
    out("DONE")
end, debug.traceback)

if not ok then out("ERROR: " .. tostring(err)) end
