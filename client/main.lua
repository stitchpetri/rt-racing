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


-- draw markers for start/finish and detect finish

CreateThread(function()
    while true do
        Wait(0)

        if testActive then
        -- start marker
        DrawMarker(1, cfg.start.x, cfg.start.y, cfg.start.z - 1.0,
            0.0,0.0,0.0, 0.0,0.0,0.0,
            cfg.radius*2.0, cfg.radius*2.0, 1.2,
            255,255,255, 120, false, true, 2, nil, nil, false)

        -- finish marker
        DrawMarker(1, cfg.finish.x, cfg.finish.y, cfg.finish.z - 1.0,
            0.0,0.0,0.0, 0.0,0.0,0.0,
            cfg.radius*2.0, cfg.radius*2.0, 1.2,
            255,255,255, 120, false, true, 2, nil, nil, false)
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