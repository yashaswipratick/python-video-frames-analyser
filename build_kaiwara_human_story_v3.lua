-- Kaiwara / Kailasagiri Hills HUMAN STORY EDIT v3
-- Audience-facing edit: intro first, then adventure tease, then story progression.
-- Uses reviewed source ranges wherever available; unknown ranges are visibly marked.
-- Music is placed on A2; V2 is reserved for scenic/B-roll overlays.
-- Original media is never modified.

local MEDIA_DIR = "/Users/yashaswipratick/Documents/video-analyser/videos"
local MUSIC_NAME = "Warriyo-Laura Brehm-Mortals.mp3"
local TIMELINE_BASE = "Kaiwara_Human_Story_Edit_v3"
local FPS = "29.97"
local WIDTH = "1920"
local HEIGHT = "1080"
local FPSN, FPSD = 30000, 1001

-- label, file, startSec, endSec, role, music, note
local MAIN = {
 {"01_INTRO_WELCOME","DJI_20260830123104_0221_D.MP4",4.560,29.300,"INTRO",false,"User's actual intro. MUST be first."},
 {"02_ADVENTURE_TEASE","DJI_20260830165231_0284-1_D.MOV",nil,nil,"HOOK",true,"Short later-adventure tease; exact sub-range not yet reviewed."},
 {"03_PLAN_DESTINATION","DJI_20260830124910_0224_D.MP4",3.660,16.820,"PLAN",false,"Plan/destination setup."},
 {"04_BREAKFAST_SEARCH","DJI_20260830124910_0224_D.MP4",17.700,38.400,"FOOD_SEARCH",false,"Search/problem; trim dead air."},
 {"05_RESTAURANT_ARRIVAL","DJI_20260830125616_0226_D.MP4",6.000,26.000,"FOOD_STOP",false,"Arrival and interaction."},
 {"06_WHAT_WE_ATE","DJI_20260830125616_0227_D.MOV",nil,nil,"FOOD_STOP",false,"Required food scene; exact range not reviewed."},
 {"07_LEAVE_FOOD_STOP","DJI_20260830141434_0233_D.MP4",1.500,20.000,"JOURNEY",false,"Quick return to road."},
 {"08_SUGARCANE_PARK","DJI_20260830143533_0239_D.MP4",nil,nil,"LOCAL_INTERACTION",false,"Required sugarcane stop; exact range not reviewed."},
 {"09_SUGARCANE_PRICE_MAKING","DJI_20260830125616_0239-1_D.MOV",nil,nil,"LOCAL_INTERACTION",false,"Price + making; exact range not reviewed."},
 {"10_FRIEND_SUGARCANE_REACTION","DJI_20260830125616_0239-2_D.MOV",nil,nil,"LOCAL_INTERACTION",false,"Friend reaction; exact range not reviewed."},
 {"11_SCENIC_JOURNEY","DJI_20260830141219_0232_D.MP4",4.820,24.820,"MUSIC_MONTAGE",true,"Compressed scenic movement; avoid road repetition."},
 {"12_HILL_APPROACH","DJI_20260830150748_0245-1_D.MP4",0.620,11.500,"DESTINATION_APPROACH",true,"First strong hill approach."},
 {"13_DESTINATION_REVEAL_A","DJI_20260830150748_0245_D.MP4",0,6,"DESTINATION_REVEAL",true,"Strong reveal fragment."},
 {"14_DESTINATION_REVEAL_B","DJI_20260830151054_0246_D.MP4",0,5,"DESTINATION_REVEAL",true,"Complementary establishing view."},
 {"15_DESTINATION_CONTEXT","DJI_20260830151143_0247_D.MP4",1.650,15.650,"DESTINATION_CONTEXT",false,"Keep only useful explanation."},
 {"16_CROWD_OBSERVATION","DJI_20260830151748_0248_D.MP4",9.010,20.000,"OBSERVATION",false,"Earlier/current crowd observation."},
 {"17_REACH_TEMPLE_EXPLAIN","DJI_20260830153327_0251_D.MP4",6.360,28.720,"DESTINATION_REVEAL",false,"Arrival + explanation."},
 {"18_TREK_REACTION","DJI_20260830153327_0251_D.MP4",29.960,50.960,"EXPLORATION",false,"Natural walking/trek reaction."},
 {"19_SPYSS_LADY","DJI_20260830154154_0255_D.MP4",11.180,17.680,"LOCAL_INTERACTION",false,"Short local exchange."},
 {"20_VISHNU_IDOL","DJI_20260830154604_0256_D.MP4",nil,nil,"EXPLORATION",false,"Required idol reveal; exact range not reviewed."},
 {"21_CAVE_INSIDE","DJI_20260830154840_0263_D.MP4",33.370,63.370,"EXPLORATION",false,"Cave discovery pass."},
 {"22_CAVE_SURROUNDINGS","DJI_20260830160147_0267_D.MP4",68.690,71.810,"WOW_MOMENT",true,"Exterior scenic punctuation."},
 {"23_PRASAD_TIMINGS","DJI_20260830162420_0278_D.MP4",0,10.800,"USEFUL_INFO",false,"Prasadam/timing info."},
 {"24_SPYSS_INFORMATION","DJI_20260830162845_0280_D.MP4",nil,nil,"USEFUL_INFO",false,"Required local information; exact range not reviewed."},
 {"25_PARKING_OFFROAD_INFO","DJI_20260830163649_0281_D.MP4",2.030,22.110,"ADVENTURE_SETUP",false,"Parking/offroad setup."},
 {"26_OFFROAD_HANDOFF","DJI_20260830164511_0283_D.MP4",100.860,123.050,"ADVENTURE_SETUP",false,"Humorous adventure handoff."},
 {"27_MANDATORY_OFFROAD","DJI_20260830165231_0284-1_D.MOV",nil,nil,"ADVENTURE",true,"Required scene; exact range not reviewed."},
 {"28_MOUNTAIN_VIEW","DJI_20260830165231_0284-2_D.MOV",nil,nil,"WOW_MOMENT",true,"Required scenic payoff; exact range not reviewed."},
 {"29_TIMELAPSE","DJI_20260830171102_0288_D.MP4",0,10.043,"MUSIC_MONTAGE",true,"Short transition."},
 {"30_NEXT_OFFROAD_DESTINATION","DJI_20260830173839_0290_D.MP4",20.140,83.570,"ADVENTURE_ESCALATION",false,"We are going higher."},
 {"31_OFFROAD_ESCALATION","DJI_20260830173839_0290_D.MP4",88.750,150.000,"ADVENTURE",true,"Escalating terrain/reactions."},
 {"32_OFFROAD_SITUATION","DJI_20260830181824_0294_D.MP4",18.580,53.580,"USEFUL_INFO",false,"What the offroad is actually like."},
 {"33_OFFROAD_STEEPNESS","DJI_20260830182058_0295_D.MP4",0.620,27.140,"ADVENTURE",false,"Steepness/reaction."},
 {"34_FINAL_OFFROAD_PAYOFF","DJI_20260830173839_0290_D.MP4",150.000,189.990,"WOW_MOMENT",true,"Later payoff only if visually distinct."},
 {"35_RETURN","DJI_20260830180912_0292_D.MP4",0,8.141,"RETURN",true,"Short descent."},
 {"36_REFLECTION","DJI_20260830182750_0300_D.MP4",144.000,202.660,"REFLECTION",true,"Late reflection/sunset; use strongest part."},
 {"37_FINAL_VERDICT","DJI_20260830185028_0302_D.MP4",7.150,30.070,"VERDICT",false,"Final assessment."},
 {"38_OUTRO","DJI_20260830185028_0302_D.MP4",30.070,40.070,"OUTRO",false,"Natural close/CTA."}
}

