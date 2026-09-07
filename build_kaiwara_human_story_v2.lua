-- Kaiwara / Kailasagiri Hills STORY-FIRST Resolve timeline builder (v2)
--
-- Goal: create a near-finished human vlog edit, not a raw selects reel.
-- Story: Hook -> Welcome/Plan -> Breakfast -> Sugarcane -> Scenic Journey ->
-- Destination -> Cave/Temple -> Local Info -> First Offroad -> Mountain Payoff ->
-- Second Climb -> Return/Reflection -> Verdict/Outro.
--
-- Original source media is never modified.
-- Selected ranges are used where prior review established good material.
-- Newly required clips without reviewed timestamps are included as full source
-- with a marker so the scene cannot be silently lost.

local MEDIA_DIR = "/Users/yashaswipratick/Documents/video-analyser/videos"
local MUSIC_NAME = "Warriyo-Laura Brehm-Mortals.mp3"
local MUSIC_FILE = MEDIA_DIR .. "/" .. MUSIC_NAME
local TIMELINE_BASE = "Kaiwara_Human_Story_Edit_v2"
local FPS_NUM = 30000 / 1001
local FPS = "29.97"
local WIDTH = "1920"
local HEIGHT = "1080"

-- sourceStart/sourceEnd are seconds. nil = full source.
-- REQUIRED means the scene was explicitly requested to survive the edit.
local MAIN = {
    {"HOOK_OFFROAD_TEASE",       "DJI_20260830165745_0285_D.MP4", 3.860, 8.860, false, "Cold-open danger/terrain tease."},
    {"HOOK_MOUNTAIN_TEASE",      "DJI_20260830165231_0284-2_D.MOV", nil, nil, false, "Cold-open scenic payoff; trim to the strongest few seconds."},

    {"WELCOME",                  "DJI_20260830123104_0221_D.MP4", 4.560, 29.300, false, "User's natural welcome + destination promise."},
    {"JOURNEY_START",            "DJI_20260830124910_0224_D.MP4", 3.660, 16.820, false, "Trip begins; distance/traffic."},
    {"BREAKFAST_SEARCH",         "DJI_20260830124910_0224_D.MP4", 17.700, 38.400, false, "Small real problem: finding breakfast."},

    {"RESTAURANT_ARRIVAL_REQUIRED","DJI_20260830125616_0226_D.MP4", 6.000, 39.630, true, "Required restaurant arrival + breakfast interaction."},
    {"WHAT_WE_ATE_REQUIRED",     "DJI_20260830125616_0227_D.MOV", nil, nil, false, "Required: show what we ate; trim dead air manually."},

    {"ROAD_AFTER_FOOD",          "DJI_20260830141434_0233_D.MP4", 61.500, 81.500, false, "Short road bridge out of food stop."},
    {"SUGARCANE_PARK_REQUIRED",  "DJI_20260830143533_0239_D.MP4", nil, nil, false, "Required spontaneous sugarcane-stop setup."},
    {"SUGARCANE_PRICE_REQUIRED", "DJI_20260830125616_0239-1_D.MOV", nil, nil, false, "Required price/order interaction; full source because range was not reviewed."},
    {"SUGARCANE_FRIEND_REQUIRED","DJI_20260830125616_0239-2_D.MOV", nil, nil, false, "Required friend reaction; preserve the human/funny exchange."},

    {"SCENIC_JOURNEY",           "DJI_20260830141219_0232_D.MP4", 4.820, 30.820, true, "Scenic travel section; compress repetitive road footage."},
    {"HILL_APPROACH",             "DJI_20260830150748_0245-1_D.MP4", 0.620, 11.500, true, "First clear hill approach/reveal."},
    {"DESTINATION_REVEAL",        "DJI_20260830150748_0245_D.MP4", 0.000, 10.000, true, "Speechless mountain reveal; music carries this moment."},
    {"DESTINATION_REVEAL_2",      "DJI_20260830151054_0246_D.MP4", 0.000, 8.000, true, "Second establishing shot; use only if it adds a different visual."},

    {"REACH_TEMPLE_REQUIRED",     "DJI_20260830153327_0251_D.MP4", 6.360, 28.720, false, "Required reach-temple + explanation."},
    {"TREK_REACTION",             "DJI_20260830153327_0251_D.MP4", 29.960, 50.960, false, "Keep genuine walking/effort reaction, remove repetition."},
    {"SPYSS_LADY_REQUIRED",       "DJI_20260830154154_0255_D.MP4", 11.180, 17.680, false, "Required local conversation; listen-check before final export."},
    {"VISHNU_IDOL_REQUIRED",      "DJI_20260830154604_0256_D.MP4", nil, nil, false, "Required Vishnu idol shot; trim to reveal."},
    {"CAVE_REQUIRED",             "DJI_20260830154840_0263_D.MP4", 33.370, 75.370, false, "Required cave exploration; keep discoveries/reactions."},
    {"CAVE_SURROUNDINGS_REQUIRED","DJI_20260830160147_0267_D.MP4", 68.690, 71.810, true, "Required surroundings shot; very short scenic punctuation."},

    {"PRASAD_TIMINGS_REQUIRED",   "DJI_20260830162420_0278_D.MP4", 0.000, 10.800, false, "Required prasadam distribution/timings."},
    {"SPYSS_INFO_REQUIRED",       "DJI_20260830162845_0280_D.MP4", nil, nil, false, "Required local info; full source only because no reviewed range exists."},
    {"PARKING_OFFROAD_INFO",      "DJI_20260830163649_0281_D.MP4", 2.030, 22.110, false, "Parking/offroad setup."},

    {"OFFROAD_HANDOFF",           "DJI_20260830164511_0283_D.MP4", 100.860, 123.050, false, "Humorous handoff into adventure."},
    {"MANDATORY_OFFROAD",         "DJI_20260830165231_0284-1_D.MOV", nil, nil, false, "Required first-offroad footage; full source to protect the scene."},
    {"MOUNTAIN_VIEW_REQUIRED",    "DJI_20260830165231_0284-2_D.MOV", nil, nil, true, "Required mountain view; scenic payoff."},
    {"TIMELAPSE_REQUIRED",        "DJI_20260830171102_0288_D.MP4", 0.000, 10.043, true, "Required timelapse transition."},

    {"NEXT_HIGHER_DESTINATION",   "DJI_20260830173839_0290_D.MP4", 20.140, 83.570, false, "Story turn: we are going higher again."},
    {"SECOND_CLIMB",              "DJI_20260830173839_0290_D.MP4", 88.750, 123.750, false, "Second climbing/offroad escalation."},
    {"OFFROAD_SITUATION",         "DJI_20260830181824_0294_D.MP4", 18.580, 53.580, false, "Explain what the offroad is like."},
    {"OFFROAD_STEEPNESS_REQUIRED","DJI_20260830182058_0295_D.MP4", 0.620, 27.140, false, "Required steepness explanation/reaction."},

    {"RETURN",                    "DJI_20260830180912_0292_D.MP4", 0.000, 8.141, true, "Short visual reset on return."},
    {"RETURN_TALK",               "DJI_20260830182750_0293_D.MP4", 5.770, 21.970, false, "Natural wrap-up conversation."},
    {"SUNSET_REFLECTION",          "DJI_20260830182750_0300_D.MP4", 144.000, 202.660, true, "Late-day reflection/sunset; music-led close."},
    {"FINAL_VERDICT",             "DJI_20260830185028_0302_D.MP4", 7.150, 30.070, false, "Final assessment."},
    {"OUTRO",                     "DJI_20260830185028_0302_D.MP4", 30.070, 40.070, false, "Natural closing/CTA."}
}

