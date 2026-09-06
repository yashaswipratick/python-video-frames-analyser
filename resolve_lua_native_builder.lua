-- Kaiwara / Kailasagiri Resolve-native Lua builder
-- Run from: Workspace > Scripts > Utility > resolve_lua_native_builder
--
-- Uses the existing resolve_assembly.json as the editorial source of truth.
-- Main story clips are inserted as linked A/V (mediaType=3).
-- B-roll is V2 (mediaType=1). Music is A2 (mediaType=2).
-- Original source media and edit_timeline.json are never modified.

local CONFIG = {
    assembly = "/Users/yashaswipratick/Library/Containers/com.blackmagic-design.DaVinciResolveLite/Data/Library/Application Support/Fusion/Scripts/Utility/resolve_assembly.json",
    mediaDir = "/Users/yashaswipratick/Documents/video-analyser/videos",
    musicFile = "/Users/yashaswipratick/Documents/video-analyser/videos/Warriyo-Laura Brehm-Mortals.mp3",
    timelineName = "Kaiwara_Kailasagiri_Final_Edit_Lua",
    fps = 30000 / 1001,
    width = 1920,
    height = 1080
}

local function log(msg)
    print("RESOLVE LUA BUILDER: " .. tostring(msg))
end

local function fail(msg)
    print("RESOLVE LUA BUILDER ERROR: " .. tostring(msg))
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Lua Builder", {
                {"Message", "Text", Text = "ERROR\n\n" .. tostring(msg)}
            })
        end)
    end
end

local function succeed(msg)
    print(msg)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Lua Builder", {
                {"Message", "Text", Text = msg}
            })
        end)
    end
end

local function readFile(path)
    local f, err = io.open(path, "rb")
    if not f then
        error("Cannot read file: " .. path .. " (" .. tostring(err) .. ")")
    end
    local data = f:read("*all")
    f:close()
    return data
end

