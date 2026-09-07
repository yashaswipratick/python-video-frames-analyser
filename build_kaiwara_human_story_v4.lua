-- Kaiwara / Kailasagiri Hills HUMAN STORY EDIT v4
--
-- Audience-facing timeline, not a selects reel.
-- FIRST story clip = user's actual intro 0221.
-- Known ranges are pre-trimmed. Unknown ranges are marked instead of guessed.
-- V2 contains exact reviewed B-roll overlays. A2 contains music beds.
-- Original media is never modified.

local MEDIA_DIR="/Users/yashaswipratick/Documents/video-analyser/videos"
local MUSIC="Warriyo-Laura Brehm-Mortals.mp3"
local BASE="Kaiwara_Human_Story_Edit_v4"
local FPSN,FPSD=30000,1001

-- label,file,start,end,role,music,note
local MAIN={
{"01_INTRO_WELCOME","DJI_20260830123104_0221_D.MP4",4.560,29.300,"INTRO",false,"Actual user intro; FIRST clip."},
{"02_ADVENTURE_TEASE","DJI_20260830165231_0284-1_D.MOV",nil,nil,"HOOK",true,"Later off-road tease; exact sub-range not reviewed."},
{"03_PLAN_DESTINATION","DJI_20260830124910_0224_D.MP4",3.660,16.820,"PLAN",false,"Trip plan and destination."},
{"04_BREAKFAST_SEARCH","DJI_20260830124910_0224_D.MP4",17.700,38.400,"FOOD_SEARCH",false,"Search for breakfast; retain the problem, remove dead air."},
{"05_RESTAURANT_ARRIVAL","DJI_20260830125616_0226_D.MP4",6,26,"FOOD_STOP",false,"Arrival and human interaction."},
{"06_WHAT_WE_ATE","DJI_20260830125616_0227_D.MOV",nil,nil,"FOOD_STOP",false,"Required food reveal; exact range not reviewed."},
{"07_LEAVE_FOOD","DJI_20260830141434_0233_D.MP4",1.500,20,"JOURNEY",false,"Quick road bridge."},
{"08_SUGARCANE_PARK","DJI_20260830143533_0239_D.MP4",nil,nil,"LOCAL_INTERACTION",false,"Required roadside stop; exact range not reviewed."},
{"09_SUGARCANE_PRICE","DJI_20260830125616_0239-1_D.MOV",nil,nil,"LOCAL_INTERACTION",false,"Ask price + watch it being made; exact range not reviewed."},
{"10_FRIEND_REACTION","DJI_20260830125616_0239-2_D.MOV",nil,nil,"LOCAL_INTERACTION",false,"Natural friend reaction; exact range not reviewed."},
{"11_SCENIC_JOURNEY","DJI_20260830141219_0232_D.MP4",4.820,24.820,"MUSIC_MONTAGE",true,"Short scenic progression."},
{"12_HILL_APPROACH","DJI_20260830150748_0245-1_D.MP4",0.620,11.500,"DESTINATION_APPROACH",true,"Hill approach."},
{"13_REVEAL_A","DJI_20260830150748_0245_D.MP4",0,6,"DESTINATION_REVEAL",true,"Strong reveal."},
{"14_REVEAL_B","DJI_20260830151054_0246_D.MP4",0,5,"DESTINATION_REVEAL",true,"Complementary establishing shot."},
{"15_DESTINATION_CONTEXT","DJI_20260830151143_0247_D.MP4",1.650,15.650,"DESTINATION_CONTEXT",false,"Keep only useful context."},
{"16_CROWD_OBSERVATION","DJI_20260830151748_0248_D.MP4",9.010,20,"OBSERVATION",false,"Human observation; concise."},
{"17_REACH_TEMPLE","DJI_20260830153327_0251_D.MP4",6.360,28.720,"DESTINATION_REVEAL",false,"Arrival/explanation."},
{"18_TREK_REACTION","DJI_20260830153327_0251_D.MP4",29.960,50.960,"EXPLORATION",false,"Genuine effort/reaction."},
{"19_SPYSS_LADY","DJI_20260830154154_0255_D.MP4",11.180,17.680,"LOCAL_INTERACTION",false,"Short local exchange."},
{"20_VISHNU_IDOL","DJI_20260830154604_0256_D.MP4",nil,nil,"EXPLORATION",false,"Required idol reveal; exact range not reviewed."},
{"21_CAVE","DJI_20260830154840_0263_D.MP4",33.370,63.370,"EXPLORATION",false,"Focused cave pass, not full 5-min source."},
{"22_CAVE_SURROUNDINGS","DJI_20260830160147_0267_D.MP4",68.690,71.810,"WOW_MOMENT",true,"Short scenic punctuation."},
{"23_PRASAD_TIMINGS","DJI_20260830162420_0278_D.MP4",0,10.800,"USEFUL_INFO",false,"Prasadam/timing information."},
{"24_SPYSS_INFO","DJI_20260830162845_0280_D.MP4",nil,nil,"USEFUL_INFO",false,"Required local info; exact range not reviewed."},
{"25_PARKING_OFFROAD_INFO","DJI_20260830163649_0281_D.MP4",2.030,22.110,"ADVENTURE_SETUP",false,"Parking/offroad setup."},
{"26_OFFROAD_HANDOFF","DJI_20260830164511_0283_D.MP4",100.860,123.050,"ADVENTURE_SETUP",false,"Humorous handoff."},
{"27_OFFROAD_REQUIRED","DJI_20260830165231_0284-1_D.MOV",nil,nil,"ADVENTURE",true,"Required off-road scene; exact range not reviewed."},
{"28_MOUNTAIN_VIEW","DJI_20260830165231_0284-2_D.MOV",nil,nil,"WOW_MOMENT",true,"Required mountain view; exact range not reviewed."},
{"29_TIMELAPSE","DJI_20260830171102_0288_D.MP4",0,10.043,"MUSIC_MONTAGE",true,"Short transition."},
{"30_GO_HIGHER","DJI_20260830173839_0290_D.MP4",20.140,83.570,"ADVENTURE_ESCALATION",false,"We decide to go higher."},
{"31_OFFROAD_ESCALATION","DJI_20260830173839_0290_D.MP4",88.750,150,"ADVENTURE",true,"Escalating terrain and reactions."},
{"32_OFFROAD_SITUATION","DJI_20260830181824_0294_D.MP4",18.580,53.580,"USEFUL_INFO",false,"What the route is actually like."},
{"33_OFFROAD_STEEPNESS","DJI_20260830182058_0295_D.MP4",0.620,27.140,"ADVENTURE",false,"Steepness and reaction."},
{"34_FINAL_PAYOFF","DJI_20260830173839_0290_D.MP4",150,189.990,"WOW_MOMENT",true,"Final stronger terrain/view; remove if repetitive."},
{"35_RETURN","DJI_20260830180912_0292_D.MP4",0,8.141,"RETURN",true,"Descent/reset."},
{"36_REFLECTION","DJI_20260830182750_0300_D.MP4",144,202.660,"REFLECTION",true,"Late-day reflection/sunset."},
{"37_VERDICT","DJI_20260830185028_0302_D.MP4",7.150,30.070,"VERDICT",false,"Final assessment."},
{"38_OUTRO","DJI_20260830185028_0302_D.MP4",30.070,40.070,"OUTRO",false,"Natural closing."}
}

