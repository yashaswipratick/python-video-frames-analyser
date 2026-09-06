-- Robustly patches the installed Resolve Lua builder so main story clips are inserted
-- as linked A/V (mediaType=3). It does not depend on the previous exact formatting.

local BUILDER = "/Users/yashaswipratick/Library/Containers/com.blackmagic-design.DaVinciResolveLite/Data/Library/Application Support/Fusion/Scripts/Utility/resolve_lua_native_builder.lua"

local function show(msg)
    print(msg)
    local comp = fu and fu:GetCurrentComp() or nil
    if comp then
        pcall(function()
            comp:AskUser("Resolve Builder Patch", {{"Message", "Text", Text = msg}})
        end)
    end
end

local f = io.open(BUILDER, "rb")
if not f then
    show("ERROR: Cannot read builder:\n" .. BUILDER)
    return
end
local text = f:read("*all")
f:close()

-- Find the first main-story V1 insertion and the record-frame advance that closes
-- that insertion block. Everything between them is replaced with linked A/V.
local v1Marker = 'appendClip(mediaPool,mediaItem,sourceIn,sourceOut,recordFrame,1,1,'
local v1Start = text:find(v1Marker, 1, true)

if not v1Start then
    -- Also accept the spaced variant used by older builder revisions.
    v1Marker = 'appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 1,'
    v1Start = text:find(v1Marker, 1, true)
end

if not v1Start then
    show("ERROR: Could not locate the main V1 insertion in the installed builder. No changes made.")
    return
end

local blockStart = v1Start
local recordMarker1 = 'recordFrame=recordFrame+duration'
local recordMarker2 = 'recordFrame = recordFrame + duration'
local recordEnd = text:find(recordMarker1, v1Start, true)
local recordMarkerUsed = recordMarker1
if not recordEnd then
    recordEnd = text:find(recordMarker2, v1Start, true)
    recordMarkerUsed = recordMarker2
end

if not recordEnd then
    show("ERROR: Could not locate the main record-frame advance. No changes made.")
    return
end

local replacement = [[        -- Insert the camera clip once as linked video + source audio.
        -- Resolve mediaType=3 preserves the native A/V relationship and timing.
        local avOk, avResult = pcall(function()
            return appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 3, "V1+A1 mainTimeline[" .. idx .. "]")
        end)

        if not avOk then
            error("Failed to place linked A/V mainTimeline[" .. idx .. "] for " .. name .. ": " .. tostring(avResult))
        end

        mainPlaced = mainPlaced + 1
        mainAudioPlaced = mainAudioPlaced + 1

]]

-- Preserve the existing record-frame line itself.
local recordLineEnd = recordEnd
while recordLineEnd <= #text do
    local c = text:sub(recordLineEnd, recordLineEnd)
    if c == "\n" then
        break
    end
    recordLineEnd = recordLineEnd + 1
end

text = text:sub(1, blockStart - 1) .. replacement .. text:sub(recordEnd, recordLineEnd)

-- Make the final report describe the actual linked A/V count.
text = text:gsub("Main A1 audio clips: %%d / %%d", "Linked A/V main clips: %%d / %%d")
text = text:gsub("Main A1 audio: %%d / %%d", "Linked A/V main clips: %%d / %%d")

local out = io.open(BUILDER, "wb")
if not out then
    show("ERROR: Cannot write builder:\n" .. BUILDER)
    return
end
out:write(text)
out:close()

show("PATCH SUCCESS\n\nMain story insertion is now linked A/V (mediaType=3).\n\nNo Resolve project or timeline was modified by this patch.")
