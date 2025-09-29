local Board = {
  enabled      = false,
  active       = false,
  startAtMs    = nil,         -- local ref time for in-progress display
  participants = {},          -- [name] = { name, finishMs=nil }
  showFinal    = true
}

-- ---------- time helpers ----------
local function nowMs() return GetGameTimer() end

local function fmtMs(ms)
  if not ms or ms < 0 then return "--:--.---" end
  local total = math.floor(ms)
  local m = math.floor(total / 60000)
  local s = math.floor((total % 60000) / 1000)
  local cs = total % 1000
  return string.format("%02d:%02d.%03d", m, s, cs)
end

local function ensureRow(name)
  if not Board.participants[name] then
    Board.participants[name] = { name = name, finishMs = nil }
  end
  return Board.participants[name]
end

-- For sorting/preview: if finished → use finishMs; if active → live elapsed; otherwise huge
local function displayTimeFor(p)
  if p.finishMs then return p.finishMs end
  if Board.active and Board.startAtMs then
    return nowMs() - Board.startAtMs
  end
  return math.huge
end

local function asArraySorted()
  local arr = {}
  for _, p in pairs(Board.participants) do arr[#arr+1] = p end
  table.sort(arr, function(a, b)
    local at, bt = displayTimeFor(a), displayTimeFor(b)
    if at ~= bt then return at < bt end
    return (a.name or "") < (b.name or "")
  end)
  return arr
end

-- ---------- draw helpers ----------
local function drawText(x, y, text, opts)
  opts = opts or {}
  local scale  = opts.scale or 0.35
  local font   = opts.font  or 0      -- try 0..7
  local r,g,b  = opts.r or 255, opts.g or 255, opts.b or 255
  local a      = opts.a or 255
  local center = opts.center or false

  local str = CreateVarString(10, "LITERAL_STRING", text)
  SetTextScale(scale, scale)                 -- 0x07C837F9A01C34C9
  SetTextFontForCurrentCommand(font)         -- 0x66E0276CC5F6B9DA
  SetTextColor(r, g, b, a)                   -- 0x50A41AD966910F03
  SetTextCentre(center)                      -- 0xC02F4DBFB51D988B
  DisplayText(str, x, y)                     -- 0xD79334A4BB99BAD1
end

local function drawRect(x, y, w, h, r,g,b,a)
  DrawRect(x, y, w, h, r or 0, g or 0, b or 0, a or 160)
end

-- ---------- render ----------
local function renderBoard()
  if not Board.enabled then return end

  local arr = asArraySorted()

  -- panel geometry
  local panelX, panelY = 0.85, 0.15    -- center of panel
  local panelW, panelH = 0.2, 0.46

  -- background
  drawRect(panelX, panelY + 0.5*panelH, panelW, panelH + 0.03, 0, 0, 0, 200)

  -- title
  local title = (Board.active and (Board.showFinal and "Race Results" or "Race Leaderboard"))
                or "Race Leaderboard"
  drawText(panelX, panelY - 0.012, title, { font=1, scale=0.48, center=true, r=184, g=12, b=4 })

  -- headers
  local leftX   = panelX - panelW*0.47
  local midX    = panelX - panelW*0.18
  local rightX  = panelX + panelW*0.30
  local y       = panelY + 0.018

  drawText(leftX,  y, "Pos",  { font=1, scale=0.36, r=200,g=200,b=200 })
  drawText(midX,   y, "Name", { font=1, scale=0.36, r=200,g=200,b=200 })
  drawText(rightX, y, Board.showFinal and "Final" or "Time", { font=1, scale=0.36, r=200,g=200,b=200, center=true })

  y = y + 0.028

  -- rows
  local maxRows = 14
  for i, p in ipairs(arr) do
    local finished = p.finishMs ~= nil
    local live = (not finished and Board.active and Board.startAtMs)
                and (nowMs() - Board.startAtMs)
                or nil
    local timeStr = fmtMs(finished and p.finishMs or live)

    local color = finished and {r=180,g=255,b=180,a=255} or {r=255,g=255,b=255,a=230}
    local posStr = string.format("%2d", i)

    drawText(leftX,  y, posStr,   { font=1, scale=0.36, r=color.r,g=color.g,b=color.b })
    drawText(midX,   y, p.name or "—", { font=1, scale=0.36, r=color.r,g=color.g,b=color.b })
    drawText(rightX, y, timeStr,  { font=0, scale=0.36, r=color.r,g=color.g,b=color.b, center=true })

    y = y + 0.024
    if i >= maxRows then break end
  end

  -- footer/status
  local status
  if Board.active then
    status = Board.showFinal and "finished" or "running"
  else
    status = "setup"
  end
  drawText(panelX, panelY + panelH - 0.02,
           string.format("status: %s  |  racers: %d", status, #arr),
           { font=0, scale=0.30, r=80,g=80,b=80, center=true })
end

-- ---------- events ----------
RegisterNetEvent("rtr:board:on", function()
  Board.enabled    = true
  Board.active     = false
  Board.showFinal  = false
  Board.participants = {}
end)

RegisterNetEvent("rtr:board:off", function() Board.enabled = false end)
RegisterNetEvent("rtr:board:toggle", function() Board.enabled = not Board.enabled end)

-- optional: roster during setup
RegisterNetEvent("rtr:board:setRoster", function(names)
  for _, n in ipairs(names or {}) do ensureRow(n) end
  Board.enabled = true
end)

-- race start (clients use local ref time for live display)
RegisterNetEvent("rtr:race:start", function(_serverStartAtMs, names)
  Board.participants = {}
  for _, n in ipairs(names or {}) do ensureRow(n) end
  Board.startAtMs = GetGameTimer()
  Board.active    = true
  Board.showFinal = false
  Board.enabled   = true
end)

RegisterNetEvent("rtr:race:participantFinished", function(name, elapsedMs)
  local row = ensureRow(name)
  row.finishMs = math.max(0, math.floor(tonumber(elapsedMs) or 0))  -- clean int
end)

-- race stop → freeze results
RegisterNetEvent("rtr:race:stop", function()
  Board.active   = false
  Board.showFinal = true
end)

-- ---------- draw loop ----------
CreateThread(function()
  while true do
    if Board.enabled then renderBoard() end
    Wait(0)
  end
end)