-- Exact reviewed overlays. Unknown ranges are intentionally excluded from V2.
local BROLL={
{"B01","03_PLAN_DESTINATION","DJI_20260830150748_0245_D.MP4",0,6},
{"B02","15_DESTINATION_CONTEXT","DJI_20260830150748_0245_D.MP4",6,14},
{"B03","25_PARKING_OFFROAD_INFO","DJI_20260830163649_0281_D.MP4",22.110,30.110}
}

local function popup(t,x)
 print("KAIWARA HUMAN STORY v4: "..x)
 local c=fu and fu:GetCurrentComp() or nil
 if c then pcall(function() c:AskUser(t,{{"Message","Text",Text=x}}) end) end
end
local function R()
 local ok,r=pcall(function() if app and app.GetResolve then return app:GetResolve() end end); if ok then return r end
end
local function find(root,n)
 for _,i in ipairs(root:GetClipList() or {}) do if i:GetName()==n then return i end end
end
local function prop(i,k)
 local ok,v=pcall(function() return i:GetClipProperty(k) end); if ok then return v end
end
local function frames(i)
 local n=tonumber(prop(i,"Frames")); if n and n>0 then return math.floor(n) end
 local d=tostring(prop(i,"Duration") or ""); local h,m,s,f=d:match("^(%d+):(%d+):(%d+):(%d+)$")
 if h then return math.floor(((tonumber(h)*3600)+(tonumber(m)*60)+tonumber(s))*(FPSN/FPSD)+tonumber(f)+0.5) end
