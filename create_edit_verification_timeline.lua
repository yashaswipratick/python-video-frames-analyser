-- Kaiwara / Kailasagiri edit verification timeline
--
-- Purpose:
--   Take the already-built Kaiwara_Kailasagiri_Final_Edit_Lua timeline,
--   duplicate it, turn the duplicate into a compound clip, and place that
--   compound clip into a fresh verification timeline.
--
-- This gives a clearly visible timeline clip that can be played to verify
-- picture/audio playback without modifying the original edited timeline.
-- The compound clip retains the edit internally, including V1/V2/A1/A2.

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

local function safeTimelineByName(pm, name)
    local ok, result = pcall(function()
        return pm:GetTimelineList()
    end)
    if ok and result then
        for _, tl in ipairs(result) do
            if tl:GetName() == name then
                return tl
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

    local sourceTimeline = safeTimelineByName(pm, SOURCE_TIMELINE)
    assert(sourceTimeline, "Could not find source timeline: " .. SOURCE_TIMELINE)

    print("KAIWARA VERIFY: source timeline = " .. sourceTimeline:GetName())
    print("KAIWARA VERIFY: source V1 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("video", 1) or {})))
    print("KAIWARA VERIFY: source V2 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("video", 2) or {})))
    print("KAIWARA VERIFY: source A1 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("audio", 1) or {})))
    print("KAIWARA VERIFY: source A2 items = " .. tostring(#(sourceTimeline:GetItemListInTrack("audio", 2) or {})))

    -- Duplicate first, so the original edited timeline is never modified.
    local duplicateName = SOURCE_TIMELINE .. "_VERIFY_SOURCE"
    local duplicate = nil
    pcall(function()
        duplicate = sourceTimeline:DuplicateTimeline(duplicateName)
    end)

    if not duplicate then
        -- Fall back to a unique duplicate name if a previous verification run
        -- left one behind.
        for i = 2, 99 do
            local candidate = duplicateName .. "_" .. tostring(i)
            pcall(function()
                duplicate = sourceTimeline:DuplicateTimeline(candidate)
            end)
            if duplicate then
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
    print("KAIWARA VERIFY: duplicate items collected = " .. tostring(#allItems))

    -- Create a compound clip from the duplicated edit. Resolve's API provides
    -- CreateCompoundClip([timelineItems], clipInfo); this preserves the
    -- internal multi-track edit while making it usable as a single timeline item.
    local compound = duplicate:CreateCompoundClip(allItems, {
        startTimecode = "01:00:00:00",
        name = COMPOUND_NAME
    })
    assert(compound, "Could not create verification compound clip")

    local compoundMedia = compound:GetMediaPoolItem()
    assert(compoundMedia, "Compound clip has no Media Pool item")

    print("KAIWARA VERIFY: compound media pool item = " .. compoundMedia:GetName())

    local mediaPool = project:GetMediaPool()
    assert(mediaPool, "Media Pool unavailable")

    local verifyName = VERIFY_TIMELINE
    local verifyTimeline = mediaPool:CreateEmptyTimeline(verifyName)
    if not verifyTimeline then
        for i = 2, 99 do
            local candidate = VERIFY_TIMELINE .. "_Run" .. tostring(i)
            verifyTimeline = mediaPool:CreateEmptyTimeline(candidate)
            if verifyTimeline then
                verifyName = candidate
                break
            end
        end
    end
    assert(verifyTimeline, "Could not create verification timeline")

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

Timeline: %s
Visible clip: %s

The visible clip contains the complete edited timeline internally:
V1 main story + V2 B-roll + A1 source audio + A2 music.

Play this verification timeline to check audio speed, distortion,
vibration and A/V sync. The original edited timeline was not modified.]],
        verifyName,
        compoundMedia:GetName()
    ))
end, debug.traceback)

if not ok then
    fail(err)
end