-- Scenic V2 overlays that sit over speech-led sections.
local BROLL = {
    {"BROLL_SCENIC",       "DJI_20260830150748_0245_D.MP4", 0.000, 6.000, "SCENIC_JOURNEY", "Destination beauty over travel narration."},
    {"BROLL_HILL",         "DJI_20260830151054_0246_D.MP4", 0.000, 6.000, "HILL_APPROACH", "Wide establishing hill shot."},
    {"BROLL_CAVE",         "DJI_20260830160147_0267_D.MP4", 0.800, 3.000, "CAVE_REQUIRED", "Exterior cave-temple atmosphere."},
    {"BROLL_OFFROAD",      "DJI_20260830165745_0285_D.MP4", 3.860, 12.000, "MANDATORY_OFFROAD", "Alternate rocky-climb angle."},
    {"BROLL_SUNSET",       "DJI_20260830182750_0300_D.MP4", 144.000, 154.000, "SUNSET_REFLECTION", "Sunset visual cover."}
}

-- Music is anchored to story labels, not hard-coded timeline seconds.
-- gainDb is best-effort; if Resolve does not expose the clip property, the A2
-- clip still exists and is easy to adjust.
local MUSIC = {
    {"MUSIC_HOOK",         "HOOK_OFFROAD_TEASE",       0, 10,   0.0, 10.0,  -16.0},
    {"MUSIC_SCENIC",       "SCENIC_JOURNEY",            0, 24,  10.0, 34.0,  -20.0},
    {"MUSIC_REVEAL",       "DESTINATION_REVEAL",         0, 14,  34.0, 48.0,  -18.0},
    {"MUSIC_OFFROAD",     "MANDATORY_OFFROAD",          0, 20,  48.0, 68.0,  -17.0},
    {"MUSIC_MOUNTAIN",    "MOUNTAIN_VIEW_REQUIRED",     0, 16,  68.0, 84.0,  -19.0},
    {"MUSIC_TIME_LAPSE",  "TIMELAPSE_REQUIRED",          0, 10,  84.0, 94.0,  -16.0},
    {"MUSIC_RETURN",      "RETURN",                     0, 8,  110.0, 118.0, -20.0},
    {"MUSIC_SUNSET",      "SUNSET_REFLECTION",           0, 28,  120.0, 148.0, -21.0}
}

