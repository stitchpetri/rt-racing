-- server/main.lua
-- Rift Trails Racing – server controller


-- ====== Temporary course & spawned props tracking ======
local TempCourse = nil  -- { id, name, mode, radius, start, finish, checkpoints }
local SpawnedProps = {} -- { entityId=true, ... }

local function clearSpawnedProps()
  for ent, _ in pairs(SpawnedProps) do
    if DoesEntityExist(ent) then DeleteEntity(ent) end
  end
  SpawnedProps = {}
end

local function layoutToCourse(layoutId)
  local L = Config.Layouts and Config.Layouts[layoutId]
  if not L then return nil end
  -- Synthesize a new course id space (e.g. 10000+) to avoid clashing with static Config.Courses ids
  local cid = 10000 + math.random(1, 999)
  TempCourse = {
    id          = cid,
    name        = L.name or ("Layout "..layoutId),
    mode        = L.mode or "time_trial",
    radius      = L.radius or 5.0,
    start       = L.start,
    finish      = L.finish,
    checkpoints = L.checkpoints or {},
  }
  return TempCourse
end

local function spawnLayoutProps(layoutId)
  local L = Config.Layouts and Config.Layouts[layoutId]
  if not L or not L.props then return end
  for _, p in ipairs(L.props) do
    local model = p.model
    if type(model) == "string" then
      model = GetHashKey(model)
    end
    if not IsModelValid(model) then goto continue end
    RequestModel(model); while not HasModelLoaded(model) do Wait(0) end
    local ent = CreateObject(model, p.pos.x, p.pos.y, p.pos.z, true, true, false)
    if ent and ent ~= 0 then
      if p.h then SetEntityHeading(ent, p.h + 0.0) end
      FreezeEntityPosition(ent, true)
      SpawnedProps[ent] = true
    end
    ::continue::
  end
end


local Race = {
  active       = false,
  host         = nil,
  courseId     = nil,
  participants = {},   -- [pid] = true
  startAtMs    = nil,
  finished     = {},   -- [pid] = true once recorded
}

local function resetRaceState()
  Race.active       = false
  Race.host         = nil
  Race.courseId     = nil
  Race.participants = {}
  Race.startAtMs    = nil
  Race.finished     = {}
end

local function courseConfig(courseId)
  return Config.Courses and Config.Courses[courseId] or nil
end

local function copyVec3(v)
  if not v then return nil end
  return {
    x = tonumber(v.x) or 0.0,
    y = tonumber(v.y) or 0.0,
    z = tonumber(v.z) or 0.0,
  }
end

local function buildCoursePayload(cfg)
  if not cfg then return nil end
  if not (cfg.start and cfg.finish) then return nil end

  local payload = {
    id          = cfg.id,
    name        = cfg.name,
    mode        = cfg.mode,
    radius      = cfg.radius,
    start       = copyVec3(cfg.start),
    finish      = copyVec3(cfg.finish),
    checkpoints = {},
  }

  if cfg.checkpoints then
    for i, cp in ipairs(cfg.checkpoints) do
      payload.checkpoints[i] = copyVec3(cp)
    end
  end

  return payload
end

local function vorpInfo(src)
  if not RTR or not RTR.Vorp or not RTR.Vorp.ready() then return nil end
  return RTR.Vorp.getCharInfo(src)
end

local function playerDisplayName(src)
  local info = vorpInfo(src)
  if info then
    local first = info.firstname or "?"
    local last  = info.lastname or "?"
    return (first .. " " .. last):gsub("%s+", " "), info.charid
  end
  local fallback = GetPlayerName(src)
  if fallback and fallback ~= "" then
    return fallback, nil
  end
  return string.format("Rider %d", src), nil
end

local function chatMessage(target, msg)
  TriggerClientEvent('chat:addMessage', target, { args = { "RTR", msg } })
end

local function broadcastChat(msg)
  for pid, _ in pairs(Race.participants) do
    chatMessage(pid, msg)
  end
end

local function broadcastToParticipants(event, ...)
  for pid, _ in pairs(Race.participants) do
    TriggerClientEvent(event, pid, ...)
  end
end

local function participantNames()
  local names = {}
  for pid, _ in pairs(Race.participants) do
    local name = playerDisplayName(pid)
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function refreshRoster()
  local roster = participantNames()
  for pid, _ in pairs(Race.participants) do
    TriggerClientEvent("rtr:board:setRoster", pid, roster)
  end
  return roster
end

local function ensureCourseLoaded()
  local cfg = courseConfig(Race.courseId)
  return cfg, buildCoursePayload(cfg)
end

