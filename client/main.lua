-- client/main.lua
-- Rift Trails Racing – client
-- Responsibilities:
--   • Show markers/blips
--   • Let player arm a simple test run (/rtr_test, /rtr_go)
--   • Time locally, send result to server


local cfg = Config.TestCourse

local currentCourse = Config.TestCourse
local serverRaceActive = false
local serverCourseId   = nil

local testActive = false
local isRunning  = false
local startTime  = 0

-- ===== State =====

local testActive = false
local isRunning = false
local startTime = 0

-- ===== Helpers =====
local function drawMarkerAt(pos, radius)
  -- _DRAW_MARKER (RDR2)
  Citizen.InvokeNative(
    0x2A32FAA57B937173,            -- drawMarker native
    0x50638AB9,                    -- marker type hash (cylinder)
    pos.x, pos.y, pos.z,
    0.0,0.0,0.0, 0.0,0.0,0.0,
    radius*2.0, radius*2.0, 1.2,
    255,255,255, 120,
    false, true, 2, nil, nil, false
  )
end

local function refreshStartFinishBlips()
  RTR.Blips.clear()
  if testActive then
    RTR.Blips.add(currentCourse.start,  "Start",  2033377404, "green")
    RTR.Blips.add(currentCourse.finish, "Finish", 2033377404, "red")
  end
end


local function nearPoint(pos, target, radius)
  return #(pos - target) <= radius
end


local function tableToVec3(t) return vector3(t.x, t.y, t.z) end

local function setCourseFromServer(c)
  -- convert plain tables to vector3s
  currentCourse = {
    id     = c.id,
    radius = c.radius,
    start  = tableToVec3(c.start),
    finish = tableToVec3(c.finish),
  }
  -- optional: show Start/Finish blips automatically
  RTR.Blips.clear()
  RTR.Blips.add(currentCourse.start,  "Start",  2033377404, "green")
  RTR.Blips.add(currentCourse.finish, "Finish", 2033377404, "red")
end
--================ Events ===============================================

RegisterNetEvent("rtr:countdown", function(i)
  -- super simple UI via chat for now
  TriggerEvent('chat:addMessage', { args = { "RTR", ("Starting in %d..."):format(i) } })
end)

RegisterNetEvent("rtr:raceGo", function(courseId)
  serverRaceActive = true
  serverCourseId   = courseId
  isRunning = true
  startTime = GetGameTimer()
  TriggerEvent('chat:addMessage', { args = { "RTR", "GO!" } })
  -- lock early starts -> ignore /rtr_go during server races.

end)

RegisterNetEvent("rtr:setCourse", function(c)
  if c then setCourseFromServer(c) end
end)

RegisterNetEvent("rtr:raceReset", function()
  serverRaceActive = false
  serverCourseId   = nil
  isRunning        = false
  RTR.Blips.clear()
end)


-- ===== Commands =====

-- Debug command: /rtr_testblip
RegisterCommand("rtr_testblip", function()
    --RTR.Blips.clear()

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    --RTR.Blips.add(pos, "Test Blip", 2033377404, "green")
    Blips.addCheckpoint(pos)

    TriggerEvent("chat:addMessage", {
        args = { "RTR", "Test blip added at your location." }
    })
end, false)

-- /rtr_clearblip to remove all
RegisterCommand("rtr_clearblip", function()
    RTR.Blips.clear()
    TriggerEvent("chat:addMessage", {
        args = { "RTR", "All test blips cleared." }
    })
end, false)


-- Toggle showing the course
RegisterCommand('rtr_test', function()
testActive = not testActive
  if Config.Debug then
    print(testActive and "[RTR] Test course ON" or "[RTR] Test course OFF")
  end
  refreshStartFinishBlips()
end, false)

-- Start a local run when you’re in the start bubble
RegisterCommand('rtr_go', function()
if serverRaceActive then
    TriggerEvent('chat:addMessage', { args = { "RTR", "A server race is active — wait for GO!" } })
    return
  end

  if not testActive then
    TriggerEvent('chat:addMessage', { args = { "RTR", "Toggle test first: /rtr_test" } })
    return
  end

  local ped = PlayerPedId()
  local pos = GetEntityCoords(ped)

  if nearPoint(pos, currentCourse.start, currentCourse.radius) then
    isRunning = true
    startTime = GetGameTimer()
    TriggerEvent('chat:addMessage', {
      args = { "RTR", ("Run started on %s!"):format(currentCourse.name or ("Course " .. tostring(currentCourse.id))) }
    })
  else
    TriggerEvent('chat:addMessage', { args = { "RTR", "Get to the start bubble to /rtr_go" } })
  end
end, false)

-- ===== Main draw / finish detection loop =====
CreateThread(function()
  while true do
    Wait(0)

    if testActive then
      drawMarkerAt(vector3(currentCourse.start.x,  currentCourse.start.y,  currentCourse.start.z - 1.0),  currentCourse.radius)
      drawMarkerAt(vector3(currentCourse.finish.x, currentCourse.finish.y, currentCourse.finish.z - 1.0), currentCourse.radius)
    end

    if isRunning or serverRaceActive then
      local ped = PlayerPedId()
      local pos = GetEntityCoords(ped)

      if nearPoint(pos, currentCourse.finish, currentCourse.radius) then
        isRunning = false
        local elapsed = GetGameTimer() - startTime

        if serverRaceActive and serverCourseId == currentCourse.id then
          TriggerServerEvent('rtr:finishedServerRace', serverCourseId)
          serverRaceActive = false              
        else
          TriggerServerEvent('rtr:submitTime', currentCourse.id, elapsed)
        end

        TriggerEvent('chat:addMessage', { args = { "RTR", ("Finished: %.3f s"):format(elapsed / 1000.0) } })
      end
    end
  end
end)
