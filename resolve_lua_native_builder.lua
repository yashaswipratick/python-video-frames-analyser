-- Kaiwara / Kailasagiri Resolve-native Lua builder
-- Run from: Workspace > Scripts > resolve_lua_native_builder
--
-- This is the Lua execution path for the sandboxed Resolve Lite installation.
-- It reads the existing resolve_assembly.json, imports the exact source media,
-- creates a 29.97 fps timeline, and places main story, B-roll and music cues.
-- It never modifies the original media or edit_timeline.json.

local CONFIG = {
    assembly = "/Users/yashaswipratick/projects/python-video-frames-analyser/resolve_assembly.json",
    mediaDir = "/Users/yashaswipratick/Documents/video-analyser/videos",
    musicFile = "/Users/yashaswipratick/Documents/video-analyser/videos/Warriyo-Laura Brehm-Mortals.mp3",
    timelineName = "Kaiwara_Kailasagiri_Final_Edit_Lua",
    fps = 30000 / 1001,
    width = 1920,
    height = 1080
}

local function fail(message)
    print("RESOLVE LUA BUILDER ERROR: " .. tostring(message))
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Lua Builder", {
                {"Message", "Text", Text = "ERROR\n\n" .. tostring(message)}
            })
        end)
    end
end

local function success(message)
    print(message)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Lua Builder", {
                {"Message", "Text", Text = message}
            })
        end)
    end
end

-- Small self-contained JSON decoder. This avoids relying on an optional Lua JSON module.
local JSON = {}

