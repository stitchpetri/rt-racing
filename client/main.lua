RTR = RTR or {}

-- ================= State =================
local currentCourse      = nil   -- { id, name, radius, start, finish, checkpoints = { vector3, ... } }
local setupActive        = false
local raceActive         = false
local joinedThisSetup    = false
local finishCooldown     = false
local checkpointCooldown = false
local nextCheckpoint     = nil

local clientStartAtMs = nil

-- tuning
local startRadius        = 10.0
local drawDist           = 250.0
local markerHeight       = 1.8
local checkpointColor    = { r=60,  g=120, b=220, a=110 }

-- visuals
local startColor   = { r=60,  g=200, b=60,  a=110 }
local finishColor  = { r=220, g=60,  b=60,  a=110 }

local INPUT_JOIN = 0x3B24C470      -- F key


-- =============== Utils ===============
local function v3(c) return vector3(c.x+0.0, c.y+0.0, c.z+0.0) end
local function dist(a, b) return #(a - b) end
local function radius() return (currentCourse and (currentCourse.radius or startRadius)) or startRadius end

local function drawCylinder(pos, r, col)
  local me = GetEntityCoords(PlayerPedId())
  if #(me - v3(pos)) > drawDist then return end
  Citizen.InvokeNative(
    0x2A32FAA57B937173, 0x50638AB9,
    pos.x, pos.y, pos.z,
    0.0,0.0,0.0, 0.0,0.0,0.0,
    r, r, markerHeight,
    col.r, col.g, col.b, col.a,
    false, true, 2, nil, nil, false
  )
end

local function PromptIsActive(p)
  local r = p and Citizen.InvokeNative(0x546E342E01DE71CF, p) or 0 -- _UI_PROMPT_IS_ACTIVE
  return r ~= 0
end


-- =============== uiprompt: group + prompt ===============
local joinPrompt = nil

local function createJoinPrompt(position, radius)
  local prompt = Citizen.InvokeNative(0x04F97DE45A519419)                           -- _UI_PROMPT_REGISTER_BEGIN
  Citizen.InvokeNative(0xAE84C5EE2C384FB3, prompt, position.x, position.y, position.z)
  Citizen.InvokeNative(0x0C718001B77CA468, prompt, radius)
  PromptSetControlAction(prompt, INPUT_JOIN)
  PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Join New Race"))


  PromptRegisterEnd(prompt)

  return prompt
end


-- =============== Events ===============
local function loadCourse(course)
  if not course then return end
  currentCourse = {
    id     = course.id,
    name   = course.name,
    radius = course.radius or startRadius,
    start  = v3(course.start),
    finish = v3(course.finish),
    checkpoints = {}
  }

  if course.checkpoints then
    for i, cp in ipairs(course.checkpoints) do
      currentCourse.checkpoints[i] = v3(cp)
    end
  end
end

local function ensureJoinPrompt()
  if currentCourse and not joinPrompt then
    joinPrompt = createJoinPrompt(currentCourse.start, radius())
  end
end

local function destroyJoinPrompt()
  if joinPrompt then
    Citizen.InvokeNative(0x00EDE88D4D13CF59, joinPrompt)  -- _UI_PROMPT_DELETE
    joinPrompt = nil
  end
end

RegisterNetEvent("rtr:race:setup", function(course)
  loadCourse(course)
  setupActive, raceActive = true, false
  joinedThisSetup, finishCooldown = false, false
  checkpointCooldown = false
  nextCheckpoint = nil
  ensureJoinPrompt()
end)

RegisterNetEvent("rtr:race:joined", function(course, roster)
  loadCourse(course or currentCourse)
  joinedThisSetup = true
  TriggerEvent("rtr:board:on")
  if roster then
    TriggerEvent("rtr:board:setRoster", roster)
  end
  destroyJoinPrompt()
end)

RegisterNetEvent("rtr:race:left", function(roster)
  joinedThisSetup = false
  TriggerEvent("rtr:board:off")
  checkpointCooldown = false
  if roster then
    TriggerEvent("rtr:board:setRoster", roster)
  end
end)

RegisterNetEvent("rtr:race:joinDenied", function(reason)
  joinedThisSetup = false
  ensureJoinPrompt()
  if reason and reason ~= "" then
    TriggerEvent('chat:addMessage', { args = {"RTR", tostring(reason)} })
  end
end)

RegisterNetEvent("rtr:race:setupEnded", function()
  setupActive = false
  destroyJoinPrompt()
end)

RegisterNetEvent("rtr:countdown", function(n)
  TriggerEvent('chat:addMessage', { args = {"RTR", ("Race starts in %d…"):format(tonumber(n) or 0)} })
end)

RegisterNetEvent("rtr:race:start", function(startAtMs, names)
  setupActive      = false
  raceActive       = true
  finishCooldown   = false
  checkpointCooldown = false
  nextCheckpoint   = 1
  clientStartAtMs  = GetGameTimer()
  destroyJoinPrompt()

  if names then
    TriggerEvent("rtr:board:setRoster", names)
  end
end)

RegisterNetEvent("rtr:race:stop", function()
  setupActive, raceActive = false, false
  finishCooldown = false
  checkpointCooldown = false
  nextCheckpoint = nil
  destroyJoinPrompt()
end)

RegisterNetEvent("rtr:raceReset", function()
  setupActive, raceActive = false, false
  joinedThisSetup, finishCooldown = false, false
  checkpointCooldown = false
  nextCheckpoint = nil
  TriggerEvent("rtr:board:off")
  currentCourse = nil
  destroyJoinPrompt()
end)

-- =============== Main Loop ===============
CreateThread(function()
  while true do
    local wait = 500

    if currentCourse then
      if setupActive then
        wait = 0
        -- Show START marker (match the prompt radius)
        drawCylinder(currentCourse.start, radius(), startColor)

        if joinedThisSetup then
          destroyJoinPrompt()
        else
          ensureJoinPrompt()
        end

        if joinPrompt and PromptIsActive(joinPrompt) and IsControlJustPressed(0, INPUT_JOIN) and not joinedThisSetup then
          TriggerServerEvent("rtr:race:join")
          joinedThisSetup = true
        end

      elseif raceActive then
        wait = 0

        local checkpoints = currentCourse.checkpoints or {}
        local target = currentCourse.finish
        local isFinish = true

        if nextCheckpoint and checkpoints[nextCheckpoint] then
          target = checkpoints[nextCheckpoint]
          isFinish = false
        end

        drawCylinder(target, radius(), isFinish and finishColor or checkpointColor)

        local me = GetEntityCoords(PlayerPedId())

        if not isFinish and not checkpointCooldown then
          if dist(me, v3(target)) <= radius() then
            checkpointCooldown = true
            nextCheckpoint = nextCheckpoint + 1
            TriggerEvent('chat:addMessage', { args = {"RTR", ("Checkpoint %d cleared"):format(nextCheckpoint - 1)} })
            SetTimeout(750, function() checkpointCooldown = false end)
          end
        elseif isFinish and not finishCooldown then
          if dist(me, v3(target)) <= radius() then
            finishCooldown = true
            local elapsed = 0
            if clientStartAtMs then
              elapsed = GetGameTimer() - clientStartAtMs
            end
            TriggerServerEvent("rtr:finishedServerRace", currentCourse.id, elapsed)
            SetTimeout(1500, function() finishCooldown = false end)
          end
        end
      end
    end

    Wait(wait)
  end
end)

-- =============== Cleanup ===============
AddEventHandler("onResourceStop", function(res)
  if res == GetCurrentResourceName() then
    destroyJoinPrompt()
  end
end)