local function popup(title, text)
    print("KAIWARA STORY V2: " .. text)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function() comp:AskUser(title, {{"Message", "Text", Text = text}}) end)
    end
end

local function getResolve()
    local ok, result = pcall(function()
        if app and app.GetResolve then return app:GetResolve() end
        return nil
    end)
    if ok and result then return result end
    return nil
end

local function findRootClip(root, name)
    for _, item in ipairs(root:GetClipList() or {}) do
        if item:GetName() == name then return item end
    end
    return nil
end

local function getProp(item, key)
    local ok, value = pcall(function() return item:GetClipProperty(key) end)
    if ok then return value end
    return nil
end

local function framesFor(item)
    local n = tonumber(getProp(item, "Frames"))
    if n and n > 0 then return math.floor(n) end
    local d = tostring(getProp(item, "Duration") or "")
    local h,m,s,f = d:match("^(%d+):(%d+):(%d+):(%d+)$")
    if h then return math.floor(((tonumber(h)*3600)+(tonumber(m)*60)+tonumber(s))*FPS_NUM + tonumber(f) + 0.5) end
    return nil
end

local function secToFrame(sec) return math.floor(sec * FPS_NUM + 0.5) end

local function ensureMedia(root, mediaPool, name)
    local item = findRootClip(root, name)
    if item then return item end
    local imported = mediaPool:ImportMedia({MEDIA_DIR .. "/" .. name})
    if imported then
        for _, candidate in ipairs(imported) do
            if candidate:GetName() == name then return candidate end
        end
    end
    return nil
end

local function createTimeline(mediaPool, base)
    local t = mediaPool:CreateEmptyTimeline(base)
    if t then return t, base end
    for i=2,99 do
        local name = base .. "_Run" .. tostring(i)
        t = mediaPool:CreateEmptyTimeline(name)
        if t then return t, name end
    end
    error("Could not create timeline: " .. base)
end