end
local function sf(x) return math.floor(x*(FPSN/FPSD)+0.5) end
local function ensure(root,pool,n)
 local i=find(root,n); if i then return i end
 local a=pool:ImportMedia({MEDIA_DIR.."/"..n})
 if a then for _,c in ipairs(a) do if c:GetName()==n then return c end end end
end
local function unique(pool,b)
 local t=pool:CreateEmptyTimeline(b); if t then return t,b end
 for k=2,99 do local n=b.."_Run"..k; t=pool:CreateEmptyTimeline(n); if t then return t,n end end
 error("Could not create timeline")
end
local function rng(i,s,e)
 local total=assert(frames(i),"No frame count: "..i:GetName())
 if s==nil or e==nil then return 0,total-1,total,true end
 local a=math.max(0,sf(s)); local b=math.min(total-1,math.max(a,sf(e)-1)); return a,b,b-a+1,false
end
local function mainClip(pool,t,root,row,rec)
 local label,n,s,e,role=row[1],row[2],row[3],row[4],row[5]
 local i=assert(ensure(root,pool,n),"Missing source: "..n); local a,b,cnt,full=rng(i,s,e)
 local r=pool:AppendToTimeline({{mediaPoolItem=i,startFrame=a,endFrame=b,recordFrame=rec,trackIndex=1,mediaType=3}})
 if not r or #r==0 then error("Append failed: "..n) end
 local note=row[7] or ""; if full then note=note.." | FULL SOURCE - exact reviewed range unavailable" end
 pcall(function() t:AddMarker(rec,"Blue",label,note,math.max(1,cnt),role) end)
 return rec+cnt,{label=label,start=rec,finish=rec+cnt,full=full}
end
local function sec(S,n) for _,s in ipairs(S) do if s.label==n then return s end end end
local function addB(pool,t,root,S,row,id)
 local _,section,file,s,e=row[1],row[2],row[3],row[4],row[5]; local q=sec(S,section); if not q then return end
 local i=ensure(root,pool,file); if not i then return end; local a,b,c,full=rng(i,s,e); if full then return end
 local at=q.start+sf(math.min(2,(q.finish-q.start)/4)); local r=pool:AppendToTimeline({{mediaPoolItem=i,startFrame=a,endFrame=b,recordFrame=at,trackIndex=2,mediaType=1}})
 if r and #r>0 then pcall(function() t:AddMarker(at,"Yellow",row[1],"Exact V2 scenic/B-roll overlay",math.max(1,c),"BROLL") end) end
