-- Kaiwara / Kailasagiri edit verification helper
--
-- Finds the generated edit timeline inside the CURRENT Resolve PROJECT,
-- duplicates it, and creates a separate verification timeline.
-- It does not modify the original edited timeline.

local SOURCE_TIMELINE = "Kaiwara_Kailasagiri_Final_Edit_Lua"
local COMPOUND_NAME = "Kaiwara_EDIT_VERIFICATION_COMPOUND"
local VERIFY_TIMELINE = "Kaiwara_EDIT_VERIFICATION"

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
    if ok and result then return result end
    return nil
end

-- IMPORTANT: timeline lookup is project-scoped. Resolve's Project API exposes
-- GetTimelineCount/GetTimelineByIndex; ProjectManager:GetTimelineList() is not
-- reliable for this sandboxed Resolve build.
local function findTimelineInProject(project, name)
    -- Fast path: the generated timeline may already be the current timeline.
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

local function uniqueTimeline(project, mediaPool, baseName)
    local timeline = mediaPool:CreateEmptyTimeline(baseName)
    if timeline then
        return timeline, baseName
    end

    for i = 2, 99 do
        local candidate = baseName .. "_Run" .. tostring(i)
        timeline = mediaPool:CreateEmptyTimeline(candidate)
        if timeline then
            return timeline, candidate
        end
    end

    error("Could not create verification timeline: " .. baseName)
end

local ok, err = xpcall(function()
    local resolve = getResolve()
    assert(resolve, "Could not obtain Resolve API")

    local pm = resolve:GetProjectManager()
    assert(pm, "Project Manager unavailable")

    local project = pm:GetCurrentProject()
    assert(project, "No current Resolve project")

    print("KAIWARA VERIFY: project = " .. tostring(project:GetName()))

    local sourceTimeline = findTimelineInProject(project, SOURCE_TIMELINE)
    assert(sourceTimeline, "Could not find source timeline in current project: " .. SOURCE_TIMELINE)

    print("KAIWARA VERIFY: source timeline = " .. sourceTimeline:GetName())
    print("KAIWARA VERIFY: source V1 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("video", 1) or {})))
    print("KAIWARA VERIFY: source V2 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("video", 2) or {})))
    print("KAIWARA VERIFY: source A1 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("audio", 1) or {})))
    print("KAIWARA VERIFY: source A2 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("audio", 2) or {})))

    -- Safely duplicate the existing edit.
    local duplicateName = SOURCE_TIMELINE .. "_VERIFY_SOURCE"
    local duplicate = nil

    local okDuplicate = pcall(function()
        duplicate = sourceTimeline:DuplicateTimeline(duplicateName)
    end)

    if not okDuplicate or not duplicate then
        for i = 2, 99 do
            local candidate = duplicateName .. "_" .. tostring(i)
            local attemptOk = pcall(function()
                duplicate = sourceTimeline:DuplicateTimeline(candidate)
            end)
            if attemptOk and duplicate then
                duplicateName = candidate
                break
            end
        end
    end

    assert(duplicate, "Could not duplicate source timeline for verification")

    project:SetCurrentTimeline(duplicate)

    local allItems = {}
    for _, trackType in ipairs({"video", "audio"}) do
        local trackCount = tonumber(duplicate:GetTrackCount(trackType)) or 0
        for track = 1, trackCount do
            local items = duplicate:GetItemListInTrack(trackType, track) or {}
            for _, item in ipairs(items) do
                allItems[#allItems + 1] = item
            end
        end
    end

    assert(#allItems > 0, "Duplicated timeline contains no timeline items")
    print("KAIWARA VERIFY: duplicated timeline items = " .. tostring(#allItems))

    -- Create compound clip from every item in the duplicated edit.
    local compound = duplicate:CreateCompoundClip(allItems, {
        startTimecode = "01:00:00:00",
        name = COMPOUND_NAME
    })
    assert(compound, "Could not create verification compound clip")

    local compoundMedia = compound:GetMediaPoolItem()
    assert(compoundMedia, "Compound clip has no Media Pool item")

    print("KAIWARA VERIFY: compound media = " .. compoundMedia:GetName())

    local mediaPool = project:GetMediaPool()
    assert(mediaPool, "Media Pool unavailable")

    local verifyTimeline, verifyName = uniqueTimeline(project, mediaPool, VERIFY_TIMELINE)
    project:SetCurrentTimeline(verifyTimeline)

    local placed = mediaPool:AppendToTimeline({{
        mediaPoolItem = compoundMedia,
        recordFrame = 0,
        trackIndex = 1,
        mediaType = 3
    }})

    assert(placed and #placed > 0, "Could not place verification compound on timeline")

    success(string.format([[
KAIWARA VERIFICATION TIMELINE READY

Source: %s
Verification timeline: %s
Visible verification clip: %s

Source tracks:
V1 + V2 + A1 + A2

The original edited timeline was not modified.
Play the verification timeline to inspect video, voice speed,
distortion/vibration and background music.]],
        SOURCE_TIMELINE,
        verifyName,
        compoundMedia:GetName()
    ))
end, debug.traceback)

if not ok then
    fail(err)
end