local function addParticipant(src, opts)
  opts = opts or {}
  if not Race.active or not Race.courseId then
    return false, "No active race. Host one with /race host <courseId>."
  end
  if Race.startAtMs then
    return false, "The race already started."
  end
  if Race.participants[src] then
    return false, "You are already part of this race."
  end

  local cfg, payload = ensureCourseLoaded()
  if not payload then
    return false, "Course data unavailable."
  end

  Race.participants[src] = true
  Race.finished[src] = nil

  local roster = refreshRoster()
  TriggerClientEvent("rtr:race:joined", src, payload, roster)
  if not opts.skipJoinMessage then
    chatMessage(src, string.format("Joined race %s.", cfg.name or ("#" .. tostring(cfg.id or "?"))))
  end

  if not opts.silent then
    local name = playerDisplayName(src)
    broadcastChat(string.format("%s joined the race.", name))
  end

  return true
end

local function removeParticipant(src, opts)
  opts = opts or {}
  if not Race.participants[src] then
    return false, "You are not part of this race."
  end

  Race.participants[src] = nil
  Race.finished[src] = nil

  local roster = refreshRoster()
  TriggerClientEvent("rtr:race:left", src, roster)
  if not opts.skipLeaveMessage then
    chatMessage(src, "You left the race.")
  end

  if not opts.silent then
    local name = playerDisplayName(src)
    broadcastChat(string.format("%s left the race.", name))
  end

  return true
end

local function endSetupPhase()
  TriggerClientEvent("rtr:race:setupEnded", -1)
end

-- =====================   Debug: confirm char info works
RegisterCommand("rtr_char", function(source)
  if not RTR or not RTR.Vorp or not RTR.Vorp.ready() then
    chatMessage(source, "❌ VORP not ready")
    return
  end

  local info = RTR.Vorp.getCharInfo(source)
  if not info then
    chatMessage(source, "❌ No character yet (not spawned?)")
    return
  end

  local msg = ("✅ CHARID=%s | %s %s")
      :format(tostring(info.charid), info.firstname or "?", info.lastname or "?")
  print("[RTR] " .. msg)
  chatMessage(source, msg)
end, false)

-- Receive a simple time-trial finish (legacy)
RegisterNetEvent("rtr:submitTime", function(courseId, elapsedMs)
  local src = source

  if type(courseId) ~= "number" or type(elapsedMs) ~= "number" then return end
  if elapsedMs < 0 or elapsedMs > (60 * 60 * 1000) then return end

  local name, charid = playerDisplayName(src)
  print(("[RTR] %s (CHARID=%s) finished course %d in %.3fs")
    :format(name, tostring(charid or "n/a"), courseId, elapsedMs / 1000.0))

  chatMessage(src, "Server received your time.")
end)

local function broadcastSetup(payload, cfg)
  TriggerClientEvent("rtr:raceReset", -1)
  TriggerClientEvent("rtr:race:setup", -1, payload)
  local label = cfg and (cfg.name or ("course " .. tostring(cfg.id or "?"))) or "course"
  TriggerClientEvent('chat:addMessage', -1, { args = {"RTR", ("Race hosted on %s. Ride to the marker to join."):format(label)} })
end

local function handleHostCommand(source, cid)
  local cfg = courseConfig(cid)
  local payload = buildCoursePayload(cfg)
  if not payload then
    chatMessage(source, "Invalid course id.")
    return
  end

  resetRaceState()
  Race.active   = true
  Race.host     = source
  Race.courseId = cid

  broadcastSetup(payload, cfg)
  local ok, err = addParticipant(source, { silent = true, skipJoinMessage = true })
  if ok then
    chatMessage(source, string.format("Hosting %s (course %d).", cfg.name or "race", cid))
    chatMessage(source, "Use /race start when everyone is ready. Use /race reset to cancel.")
  else
    chatMessage(source, err or "Failed to join hosted race.")
  end
end

local function handleJoinCommand(source)
  local ok, err = addParticipant(source)
  if not ok then
    TriggerClientEvent("rtr:race:joinDenied", source, err)
  end
end

local function handleLeaveCommand(source)
  local ok, err = removeParticipant(source)
  if not ok then
    chatMessage(source, err)
  end
end

local function allParticipantsFinished()
  for pid, _ in pairs(Race.participants) do
    if not Race.finished[pid] then
      return false
    end
  end
  return next(Race.participants) ~= nil
end

local function handleStartCommand(source)
  if source ~= Race.host then
    chatMessage(source, "Only the host can /race start.")
    return
  end
  if not Race.active or not next(Race.participants) then
    chatMessage(source, "No participants to start.")
    return
  end
  
  endSetupPhase()
  for i = 3, 1, -1 do
    broadcastToParticipants("rtr:countdown", i)
    Wait(1000)
  end
  
  Race.startAtMs = GetGameTimer()
  Race.finished = {}
  local roster = refreshRoster()
  broadcastToParticipants("rtr:race:start", Race.startAtMs, roster)
  broadcastChat("Race started – good luck!")