function JSON.decode(text)
    local pos = 1
    local len = #text

    local function skip()
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == " " or c == "\t" or c == "\r" or c == "\n" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local function parseString()
        assert(text:sub(pos, pos) == '"', "expected string")
        pos = pos + 1
        local out = {}
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(out)
            elseif c == "\\" then
                pos = pos + 1
                local e = text:sub(pos, pos)
                local map = {
                    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                    ['b'] = '\b', ['f'] = '\f', ['n'] = '\n',
                    ['r'] = '\r', ['t'] = '\t'
                }
                if map[e] then
                    out[#out + 1] = map[e]
                    pos = pos + 1
                elseif e == "u" then
                    local hex = text:sub(pos + 1, pos + 4)
                    assert(#hex == 4 and hex:match("^%x%x%x%x$"), "invalid unicode escape")
                    local code = tonumber(hex, 16)
                    -- JSON in this project is ASCII/UTF-8 for the fields we consume.
                    if code < 128 then
                        out[#out + 1] = string.char(code)
                    else
                        out[#out + 1] = "?"
                    end
                    pos = pos + 5
                else
                    error("invalid escape: \\" .. tostring(e))
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        error("unterminated string")
    end

    local function parseValue()
        skip()
        local c = text:sub(pos, pos)
        if c == '"' then
            return parseString()
        elseif c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            while true do
                skip()
                local key = parseString()
                skip()
                assert(text:sub(pos, pos) == ":", "expected ':'")
                pos = pos + 1
                obj[key] = parseValue()
                skip()
                local sep = text:sub(pos, pos)
                if sep == "}" then
                    pos = pos + 1
                    return obj
                end
                assert(sep == ",", "expected ',' or '}'")
                pos = pos + 1
            end
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if text:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            while true do
                arr[#arr + 1] = parseValue()
                skip()
                local sep = text:sub(pos, pos)
                if sep == "]" then
                    pos = pos + 1
                    return arr
                end
                assert(sep == ",", "expected ',' or ']'")
                pos = pos + 1
            end
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            local number = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            assert(number and #number > 0, "invalid JSON value near position " .. tostring(pos))
            pos = pos + #number
            return tonumber(number)
        end
    end

    local value = parseValue()
    skip()
    assert(pos > len, "trailing data after JSON value")
    return value
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then
        error("Cannot read file: " .. path)
    end
    local data = f:read("*all")
    f:close()
    return data
end

local function parseSeconds(value)
    if type(value) == "number" then
        return value
    end
    local s = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
    local parts = {}
    for p in s:gmatch("[^:]+") do
        parts[#parts + 1] = p
    end
    if #parts == 1 then
        return tonumber(parts[1])
    elseif #parts == 2 then
        return tonumber(parts[1]) * 60 + tonumber(parts[2])
    elseif #parts == 3 then
        return tonumber(parts[1]) * 3600 + tonumber(parts[2]) * 60 + tonumber(parts[3])
    end
    error("Invalid timestamp: " .. s)
end

local function round(x)
    return math.floor(x + 0.5)
end

local function frameAtSeconds(seconds, fps)
    return round(seconds * fps)
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

local function getClipProperty(item, key, fallback)
    local ok, value = pcall(function() return item:GetClipProperty(key) end)
    if not ok or value == nil then
        return fallback
    end
    if type(value) == "table" then
        value = value[key]
    end
    return value
end

local function getSourceStart(item)
    local value = tonumber(getClipProperty(item, "Start", "0"))
    return value or 0
end

local function findRootItem(root, name)
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == name then
            return item
        end
    end
    return nil
end

local function pathFor(name)
    return CONFIG.mediaDir .. "/" .. name
end

local function collectRequiredNames(assembly)
    local names = {}
    local seen = {}
    local function add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for _, item in ipairs(assembly.mainTimeline or {}) do
        add(item.sourceFile)
    end
    for _, item in ipairs(assembly.brollOverlays or {}) do
        add(item.sourceFile)
    end
    add("Warriyo-Laura Brehm-Mortals.mp3")
    return names
end

local function importMissing(mediaPool, root, names)
    local missingPaths = {}
    local missingNames = {}
    local lookup = {}
    for _, name in ipairs(names) do
        local item = findRootItem(root, name)
        if item then
            lookup[name] = item
        else
            missingPaths[#missingPaths + 1] = pathFor(name)
            missingNames[#missingNames + 1] = name
        end
    end

    if #missingPaths > 0 then
        local imported = mediaPool:ImportMedia(missingPaths)
        if not imported then
            error("Resolve imported no media. Check Media Storage permissions.")
        end
        for _, item in ipairs(imported) do
            lookup[item:GetName()] = item
        end
    end

    -- Re-read the root after ImportMedia because already-imported and newly-imported
    -- items can be represented differently by the API's return value.
    for _, name in ipairs(names) do
        if not lookup[name] then
            local item = findRootItem(root, name)
            if item then lookup[name] = item end
        end
    end

    for _, name in ipairs(names) do
        if not lookup[name] then
            error("Media Pool item not found: " .. name)
        end
    end
    return lookup
end

local function appendClip(mediaPool, mediaItem, sourceStart, sourceEnd, recordFrame, trackIndex, mediaType, label)
    -- AppendToTimeline expects a list containing clip-info tables.
    local clipInfo = {
        mediaPoolItem = mediaItem,
        startFrame = sourceStart,
        endFrame = sourceEnd,
        recordFrame = recordFrame,
        trackIndex = trackIndex,
        mediaType = mediaType
    }
    local ok, result = pcall(function()
        return mediaPool:AppendToTimeline({clipInfo})
    end)
    if not ok or not result or #result == 0 then
        error("Failed to place " .. label)
    end
    return result[1]
end

local function ensureTrack(timeline, trackType, desired)
    local count = tonumber(timeline:GetTrackCount(trackType)) or 0
    while count < desired do
        local ok = timeline:AddTrack(trackType)
        if not ok then error("Could not add " .. trackType .. " track") end
        count = count + 1
    end
end

local ok, err = xpcall(function()
    local assemblyText = readFile(CONFIG.assembly)
    local assembly = JSON.decode(assemblyText)
    assert(type(assembly) == "table", "resolve_assembly.json did not decode to an object")
    assert(type(assembly.mainTimeline) == "table" and #assembly.mainTimeline > 0, "mainTimeline is empty")

    local resolve = getResolve()
    assert(resolve, "Could not obtain Resolve API from the running Resolve instance")

    local pm = resolve:GetProjectManager()
    assert(pm, "Project Manager unavailable")
    local project = pm:GetCurrentProject()
    assert(project, "Open a Resolve project first")

    -- Set project defaults before creating the new timeline.
    pcall(function() project:SetSetting("timelineFrameRate", "29.97") end)
    pcall(function() project:SetSetting("timelineResolutionWidth", tostring(CONFIG.width)) end)
    pcall(function() project:SetSetting("timelineResolutionHeight", tostring(CONFIG.height)) end)

    local mediaPool = project:GetMediaPool()
    assert(mediaPool, "Media Pool unavailable")
    local root = mediaPool:GetRootFolder()
    mediaPool:SetCurrentFolder(root)

    local names = collectRequiredNames(assembly)
    local byName = importMissing(mediaPool, root, names)

    local timeline = mediaPool:CreateEmptyTimeline(CONFIG.timelineName)
    assert(timeline, "Could not create timeline: " .. CONFIG.timelineName)
    project:SetCurrentTimeline(timeline)

    ensureTrack(timeline, "video", 2)
    ensureTrack(timeline, "audio", 2)

    local recordFrame = 0
    local mainPlaced = 0
    local mainAudioPlaced = 0
    local brollPlaced = 0
    local musicPlaced = 0

    -- Main story: V1 and source audio on A1 at the same record positions.
    for idx, item in ipairs(assembly.mainTimeline) do
        local name = tostring(item.sourceFile)
        local mediaItem = byName[name]
        local fps = CONFIG.fps
        local sourceBase = getSourceStart(mediaItem)
        local inSec = parseSeconds(item.sourceStart)
        local outSec = parseSeconds(item.sourceEnd)
        assert(outSec > inSec, "Invalid range in mainTimeline[" .. idx .. "]")

        -- Resolve's clip-info start/end are source-frame coordinates; sourceBase
        -- anchors them to the imported clip's native source start.
        local sourceIn = sourceBase + frameAtSeconds(inSec, fps)
        local sourceOut = sourceBase + frameAtSeconds(outSec, fps)
        local duration = sourceOut - sourceIn
        assert(duration > 0, "Zero duration in mainTimeline[" .. idx .. "]")

        appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 1, "V1 mainTimeline[" .. idx .. "]")
        mainPlaced = mainPlaced + 1

        appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 2, "A1 mainTimeline[" .. idx .. "]")
        mainAudioPlaced = mainAudioPlaced + 1

        -- Native media are 29.97 fps in this edit. Advance the record position
        -- using the exact source-frame duration to avoid cumulative drift.
        recordFrame = recordFrame + duration
    end

    -- Explicit V2 B-roll positions from resolve_assembly.json.
    for idx, b in ipairs(assembly.brollOverlays or {}) do
        local name = tostring(b.sourceFile)
        local mediaItem = byName[name]
        local sourceBase = getSourceStart(mediaItem)
        local inSec = parseSeconds(b.sourceStart)
        local outSec = parseSeconds(b.sourceEnd)
        local sourceIn = sourceBase + frameAtSeconds(inSec, CONFIG.fps)
        local sourceOut = sourceBase + frameAtSeconds(outSec, CONFIG.fps)
        local record = frameAtSeconds(parseSeconds(b.timelineStart), CONFIG.fps)
        appendClip(mediaPool, mediaItem, sourceIn, sourceOut, record, 2, 1, "V2 B-roll[" .. idx .. "]")
        brollPlaced = brollPlaced + 1
    end

    -- Music cues are placed on A2. The external MP3 has its own source-frame base.
    local musicItem = byName["Warriyo-Laura Brehm-Mortals.mp3"]
    if musicItem and type(assembly.musicCues) == "table" then
        local musicBase = getSourceStart(musicItem)
        local musicEnd = tonumber(getClipProperty(musicItem, "End", "0")) or 0
        for idx, cue in ipairs(assembly.musicCues) do
            local record = frameAtSeconds(parseSeconds(cue.timelineStart), CONFIG.fps)
            local duration = frameAtSeconds(parseSeconds(cue.duration), CONFIG.fps)
            local sourceIn = musicBase
            local sourceOut = sourceIn + duration
            if musicEnd > musicBase then
                sourceOut = math.min(sourceOut, musicEnd)
            end
            if sourceOut > sourceIn then
                appendClip(mediaPool, musicItem, sourceIn, sourceOut, record, 2, 2, "A2 Music[" .. idx .. "]")
                musicPlaced = musicPlaced + 1
            end
        end
    end

    local finalSeconds = recordFrame / CONFIG.fps
    local report = string.format(
        "SUCCESS\n\nTimeline: %s\nMain video clips: %d\nMain audio clips: %d\nB-roll clips: %d\nMusic cues: %d\nMain story duration: %.2f sec\n\nSource media were not modified.",
        timeline:GetName(), mainPlaced, mainAudioPlaced, brollPlaced, musicPlaced, finalSeconds
    )
    success(report)
end, debug.traceback)

if not ok then
    fail(err)
end
