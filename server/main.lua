local VorpCore = exports.vorp_core:getCore()

local charIdentifier = character.charIdentifier


-- then on the server, when a player joins or submits race time:
RegisterNetEvent("rtr:submitTime", function(courseId, elapsedMs)
    local src = source
    local User = VorpCore.getUser(src)
    if not User then return end

    local Character = User.getUsedCharacter
        and User.getUsedCharacter()
        or nil

    if not Character then return end

    local charid = Character.charIdentifier -- this is the unique CHARID
    local firstname = Character.firstname
    local lastname = Character.lastname

    print(("[RTR] Player %s (CHARID=%s) finished course %d in %.3fs")
        :format(firstname .. " " .. lastname, charid, courseId, elapsedMs/1000.0))

    TriggerClientEvent('chat:addMessage', src, {args={"RTR", "Server received your time."}})
 
end)