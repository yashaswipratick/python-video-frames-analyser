-- Kaiwara / Kailasagiri edit verification helper
--
-- Purpose: make the already-built edit timeline the CURRENT Resolve timeline.
-- No duplicate, compound clip, or media insertion is performed.
-- This avoids unnecessary Resolve API operations and lets the user verify
-- the exact generated edit directly in the Edit page.

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

    local v1 = #(timeline:GetItemListInTrack("video", 1) or {})
    local v2 = #(timeline:GetItemListInTrack("video", 2) or {})
    local a1 = #(timeline:GetItemListInTrack("audio", 1) or {})
    local a2 = #(timeline:GetItemListInTrack("audio", 2) or {})

    project:SetCurrentTimeline(timeline)

    print("KAIWARA VERIFY: current timeline set to " .. timeline:GetName())
    print("KAIWARA VERIFY: V1 items = " .. tostring(v1))
    print("KAIWARA VERIFY: V2 items = " .. tostring(v2))
    print("KAIWARA VERIFY: A1 items = " .. tostring(a1))
    print("KAIWARA VERIFY: A2 items = " .. tostring(a2))

    success(string.format([[
KAIWARA EDIT TIMELINE READY

Timeline: %s

V1 main clips: %d
V2 B-roll clips: %d
A1 audio clips: %d
A2 audio/music clips: %d

Resolve is now showing the generated edit timeline directly.
No clips were duplicated or modified.
Press Play on the Edit page to verify the complete edit.]],
        timeline:GetName(), v1, v2, a1, a2
    ))
end, debug.traceback)

if not ok then
    fail(err)
end
