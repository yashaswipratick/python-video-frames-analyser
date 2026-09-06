-- Kaiwara / Kailasagiri Resolve-native Lua builder
-- Run from Workspace > Scripts > Utility.

local CONFIG = {
    assembly = "/Users/yashaswipratick/Library/Containers/com.blackmagic-design.DaVinciResolveLite/Data/Library/Application Support/Fusion/Scripts/Utility/resolve_assembly.json",
    mediaDir = "/Users/yashaswipratick/Documents/video-analyser/videos",
    musicFile = "/Users/yashaswipratick/Documents/video-analyser/videos/Warriyo-Laura Brehm-Mortals.mp3",
    timelineName = "Kaiwara_Kailasagiri_Final_Edit_Lua",
    fps = 30000 / 1001,
    width = 1920,
    height = 1080
}

local function fail(message)
    print("RESOLVE LUA BUILDER ERROR: " .. tostring(message))
end

local function success(message)
    print(message)
end

local JSON = {}
function JSON.decode(text)
    local pos = 1
    local len = #text
    local function skip()
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == " " or c == "\t" or c == "\r" or c == "\n" then pos = pos + 1 else break end
        end
    end
    local function parseString()
        assert(text:sub(pos, pos) == '"', "expected string")
        pos = pos + 1
        local out = {}
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == '"' then pos = pos + 1; return table.concat(out)
            elseif c == "\\" then
                pos = pos + 1
                local e = text:sub(pos, pos)
                local map = {['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if map[e] then out[#out+1] = map[e]; pos = pos + 1
                elseif e == "u" then
                    local hex = text:sub(pos + 1, pos + 4)
                    assert(#hex == 4 and hex:match("^%x%x%x%x$"), "invalid unicode escape")
                    local code = tonumber(hex, 16)
                    out[#out+1] = (code < 128) and string.char(code) or "?"
                    pos = pos + 5
                else error("invalid escape: \\" .. tostring(e)) end
            else out[#out+1] = c; pos = pos + 1 end
        end
        error("unterminated string")
    end
    local function parseValue()
        skip(); local c = text:sub(pos, pos)
        if c == '"' then return parseString()
        elseif c == "{" then
            pos = pos + 1; local obj = {}; skip()
            if text:sub(pos,pos) == "}" then pos = pos + 1; return obj end
            while true do
                skip(); local key = parseString(); skip(); assert(text:sub(pos,pos)==":","expected ':'"); pos=pos+1
                obj[key]=parseValue(); skip(); local sep=text:sub(pos,pos)
                if sep=="}" then pos=pos+1; return obj end
                assert(sep==",","expected ',' or '}'"); pos=pos+1
            end
        elseif c == "[" then
            pos = pos + 1; local arr = {}; skip()
            if text:sub(pos,pos) == "]" then pos=pos+1; return arr end
            while true do
                arr[#arr+1]=parseValue(); skip(); local sep=text:sub(pos,pos)
                if sep=="]" then pos=pos+1; return arr end
                assert(sep==",","expected ',' or ']'"); pos=pos+1
            end
        elseif text:sub(pos,pos+3)=="true" then pos=pos+4; return true
        elseif text:sub(pos,pos+4)=="false" then pos=pos+5; return false
        elseif text:sub(pos,pos+3)=="null" then pos=pos+4; return nil
        else
            local number=text:match("^-?%d+%.?%d*[eE]?[+-]?%d*",pos)
            assert(number and #number>0,"invalid JSON value near position "..tostring(pos)); pos=pos+#number; return tonumber(number)
        end
    end
    local value=parseValue(); skip(); assert(pos>len,"trailing data after JSON value"); return value
end

local function readFile(path)
    local f=io.open(path,"rb")
    if not f then error("Cannot read file: "..path) end
    local data=f:read("*all"); f:close(); return data
end

local function parseSeconds(value)
    if type(value)=="number" then return value end
    local s=tostring(value):gsub("^%s+",""):gsub("%s+$","")
    local parts={}; for p in s:gmatch("[^:]+") do parts[#parts+1]=p end
    if #parts==1 then return tonumber(parts[1])
    elseif #parts==2 then return tonumber(parts[1])*60+tonumber(parts[2])
    elseif #parts==3 then return tonumber(parts[1])*3600+tonumber(parts[2])*60+tonumber(parts[3]) end
    error("Invalid timestamp: "..s)
end

local function round(x) return math.floor(x+0.5) end
local function frameAtSeconds(seconds,fps) return round(seconds*fps) end

local function getResolve()
    local ok,result=pcall(function() if app and app.GetResolve then return app:GetResolve() end return nil end)
    if ok and result then return result end
    return nil
end

local function getClipProperty(item,key,fallback)
    local ok,value=pcall(function() return item:GetClipProperty(key) end)
    if not ok or value==nil then return fallback end
    if type(value)=="table" then value=value[key] end
    return value
end

local function getSourceStart(item)
    return tonumber(getClipProperty(item,"Start","0")) or 0
end

local function findRootItem(root,name)
    for _,item in ipairs(root:GetClipList() or {}) do if item:GetName()==name then return item end end
    return nil
end

local function pathFor(name) return CONFIG.mediaDir .. "/" .. name end

local function collectRequiredNames(assembly)
    local names={}; local seen={}
    local function add(name) if name and name~="" and not seen[name] then seen[name]=true; names[#names+1]=name end end
    for _,item in ipairs(assembly.mainTimeline or {}) do add(item.sourceFile) end
    for _,item in ipairs(assembly.brollOverlays or {}) do add(item.sourceFile) end
    add("Warriyo-Laura Brehm-Mortals.mp3")
    return names
end

local function importMissing(mediaPool,root,names)
    local missingPaths={}; local lookup={}
    for _,name in ipairs(names) do
        local item=findRootItem(root,name)
        if item then lookup[name]=item else missingPaths[#missingPaths+1]=pathFor(name) end
    end
    if #missingPaths>0 then
        local imported=mediaPool:ImportMedia(missingPaths)
        if not imported then error("Resolve imported no media. Check Media Storage permissions.") end
        for _,item in ipairs(imported) do lookup[item:GetName()]=item end
    end
    for _,name in ipairs(names) do if not lookup[name] then local item=findRootItem(root,name); if item then lookup[name]=item end end end
    for _,name in ipairs(names) do if not lookup[name] then error("Media Pool item not found: "..name) end end
    return lookup
end

local function appendClip(mediaPool,mediaItem,sourceStart,sourceEnd,recordFrame,trackIndex,mediaType,label)
    local clipInfo={mediaPoolItem=mediaItem,startFrame=sourceStart,endFrame=sourceEnd,recordFrame=recordFrame,trackIndex=trackIndex,mediaType=mediaType}
    local ok,result=pcall(function() return mediaPool:AppendToTimeline({clipInfo}) end)
    if not ok or not result or #result==0 then error("Failed to place "..label..": "..tostring(result)) end
    return result[1]
end

local function ensureTrack(timeline,trackType,desired)
    local count=tonumber(timeline:GetTrackCount(trackType)) or 0
    while count<desired do
        local ok=timeline:AddTrack(trackType)
        if not ok then error("Could not add "..trackType.." track") end
        count=count+1
    end
end

local function makeTimeline(mediaPool,baseName)
    local timeline=mediaPool:CreateEmptyTimeline(baseName)
    if timeline then return timeline,baseName end
    print("RESOLVE LUA BUILDER: canonical timeline name already exists; trying a run suffix")
    for i=2,99 do
        local candidate=baseName .. "_Run" .. tostring(i)
        timeline=mediaPool:CreateEmptyTimeline(candidate)
        if timeline then return timeline,candidate end
    end
    error("Could not create a timeline using "..baseName.." or _Run2.._Run99")
end

local ok,err=xpcall(function()
    local assembly=JSON.decode(readFile(CONFIG.assembly))
    assert(type(assembly)=="table" and type(assembly.mainTimeline)=="table" and #assembly.mainTimeline>0,"Invalid resolve_assembly.json")
    local resolve=getResolve(); assert(resolve,"Could not obtain Resolve API")
    local pm=resolve:GetProjectManager(); assert(pm,"Project Manager unavailable")
    local project=pm:GetCurrentProject(); assert(project,"Open a Resolve project first")
    pcall(function() project:SetSetting("timelineFrameRate","29.97") end)
    pcall(function() project:SetSetting("timelineResolutionWidth",tostring(CONFIG.width)) end)
    pcall(function() project:SetSetting("timelineResolutionHeight",tostring(CONFIG.height)) end)
    local mediaPool=project:GetMediaPool(); assert(mediaPool,"Media Pool unavailable")
    local root=mediaPool:GetRootFolder(); mediaPool:SetCurrentFolder(root)
    local byName=importMissing(mediaPool,root,collectRequiredNames(assembly))
    local timeline,timelineName=makeTimeline(mediaPool,CONFIG.timelineName)
    project:SetCurrentTimeline(timeline)
    ensureTrack(timeline,"video",2); ensureTrack(timeline,"audio",2)
    local recordFrame=0; local mainPlaced=0; local audioPlaced=0; local brollPlaced=0; local musicPlaced=0

    for idx,item in ipairs(assembly.mainTimeline) do
        local mediaItem=byName[tostring(item.sourceFile)]
        local sourceBase=getSourceStart(mediaItem)
        local sourceIn=sourceBase+frameAtSeconds(parseSeconds(item.sourceStart),CONFIG.fps)
        local sourceOut=sourceBase+frameAtSeconds(parseSeconds(item.sourceEnd),CONFIG.fps)
        local duration=sourceOut-sourceIn
        assert(duration>0,"Invalid mainTimeline["..idx.."] range")
        appendClip(mediaPool,mediaItem,sourceIn,sourceOut,recordFrame,1,1,"V1 mainTimeline["..idx.."]")
        mainPlaced=mainPlaced+1
        local audioOk,audioErr=pcall(function() appendClip(mediaPool,mediaItem,sourceIn,sourceOut,recordFrame,1,2,"A1 mainTimeline["..idx.."]") end)
        if audioOk then audioPlaced=audioPlaced+1 else print("RESOLVE LUA BUILDER WARNING: skipping A1 mainTimeline["..idx.."] for "..tostring(item.sourceFile)..": "..tostring(audioErr)) end
        recordFrame=recordFrame+duration
        print(string.format("RESOLVE LUA BUILDER: MAIN %02d/%02d %s",idx,#assembly.mainTimeline,tostring(item.section or "")))
    end

    for idx,b in ipairs(assembly.brollOverlays or {}) do
        local mediaItem=byName[tostring(b.sourceFile)]
        local sourceBase=getSourceStart(mediaItem)
        local sourceIn=sourceBase+frameAtSeconds(parseSeconds(b.sourceStart),CONFIG.fps)
        local sourceOut=sourceBase+frameAtSeconds(parseSeconds(b.sourceEnd),CONFIG.fps)
        local record=frameAtSeconds(parseSeconds(b.timelineStart),CONFIG.fps)
        appendClip(mediaPool,mediaItem,sourceIn,sourceOut,record,2,1,"V2 B-roll["..idx.."]")
        brollPlaced=brollPlaced+1
    end

    local musicItem=byName["Warriyo-Laura Brehm-Mortals.mp3"]
    if musicItem and type(assembly.musicCues)=="table" then
        local musicBase=getSourceStart(musicItem)
        local musicEnd=tonumber(getClipProperty(musicItem,"End","0")) or 0
        for idx,cue in ipairs(assembly.musicCues) do
            local record=frameAtSeconds(parseSeconds(cue.timelineStart),CONFIG.fps)
            local duration=frameAtSeconds(parseSeconds(cue.duration),CONFIG.fps)
            local sourceIn=musicBase; local sourceOut=sourceIn+duration
            if musicEnd>musicBase then sourceOut=math.min(sourceOut,musicEnd) end
            if sourceOut>sourceIn then appendClip(mediaPool,musicItem,sourceIn,sourceOut,record,2,2,"A2 Music["..idx.."]"); musicPlaced=musicPlaced+1 end
        end
    end

    success(string.format("RESOLVE LUA BUILDER COMPLETE\n\nTimeline: %s\nMain V1 clips: %d/%d\nMain A1 audio: %d/%d\nV2 B-roll: %d/%d\nA2 music: %d/%d\n29.97 fps\n1920x1080\nOriginal media modified: NO",timelineName,mainPlaced,#assembly.mainTimeline,audioPlaced,#assembly.mainTimeline,brollPlaced,#(assembly.brollOverlays or {}),musicPlaced,#(assembly.musicCues or {})))
end,function(e) return e end)

if not ok then fail(err) end
