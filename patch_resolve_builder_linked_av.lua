-- Patches the installed Resolve Lua builder so main story media is inserted as
-- linked A/V (mediaType=3) instead of separate video/audio insertions.
-- Run once from Workspace > Scripts > Utility.

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

local oldBlock = [[        appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 1, "V1 mainTimeline[" .. idx .. "]")
        mainPlaced = mainPlaced + 1

        local audioOk, audioErr = pcall(function()
            appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 2, "A1 mainTimeline[" .. idx .. "]")
        end)

        if audioOk then
            mainAudioPlaced = mainAudioPlaced + 1
        else
            print("RESOLVE LUA BUILDER WARNING: skipping A1 mainTimeline[" .. idx .. "] for " .. name .. ": " .. tostring(audioErr))
        end
]]

local newBlock = [[        -- Insert the camera clip once as linked video + source audio.
        -- Resolve mediaType=3 keeps the native A/V relationship intact.
        local avOk, avResult = pcall(function()
            return appendClip(mediaPool, mediaItem, sourceIn, sourceOut, recordFrame, 1, 3, "V1+A1 mainTimeline[" .. idx .. "]")
        end)

        if avOk then
            mainPlaced = mainPlaced + 1
            mainAudioPlaced = mainAudioPlaced + 1
        else
            error("Failed to place linked A/V mainTimeline[" .. idx .. "] for " .. name .. ": " .. tostring(avResult))
        end
]]

if not text:find("local avOk, avResult", 1, true) then
    if not text:find(oldBlock, 1, true) then
        show("ERROR: Expected main V1/A1 block was not found. Builder was not changed.")
        return
    end
    text = text:gsub(oldBlock, newBlock, 1)
end

-- Update the report wording to make linked A/V explicit.
text = text:gsub("Main A1 audio: %d / %d", "Linked A/V main clips: %d / %d", 1)

local out = io.open(BUILDER, "wb")
if not out then
    show("ERROR: Cannot write builder:\n" .. BUILDER)
    return
end
out:write(text)
out:close()

show("PATCH SUCCESS\n\nMain story clips now use linked A/V insertion (mediaType=3).\n\nThe separate A1 insertion path has been removed.\n\nRe-run resolve_lua_native_builder after deleting/ignoring the previous generated timeline.")
