-- Window keeper (Windows only). Runs in its own thread, where LuaJIT's FFI can
-- reach user32. It only moves and raises this game's own windows:
--   * the main game window (this process), and
--   * the second-display windows the game opens ("gen1recomp Secondary Display").
-- It remembers their place and size, puts them back when they open, and brings
-- the others forward when one of them gains focus from another program.
local control, results, initial = ...
require("love.timer")
local ffi = require("ffi")
if ffi.os ~= "Windows" then return end

ffi.cdef [[
typedef void* PP_HWND;
typedef struct { long left; long top; long right; long bottom; } PP_RECT;
typedef struct { unsigned long lo; unsigned long hi; } PP_FILETIME;
PP_HWND GetTopWindow(PP_HWND parent);
PP_HWND GetWindow(PP_HWND hwnd, unsigned int cmd);
PP_HWND GetForegroundWindow(void);
unsigned long GetWindowThreadProcessId(PP_HWND hwnd, unsigned long *pid);
int GetWindowTextA(PP_HWND hwnd, char *text, int max);
long GetWindowLongA(PP_HWND hwnd, int index);
int IsWindowVisible(PP_HWND hwnd);
int IsIconic(PP_HWND hwnd);
int IsZoomed(PP_HWND hwnd);
int ShowWindow(PP_HWND hwnd, int cmd);
int GetWindowRect(PP_HWND hwnd, PP_RECT *rect);
int SetWindowPos(PP_HWND hwnd, PP_HWND after, int x, int y, int w, int h, unsigned int flags);
unsigned long GetCurrentProcessId(void);
void* OpenProcess(unsigned long access, int inherit, unsigned long pid);
int CloseHandle(void *handle);
int GetProcessTimes(void *process, PP_FILETIME *created, PP_FILETIME *exited, PP_FILETIME *kernel, PP_FILETIME *user);
typedef struct { unsigned long addr; unsigned long port; unsigned long pid; } PP_UDPROW;
unsigned long GetExtendedUdpTable(void *table, unsigned long *size, int order, unsigned long family, int class, unsigned long reserved);
]]
local C = ffi.C
local COMPANION = "gen1recomp Secondary Display"
local GW_HWNDNEXT, GW_OWNER, GWL_STYLE, WS_CAPTION = 2, 4, -16, 0x00C00000
local SWP_KEEP, SWP_PLACE = 0x0013, 0x0014   -- NOSIZE|NOMOVE|NOACTIVATE, NOZORDER|NOACTIVATE
local TOPMOST, NOTOPMOST = ffi.cast("PP_HWND", -1), ffi.cast("PP_HWND", -2)
local SETTLE = 4          -- seconds a window is held at its saved place once it is identified
local GRACE = 1.5         -- seconds a new window may take to turn out to be a panel
local okIp, iphlp = pcall(ffi.load, "iphlpapi")
local myPid = tonumber(C.GetCurrentProcessId())

local config = { raise = true, remember = true, main = true }
local layout = {}         -- key -> { x, y, w, h, max }
local panelPort = {}      -- UDP port -> panel name, as the mod reports its windows
for key, x, y, w, h, flag in tostring(initial or ""):gmatch("([%w_%.]+)=(-?%d+),(-?%d+),(%d+),(%d+),(%d)") do
  layout[key] = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), max = flag == "1" }
end

local function id(hwnd) return tonumber(ffi.cast("intptr_t", hwnd)) end
local textBuffer = ffi.new("char[160]")
local function title(hwnd)
  local n = C.GetWindowTextA(hwnd, textBuffer, 160)
  return n > 0 and ffi.string(textBuffer, n) or ""
end
local pidOut = ffi.new("unsigned long[1]")
local function pidOf(hwnd)
  C.GetWindowThreadProcessId(hwnd, pidOut)
  return tonumber(pidOut[0])
end
local created = {}
local function createdAt(pid)
  if created[pid] then return created[pid] end
  local value = math.huge
  local handle = C.OpenProcess(0x1000, 0, pid)
  if handle ~= nil then
    local a, b, c, d = ffi.new("PP_FILETIME"), ffi.new("PP_FILETIME"), ffi.new("PP_FILETIME"), ffi.new("PP_FILETIME")
    if C.GetProcessTimes(handle, a, b, c, d) ~= 0 then value = tonumber(a.hi) * 4294967296 + tonumber(a.lo) end
    C.CloseHandle(handle)
  end
  created[pid] = value
  return value
