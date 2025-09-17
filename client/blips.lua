Blips = Blips or {}
Blips = {}

-- local module = Import "blips" -- no symbols

-- local blips = Import("blips").blips-- every module has a table with the module name as the key for readability

-- local Lib = Import "blip"
-- local Blip = Lib.Blips -- [[@as BLIPS]] -- for intellisense




local activeBlips = {}
local checkpointBlipHash = -361388975
local blipHash = {
    start = 589239430,
    checkpoints = 1453767378,
    finish = -361388975
}

local function addBlipForCoords(blipname,bliphash,coords)
	local blip = Citizen.InvokeNative(0x554D9D53F696D002,1664425300, coords[1], coords[2], coords[3])
    
	SetBlipSprite(blip,blipHash.start,true)
	SetBlipScale(blip,0.2)
	Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipname)
end


function addCheckpoint(coords)
    local blip_name = "blip_"
    local blip_coords = coords
    local blip_hash = blipHash.checkpoints
    local blip_modifier_hash = GetHashKey("BLIP_MODIFIER_MP_COLOR_2")
    local blip_id = Citizen.InvokeNative(0x554D9D53F696D002,1664425300, coords.x, coords.y, coords.z)

    -- BLIP_ADD_MODIFIER:
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip_id, blip_modifier_hash)
    SetBlipSprite(blip_id, blip_hash, 0)
    SetBlipScale(blip,0.2)
    -- _SET_BLIP_NAME_FROM_PLAYER_STRING:
    Citizen.InvokeNative(0x9CB1A1623062F402, blip_id, blip_name)
    print(blip_name)
    activeBlips[blip_id] = true   -- table for removing blips if needed
end

local function removeAllBlips()
    for i in activeBlips do
        RemoveBlip(activeBlips[i])
    end
end

-- function RTR.Blips.add(coords, name, sprite, color)
--     local blip = addBlipForCoords(name, blipHash, coords)
--     Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey("BLIP_MODIFIER_MP_COLOR_2"))

-- end

-- function RTR.Blips.clear()
--     for _, b in ipairs(activeBlips) do
--         if b and b.Remove then b:Remove() end
--     end
--     activeBlips = {}
-- end

RegisterNetEvent("rtr:showCheckpoints", function(checkpoints)
    RTR.Blips.clear()
    for i, cp in ipairs(checkpoints or {}) do
        RTR.Blips.add(vector3(cp.x, cp.y, cp.z), ("Checkpoint %d"):format(i), 2033377404, "yellow")
    end
end)

RegisterNetEvent("rtr:clearCheckpoints", function()
    RTR.Blips.clear()
end)