-- Resolve Lua native scripting POC
-- Run from Workspace > Scripts > Utility inside DaVinci Resolve.
-- This deliberately places ONE known source clip into a new timeline.

local function getResolve()
    -- Internal Resolve/Fusion scripting environments may expose Resolve through app.
    local ok, result = pcall(function()
        if app and app.GetResolve then
            return app:GetResolve()
        end
        return nil
    end)
    if ok and result then
        return result
    end

    -- Fallback used by many Fusion/Resolve Lua scripts.
    local ok2, result2 = pcall(function()
        if bmd and bmd.scriptapp then
            return bmd.scriptapp("Resolve")
        end
        return nil
    end)
    if ok2 and result2 then
        return result2
    end

    return nil
end

local function show(message)
    print(message)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Lua POC", {
                {"Message", "Text", Text = message}
            })
        end)
    end
end

local resolve = getResolve()
if not resolve then
    show("FAIL: Could not obtain the Resolve API object from the running Resolve instance.")
    return
end

local pm = resolve:GetProjectManager()
if not pm then
    show("FAIL: Resolve object obtained, but Project Manager is unavailable.")
    return
end

local project = pm:GetCurrentProject()
if not project then
    show("FAIL: Open a Resolve project first.")
    return
end

local mediaPool = project:GetMediaPool()
if not mediaPool then
    show("FAIL: Current project has no Media Pool object.")
    return
end

local mediaDir = "/Users/yashaswipratick/Documents/video-analyser/videos"
local sourceName = "DJI_20260830123104_0221_D.MP4"
local sourcePath = mediaDir .. "/" .. sourceName

-- Import one exact source clip so the test is independent of an existing Media Pool state.
local imported = mediaPool:ImportMedia({sourcePath})
if not imported or #imported == 0 then
    show("FAIL: Resolve could not import the POC source clip:\n" .. sourcePath)
    return
end

local mediaItem = imported[1]
if not mediaItem then
    show("FAIL: ImportMedia returned no usable MediaPoolItem.")
    return
end

local timelineName = "Kaiwara_Lua_POC"
local timeline = mediaPool:CreateEmptyTimeline(timelineName)
if not timeline then
    show("FAIL: Could not create timeline: " .. timelineName)
    return
end

project:SetCurrentTimeline(timeline)

-- The exact source range from edit_timeline.json:
-- DJI_20260830123104_0221_D.MP4 00:04.560 -> 00:24.120
-- POC intentionally uses Resolve source-frame properties instead of changing media.
local fps = 30000 / 1001
local startSeconds = 4.560
local endSeconds = 24.120
local startFrame = math.floor(startSeconds * fps + 0.5)
local endFrame = math.floor(endSeconds * fps + 0.5) - 1

local clipInfo = {
    mediaPoolItem = mediaItem,
    startFrame = startFrame,
    endFrame = endFrame,
    recordFrame = 0,
    trackIndex = 1,
    mediaType = 1
}

local result = mediaPool:AppendToTimeline({clipInfo})
if not result or #result == 0 then
    show("FAIL: Resolve created the timeline but could not place the test clip.")
    return
end

local msg = string.format(
    "SUCCESS\n\nTimeline: %s\nSource: %s\nSource range: 00:04.560 -> 00:24.120\nSource frames: %d -> %d\n\nOne clip was placed on V1 at record frame 0.",
    timelineName,
    sourceName,
    startFrame,
    endFrame
)

show(msg)