end
local rectOut = ffi.new("PP_RECT")
local function rectOf(hwnd)
  if C.GetWindowRect(hwnd, rectOut) == 0 then return nil end
  return { x = tonumber(rectOut.left), y = tonumber(rectOut.top),
    w = tonumber(rectOut.right - rectOut.left), h = tonumber(rectOut.bottom - rectOut.top) }
end

-- Which process owns each local UDP port. A panel window is the companion
-- process that talks to the mod from the port the mod reported for it.
local sizeOut = ffi.new("unsigned long[1]")
local function udpOwners()
  if not okIp then return nil end
  sizeOut[0] = 0
  iphlp.GetExtendedUdpTable(nil, sizeOut, 0, 2, 1, 0)
  local size = tonumber(sizeOut[0])
  if size < 4 or size > 4194304 then return nil end
  local buffer = ffi.new("uint8_t[?]", size + 1024)
  sizeOut[0] = size + 1024
  if iphlp.GetExtendedUdpTable(buffer, sizeOut, 0, 2, 1, 0) ~= 0 then return nil end
  local total = tonumber(ffi.cast("unsigned long*", buffer)[0])
  local rows = ffi.cast("PP_UDPROW*", buffer + 4)
  local owners = {}
  for index = 0, total - 1 do
    local raw = tonumber(rows[index].port)
    local port = bit.bor(bit.lshift(bit.band(raw, 0xFF), 8), bit.band(bit.rshift(raw, 8), 0xFF))
    owners[port] = tonumber(rows[index].pid)
  end
  return owners
end

local identity = {}       -- window id -> { first, key, since }
local lastLookup, owners = -math.huge, nil
-- Gives each companion window a lasting name: "panelN" for the mod's own
-- panels, "otherN" (oldest first) for any other second-display window.
local function identify(companions, clock)
  local pending = false
  for _, entry in ipairs(companions) do
    local known = identity[entry.id]
    if not known then
      known = { first = clock }
      identity[entry.id] = known
    end
    if not known.key then pending = true end
  end
  if pending and next(panelPort) and clock - lastLookup >= 0.3 then
    lastLookup = clock
    local ok, found = pcall(udpOwners)
    owners = ok and found or nil
  end
  local used = {}
  for _, entry in ipairs(companions) do
    local key = identity[entry.id].key
    if key then used[key] = true end
  end
  for _, entry in ipairs(companions) do
    local known = identity[entry.id]
    if not known.key then
      local pid = pidOf(entry.hwnd)
      for port, panel in pairs(panelPort) do
        if owners and owners[port] == pid and not used["panel" .. panel] then
          known.key = "panel" .. panel
          break
        end
      end
      if not known.key and clock - known.first >= GRACE then
        local index = 0
        while used["other" .. index] do index = index + 1 end
        known.key = "other" .. index
      end
      if known.key then known.since, used[known.key] = clock, true end
    end
    entry.key, entry.since = known.key, known.since
  end
end

