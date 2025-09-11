local cfg = Config.TestCourse


local testActive = false
local isRunning = false
local startTime = 0


-- toggle test markers

RegisterCommand('rtr_test', function()
    testActive = not testActive
    if Config.Debug then
        print(testActive and "[RTR] Test course ON" or "[RTR] Test course OFF")
    end
end, false)

-- start race

RegisterCommand('rtr_go', function()
if not testActive then
    print("[RTR] Toggle test first: /rtr_test")
    return
  end
  local ped = PlayerPedId()
  local pos = GetEntityCoords(ped)
  if #(pos - cfg.start) <= cfg.radius then
    isRunning = true
    startTime = GetGameTimer()
    TriggerEvent('chat:addMessage', {args = {"RTR", "Run started! Go!"}})
  else
    TriggerEvent('chat:addMessage', {args = {"RTR", "Get to the start to use /rtr_go"}})
  end
end, false)


local function DrawMarkerRDR(x, y, z)
  Citizen.InvokeNative(0x2A32FAA57B937173,0x50638AB9, x, y, z,
            0.0,0.0,0.0, 0.0,0.0,0.0,
            cfg.radius*2.0, cfg.radius*2.0, 1.2,
            255,255,255, 120, false, true, 2, nil, nil, false)
end

-- draw markers for start/finish and detect finish

CreateThread(function()
    while true do
        Wait(0)

        if testActive then
        -- start marker
        DrawMarkerRDR(cfg.start.x, cfg.start.y, cfg.start.z -1)

        -- finish marker
        DrawMarkerRDR(cfg.finish.x, cfg.finish.y, cfg.finish.z - 1.0)
        
        end

        if isRunning then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            if #(pos - cfg.finish) <= cfg.radius then
                isRunning = false
                local elapsed = GetGameTimer() - startTime
                -- Send time to server 
                TriggerServerEvent('rtr:submitTime', cfg.id, elapsed)
                TriggerEvent('chat:addMessage', {args = {"RTR", ("Finished: %.3f s"):format(elapsed/1000.0)}})
            end
        end
    end
end)