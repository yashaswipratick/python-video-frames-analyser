-- Kaiwara / Kailasagiri edit verification helper
--
-- Purpose: make the already-built edit timeline the CURRENT Resolve timeline
-- and move the playhead to the first generated clip so the timeline is
-- immediately visible for verification.
-- No duplicate, compound clip, or media insertion is performed.

local SOURCE_TIMELINE = "Kaiwara_Kailasagiri_Final_Edit_Lua"

local function fail(msg)
    print("KAIWARA VERIFY ERROR: " .. tostring(msg))
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Kaiwara Verification", {
                {"Message", "Text", Text = "ERROR\n\n" .. tostring(msg)}
            })
        end)
    end
end

local function success(msg)
    print(msg)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Kaiwara Verification", {
                {"Message", "Text", Text = msg}
            })
        end)
    end
end

local function getResolve()
    local ok, result = pcall(function()
        if app and app.GetResolve then
            return app:GetResolve()
        end
        return nil
    end)
    if ok and result then
        return result
    end
    return nil
end

local function findTimelineInProject(project, name)
    local okCurrent, current = pcall(function()
        return project:GetCurrentTimeline()
    end)

    if okCurrent and current then
        local okName, currentName = pcall(function()
            return current:GetName()
        end)
        if okName and currentName == name then
            return current
        end
    end

    local okCount, count = pcall(function()
        return project:GetTimelineCount()
    end)

    if not okCount or not count then
        return nil
    end

    count = tonumber(count) or 0
    for index = 1, count do
        local okTimeline, timeline = pcall(function()
            return project:GetTimelineByIndex(index)
        end)
        if okTimeline and timeline then
            local okName, timelineName = pcall(function()
                return timeline:GetName()
            end)
            if okName and timelineName == name then
                return timeline
            end
        end
    end

    return nil
end

local function getItemPosition(item)
    local okStart, startFrame = pcall(function()
        return item:GetStart()
    end)
    local okEnd, endFrame = pcall(function()
        return item:GetEnd()
    end)
    if okStart then
        return tonumber(startFrame) or 0, (okEnd and tonumber(endFrame)) or nil
    end
    return nil, nil
end

local ok, err = xpcall(function()
    local resolve = getResolve()
    assert(resolve, "Could not obtain Resolve API")

    local pm = resolve:GetProjectManager()
    assert(pm, "Project Manager unavailable")

    local project = pm:GetCurrentProject()
    assert(project, "No current Resolve project")

    print("KAIWARA VERIFY: project = " .. tostring(project:GetName()))

    local timeline = findTimelineInProject(project, SOURCE_TIMELINE)
    assert(timeline, "Could not find source timeline in current project: " .. SOURCE_TIMELINE)

    local v1Items = timeline:GetItemListInTrack("video", 1) or {}
    local v2Items = timeline:GetItemListInTrack("video", 2) or {}
    local a1Items = timeline:GetItemListInTrack("audio", 1) or {}
    local a2Items = timeline:GetItemListInTrack("audio", 2) or {}

    local firstItem = v1Items[1]
    local firstStartFrame, firstEndFrame = nil, nil
    if firstItem then
        firstStartFrame, firstEndFrame = getItemPosition(firstItem)
    end

    local setTimelineOk, setTimelineErr = pcall(function()
        project:SetCurrentTimeline(timeline)
    end)
    assert(setTimelineOk, "Could not set current timeline: " .. tostring(setTimelineErr))

    -- Put Resolve on the Edit page.
    pcall(function()
        resolve:OpenPage("edit")
    end)

    -- Force the playhead onto the first generated clip.  Different Resolve
    -- versions expose slightly different timeline-position helpers, so use
    -- the frame value with protected calls and report what succeeded.
    local positioned = false
    if firstStartFrame ~= nil then
        local okPos = pcall(function()
            timeline:SetCurrentTimecode(firstStartFrame)
        end)
        if okPos then
            positioned = true
        else
            okPos = pcall(function()
                timeline:SetCurrentFrame(firstStartFrame)
            end)
            if okPos then
                positioned = true
            end
        end
    end

    print("KAIWARA VERIFY: current timeline set to " .. timeline:GetName())
    print("KAIWARA VERIFY: V1 items = " .. tostring(#v1Items))
    print("KAIWARA VERIFY: V2 items = " .. tostring(#v2Items))
    print("KAIWARA VERIFY: A1 items = " .. tostring(#a1Items))
    print("KAIWARA VERIFY: A2 items = " .. tostring(#a2Items))
    print("KAIWARA VERIFY: first V1 start frame = " .. tostring(firstStartFrame))
    print("KAIWARA VERIFY: first V1 end frame = " .. tostring(firstEndFrame))
    print("KAIWARA VERIFY: playhead positioned = " .. tostring(positioned))

    success(string.format([[
KAIWARA EDIT TIMELINE READY

Timeline: %s

V1 main clips: %d
V2 B-roll clips: %d
A1 audio clips: %d
A2 audio/music clips: %d

First V1 clip start frame: %s
First V1 clip end frame: %s
Playhead positioned: %s

Resolve has been switched to the Edit page and the generated edit timeline is current.
No clips were duplicated or modified.

Press Play now.]],
        timeline:GetName(), #v1Items, #v2Items, #a1Items, #a2Items,
        tostring(firstStartFrame), tostring(firstEndFrame), tostring(positioned)
    ))
end, debug.traceback)

if not ok then
    fail(err)
end