end
local function addMusic(pool,t,music,startF,durF,srcF,id)
 local total=assert(frames(music),"No music frame count"); local rem=durF; local rec=startF; local src=math.min(srcF,total-1); local guard=0
 while rem>0 and guard<50 do
  guard=guard+1; local take=math.min(rem,total-src); if take<=0 then src=0; take=math.min(rem,total) end
  local r=pool:AppendToTimeline({{mediaPoolItem=music,startFrame=src,endFrame=src+take-1,recordFrame=rec,trackIndex=2,mediaType=2}}); if not r or #r==0 then error("Music append failed") end
  rec=rec+take; rem=rem-take; src=src+take; if src>=total then src=0 end
 end
 pcall(function() t:AddMarker(startF,"Green","MUSIC_"..id,"Music bed; duck under dialogue as needed",math.max(1,durF),"MUSIC") end)
end
function main()
 popup("Kaiwara Human Story v4","STARTED\n\n0221 intro is FIRST. Building trimmed story + exact V2 B-roll + A2 music.")
 local r=assert(R(),"Resolve API unavailable"); local pm=assert(r:GetProjectManager(),"Project manager unavailable"); local p=assert(pm:GetCurrentProject(),"No active project")
 pcall(function() p:SetSetting("timelineFrameRate","29.97"); p:SetSetting("timelineResolutionWidth","1920"); p:SetSetting("timelineResolutionHeight","1080") end)
 local pool=assert(p:GetMediaPool(),"Media pool unavailable"); local root=assert(pool:GetRootFolder(),"Root unavailable"); pool:SetCurrentFolder(root)
 local t,name=unique(pool,BASE); assert(t:SetStartTimecode("00:00:00:00")); p:SetCurrentTimeline(t)
 while (tonumber(t:GetTrackCount("video")) or 0)<2 do assert(t:AddTrack("video")) end
 while (tonumber(t:GetTrackCount("audio")) or 0)<2 do assert(t:AddTrack("audio")) end
 local music=assert(ensure(root,pool,MUSIC),"Missing music: "..MUSIC)
 local rec=0; local S={}; local unknown={}
 for _,row in ipairs(MAIN) do local nr,s=mainClip(pool,t,root,row,rec); rec=nr; S[#S+1]=s; if s.full then unknown[#unknown+1]=row[1] end end
 -- Music attaches to story sections with visual breathing/payoff.
 local musicSections={"ADVENTURE_TEASE","SCENIC_JOURNEY","HILL_APPROACH","DESTINATION_REVEAL_A","DESTINATION_REVEAL_B","CAVE_SURROUNDINGS","MANDATORY_OFFROAD","MOUNTAIN_VIEW","TIMELAPSE","OFFROAD_ESCALATION","FINAL_OFFROAD_PAYOFF","RETURN","REFLECTION"}
 local cursor=0
 for id,label in ipairs(musicSections) do local q=sec(S,label); if q then local d=math.floor((q.finish-q.start)*0.72); if d>0 then addMusic(pool,t,music,q.start,d,cursor,id); cursor=cursor+d+sf(1) end end end
 for id,row in ipairs(BROLL) do addB(pool,t,root,S,row,id) end
 p:SetCurrentTimeline(t)
 popup("Kaiwara Human Story v4",string.format([[COMPLETE

Timeline: %s
Main story blocks: %d
V1+A1 linked source footage
V2 exact reviewed B-roll overlays
A2 music attached

FIRST CLIP: 01_INTRO_WELCOME / 0221

Story order:
INTRO -> ADVENTURE TEASE -> PLAN -> BREAKFAST -> FOOD -> SUGARCANE -> SCENIC -> DESTINATION -> CAVE/TEMPLE -> LOCAL INFO -> OFFROAD -> MOUNTAIN PAYOFF -> HIGHER CLIMB -> RETURN -> VERDICT -> OUTRO

Unknown exact-range blocks: %d
%s]],name,#MAIN,#unknown,table.concat(unknown,"\n")))
end
local ok,err=xpcall(main,debug.traceback); if not ok then popup("Kaiwara Human Story v4 ERROR",tostring(err)) end
