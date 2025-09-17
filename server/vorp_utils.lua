RTR = RTR or {}
RTR.Vorp = RTR.Vorp or {}

local VORP = nil
local Map = nil


local function acquireVorp()
    if VORP then return true end
    local ok, core = pcall(function()
        return exports['vorp_core']:GetCore()  
    end)
    if ok and core then
        VORP = core
        print("[RTR] VORP Core acquired")
        return true
    end
    return false
end


AddEventHandler('onResourceStart', function(res)
    if res == 'vorp_core' or res == GetCurrentResourceName() then
        CreateThread(function()
            while not acquireVorp() do Wait(200) end
            
        end)
    end
end)




-- Internal Functions ===========================================



local function _getCharacterFromUser(User)
    if not User then return nil end
    if type(User.getUsedCharacter) == "function" then
        local ok, C = pcall(User.getUsedCharacter, User)
        if ok and C then return C end
    end
    if type(User.getUsedCharacter) == "table" then
        return User.getUsedCharacter
    end
    if type(User.getCharacter) == "function" then
        local ok, C = pcall(User.getCharacter, User)
        if ok and C then return C end
    end
    if type(User.character) == "table" then
        return User.character
    end
    return nil
end


--====== Public Functions ===================================================

function RTR.Vorp.ready()
    return acquireVorp()
end


function RTR.Vorp.getUser(src)
    if not acquireVorp() then return nil end
    return VORP.getUser and VORP.getUser(src) or nil
end



-- get character table for a src
function RTR.Vorp.getCharacter(src)
    local User = RTR.Vorp.getUser(src)
    return _getCharacterFromUser(User)
end

-- get charIdentifier only
function RTR.Vorp.getCharId(src)
    local C = RTR.Vorp.getCharacter(src)
    return C and (C.charIdentifier or C.charid or C.identifier) or nil
end

-- charid, firstname, lastname
function RTR.Vorp.getCharInfo(src)
    local C = RTR.Vorp.getCharacter(src)
    if not C then return nil end
    return {
        charid    = C.charIdentifier or C.charid or C.identifier,
        firstname = C.firstname,
        lastname  = C.lastname
    }
end