local function popup(title,text)
 print("KAIWARA HUMAN STORY v3: "..text)
 local comp=fu and fu:GetCurrentComp() or nil
 if comp then pcall(function() comp:AskUser(title,{{"Message","Text",Text=text}}) end) end
end
local function resolveObj()
 local ok,r=pcall(function() if app and app.GetResolve then return app:GetResolve() end end)
 if ok then return r end
end
local function rootClip(root,name)
 for _,i in ipairs(root:GetClipList() or {}) do if i:GetName()==name then return i end end
end
local function cp(i,k)
 local ok,v=pcall(function() return i:GetClipProperty(k) end); if ok then return v end
end
local function frameCount(i)
 local n=tonumber(cp(i,"Frames")); if n and n>0 then return math.floor(n) end
 local d=tostring(cp(i,"Duration") or "")
 local h,m,s,f=d:match("^(%d+):(%d+):(%d+):(%d+)$")
 if h then return math.floor(((tonumber(h)*3600)+(tonumber(m)*60)+tonumber(s))*(FPSN/FPSD)+tonumber(f)+0.5) end
end
local function sf(x) return math.floor(x*(FPSN/FPSD)+0.5) end
local function ensure(root,pool,name)
 local i=rootClip(root,name); if i then return i end
 local a=pool:ImportMedia({MEDIA_DIR.."/"..name})
 if a then for _,c in ipairs(a) do if c:GetName()==name then return c end end end
end
local function unique(pool,base)
 local t=pool:CreateEmptyTimeline(base); if t then return t,base end
 for n=2,99 do local name=base.."_Run"..n; t=pool:CreateEmptyTimeline(name); if t then return t,name end end
 error("Could not create timeline")
end
local function range(i,s,e)
 local total=assert(frameCount(i),"No frame count: "..i:GetName())
 if s==nil or e==nil then return 0,total-1,total,true end
 local a=math.max(0,sf(s)); local b=math.min(total-1,math.max(a,sf(e)-1))
 return a,b,b-a+1,false
