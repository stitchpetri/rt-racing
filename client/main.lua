RTR = RTR or {}

-- ================= State =================
local currentCourse      = nil   -- { id, start, finish, radius }
local setupActive        = false
local raceActive         = false
local joinedThisSetup    = false
local finishCooldown     = false

local clientStartAtMs = nil

-- tuning
local startRadius        = 10.0
local drawDist           = 250.0
local markerHeight       = 1.8

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

local racePrompt = nil

local function LStr(text)
  -- _CREATE_VAR_STRING(type=10, "LITERAL_STRING", text)
  return Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", text, 1)
end

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
RegisterNetEvent("rtr:race:setup", function(course)
  currentCourse = course
  setupActive, raceActive = true, false
  joinedThisSetup, finishCooldown = false, false
  racePrompt = createJoinPrompt(currentCourse.start, startRadius)
  TriggerEvent("rtr:board:on")                 
end)

RegisterNetEvent("rtr:countdown", function(n)
  TriggerEvent('chat:addMessage', { args = {"RTR", ("Race starts in %d…"):format(tonumber(n) or 0)} })
end)

RegisterNetEvent("rtr:race:start", function(startAtMs, names)
  setupActive  = false
  raceActive   = true
  finishCooldown = false
  clientStartAtMs = GetGameTimer()

end)

RegisterNetEvent("rtr:race:stop", function()
  setupActive, raceActive = false, false
  finishCooldown = false

end)

RegisterNetEvent("rtr:raceReset", function()
  setupActive, raceActive = false, false
  finishCooldown = false
  
end)

-- =============== Main Loop ===============
CreateThread(function()
  while true do
    local wait = 500

    if currentCourse then
      if setupActive then
        wait = 0
        -- Show START marker (match the prompt radius)
        drawCylinder(currentCourse.start, startRadius, startColor)

        local active = PromptIsActive(racePrompt)
        if active and IsControlJustPressed(0, INPUT_JOIN) and not joinedThisSetup then
          TriggerServerEvent("rtr:race:join")
          joinedThisSetup = true
          TriggerEvent('chat:addMessage', { args = {"RTR","You joined the race"} })
          Citizen.InvokeNative(0x00EDE88D4D13CF59, racePrompt)  -- _UI_PROMPT_DELETE
          racePrompt = nil
        end

      elseif raceActive then
        wait = 0
        -- Show FINISH marker
        drawCylinder(currentCourse.finish, radius(), finishColor)

        -- Finish detection
        if not finishCooldown then
          local me = GetEntityCoords(PlayerPedId())
          if dist(me, v3(currentCourse.finish)) <= radius() then
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
    Citizen.InvokeNative(0x00EDE88D4D13CF59, racePrompt)
    racePrompt = nil
  end
end)