end

local function finishRace()
  broadcastToParticipants("rtr:race:stop")
  broadcastChat("Race finished!")
  Race.startAtMs = nil
  clearSpawnedProps()
  TempCourse = nil
end

local function handleResetCommand()
  TriggerClientEvent("rtr:raceReset", -1)
  broadcastChat("Race reset.")
  resetRaceState()
  clearSpawnedProps()
  TempCourse = nil
end

RegisterCommand("race", function(source, args)
  local sub = (args[1] or ""):lower()
  
  if sub == "host" then
    local cid = tonumber(args[2] or "0")
    if not cid or cid <= 0 then
      chatMessage(source, "Usage: /race host <courseId>")
      return
    end
    handleHostCommand(source, cid)
    return
  end
  
  if sub == "join" then
    handleJoinCommand(source)
    return
  end
  
  if sub == "leave" then
    handleLeaveCommand(source)
    return
  end
  
  if sub == "start" then
    handleStartCommand(source)
    return
  end
  
  if sub == "reset" then
    handleResetCommand()
    return
  end
  
  if source > 0 then
    chatMessage(source, "Commands: /race host <id>, /race join, /race leave, /race start, /race reset")
  end
end, false)

RegisterNetEvent("rtr:race:join", function()
  local src = source
  local ok, err = addParticipant(src)
  if not ok then
    TriggerClientEvent("rtr:race:joinDenied", src, err)
  end
end)



RegisterNetEvent("rtr:finishedServerRace", function(courseId)
  local src = source
  if not Race.active or Race.courseId ~= courseId or not Race.participants[src] or not Race.startAtMs then return end
  if Race.finished[src] then return end
  
  local elapsed = GetGameTimer() - Race.startAtMs
  Race.finished[src] = true
  
  local name, charid = playerDisplayName(src)
  print(("[RTR] (ServerRace) %s (CHARID=%s) finished course %d in %.3fs")
  :format(name, tostring(charid or "n/a"), courseId, elapsed/1000.0))
  
  broadcastToParticipants("rtr:race:participantFinished", name, elapsed)
  chatMessage(src, string.format("You finished in %.3fs", elapsed/1000.0))
  
  if allParticipantsFinished() then
    finishRace()
  end
end)


RegisterNetEvent("rtr:anchor:choose", function(anchorId, opt)
  local src = source
  if not opt or not opt.type then return end

  -- Reset any previous hosted state first
  TriggerClientEvent("rtr:raceReset", -1)
  resetRaceState()
  clearSpawnedProps()
  TempCourse = nil

  if opt.type == "course" then
    local cid = tonumber(opt.id or 0)
    if not cid or cid <= 0 then
      TriggerClientEvent('chat:addMessage', src, { args = {"RTR", "Invalid course."} })
      return
    end
    -- Reuse your existing host pipeline
    handleHostCommand(src, cid)
    return
  end

  if opt.type == "layout" then
    local course = layoutToCourse(opt.id)
    if not course then
      chatMessage(src, "Layout not found.")
      return
    end

    -- Spawn the props for this layout
    spawnLayoutProps(opt.id)

    -- Build a payload compatible with your current client loader
    local payload = {
      id = course.id, name = course.name, mode = course.mode,
      radius = course.radius,
      start = course.start, finish = course.finish,
      checkpoints = course.checkpoints
    }

    -- Flip Race.active and host like your handleHostCommand does
    Race.active   = true
    Race.host     = src
    Race.courseId = course.id

    -- Broadcast setup and auto-join the host (same as host command)
    TriggerClientEvent("rtr:raceReset", -1)
    TriggerClientEvent("rtr:race:setup", -1, payload)
    chatMessage(src, ("Hosted %s. Ride to the marker to join."):format(course.name))
    local ok = addParticipant(src, { silent = true, skipJoinMessage = true })
    if ok then
      chatMessage(src, "Use /race start when everyone is ready. Use /race reset to cancel.")
    end
    return
  end
end)


AddEventHandler("playerDropped", function()
  local src = source
  if Race.host == src then
    TriggerClientEvent("rtr:raceReset", -1)
    broadcastChat("Race host left. Race reset.")
    resetRaceState()
    return
  end

  if Race.participants[src] then
    Race.participants[src] = nil
    Race.finished[src] = nil
    refreshRoster()
    local name = playerDisplayName(src)
    broadcastChat(string.format("%s left the race.", name))
  end
end)

-- initialise clean state
resetRaceState()