end
local function addMain(pool,timeline,root,row,rec)
 local label,name,s,e,role=row[1],row[2],row[3],row[4],row[5]
 local i=assert(ensure(root,pool,name),"Missing source: "..name)
 local a,b,count,full=range(i,s,e)
 local r=pool:AppendToTimeline({{mediaPoolItem=i,startFrame=a,endFrame=b,recordFrame=rec,trackIndex=1,mediaType=3}})
 if not r or #r==0 then error("Failed append: "..name) end
 local note=row[7] or ""
 if full then note=note.." | FULL SOURCE - exact reviewed range unavailable" end
 pcall(function() timeline:AddMarker(rec,"Blue",label,note,math.max(1,count),role) end)
 return rec+count,{start=rec,finish=rec+count,label=label,role=role,full=full}
end
local function addMusic(pool,timeline,music,startF,durF,srcF,id)
 local total=assert(frameCount(music),"No music frame count")
 local rem=durF; local rec=startF; local src=math.min(srcF,total-1); local guard=0
 while rem>0 and guard<50 do
  guard=guard+1
  local take=math.min(rem,total-src)
  if take<=0 then src=0; take=math.min(rem,total) end
  local r=pool:AppendToTimeline({{mediaPoolItem=music,startFrame=src,endFrame=src+take-1,recordFrame=rec,trackIndex=2,mediaType=2}})
  if not r or #r==0 then error("Music append failed #"..id) end
  rec=rec+take; rem=rem-take; src=src+take; if src>=total then src=0 end
 end
 pcall(function() timeline:AddMarker(startF,"Green","MUSIC_"..id,"Music bed; lower under dialogue as needed",math.max(1,durF),"MUSIC") end)
end

local function main()
 popup("Kaiwara Human Story v3","STARTED\n\nIntro 0221 is now FIRST. Building trimmed story structure with attached music.")
 local R=assert(resolveObj(),"Resolve API unavailable")
 local PM=assert(R:GetProjectManager(),"Project Manager unavailable")
 local P=assert(PM:GetCurrentProject(),"No active Resolve project")
 pcall(function() P:SetSetting("timelineFrameRate",FPS); P:SetSetting("timelineResolutionWidth",WIDTH); P:SetSetting("timelineResolutionHeight",HEIGHT) end)
 local pool=assert(P:GetMediaPool(),"Media Pool unavailable"); local root=assert(pool:GetRootFolder(),"Media root unavailable"); pool:SetCurrentFolder(root)
 local t,name=unique(pool,TIMELINE_BASE); assert(t:SetStartTimecode("00:00:00:00")); P:SetCurrentTimeline(t)
 while (tonumber(t:GetTrackCount("video")) or 0)<2 do assert(t:AddTrack("video"),"Cannot add V2") end
 while (tonumber(t:GetTrackCount("audio")) or 0)<2 do assert(t:AddTrack("audio"),"Cannot add A2") end
 local music=assert(ensure(root,pool,MUSIC_NAME),"Missing music file: "..MUSIC_NAME)
 local rec=0; local S={}; local unknown={}
 for _,row in ipairs(MAIN) do rec,S[#S+1]=addMain(pool,t,root,row,rec); if S[#S].full then unknown[#unknown+1]=row[1] end end
 -- Add music only to visually driven sections, with coverage tied to their actual assembled positions.
 local order={"ADVENTURE_TEASE","SCENIC_JOURNEY","HILL_APPROACH","DESTINATION_REVEAL_A","DESTINATION_REVEAL_B","CAVE_SURROUNDINGS","MANDATORY_OFFROAD","MOUNTAIN_VIEW","TIMELAPSE","OFFROAD_ESCALATION","FINAL_OFFROAD_PAYOFF","RETURN","REFLECTION"}
 local cursor=0
 for n,label in ipairs(order) do
  for _,sec in ipairs(S) do
   if sec.label==label and sec.finish>sec.start then
    local desired=math.floor((sec.finish-sec.start)*0.72)
    addMusic(pool,t,music,sec.start,desired,cursor,n); cursor=cursor+desired+sf(1); break
   end
  end
 end
 P:SetCurrentTimeline(t)
 popup("Kaiwara Human Story v3",string.format([[COMPLETE

Timeline: %s
Main story blocks: %d
V1+A1 = linked story footage
V2 = available for scenic overlays
A2 = music attached

FIRST STORY CLIP: 01_INTRO_WELCOME / 0221

Story:
INTRO -> ADVENTURE TEASE -> PLAN -> BREAKFAST -> SUGARCANE -> SCENIC -> DESTINATION -> CAVE/TEMPLE -> LOCAL INFO -> OFFROAD -> MOUNTAIN PAYOFF -> HIGHER CLIMB -> RETURN -> VERDICT -> OUTRO

Unknown exact-range blocks (full source, marked for manual trim): %d
%s]],name,#MAIN,#unknown,table.concat(unknown,"\n")))
end
local ok,err=xpcall(main,debug.traceback)
if not ok then popup("Kaiwara Human Story v3 ERROR",tostring(err)) end