local function rangeFor(item, startSec, endSec)
    local total = assert(framesFor(item), "Unable to determine frames for " .. item:GetName())
    if startSec == nil or endSec == nil then return 0, total-1, total end
    local sf = math.max(0, secToFrame(startSec))
    local ef = math.min(total-1, math.max(sf, secToFrame(endSec)-1))
    return sf, ef, ef-sf+1
end

local function putMain(root, mediaPool, timeline, row, recordFrame, positions)
    local label,name,startSec,endSec,_,note = row[1],row[2],row[3],row[4],row[5],row[6]
    local item = assert(ensureMedia(root, mediaPool, name), "Missing source: " .. name)
    local sf,ef,frames = rangeFor(item,startSec,endSec)
    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem=item, startFrame=sf, endFrame=ef,
        recordFrame=recordFrame, trackIndex=1, mediaType=3
    }})
    if not result or #result==0 then error("Failed V1/A1: " .. name) end
    positions[label] = {startFrame=recordFrame, durationFrames=frames, endFrame=recordFrame+frames}
    local markerNote = note
    if startSec==nil or endSec==nil then markerNote = markerNote .. " | FULL SOURCE - TRIM MANUALLY" end
    pcall(function() timeline:AddMarker(recordFrame,"Blue",label,markerNote,math.max(1,frames),"STORY_BEAT") end)
    return recordFrame+frames
end

local function putMusic(mediaPool, timeline, musicItem, label, timelineStartFrame, durationFrames, srcStartSec, gainDb, cueName)
    local srcStart = secToFrame(srcStartSec)
    local srcEnd = srcStart + durationFrames - 1
    local result = mediaPool:AppendToTimeline({{
        mediaPoolItem=musicItem, startFrame=srcStart, endFrame=srcEnd,
        recordFrame=timelineStartFrame, trackIndex=2, mediaType=2
    }})
    if not result or #result==0 then error("Failed A2 music: " .. cueName) end
    local ti=result[1]
    pcall(function() ti:SetProperty("Audio Gain",gainDb) end)
    pcall(function() ti:SetProperty("Volume",10^(gainDb/20)) end)
    pcall(function() timeline:AddMarker(timelineStartFrame,"Green",cueName,"Music bed, target gain "..tostring(gainDb).." dB",math.max(1,durationFrames),"MUSIC") end)
end

local function putBroll(root, mediaPool, timeline, row, positions)
    local label,name,srcStart,srcEnd,targetLabel,note=row[1],row[2],row[3],row[4],row[5],row[6]
    local target=positions[targetLabel]
    if not target then
        print("KAIWARA STORY V2: skipped B-roll "..label.." because target label not found")
        return
    end
    local item=assert(ensureMedia(root,mediaPool,name),"Missing B-roll source: "..name)
    local sf,ef,frames=rangeFor(item,srcStart,srcEnd)
    local duration=math.min(frames,target.durationFrames)
    local result=mediaPool:AppendToTimeline({{
        mediaPoolItem=item, startFrame=sf, endFrame=sf+duration-1,
        recordFrame=target.startFrame, trackIndex=2, mediaType=1
    }})
    if not result or #result==0 then error("Failed V2 B-roll: "..name) end
    pcall(function() timeline:AddMarker(target.startFrame,"Yellow","BROLL_"..label,note,duration,"BROLL") end)
end

