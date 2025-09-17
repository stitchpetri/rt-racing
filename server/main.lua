
-- server/main.lua
-- Rift Trails Racing – server
-- Responsibilities:
--   • Authoritative identity (charIdentifier via VORP)
--   • Receive client finish times
--   • Debug command to verify character info

-- ============= Server Race State ============

local Race = { 
    active = false,
    host = nil,
    courseId = nil,
    participants = {},
    startAtMs = nil -- server GetGameTimer at Go

}


local function clearRace()
    Race.active = false
    Race.host = nil
    Race.courseId = nil
    Race.participants = {}
    Race.startAtMs = nil
end
--================ Helpers


local function sendCourse(pid, courseId)
    local c = Config.Courses and Config.Courses[courseId]
    if not c then return end

    TriggerClientEvent("rtr:setCourse", pid, {
        id = c.id,
        radius = c.radius,
        start = { x = c.start.x, y = c.start.y, z = c.start.z },
        finish= { x = c.finish.x,y = c.finish.y,z = c.finish.z },
  })
end


local function broadcastCourse(courseId)
  for pid,_ in pairs(Race.participants) do
    sendCourse(pid, courseId)
  end
end

local function inRace(src) return Race.participants[src] == true end

-- =====================   Debug: confirm char info works
RegisterCommand("rtr_char", function(source)
  if not RTR.Vorp.ready() then
    TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "❌ VORP not ready"} })
    return
  end

  local info = RTR.Vorp.getCharInfo(source)
  if not info then
    TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "❌ No character yet (not spawned?)"} })
    return
  end

  local msg = ("✅ CHARID=%s | %s %s")
      :format(tostring(info.charid), info.firstname or "?", info.lastname or "?")
  print("[RTR] " .. msg)
  TriggerClientEvent('chat:addMessage', source, { args = {"RTR", msg} })
end, false)


--=====================================================================

-- Receive a simple time-trial finish
RegisterNetEvent("rtr:submitTime", function(courseId, elapsedMs)
  local src = source

  -- junk collection
  if type(courseId) ~= "number" or type(elapsedMs) ~= "number" then return end
  if elapsedMs < 0 or elapsedMs > (60 * 60 * 1000) then return end -- >1h? discard

  local info = RTR.Vorp.getCharInfo(src)
  local charid = info and info.charid or nil
  local name   = info and ((info.firstname or "?") .. " " .. (info.lastname or "?")) or GetPlayerName(src)

  print(("[RTR] %s (CHARID=%s) finished course %d in %.3fs")
    :format(name, tostring(charid or "n/a"), courseId, elapsedMs / 1000.0))

  -- TODO: INSERT into DB 
  TriggerClientEvent('chat:addMessage', src, { args = { "RTR", "Server received your time." } })
end)




--=====================================================================
--=====================================================================



-- /race host <courseId>
RegisterCommand("race", function (source, args)
    local sub = (args[1] or ""):lower()

    -- host ----------------
    if sub == "host" then 
        local cid = tonumber(args[2] or "0")
        if not cid or cid <= 0 then
            TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "Usage: /race host <courseId>"} })
            return
        end
        clearRace()
        Race.active   = true
        Race.host     = source
        Race.courseId = cid
        Race.participants[source] = true
        sendCourse(source, cid) -- tells host client which course
        TriggerClientEvent('chat:addMessage', -1, { args = {"RTR", ("Race hosted by %s on course %d. /race join"):format(GetPlayerName(source), cid)} })
    return
    end


    -- join ----------------
    if sub == "join" then
        if not Race.active or not Race.host then
        TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "No pending race. Use /race host <courseId>"} })
        return
        end
        Race.participants[source] = true
        sendCourse(source, Race.courseId)
        TriggerClientEvent('chat:addMessage', -1, { args = {"RTR", ("%s joined the race!"):format(GetPlayerName(source))} })
        return
    end

    -- leave ----------------
    if sub == "leave" then
        if Race.participants[source] then
            Race.participants[source] = nil
            TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "You left the race."} })
        end
        return
    end


    -- start ----------------
    if sub == "start" then
        if source ~= Race.host then
             TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "Only the host can /race start."} })
            return
        end
        if not Race.active or not next(Race.participants) then
            TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "No participants to start."} })
        return
        end

        for i = 3,1,-1 do
            for pid,_ in pairs(Race.participants) do
                TriggerClientEvent("rtr:countdown", pid, i)
            end
            Wait(1000)
        end

        -- RACE LOOP 
        Race.startAtMs = GetGameTimer()
        broadcastCourse(Race.courseId)
        for pid,_ in pairs(Race.participants) do
            TriggerClientEvent("rtr:raceGo", pid, Race.courseId)
        end
        return
    end


    -- restart 

    if sub == "reset" then
        clearRace()
        TriggerClientEvent('chat:addMessage', -1, { args = {"RTR", "Race reset."} })
        return
    end


    -- help
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, { args = {"RTR", "Commands: /race host <id>, /race join, /race leave, /race start, /race reset"} })
    end


end, false)


RegisterNetEvent("rtr:finishedServerRace", function(courseId)
  local src = source
  if not Race.active or Race.courseId ~= courseId or not inRace(src) or not Race.startAtMs then return end
  local elapsed = GetGameTimer() - Race.startAtMs  -- server-authoritative timing
  local info = RTR.Vorp.getCharInfo(src)
  local name = info and ((info.firstname or "?") .. " " .. (info.lastname or "?")) or GetPlayerName(src)
  local charid = info and info.charid or "n/a"

  print(("[RTR] (ServerRace) %s (CHARID=%s) finished course %d in %.3fs")
    :format(name, tostring(charid), courseId, elapsed/1000.0))

  TriggerClientEvent('chat:addMessage', src, { args = { "RTR", ("You finished in %.3fs"):format(elapsed/1000.0) } })

  -- Race.participants[src] = nil
end)