-- Small JSON decoder; sufficient for the assembly file used by this project.
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
                return
            end
        end
    end

    local function parseString()
        if text:sub(pos, pos) ~= '"' then
            error("expected JSON string")
        end
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
                if map[e] ~= nil then
                    out[#out + 1] = map[e]
                    pos = pos + 1
                elseif e == "u" then
                    local hex = text:sub(pos + 1, pos + 4)
                    if #hex ~= 4 or not hex:match("^%x%x%x%x$") then
                        error("invalid unicode escape")
                    end
                    local code = tonumber(hex, 16)
                    if code < 128 then
                        out[#out + 1] = string.char(code)
                    else
                        out[#out + 1] = "?"
                    end
                    pos = pos + 5
                else
                    error("invalid JSON escape: \\" .. tostring(e))
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        error("unterminated JSON string")
    end

    local function parseValue()
        skip()
        local c = text:sub(pos, pos)

        if c == '"' then
            return parseString()
        end

        if c == "{" then
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
                if text:sub(pos, pos) ~= ":" then
                    error("expected ':' after JSON object key")
                end
                pos = pos + 1
                obj[key] = parseValue()
                skip()
                local sep = text:sub(pos, pos)
                if sep == "}" then
                    pos = pos + 1
                    return obj
                end
                if sep ~= "," then
                    error("expected ',' or '}' in JSON object")
                end
                pos = pos + 1
            end
        end

        if c == "[" then
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
                if sep ~= "," then
                    error("expected ',' or ']' in JSON array")
                end
                pos = pos + 1
            end
        end

        if text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end

        local number = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        if not number or #number == 0 then
            error("invalid JSON value near position " .. tostring(pos))
        end
        pos = pos + #number
        return tonumber(number)
    end

    local value = parseValue()
    skip()
    if pos <= len then
        error("trailing JSON data near position " .. tostring(pos))
    end
    return value
end

local function parseSeconds(v)
    if type(v) == "number" then
        return v
    end
    local s = tostring(v)
    local h, m, sec = s:match("^(%d+):(%d+):(%d+%.?%d*)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
    end
    local mm, ss = s:match("^(%d+):(%d+%.?%d*)$")
    if mm then
        return tonumber(mm) * 60 + tonumber(ss)
    end
    return tonumber(s)
end

local function frameAt(seconds)
    return math.floor(seconds * CONFIG.fps + 0.5)
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

local function findRootItem(root, name)
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == name then
            return item
        end
    end
    return nil
end

local function collectNames(assembly)
    local names, seen = {}, {}
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
    local lookup = {}
    local paths = {}

    for _, name in ipairs(names) do
        local item = findRootItem(root, name)
        if item then
            lookup[name] = item
        else
            paths[#paths + 1] = CONFIG.mediaDir .. "/" .. name
        end
    end

    if #paths > 0 then
        local imported = mediaPool:ImportMedia(paths)
        if not imported then
            error("Resolve could not import required media.")
        end
        for _, item in ipairs(imported) do
            lookup[item:GetName()] = item
        end
    end

    for _, name in ipairs(names) do
        if not lookup[name] then
            local item = findRootItem(root, name)
            if item then
                lookup[name] = item
            end
        end
    end

    for _, name in ipairs(names) do
        if not lookup[name] then
            error("Media Pool item not found: " .. name)
        end
    end

    return lookup
end

local function ensureTracks(timeline)
    local videoCount = tonumber(timeline:GetTrackCount("video")) or 0
    while videoCount < 2 do
        if not timeline:AddTrack("video") then
            error("Could not add video track")
        end
        videoCount = videoCount + 1
    end

    local audioCount = tonumber(timeline:GetTrackCount("audio")) or 0
    while audioCount < 2 do
        if not timeline:AddTrack("audio") then
            error("Could not add audio track")
        end
        audioCount = audioCount + 1
    end
end

local function createTimeline(mediaPool, baseName)
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

    error("Could not create timeline with base name: " .. baseName)
end

local function append(mediaPool, mediaItem, inFrame, outFrame, recordFrame, trackIndex, mediaType, label)
    local clipInfo = {
        mediaPoolItem = mediaItem,
        startFrame = inFrame,
        endFrame = outFrame,
        recordFrame = recordFrame,
        trackIndex = trackIndex,
        mediaType = mediaType
    }

    local ok, result = pcall(function()
        return mediaPool:AppendToTimeline({clipInfo})
    end)

    if not ok then
        error(label .. " failed: " .. tostring(result))
    end

    if not result or #result == 0 then
        error(label .. " failed: Resolve returned no timeline item")
    end

    return result[1]
end

local function main()
    local assembly = JSON.decode(readFile(CONFIG.assembly))
    if type(assembly) ~= "table" then
        error("Invalid resolve_assembly.json")
    end

    local resolve = getResolve()
    if not resolve then
        error("Could not obtain Resolve API")
    end

    local projectManager = resolve:GetProjectManager()
    if not projectManager then
        error("Project Manager unavailable")
    end

    local project = projectManager:GetCurrentProject()
    if not project then
        error("Open a Resolve project first")
    end

    local mediaPool = project:GetMediaPool()
    if not mediaPool then
        error("Media Pool unavailable")
    end

    local root = mediaPool:GetRootFolder()
    mediaPool:SetCurrentFolder(root)

    pcall(function()
        project:SetSetting("timelineFrameRate", "29.97")
        project:SetSetting("timelineResolutionWidth", tostring(CONFIG.width))
        project:SetSetting("timelineResolutionHeight", tostring(CONFIG.height))
    end)

    local byName = importMissing(mediaPool, root, collectNames(assembly))
    local timeline, timelineName = createTimeline(mediaPool, CONFIG.timelineName)
    project:SetCurrentTimeline(timeline)
    ensureTracks(timeline)

    local recordFrame = 0
    local mainPlaced = 0
    local audioPlaced = 0
    local brollPlaced = 0
    local musicPlaced = 0

    -- Main story is inserted once as linked A/V so Resolve maintains native
    -- source-video/source-audio synchronization and playback characteristics.
    for idx, item in ipairs(assembly.mainTimeline or {}) do
        local name = tostring(item.sourceFile)
        local mediaItem = byName[name]
        local sourceIn = frameAt(parseSeconds(item.sourceStart))
        local sourceOut = frameAt(parseSeconds(item.sourceEnd)) - 1
        local duration = sourceOut - sourceIn + 1

        if duration <= 0 then
            error("Invalid source range in mainTimeline[" .. idx .. "]")
        end

        append(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 3,
            "linked A/V mainTimeline[" .. idx .. "]")

        mainPlaced = mainPlaced + 1
        audioPlaced = audioPlaced + 1
        recordFrame = recordFrame + duration

        log(string.format("MAIN %02d/%02d %s", idx, #assembly.mainTimeline, tostring(item.section or "")))
    end

    -- Explicit B-roll overlays. timelineStart is relative to the beginning of V1.
    for idx, item in ipairs(assembly.brollOverlays or {}) do
        local name = tostring(item.sourceFile)
        local mediaItem = byName[name]
        local sourceIn = frameAt(parseSeconds(item.sourceStart))
        local sourceOut = frameAt(parseSeconds(item.sourceEnd)) - 1
        local record = frameAt(parseSeconds(item.timelineStart))

        if sourceOut >= sourceIn then
            append(mediaPool, mediaItem, sourceIn, sourceOut, record, 2, 1,
                "V2 B-roll[" .. idx .. "]")
            brollPlaced = brollPlaced + 1
        end
    end

    -- External music cues on A2.
    local musicItem = byName["Warriyo-Laura Brehm-Mortals.mp3"]
    if musicItem then
        for idx, cue in ipairs(assembly.musicCues or {}) do
            local record = frameAt(parseSeconds(cue.timelineStart))
            local duration = frameAt(parseSeconds(cue.duration))
            if duration > 0 then
                local ok, result = pcall(function()
                    return append(mediaPool, musicItem, 0, duration - 1, record, 2, 2,
                        "A2 Music[" .. idx .. "]")
                end)
                if ok and result then
                    musicPlaced = musicPlaced + 1
                else
                    log("WARNING: skipping A2 Music[" .. idx .. "]: " .. tostring(result))
                end
            end
        end
    end

    local totalMain = #(assembly.mainTimeline or {})
    local totalBroll = #(assembly.brollOverlays or {})
    local totalMusic = #(assembly.musicCues or {})

    succeed(string.format(
        [[RESOLVE LUA BUILDER COMPLETE

Timeline: %s
Main linked A/V clips: %d/%d
Linked main audio clips: %d/%d
V2 B-roll clips: %d/%d
A2 music cues: %d/%d

Frame rate: 29.97
Resolution: %dx%d
Original media modified: NO]],
        timelineName,
        mainPlaced, totalMain,
        audioPlaced, totalMain,
        brollPlaced, totalBroll,
        musicPlaced, totalMusic,
        CONFIG.width, CONFIG.height
    ))
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    fail(err)
end