-- This game's visible windows, front to back: the main window and companions.
local function scan()
  local main, companions, all = nil, {}, {}
  local hwnd, guard = C.GetTopWindow(nil), 0
  while hwnd ~= nil and guard < 4000 do
    guard = guard + 1
    if C.IsWindowVisible(hwnd) ~= 0 then
      local name = title(hwnd)
      if name == COMPANION then
        local entry = { hwnd = hwnd, id = id(hwnd), created = createdAt(pidOf(hwnd)) }
        companions[#companions + 1], all[#all + 1] = entry, entry
      elseif not main and name ~= "" and pidOf(hwnd) == myPid and C.GetWindow(hwnd, GW_OWNER) == nil then
        main = { hwnd = hwnd, id = id(hwnd), main = true }
        all[#all + 1] = main
      end
    end
    hwnd = C.GetWindow(hwnd, GW_HWNDNEXT)
  end
  table.sort(companions, function(a, b)
    if a.created ~= b.created then return a.created < b.created end
    return a.id < b.id
  end)
  if main then main.key = "main" end
  return main, companions, all
end

local function framed(hwnd)
  return bit.band(tonumber(C.GetWindowLongA(hwnd, GWL_STYLE)), WS_CAPTION) == WS_CAPTION
end

local function place(entry, slot)
  if slot.max and entry.main then
    if C.IsZoomed(entry.hwnd) == 0 then C.ShowWindow(entry.hwnd, 3) end
    return
  end
  if slot.w < 120 or slot.h < 100 then return end
  local now = rectOf(entry.hwnd)
  if now and (now.x ~= slot.x or now.y ~= slot.y or now.w ~= slot.w or now.h ~= slot.h) then
    C.SetWindowPos(entry.hwnd, nil, slot.x, slot.y, slot.w, slot.h, SWP_PLACE)
  end
end

local function serialize()
  local parts = {}
  for key, slot in pairs(layout) do
    parts[#parts + 1] = ("%s=%d,%d,%d,%d,%d"):format(key, slot.x, slot.y, slot.w, slot.h, slot.max and 1 or 0)
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

local mainSeen = {}       -- main window id -> time first seen
local resettle = -math.huge   -- when another save's places arrived: windows are put there once more
local wasInside, lastSave, lastSent = false, 0, serialize()
while true do
  -- a newer load of the mod has started its own keeper
  if __owner and __owner:peek() ~= __epoch then return end
  local message = control:pop()
  while message ~= nil do
    if message == false then return end
    if type(message) == "table" then
      for key in pairs(config) do if message[key] ~= nil then config[key] = message[key] == true end end
      if type(message.layout) == "string" then
        -- another save was opened: its own places for the windows
        layout = {}
        for key, x, y, w, h, flag in message.layout:gmatch("([%w_%.]+)=(-?%d+),(-?%d+),(%d+),(%d+),(%d)") do
          layout[key] = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), max = flag == "1" }
        end
        resettle, lastSent = love.timer.getTime(), serialize()
      end
      if type(message.ports) == "string" then
        panelPort = {}
        for panel, port in message.ports:gmatch("([%w_%.]+):(%d+)") do panelPort[tonumber(port)] = panel end
      end
    end
    message = control:pop()
  end
  local clock = love.timer.getTime()
  local ok, err = pcall(function()
    local main, companions, all = scan()
    identify(companions, clock)
    if main then
      if not mainSeen[main.id] then mainSeen[main.id] = clock end
      main.since = mainSeen[main.id]
    end
    -- put windows back where they were, and hold them there while they settle
    for _, entry in ipairs(all) do
      entry.settling = not entry.since or clock - entry.since < SETTLE or clock - resettle < SETTLE
      local slot = entry.key and layout[entry.key]
      if config.remember and slot and entry.settling and (not entry.main or config.main)
          and C.IsIconic(entry.hwnd) == 0 and framed(entry.hwnd) then
        place(entry, slot)
      end
    end
    -- focus came into the game from another program: bring the rest along
    local foreground = C.GetForegroundWindow()
    local inside = false
    for _, entry in ipairs(all) do if entry.hwnd == foreground then inside = true end end
    if config.raise and inside and not wasInside then
      for _, entry in ipairs(all) do
        if entry.hwnd ~= foreground then
          local minimized = C.IsIconic(entry.hwnd) ~= 0
          if not minimized or not entry.main then
            if minimized then C.ShowWindow(entry.hwnd, 4) end
            C.SetWindowPos(entry.hwnd, TOPMOST, 0, 0, 0, 0, SWP_KEEP)
            C.SetWindowPos(entry.hwnd, NOTOPMOST, 0, 0, 0, 0, SWP_KEEP)
          end
        end
      end
      C.SetWindowPos(foreground, nil, 0, 0, 0, 0, SWP_KEEP)
    end
    wasInside = inside
    -- remember where the player leaves them
    if config.remember and clock - lastSave >= 1.5 then
      lastSave = clock
      for _, entry in ipairs(all) do
        if entry.key and not entry.settling and (not entry.main or config.main)
            and C.IsIconic(entry.hwnd) == 0 and framed(entry.hwnd) then
          local zoomed = entry.main and C.IsZoomed(entry.hwnd) ~= 0
          local r = rectOf(entry.hwnd)
          if zoomed then
            local slot = layout[entry.key] or { x = 0, y = 0, w = 0, h = 0 }
            slot.max = true
            layout[entry.key] = slot
          elseif r and r.w >= 120 and r.h >= 100 and r.x > -30000 then
            r.max = false
            layout[entry.key] = r
          end
        end
      end
      local text = serialize()
      if text ~= lastSent then
        lastSent = text
        results:push(text)
      end
    end
  end)
  if not ok then results:push("!" .. tostring(err)) end
  love.timer.sleep(0.15)
end