local function main()
    popup("Kaiwara Story V2", "STARTED\n\nThis build is story-first, with selected ranges, music beds and sparse B-roll overlays.")
    local resolve=assert(getResolve(),"Resolve API unavailable")
    local pm=assert(resolve:GetProjectManager(),"Project Manager unavailable")
    local project=assert(pm:GetCurrentProject(),"No current Resolve project")
    pcall(function() project:SetSetting("timelineFrameRate",FPS) end)
    pcall(function() project:SetSetting("timelineResolutionWidth",WIDTH) end)
    pcall(function() project:SetSetting("timelineResolutionHeight",HEIGHT) end)

    local mediaPool=assert(project:GetMediaPool(),"Media Pool unavailable")
    local root=assert(mediaPool:GetRootFolder(),"Media Pool root unavailable")
    mediaPool:SetCurrentFolder(root)
    local timeline,timelineName=createTimeline(mediaPool,TIMELINE_BASE)
    pcall(function() assert(timeline:SetStartTimecode("00:00:00:00")) end)
    project:SetCurrentTimeline(timeline)

    local vc=tonumber(timeline:GetTrackCount("video")) or 0
    while vc<2 do assert(timeline:AddTrack("video"),"Could not add video track"); vc=vc+1 end
    local ac=tonumber(timeline:GetTrackCount("audio")) or 0
    while ac<2 do assert(timeline:AddTrack("audio"),"Could not add audio track"); ac=ac+1 end
    popup("Kaiwara Story V2", "1/4 Timeline ready: "..timelineName)

    local needed={[MUSIC_NAME]=true}
    for _,r in ipairs(MAIN) do needed[r[2]]=true end
    for _,r in ipairs(BROLL) do needed[r[2]]=true end
    local available={}
    local missing={}
    for name,_ in pairs(needed) do
        local item=ensureMedia(root,mediaPool,name)
        if item then available[name]=item else missing[#missing+1]=name end
    end
    if #missing>0 then error("Missing media:\n"..table.concat(missing,"\n")) end
    popup("Kaiwara Story V2", "2/4 All required source media is available")

    local positions={}
    local recordFrame=0
    for i,row in ipairs(MAIN) do
        recordFrame=putMain(root,mediaPool,timeline,row,recordFrame,positions)
        print(string.format("KAIWARA STORY V2: %d/%d %s",i,#MAIN,row[1]))
    end

    -- Music cues are computed against actual section positions, not guessed total time.
    local sourceCursor=0
    for _,cue in ipairs(MUSIC) do
        local cueName,targetLabel,offsetSec,durationSec,_,_,gainDb=cue[1],cue[2],cue[3],cue[4],cue[5],cue[6],cue[7]
        local target=positions[targetLabel]
        if target then
            local startFrame=target.startFrame+secToFrame(offsetSec)
            local maxFrames=math.max(1,target.durationFrames-secToFrame(offsetSec))
            local frames=math.min(secToFrame(durationSec),maxFrames)
            putMusic(mediaPool,timeline,available[MUSIC_NAME],targetLabel,startFrame,frames,sourceCursor,gainDb,cueName)
            sourceCursor=sourceCursor+durationSec
            print("KAIWARA STORY V2: MUSIC "..cueName)
        end
    end

    for _,row in ipairs(BROLL) do putBroll(root,mediaPool,timeline,row,positions) end
    project:SetCurrentTimeline(timeline)

    local totalSec=recordFrame/FPS_NUM
    popup("Kaiwara Story V2", string.format([[3/4 STORY EDIT BUILT

Timeline: %s
Main story clips: %d
Approx. assembled duration: %.1f minutes
Tracks: V1+V2 and A1+A2
Music cues: %d
B-roll overlays: %d

Story progression:
Hook -> Welcome/Plan -> Breakfast -> Sugarcane -> Scenic Journey ->
Destination -> Cave/Temple -> Local Info -> First Offroad ->
Mountain Payoff -> Second Climb -> Return/Reflection -> Verdict/Outro

The full-source required clips are marked "FULL SOURCE - TRIM MANUALLY".
All reviewed clips use selected source ranges.
]],timelineName,#MAIN,totalSec/60,#MUSIC,#BROLL))

    popup("Kaiwara Story V2", [[4/4 READY

This is the story edit, not a raw selects reel.

Watch it once from start to finish before changing anything.
The intended manual pass is only:
- remove dead air from FULL SOURCE required clips;
- trim any repeated road/offroad shots;
- confirm local dialogue is clear;
- fine-tune music level around speech;
- then captions/color/export.

Original media was not modified.]] )
end

local ok,err=xpcall(main,debug.traceback)
if not ok then popup("Kaiwara Story V2 ERROR",tostring(err)) end
