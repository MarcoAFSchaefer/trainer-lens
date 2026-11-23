local OUT = os.getenv("TEST_OUT") or "/tmp/kg_out"
local function reader(dir) return function(name) local f = io.open(dir .. "/" .. name, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end end
function love.errorhandler(msg) print("HARNESS ERROR", msg, debug.traceback()); return function() return 1 end end
local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end; print("ok  " .. msg) end
local HOST = ""
function love.load()
  os.execute("mkdir -p " .. OUT)
  local G = love.graphics
  local blob = G.newCanvas(64, 64); G.setCanvas(blob); G.clear(0, 0, 0, 0); G.setColor(.9, .5, .3); G.circle("fill", 32, 32, 26); G.setCanvas(); G.setColor(1, 1, 1)
  local icon = G.newCanvas(32, 64); G.setCanvas(icon); G.clear(0, 0, 0, 0); G.setColor(.4, .7, .9); G.circle("fill", 16, 16, 13); G.circle("fill", 16, 48, 13); G.setCanvas(); G.setColor(1, 1, 1)
  local names = { [4] = "CHARMANDER", [16] = "PIDGEY", [19] = "RATTATA", [58] = "GROWLITHE", [129] = "MAGIKARP", [72] = "TENTACOOL", [29] = "NIDORAN♀" }
  local battle = { active = false }
  local P = { speciesOf = function(m) return m.species end, isEgg = function(m) return m.isEgg == true end, name = function(s) return names[s] or error("no ROM species name") end,
    isShiny = function(m) return m.shiny == true end, types = function(s) return s == 58 and { 10, 10 } or s == 4 and { 10, 2 } or { 0, 2 } end,
    abilityId = function() return 22 end, abilityName = function(id) return "INTIMIDATE" end,
    monIcon = function() return { image = icon, w = 32, h = 32, quads = { [0] = G.newQuad(0, 0, 32, 32, 32, 64) } } end,
    icon = function() return { image = icon, w = 32, h = 32, quads = { [0] = G.newQuad(0, 0, 32, 32, 32, 64) } } end,
    monPicSpecies = function(m) return m.species end, frontPic = function() return { image = blob, w = 64, h = 64 } end }
  package.preload["src.core.game3.pokemon"] = function() return P end
  package.preload["src.core.game3.battle.moves"] = function() return { get = function(id) return { type = id == 52 and 10 or 17, pp = 25 } end, displayName = function(id) return id == 52 and "EMBER" or "BITE" end } end
  package.preload["src.core.game3.battle.types"] = function() return { ID = { NORMAL = 0, FLYING = 2, FIRE = 10, DARK = 17, MYSTERY = 9 } } end
do
  package.preload["src.import.CacheFs"] = function() return { readActive = function(path)
    if path ~= "trainer_card/badges.rgba" then return nil end
    local data = love.image.newImageData(128, 16)
    data:mapPixel(function(x, y) local i = math.floor(x / 16); local d = (x % 16 - 7.5) ^ 2 + (y - 7.5) ^ 2
      if d > 49 then return 0, 0, 0, 0 end return (i * 37 % 255) / 255, (i * 91 % 255) / 255, 1 - i / 8, 1 end)
    return data:getString() end } end
  package.preload["src.ui.game3.trainer_card"] = function() local C = {}; C.isBadgeUnlocked = function(i) return C._session ~= nil and i <= 3 end; return C end
  package.preload["src.core.game3.collision"] = function() return { isWater = function(x, y) return x > 15 and y > 7 end, isGrass = function(x, y) return x < 6 and y > 2 end,
    isWalkable = function(x, y) return y > 0 and not (x > 8 and x < 12 and y < 5) end, warpAt = function(x, y) if x == 6 and y == 0 then return {} end end } end
  package.preload["src.core.game3.map"] = function() return { current = "MAP_ROUTE22" } end
  package.preload["src.core.game3.objects"] = function() return { _order = { 1, 2 }, _byId = { { visible = true, cellX = 5, cellY = 4, def = { trainerType = 1 } }, { visible = true, cellX = 13, cellY = 6, def = {} } } } end
  package.preload["src.core.game3.connections"] = function() return { each = function(def) return def.connections or {} end, sizeOf = function(def) return def.w or 0, def.h or 0 end } end
  do
    local atlasData = love.image.newImageData(64, 16)
    atlasData:mapPixel(function(x, y) local i = math.floor(x / 16); local edge = (x % 16 == 0 or y == 0) and 0.8 or 1
      local c = ({ { .35, .6, .3 }, { .2, .45, .25 }, { .25, .5, .85 }, { .55, .5, .4 } })[i + 1]; return c[1] * edge, c[2] * edge, c[3] * edge, 1 end)
    local atlas = { image = love.graphics.newImage(atlasData), midToSlot = { [0] = 0, 1, 2, 3 }, quads = {} }
    package.preload["src.core.game3.tileset_native"] = function() return { get = function(pair) return pair == "T" and atlas or nil end,
      slotFor = function(a, mid) return a.midToSlot[mid] end,
      quad = function(a, slot) a.quads[slot] = a.quads[slot] or love.graphics.newQuad(slot * 16, 0, 16, 16, 64, 16); return a.quads[slot] end } end
    local town = love.image.newImageData(240, 160)
    town:mapPixel(function(x, y) if x < 24 or y < 16 or x >= 216 then return 1, 0, 1, 1 end return .3 + (x % 16) / 60, .55, .75 - (y % 16) / 60, 1 end)
    local townImage = love.graphics.newImage(town)
    package.preload["src.import.gba.region_map_extract"] = function() return { ensureGenerated = function() return true end, LAYOUTS = {}, GEOMETRY = {} } end
    package.preload["src.ui.game3.region_map_position"] = function() return { regionFor = function() return 0 end, playerCell = function() return 5, 9 end } end
    package.preload["src.ui.game3.region_map_gpu"] = function() return { image = function(name) assert(name == "kanto_map"); return townImage end } end
  end
  TOOL_USED = {}
  local used = TOOL_USED
  package.preload["src.world.game3.WorldAPI"] = function() return { new = function() return {
    availableFieldActions = function() return { { id = "bicycle" }, { id = "surf" } } end,
    useFieldAction = function(_, id) used[#used + 1] = id; return true end,
    canReorderParty = function() return true end, reorderParty = function(_, a, b) used[#used + 1] = "swap" .. a .. b; return true end } end } end
  package.preload["src.core.game3.field_moves"] = function() return { MOVES = { SURF = 57, CUT = 15 },
    partyMoveUser = function(p, move) if move == "SURF" or move == "CUT" then return p[1], 0 end end } end
  package.preload["src.core.game3.bag"] = function() return { get = function(bag, id) return bag[id] or 0 end,
      listPocket = function(bag, key) local rows = {}; if key == "ITEMS" then for id, n in pairs(bag) do rows[#rows + 1] = { id = id, qty = n, name = "ITEM " .. id, description = "Um item de teste com uma descrição comprida o bastante para quebrar em duas linhas no rodapé." } end; table.sort(rows, function(a, b) return a.id < b.id end) end; return rows end, has = function(bag, id) return (bag[id] or 0) > 0 end } end
  package.preload["src.core.game3.item_use"] = function() return { canFish = function() return true end,
    useField = function(_, bag, id) used[#used + 1] = "item" .. id; bag[id] = bag[id] - 1; return true, "x", "It was used." end } end
  package.preload["src.core.game3.vs_seeker"] = function() return { MAX_CHARGE = 100, getBattery = function() return 73 end } end
  package.preload["src.ui.game3.message"] = function() return { show = function(text) used[#used + 1] = "say:" .. text end, close = function() end } end
  package.preload["src.core.game3.player"] = function() return { biking = false, cellX = 7, cellY = 5, facing = "left" } end
end
  package.preload["src.core.game3.battle"] = function() return { isActive = function() return battle.active end, getState = function() return battle.state end } end
  package.preload["src.core.game3.battle.anim"] = function() return { shownBattler = function(_, b) return b end, displayHpRatio = function(_, b) return .5, b.mon.hp - 3, b.mon.maxHp end } end
  package.preload["src.core.game3.summary_data"] = function() return { gender = function(m) return m.gender or "" end, statusAilment = function(m) return m.hp <= 0 and 7 or m.status or 0 end, nature = function(m) return m.personality % 25, "ADAMANT" end } end
  package.preload["src.core.game3.items_data"] = function() return { displayName = function() return "ORAN BERRY" end } end
  package.preload["src.core.game3.dex"] = function() return { isCaught = function(_, s) return s == 16 end } end
  package.preload["src.core.game3.profile"] = function() return { forSession = function() return { family = "frlg" } end } end
  package.preload["src.import.gba.map_sections_extract"] = function() return { getInfo = function() return { resolved = true, rawName = "ROUTE 22" } end } end
  local flags = { [1002] = true, [301] = true }
  package.preload["src.core.game3.scripting.flags"] = function() return { IDS = { FLAG_HIDDEN_ITEMS_START = 1000 }, getFlag = function(store, _, id) return flags[id] == true end } end
  package.preload["src.core.game3.scripting.space"] = function() return { getStore = function() return {} end, bundle = {
    scripts = { Ball1 = { { op = "setvar", var = 0x8000, value = 13 }, { op = "callstd", std = 1 } }, Ball2 = { { op = "setorcopyvar", 0x8000, 22 }, { op = "gotostd", std = 1 } }, Npc = { { op = "msgbox" } } },
    events = { MAP_ROUTE22 = { objects = { { x = 12, y = 4, flag = 300, scriptKey = "Ball1" }, { x = 3, y = 20, flag = 301, scriptKey = "Ball2" }, { x = 9, y = 9, scriptKey = "Npc" }, { x = 40, y = 2, flag = 302, graphicsId = 92 } },
      bgEvents = { { type = "hidden_item", x = 10, y = 11, item = 4, hiddenItemId = 1 }, { type = "hidden_item", x = 5, y = 5, item = 4, hiddenItemId = 2 }, { type = "hidden_item", x = 10, y = 10, item = 4, flag = 1500 }, { type = "sign", x = 1, y = 1 } } } } } } end
  package.preload["src.core.game3.player"] = function() return { cellX = 10, cellY = 10 } end
  package.preload["src.core.game3.map"] = function() return { current = "MAP_ROUTE22" } end
  local SummaryStub, BoxStub, MenuStub, StorageStub = { open = false }, { open = false, cursorSlot = 1 }, { open = false, cursor = 1 }, {}
  package.preload["src.ui.game3.summary_menu"] = function() return SummaryStub end
  package.preload["src.ui.game3.box_storage_ui"] = function() return BoxStub end
  package.preload["src.ui.game3.party_menu"] = function() return MenuStub end
  package.preload["src.core.game3.storage"] = function() return StorageStub end
  local spawned = 0
  package.preload["src.core.Platform"] = function() return { canSpawnProcess = function() return true end } end
  local enet = require("enet")
  local spawnMode, fakes = "none", {}
  package.preload["src.core.HostShell"] = function() return { spawnSelfDetached = function(args) spawned = spawned + 1
    local port, token = args[1]:match("=(%d+),(%w+)")
    if spawnMode == "real" then
      os.execute(("love %s %s >/tmp/kg_out/dock_companion%d.log 2>&1 &"):format(os.getenv("KG_HOST"), args[1], spawned))
    elseif spawnMode == "fake" then
      local host = enet.host_create(); local peer = host:connect("127.0.0.1:" .. port, 2)
      fakes[#fakes + 1] = { host = host, peer = peer, token = token, frames = 0 }
    end
    return true end } end
  local function pumpFakes()
    for _, f in ipairs(fakes) do
      local e = f.host:service(0)
      while e do
        if e.type == "disconnect" then f.quit = true elseif e.type == "connect" then e.peer:send("H" .. f.token, 0, "reliable"); f.up = true
        elseif e.type == "receive" then
          local kind = e.data:sub(1, 1)
          if kind == "F" then f.frames = f.frames + 1; f.header = e.data:match("^F%w+\n([^\n]+)\n") elseif kind == "Q" then f.quit = true end
        end
        e = f.host:service(0)
      end
    end
  end


  local registry, logs = {}, {}
  local function newMod(id, dir, cache)
    local read = reader(dir)
    local m = { id = id, options_ = {}, hooks_ = {}, events_ = {}, exports = {}, cache_ = cache or {} }
    m.read = function(_, n) return read(n) end
    m.options = { define = function(_, s) m.schema = s; for _, row in ipairs(s) do if m.options_[row.key] == nil then m.options_[row.key] = row.default end end
      -- TEST_LANG picks the panels' language (en by default)
      if os.getenv("TEST_LANG") then m.options_.language = os.getenv("TEST_LANG") end end,
      get = function(_, k) return m.options_[k] end, set = function(_, k, v) m.options_[k] = v end }
    m.hooks = { wrap = function(_, n, f, p) m.hooks_[n] = f end }
    m.events = { on = function(_, n, f) m.events_[n] = f end }
    m.log = { warn = function(_, f, ...) logs[#logs + 1] = id .. ": " .. f:format(...); print("WARN", logs[#logs]) end, info = function() end }
    m.cache = { read = function(_, k) return m.cache_[k] end, write = function(_, k, v) m.cache_[k] = v; return true end }
    m.find = function(other) return registry[other] end
    registry[id] = m
    assert(loadstring(read("main.lua"), "@" .. id .. "/main.lua"))()(m)
    return m
  end
  local dock = newMod("trainer_desk", os.getenv("DOCK_MOD"))
  local pp = newMod("trainer_lens", os.getenv("PP_MOD"))
  registry.kanto_gear = { exports = {} }
  local mon = function(species, hp, extra) local m = { species = species, level = 12, hp = hp, maxHp = 40, attack = 30, defense = 20, speed = 25, spAtk = 22, spDef = 21, personality = 3,
    ivs = { hp = 31, atk = 20, def = 3, spe = 28, spa = 17, spd = 9 }, moves = { 44, 52 }, pp = { 25, 19 }, maxPp = { 25, 25 }, nickname = "" }
    for k, v in pairs(extra or {}) do m[k] = v end; return m end
  local game = { generation = 3, session = { map = "MAP_ROUTE22", dex = {}, party = { mon(4, 31, { gender = "M" }), mon(16, 12, { gender = "F" }) } },
    data = { maps = { MAP_ROUTE22 = { regionMapSectionId = 120 } }, gen3Encounters = { MAP_ROUTE22 = { land = { rate = 20, slots = { { species = 16, minLevel = 2, maxLevel = 5 }, { species = 19, minLevel = 2, maxLevel = 4 } } } } } } }
  local WW, WH = 1600, 900
  local window = G.newCanvas(WW, WH)
  -- a stand-in for Kanto Gear in Separate Screens mode: it draws to whatever bridge it is handed
  local engineBridge = { pushed = 0, push = function() return true end, detected = function() return true end, pollTouch = function() end, setEnabled = function() end }
  local gearFrame = love.image.newImageData(240, 216); gearFrame:mapPixel(function(x, y) return x / 240, 0.3, y / 216, 1 end)
  local gearTouches, gearBridge = {}, nil
  local rect
  local function frame()
    pp.hooks_["core.update"](function() end, game, 1 / 60)
    dock.hooks_["core.update"](function() end, game, 1 / 60)
    pumpFakes()
    local ctx = { width = WW, height = WH }
    rect = dock.hooks_["render.viewport"](function(c) return { x = 0, y = 0, width = c.width, height = c.height } end, ctx)
    local composeCtx = { secondScreen = engineBridge }
    dock.hooks_["render.compose"](function(_, c)
      gearBridge = c.secondScreen
      c.secondScreen.setEnabled(true)
      if c.secondScreen.detected() then c.secondScreen.push(gearFrame, 240, 216, 0, "secondary:fit") end
      for _ = 1, 32 do local e = c.secondScreen.pollTouch(); if not e then break end; gearTouches[#gearTouches + 1] = e end
      return false
    end, nil, composeCtx)
    G.setCanvas(window); G.clear(0, 0, 0, 1)
    local depth = G.getStackDepth()
    dock.hooks_["render.window"](function(_, c)
      G.setColor(0.25, 0.45, 0.3, 1); G.rectangle("fill", c.x, c.y, c.width, c.height)
      G.setColor(1, 1, 1, 1); G.print("GAME " .. c.width .. "x" .. c.height, c.x + 20, c.y + 20)
    end, game, { x = rect.x, y = rect.y, width = rect.width, height = rect.height })
    check(G.getStackDepth() == depth, "graphics stack is balanced after drawing")
    G.setCanvas()
  end
  local quiet = check
  local function frames(n) local keep = check; check = function(c, m) if not c then error(m, 2) end end; for _ = 1, n do frame() end; check = keep end
  local function save(name) local f = io.open(OUT .. "/dock-" .. name .. ".png", "wb"); f:write(window:newImageData():encode("png"):getString()); f:close() end
  local function ptr(phase, x, y) return dock.hooks_["input.pointer"](function() return "game" end, game, { phase = phase, x = x, y = y, id = "mouse", button = 1 }) end
  local Layout = assert(loadstring(reader(os.getenv("DOCK_MOD"))("layout.lua")))()
  local function where(id) return Layout.find(Layout.decode(dock.cache_["layout/v1"]), id) end

  -- before the game is ready nothing is laid out
  frames(2)
  check(rect.width == WW and gearBridge == engineBridge, "nothing changes before a game is running")
  dock.events_["game.ready"]({ game = game }); pp.events_["game.ready"]({ game = game })
  frames(3)
  check(gearBridge ~= engineBridge, "the second-screen mod is handed the dock's bridge")
  check(rect.width < WW and rect.height < WH and rect.x == 0, "the game is given the middle area: " .. rect.width .. "x" .. rect.height)
  check(spawned == 0, "docked panels open no windows")
  love.timer.sleep(0.7); frames(2)
  check(#logs == 0, "no warnings while drawing")
  local sx, sy = where("second_screen"); check(sx == "right", "the captured screen sits in the right dock")
  check(where("trainer_lens.party") == "right" and where("trainer_lens.wild") == "bottom" and where("trainer_lens.radar") == "bottom", "panels take their default docks")
  save("default")
  -- clicks in the game still reach the game; clicks in a dock do not
  check(ptr("pressed", 200, 200) == "game", "a click on the game goes to the game")
  ptr("released", 200, 200)
  -- a click on the captured screen becomes a touch in that screen's own pixels
  local rightX = rect.width + 5 + 10
  check(ptr("pressed", rightX + 200, 22 + 100) == true and ptr("released", rightX + 200, 22 + 100) == true, "a click on a panel is taken by the dock")
  frames(1)
  check(#gearTouches == 2 and gearTouches[1]:match("^down,%d+,%d+$") and gearTouches[2]:match("^up,"), "the captured screen receives the touch: " .. tostring(gearTouches[1]))
  local tx, ty = gearTouches[1]:match("(%d+),(%d+)"); check(tonumber(tx) < 240 and tonumber(ty) < 216, "touch is in the screen's own pixels")
  -- drag the divider between the game and the right dock
  local before = rect.width
  ptr("pressed", before + 2, 300); ptr("moved", before - 198, 300); ptr("released", before - 198, 300)
  frames(1)
  check(math.abs(rect.width - (before - 200)) <= 6, "dragging the divider resizes the dock: " .. before .. " -> " .. rect.width)
  -- switch tab, then drag a tab to the left edge of the game
  local geo = Layout.geometry(Layout.decode(dock.cache_["layout/v1"] or ""), { x = 0, y = 0, w = WW, h = WH }, { tab = 22, splitter = 5, minDock = 120, tabMax = 170 }, function() return true end)
  local bottom = geo.docks.bottom.groups
  local lastGroup = bottom[#bottom]
  check(#lastGroup.ids == 15, "the bottom dock holds the new panels too")
  frames(1)
  local second = lastGroup.tabs[2]
  -- tab rectangles follow label widths, so find the tab by probing along the bar
  local function tabX(id)
    for x = 0, WW - 1, 4 do
      local probe = ptr("pressed", x, WH - 5 - 0) ; ptr("cancelled")
    end
  end
  love.timer.sleep(0.6); frames(1)
  local text = dock.cache_["layout/v1"]
  check(type(text) == "string" and text:find("trainer_lens.enemy", 1, true), "the layout is saved: " .. tostring(text))
  -- move a panel with the model the pointer code uses, through real pointer events on its tab
  local live = Layout.geometry(Layout.decode(text), { x = 0, y = 0, w = WW, h = WH }, { tab = 22, splitter = 5, minDock = 120, tabMax = 170 }, function() return true end,
    function(id) return 80 end)
  local view = live.docks.right.groups[2] or live.docks.right.groups[1]
  local tab = view.tabs[#view.tabs]
  ptr("pressed", tab.rect.x + 6, tab.rect.y + 6); ptr("moved", 300, 300); ptr("moved", 20, 300); frames(1); save("dragging"); ptr("released", 20, 300)
  frames(1); love.timer.sleep(0.6); frames(1)
  check(where(tab.id) == "left", "dragging a tab to the game's left edge opens the left dock with it: " .. tab.id)
  check(rect.x > 0, "the game moves over for the left dock")
  check(#logs == 0, "no warnings after interaction")
  save("moved")
  -- the layout survives a restart
  local saved = dock.cache_["layout/v1"]
  local dock2 = newMod("trainer_desk", os.getenv("DOCK_MOD"), { ["layout/v1"] = saved })
  dock = dock2; dock.events_["game.ready"]({ game = game })
  frames(3); love.timer.sleep(0.6); frames(2)
  check(where(tab.id) == "left" and where("second_screen") == "right", "a restart keeps every panel where it was")
  -- reset
  dock.options_.reset_layout = true; frames(1); love.timer.sleep(0.6); frames(1)
  check(where(tab.id) ~= "left" and dock.options_.reset_layout == false, "reset puts panels back")
  -- switching the IDE off gives everything back
  dock.options_.enabled = false
  frames(3)
  check(rect.width == WW and gearBridge == engineBridge, "IDE off: the game has the whole window and the second screen is the engine's again")
  check(spawned > 0, "IDE off: panels fall back to their own windows")
  dock.options_.enabled = true; frames(3)
  check(rect.width < WW and gearBridge ~= engineBridge, "IDE back on")
  -- themes
  local api = dock.exports.dock
  check(api.registerTheme("light", { name = "Light", colors = { dock = "f0f0f0", text = { 0.1, 0.1, 0.1 } } }) == true and api.setTheme("light") and api.theme().colors.dock[1] > 0.9 and api.theme().colors.accent ~= nil, "a new theme overrides some colours and inherits the rest")
  frames(2); save("light"); api.setTheme("dark")
  check(select(2, api.register({ id = "Bad Id", width = 10, height = 10 })) ~= nil and api.register({ id = "x.y", title = "X", width = 100, height = 100, side = "left", first = true, draw = function() error("boom") end }) == true, "panel registration is validated")
  frames(2); love.timer.sleep(0.3); frames(1)
  check(#logs == 1 and logs[1]:find("boom"), "a panel that fails to draw is reported once and contained")
  api.unregister("x.y"); logs = {}
  ---------------------------------------------------------------- my Pokémon panel
  do
    local function shot(name)
      love.timer.sleep(0.25); frames(2)
      local c = G.newCanvas(480, 432); G.setCanvas(c); G.clear(0, 0, 0, 1)
      G.push("all"); G.origin(); pp.exports.debugPaint("ally"); G.pop(); G.setCanvas()
      local f = io.open(OUT .. "/ally-" .. name .. ".png", "wb"); f:write(c:newImageData():encode("png"):getString()); f:close()
      return pp.exports.debugAlly()
    end
    local party = game.session.party
    local name, label = shot("lead"); check(name == "Charmander" and label == "LEAD", "out of battle: the first of the party (" .. tostring(name) .. ")")
    MenuStub.open, MenuStub._party, MenuStub.cursor = true, party, 2
    name, label = shot("menu"); check(name == "Pidgey" and label == "MENU", "party menu: the one under the cursor")
    SummaryStub.open, SummaryStub._party, SummaryStub._cursor = true, party, 1
    name, label = shot("summary"); check(name == "Charmander" and label == "SUMMARY", "summary screen wins over the menu below it")
    SummaryStub.open, MenuStub.open = false, false
    local boxed = mon(58, 40, { shiny = true, gender = "F", heldItem = 5, evs = { hp = 4, atk = 252, def = 0, spe = 252, spa = 0, spd = 2 } })
    party[1].evs = { hp = 12, atk = 100, def = 0, spe = 37, spa = 255, spd = 6 }
    StorageStub.ensure = function() return { currentBox = 2, boxes = { { mons = {} }, { mons = { [7] = boxed } } } } end
    BoxStub.open, BoxStub.mode, BoxStub.cursorSlot, BoxStub._session = true, "browse", 7, game.session
    name, label = shot("box"); check(name == "Growlithe" and label == "BOX", "PC box: the one under the hand")
    BoxStub.cursorSlot = 8
    name, label = shot("box-empty"); check(name == "Charmander" and label == "LEAD", "an empty box slot falls back to the first of the party")
    BoxStub.holdingMon = boxed
    name, label = shot("box-held"); check(name == "Growlithe" and label == "HELD", "an empty slot while carrying one shows the carried one")
    BoxStub.holdingMon, BoxStub.cursorSlot = nil, -2
    name = shot("box-party"); check(name == "Pidgey", "the box's party drawer works too")
    BoxStub.open = false
    battle.active, battle.state = true, { wild = true, enemy = { mon = mon(19, 20) }, player = { mon = party[2] } }
    name, label = shot("battle"); check(name == "Pidgey" and label == "IN_BATTLE", "in battle: the one that is out")
    SummaryStub.open, SummaryStub._party, SummaryStub._cursor = true, party, 1
    name, label = shot("battle-summary"); check(label == "SUMMARY" and name == "Charmander", "a summary opened in battle still wins")
    SummaryStub._enemyParty = true
    name, label = shot("battle-foe-summary"); check(label == "IN_BATTLE", "a summary of the foe's party is not mine")
    SummaryStub.open, SummaryStub._enemyParty = false, nil
    battle.active = false
    party[1].isEgg = true
    name, label = shot("egg"); check(name == nil and label == "LEAD", "an egg shows no sheet")
    party[1].isEgg = nil
    check(#logs == 0, "no warnings from the my-Pokémon panel")
  end
  ---------------------------------------------------------------- 0.2: close, reopen, own window, menu
  -- measured like the dock does: the default face with the Japanese fallback
  local font12 = G.newFont(12)
  pcall(function()
    local bytes = reader(os.getenv("DOCK_MOD"))("fonts/NotoSansJP-subset.ttf")
    font12:setFallbacks(G.newFont(love.filesystem.newFileData(bytes, "ja.ttf"), 12))
  end)
  local function titleOf(id) for _, p in ipairs(api.panels()) do if p.id == id then return p.title end end end
  local function stateOf(id) for _, p in ipairs(api.panels()) do if p.id == id then return p.state end end end
  local function tabRect(id)
    local shown = function(other) return stateOf(other) == "docked" end
    local geo = Layout.geometry(Layout.decode(dock.cache_["layout/v1"]), { x = 0, y = 0, w = WW, h = WH }, { tab = 22, splitter = 5, minDock = 120, tabMax = 170 }, shown,
      function(other) return font12:getWidth(titleOf(other) or "") + 16 + 32 end)
    for _, side in ipairs(Layout.SIDES) do
      for _, view in ipairs(geo.docks[side] and geo.docks[side].groups or {}) do
        for _, tab in ipairs(view.tabs) do if tab.id == id then return tab.rect end end
      end
    end
  end
  local function settle() frames(1); love.timer.sleep(0.6); frames(2) end
  local function click(x, y) local a = ptr("pressed", x, y); ptr("released", x, y); return a end
  dock.options_.reset_layout = true; settle()
  check(#api.panels() == 18 and stateOf("second_screen") == "docked", "eighteen panels, all docked")
  -- close a panel with the X on its tab
  local r = tabRect("trainer_lens.party"); click(r.x + 6, r.y + 6); frames(1)
  click(r.x + r.w - 10, r.y + 11); settle()
  check(stateOf("trainer_lens.party") == "closed" and dock.cache_["layout/v1"]:find("hidden=trainer_lens.party", 1, true), "the X on a tab closes the panel: " .. dock.cache_["layout/v1"])
  check(tabRect("trainer_lens.party") == nil, "a closed panel has no tab")
  save("closed")
  -- the menu button reopens it
  local function openMenu() return click(rect.x + rect.width - 17, rect.y + 17) end
  local function rowY(n) return rect.y + 6 + 22 + 2 + (n - 1) * 22 + 11 end
  local function menuRow(id) for i, p in ipairs(api.panels()) do if p.id == id then return i + 1 end end end
  check(openMenu() == true, "the menu button takes the click")
  frames(1); save("menu")
  click(rect.x + rect.width - 40, rowY(menuRow("trainer_lens.party"))); settle()
  check(stateOf("trainer_lens.party") == "docked" and where("trainer_lens.party") == "right", "the menu reopens a closed panel where it was")
  check(ptr("pressed", 200, 300) == true, "a click outside the menu only closes it"); ptr("released", 200, 300)
  check(click(200, 300) == "game", "then the game gets clicks again")
  -- closing every panel leaves the game the whole window, and the menu still reachable
  for _, p in ipairs(api.panels()) do api.show(p.id, "closed") end
  settle()
  check(rect.width == WW and rect.height == WH, "all panels closed: the game has the whole window")
  openMenu(); frames(1); save("menu-all-closed")
  click(rect.x + rect.width - 40, rowY(menuRow("trainer_lens.radar"))); settle()
  check(stateOf("trainer_lens.radar") == "docked" and rect.height < WH, "a panel can be reopened from the menu when none is shown")
  click(rect.x + rect.width - 40, rowY(#api.panels() + 6)); settle()
  check(stateOf("second_screen") == "docked" and stateOf("trainer_lens.party") == "docked", "the menu's last row restores the layout")
  click(5, 5); frames(1)
  -- hidden panels survive a restart
  api.show("trainer_lens.wild", "closed"); settle()
  dock = newMod("trainer_desk", os.getenv("DOCK_MOD"), { ["layout/v1"] = dock.cache_["layout/v1"] }); api = dock.exports.dock
  dock.events_["game.ready"]({ game = game }); frames(3); settle()
  check(stateOf("trainer_lens.wild") == "closed" and stateOf("trainer_lens.enemy") == "docked", "a restart keeps closed panels closed")
  api.show("trainer_lens.wild", "docked"); settle()
  for _, extra in ipairs({ "trainer", "progress", "map", "region", "tools", "bag", "moves", "daycare", "counter", "dex", "notices", "box" }) do api.show("trainer_lens." .. extra, "closed") end
  settle()
  -- own window: the tab's other mark
  spawnMode = "fake"; local before = spawned
  r = tabRect("trainer_lens.radar"); click(r.x + 6, r.y + 6); settle()
  r = tabRect("trainer_lens.radar")          -- the active tab takes its full width
  click(r.x + r.w - 25, r.y + 11)
  for _ = 1, 40 do frames(1); love.timer.sleep(0.02) end
  local fake = fakes[#fakes]
  check(spawned == before + 1 and stateOf("trainer_lens.radar") == "window" and tabRect("trainer_lens.radar") == nil, "the window mark takes the panel out of the dock")
  check(fake.up and fake.frames >= 1 and fake.header:match("^480,432,"), "its window receives the panel's picture: " .. tostring(fake.header))
  check(api.windowPorts():match("^dock%.trainer_lens%.radar:%d+$"), "the window's port is published for the window keeper: " .. api.windowPorts())
  local n = fake.frames; for _ = 1, 30 do frames(1); love.timer.sleep(0.02) end
  check(fake.frames > n, "a moving panel keeps being sent (" .. n .. " -> " .. fake.frames .. ")")
  -- the captured screen in its own window, with touches coming back
  api.show("second_screen", "window")
  for _ = 1, 60 do frames(1); love.timer.sleep(0.02) end
  local gear = fakes[#fakes]
  check(gear ~= fake and gear.frames >= 1 and gear.header:match("^240,216,"), "the captured screen floats too: " .. tostring(gear.header))
  gearTouches = {}
  gear.peer:send("I" .. gear.token .. "\ndown,30,40", 0, "reliable"); gear.peer:send("I" .. gear.token .. "\nup,30,40", 0, "reliable"); gear.host:flush()
  for _ = 1, 20 do frames(1); love.timer.sleep(0.02) end
  check(gearTouches[1] == "down,30,40" and gearTouches[2] == "up,30,40", "a click in the floating screen reaches the mod that draws it")
  settle()
  check(dock.cache_["layout/v1"]:find("floating=", 1, true), "floating panels are remembered: " .. dock.cache_["layout/v1"])
  -- closing the window brings the panel back to its dock
  gear.peer:send("C" .. gear.token, 0, "reliable"); gear.host:flush()
  for _ = 1, 20 do frames(1); love.timer.sleep(0.02) end
  check(stateOf("second_screen") == "docked" and tabRect("second_screen") ~= nil, "closing the window docks the panel again")
  -- the menu docks a floating panel
  openMenu(); frames(1); save("menu-window")
  click(rect.x + rect.width - 40, rowY(menuRow("trainer_lens.radar"))); click(5, 5)
  for _ = 1, 20 do frames(1); love.timer.sleep(0.02) end
  check(stateOf("trainer_lens.radar") == "docked" and fake.quit == true and api.windowPorts() == "", "the menu docks a floating panel and its window is told to close")
  -- themes in the menu, remembered
  api.registerTheme("light", { name = "Light", colors = { dock = "f0f0f0", tabBar = "e4e4e4", tab = "dcdcdc", tabActive = "ffffff", text = { 0.2, 0.2, 0.2 }, textActive = { 0, 0, 0 } } })
  openMenu(); frames(1)
  click(rect.x + rect.width - 40, rowY(#api.panels() + 4)); frames(1); save("menu-theme")
  click(5, 5)
  check(api.theme().colors.dock[1] > 0.9 and dock.cache_.theme == "light", "the menu switches theme and remembers it")
  local dock3 = newMod("trainer_desk", os.getenv("DOCK_MOD"), { ["layout/v1"] = dock.cache_["layout/v1"], theme = "light" })
  check(dock3.exports.dock.theme().colors.dock[1] < 0.5, "a remembered theme that is not registered yet falls back to dark")
  dock3.exports.dock.registerTheme("light", { colors = { dock = "f0f0f0" } })
  check(dock3.exports.dock.theme().colors.dock[1] > 0.9, "and is applied once its mod registers it")
  registry.trainer_desk = dock
  api.setTheme("dark")
  -- 0.3.0: more tabs than a bar holds --------------------------------------------
  do
    local L = Layout.new()
    local ids = { "a", "b", "c", "d", "e", "f", "g", "h" }
    Layout.place(L, "a", "left", "new")
    for i = 2, 8 do Layout.place(L, ids[i], "left", "tab", 1) end
    local metrics = { tab = 22, splitter = 5, minDock = 120, tabMax = 170 }
    local function geo() return Layout.geometry(L, { x = 0, y = 0, w = WW, h = WH }, metrics, function() return true end, function() return 120 end) end
    local view = geo().docks.left.groups[1]
    local function within() for _, tab in ipairs(view.tabs) do if tab.rect.x + tab.rect.w > view.more.x or tab.rect.x < view.rect.x then return false end end return true end
    local function shows(id) for _, tab in ipairs(view.tabs) do if tab.id == id then return true end end return false end
    check(view.more ~= nil and #view.tabs < 8 and within() and view.active == "h" and shows("h"), "a crowded bar keeps its tabs inside the dock, shows the active one and gains a button for the rest: " .. #view.tabs .. " of 8")
    L.docks.left.groups[1].active = 1; view = geo().docks.left.groups[1]
    check(within() and view.active == "a" and shows("a") and not shows("h"), "the run of tabs follows the active one")
    check(Layout.hit(geo(), view.more.x + 3, view.more.y + 3).kind == "more", "the button is found under the pointer")
    L.docks.left.size = 0.6; view = geo().docks.left.groups[1]
    check(view.more == nil and #view.tabs == 8, "a bar with room shows every tab and no button")
  end
  for i = 1, 8 do api.register({ id = "many." .. i, title = "Painel número " .. i, width = 100, height = 100, side = "left", draw = function() end }) end
  frames(3); save("overflow")
  for i = 1, 8 do api.unregister("many." .. i) end
  -- text with accents cut in the middle of a letter must not stop the drawing
  api.register({ id = "cut.title", title = string.rep("a", 39) .. "éééé", width = 100, height = 100, side = "left", first = true, draw = function() end })
  api.register({ id = "cut.err1", title = "E1", width = 100, height = 100, side = "left", first = true, draw = function() error(string.rep("é", 120)) end })
  api.register({ id = "cut.err2", title = "E2", width = 100, height = 100, side = "left", first = true, draw = function() error("x" .. string.rep("é", 120)) end })
  frames(3); save("cut")
  local drawFailed = false
  for _, line in ipairs(logs) do if line:find("trainer_desk: draw", 1, true) then drawFailed = true end end
  check(not drawFailed, "titles and error texts with accents are cut on a whole letter: the window keeps drawing")
  for i = #logs, 1, -1 do logs[i] = nil end
  api.unregister("cut.title"); api.unregister("cut.err1"); api.unregister("cut.err2")
  -- the wheel over a panel goes to the panel; over the game it is still the game's
  local wheel = {}
  api.register({ id = "wheel.t", title = "Wheel", width = 200, height = 200, side = "left", first = true, draw = function() end,
    pointer = function(action, x, y, amount) if action == "wheel" then wheel[#wheel + 1] = { x, y, amount } end end })
  frames(2)
  local keepMouse = love.mouse.getPosition
  local passed, taken = 0, 0
  for y = 40, WH - 40, 60 do
    love.mouse.getPosition = function() return 60, y end
    local r = dock.hooks_["input.wheel"](function() return "zoom" end, game, -1)
    if r == "zoom" then passed = passed + 1 else taken = taken + 1 end
  end
  check(#wheel > 0 and wheel[1][3] == -1 and wheel[1][1] >= 0 and wheel[1][1] <= 200 and passed == 0, "the wheel over a panel reaches it, in the panel's own pixels, and never zooms the game: " .. #wheel .. " of " .. taken)
  love.mouse.getPosition = function() return rect.x + rect.width / 2, rect.y + rect.height / 2 end
  check(dock.hooks_["input.wheel"](function() return "zoom" end, game, 1) == "zoom", "over the game the wheel is still the game's")
  love.mouse.getPosition = keepMouse
  api.unregister("wheel.t")
  -- the hide key, and Esc on a menu
  local function key(name) return dock.hooks_["input.key"](function() return "game" end, game, { phase = "pressed", key = name }) end
  check(key("a") == "game" and key("escape") == "game", "other keys, and Esc with no menu open, go on to the game")
  frames(1); local docked = rect.width
  check(key("f10") == nil and api.collapsed(), "the hide key is taken by the dock")
  frames(1); save("collapsed")
  check(rect.width == WW and rect.height == WH and docked < WW, "hidden: the game has the whole window")
  check(ptr("pressed", 5, 5) == "game", "and clicks where a dock was go to the game"); ptr("released", 5, 5)
  key("f10"); frames(1)
  check(not api.collapsed() and rect.width == docked, "the same key brings the docks back as they were")
  openMenu(); frames(1); save("menu-0.3")
  check(key("escape") == nil, "Esc closes an open menu instead of reaching the game")
  ptr("released", 5, 5); frames(1)
  check(ptr("pressed", rect.x + rect.width / 2, rect.y + rect.height / 2) == "game", "and after that a click on the game is the game's again"); ptr("released", 5, 5)
  -- 2.0: the new look, at several sizes -------------------------------------------
  do
    local party = game.session.party
    party[1].evs = { hp = 12, atk = 100, def = 0, spe = 252, spa = 140, spd = 6 }
    battle.active, battle.state = true, { wild = false, enemy = { mon = mon(19, 20, { gender = "F", shiny = true }) }, player = { mon = party[1] },
      foeParty = {} }
    -- tools: field moves and key items behind one click
    local used = TOOL_USED
    game.session.bag = { [360] = 1, [264] = 1, [362] = 1, [86] = 3, [85] = 2 }
    battle.active = false
    local tc = G.newCanvas(520, 240)
    local function paintTools() G.setCanvas(tc); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); local ok, err = pcall(pp.exports.debugPaint, "tools", 520, 240); G.pop(); G.setCanvas(); return ok, err end
    local okT, errT = paintTools(); check(okT, "the tools view draws: " .. tostring(errT))
    pp.exports.debugToolClick(20, 45)
    check(used[1] == "bicycle", "a click on the bicycle uses it through the game's own field action: " .. tostring(used[1]))
    pp.exports.debugToolClick(20 + 174, 45)       -- Cut is known but not usable here: it is not shown, Surf takes its place
    check(#used == 2 and used[2] == "surf", "a tool that cannot be used here is hidden and the next one takes its place: " .. tostring(used[2]))
    paintTools()
    local f = io.open(OUT .. "/panels-tools.png", "wb"); f:write(tc:newImageData():encode("png"):getString()); f:close()
    battle.active = true
    local shots = { { "enemy", 440, 560 }, { "ally", 440, 560 }, { "ally", 900, 380 }, { "party", 320, 420 }, { "party", 700, 170 },
      { "wild", 700, 220 }, { "wild", 300, 420 }, { "radar", 380, 520 }, { "radar", 700, 300 }, { "enemy", 300, 400 }, { "trainer", 420, 420 }, { "trainer", 760, 260 }, { "progress", 520, 300 }, { "map", 520, 320 }, { "region", 520, 320 }, { "map", 260, 300 },
      { "bag", 520, 260 }, { "moves", 440, 420 }, { "daycare", 440, 260 }, { "counter", 440, 260 }, { "dex", 560, 300 }, { "notices", 380, 200 }, { "dex", 620, 360 }, { "party", 320, 200 }, { "bag", 520, 200 }, { "tools", 520, 240 } }
    package.preload["src.core.game3.daycare"] = function() local D = {}
      D.stateOf = function() return { steps = { 5400, 300 }, party[1], party[2] } end
      D.mon = function(dc, i) return dc[i] end; D.isEggPending = function() return true end
      D.levelsGained = function(_, steps) return math.floor(steps / 1000) end; D.cost = function(m, steps) return 100 + 100 * D.levelsGained(m, steps) end
      D.route5Of = function() return { steps = 0 } end; return D end
    -- the counter: every new wild battle is one more encounter, remembered
    for round = 1, 3 do
      battle.active, battle.state = true, { wild = true, enemy = { mon = mon(round == 3 and 16 or 19, 20) }, player = { mon = party[1] } }
      frames(1); battle.active = false; frames(1)
    end
    check(pp.cache_["counter/v1"] and pp.cache_["counter/v1"]:find("s16=1", 1, true) and tonumber(pp.cache_["counter/v1"]:match("total=(%d+)")) >= 3,
      "wild encounters are counted by species and remembered: " .. tostring(pp.cache_["counter/v1"]):gsub("\n", " "))
    local M = game.data.maps
    M.MAP_ROUTE22.w, M.MAP_ROUTE22.h = 24, 12
    M.MAP_ROUTE22.midLayout = { width = 24, height = 12, pair = "T", cells = {}, overrides = {},
      midAt = function(_, x, y) return (x < 6 and y > 2) and 1 or (x > 15 and y > 7) and 2 or (y == 0) and 3 or 0 end }
    M.MAP_ROUTE22.connections = { { dir = "east", map = "FR_VIRIDIAN_CITY", offset = -4 }, { dir = "north", map = "FR_ROUTE_23", offset = 2 } }
    M.FR_VIRIDIAN_CITY = { w = 24, h = 20, connections = { { dir = "west", map = "MAP_ROUTE22", offset = 4 }, { dir = "south", map = "FR_ROUTE_1", offset = 6 }, { dir = "north", map = "FR_ROUTE_2", offset = 6 } } }
    M.FR_ROUTE_23 = { w = 12, h = 40, connections = {} }
    M.FR_ROUTE_1 = { w = 12, h = 20, connections = { { dir = "south", map = "FR_PALLET_TOWN", offset = -6 } } }
    M.FR_ROUTE_2 = { w = 12, h = 30, connections = {} }
    M.FR_PALLET_TOWN = { w = 24, h = 20, connections = {} }
    game.data.gen3Encounters.FR_ROUTE_1 = { land = { rate = 20, slots = { { species = 16 }, { species = 19 } } } }
    game.data.gen3Encounters.FR_ROUTE_2 = { land = { rate = 20, slots = { { species = 16 } } } }
    game.session.name, game.session.money, game.session.trainerId, game.session.playtime = "MARCO", 1234567, 40213, { hours = 57, minutes = 8 }
    game.session.gameStats = { [5] = 48211, [8] = 912, [9] = 143, [11] = 61, [12] = 30 }
    -- party order: click one, then another
    do
      local c = G.newCanvas(320, 200)
      local function paintParty() G.setCanvas(c); G.push("all"); G.origin(); pp.exports.debugPaint("party", 320, 200); G.pop(); G.setCanvas() end
      battle.active = false; paintParty()
      pp.exports.debugClick("party", 40, 30); paintParty(); pp.exports.debugClick("party", 40, 70)
      check(TOOL_USED[#TOOL_USED] == "swap12", "clicking one team member and then another swaps them through the game: " .. tostring(TOOL_USED[#TOOL_USED]))
      pp.exports.debugClick("party", 40, 30); pp.exports.debugClick("party", 40, 30)
      check(TOOL_USED[#TOOL_USED] == "swap12", "clicking the same one twice just lets go of it")
      battle.active = true
    end
    -- Auto Repel: the weakest repel when none is active, only where wild Pokémon appear
    do
      battle.active = false
      game.session.bag[86], game.session.bag[83], game.session.repelSteps = 2, 5, 0
      local keep = game.data.gen3Encounters.MAP_ROUTE22
      game.data.gen3Encounters.MAP_ROUTE22 = nil
      pp.exports.debugAutoRepel(true)
      local n = #TOOL_USED
      love.timer.sleep(0.6); frames(1)
      check(#TOOL_USED == n, "Auto Repel leaves a safe area alone")
      game.data.gen3Encounters.MAP_ROUTE22 = keep
      love.timer.sleep(0.6); frames(1)
      check(TOOL_USED[#TOOL_USED] == "item86" and #TOOL_USED == n + 1, "where wild Pokémon appear it uses the weakest repel: " .. tostring(TOOL_USED[#TOOL_USED]))
      game.session.repelSteps = 100
      love.timer.sleep(0.6); frames(1)
      check(#TOOL_USED == n + 1, "and nothing more while that one lasts")
      game.session.repelSteps, game.session.bag[86] = 0, 0
      love.timer.sleep(0.6); frames(1)
      check(TOOL_USED[#TOOL_USED] == "item83", "with the weakest gone, the next one up")
      pp.exports.debugAutoRepel(false); game.session.repelSteps = 0
      love.timer.sleep(0.6); frames(1)
      check(#TOOL_USED == n + 2, "switched off, it uses nothing")
      battle.active = true
    end
    -- the area list: a click opens the species, Back returns to the list
    do
      local c = G.newCanvas(520, 300)
      local function paintWild() G.setCanvas(c); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); local ok, err = pcall(pp.exports.debugPaint, "wild", 520, 300); G.pop(); G.setCanvas(); return ok, err end
      battle.active = false
      check(paintWild(), "the area list draws")
      pp.exports.debugClick("wild", 60, 50)
      local okD, errD = paintWild(); check(okD, "a click on a species opens it in full: " .. tostring(errD))
      local f = io.open(OUT .. "/panels-wild-detail.png", "wb"); f:write(c:newImageData():encode("png"):getString()); f:close()
      pp.exports.debugClick("wild", 20, 15); check(paintWild(), "Back returns to the list")
      battle.active = true
    end
    -- the PC: a box as a grid, a click shows the sheet, and nothing in the save changes
    do
      local boxMons = {}
      for slot, species in pairs({ [1] = 4, [2] = 16, [5] = 129, [8] = 19, [13] = 58, [30] = 72 }) do
        boxMons[slot] = mon(species, 40, { level = 20 + slot, shiny = slot == 5, gender = slot % 2 == 0 and "F" or "M",
          maxHp = nil, attack = nil, evs = { hp = 0, atk = 6, def = 0, spe = 12, spa = 0, spd = 0 } })
      end
      game.session.storage = { currentBox = 2, boxes = { { name = "BOX 1", mons = {} }, { name = "BOX 2", mons = boxMons }, { name = "LENDÁRIOS", mons = {} } } }
      local function fingerprint()
        local parts = {}
        for b, box in ipairs(game.session.storage.boxes) do
          for slot = 1, 30 do local m = box.mons[slot]; parts[#parts + 1] = m and (b .. ":" .. slot .. ":" .. m.species .. ":" .. tostring(m.hp)) or nil end
        end
        return table.concat(parts, ",") .. "|" .. game.session.storage.currentBox
      end
      local before = fingerprint()
      local out = G.newCanvas(1300, 460)
      local function put(w2, h2, x2, pre)
        local c = G.newCanvas(w2, h2)
        G.setCanvas(c); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); local ok, err = pcall(pp.exports.debugPaint, "box", w2, h2); G.pop(); G.setCanvas()
        check(ok, "the PC panel draws at " .. w2 .. "x" .. h2 .. ": " .. tostring(err))
        if pre then pre() end
        G.setCanvas(c); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); pcall(pp.exports.debugPaint, "box", w2, h2); G.pop(); G.setCanvas()
        G.setCanvas(out); G.setColor(1, 1, 1, 1); G.draw(c, x2, 0); G.setCanvas()
      end
      battle.active = false
      put(400, 360, 0)                                                     -- the box the PC is on: BOX 2
      put(860, 460, 410, function() pp.exports.debugClick("box", 220, 76) end)  -- a click on slot 1: the sheet beside it
      check(fingerprint() == before, "looking at the PC changes nothing in it")
      local f5 = io.open(OUT .. "/panels-box.png", "wb"); f5:write(out:newImageData():encode("png"):getString()); f5:close()
      local c2 = G.newCanvas(400, 460)
      G.setCanvas(c2); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); pcall(pp.exports.debugPaint, "box", 400, 460); G.pop(); G.setCanvas()
      local f6 = io.open(OUT .. "/panels-box-narrow.png", "wb"); f6:write(c2:newImageData():encode("png"):getString()); f6:close()
      pp.exports.debugClick("box", 20, 15)                                   -- back

      -- Lock and Sort: box 3 is locked; the others are sorted by living dex
      local legend = mon(150, 70, { level = 70 })
      game.session.storage.boxes[3].mons = { [4] = legend }
      game.session.storage.boxes[1].mons = { [3] = mon(16, 40, { level = 3 }), [9] = mon(1, 40, { level = 5 }),
        [10] = mon(16, 40, { level = 30 }), [11] = { species = 25, isEgg = true, ivs = {}, evs = {} } }
      local function paintBox(w2, h2)
        local c = G.newCanvas(w2 or 400, h2 or 360)
        G.setCanvas(c); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); local ok, err = pcall(pp.exports.debugPaint, "box", w2 or 400, h2 or 360); G.pop(); G.setCanvas()
        check(ok, "the PC panel draws: " .. tostring(err))
        return c
      end
      local function order()
        local out = {}
        for b = 1, 3 do
          for slot = 1, 30 do
            local m = game.session.storage.boxes[b].mons[slot]
            if m then out[#out + 1] = b .. ":" .. slot .. ":" .. (m.isEgg and "egg" or (m.species .. "L" .. m.level)) end
          end
        end
        return table.concat(out, " ")
      end
      local original = order()
      battle.active = false
      -- go to box 3 and lock it
      for _ = 1, 3 do paintBox(); pp.exports.debugBoxPress("page", 1) end
      paintBox(); check(pp.exports.debugBoxPress("lock"), "the lock button is there")
      paintBox()
      check((pp.cache_["box_locks/v1"] or ""):find("=3$") ~= nil, "the lock is saved: " .. tostring(pp.cache_["box_locks/v1"]))
      -- in a battle, sorting refuses
      battle.active = true
      paintBox(); pp.exports.debugBoxPress("openSort"); paintBox(); pp.exports.debugBoxPress("sort", "dex_all"); paintBox(); pp.exports.debugBoxPress("confirm")
      check(order() == original, "no sorting during a battle")
      battle.active = false
      paintBox(); pp.exports.debugBoxPress("openSort")
      local cs = paintBox(); local fs = io.open(OUT .. "/panels-box-sort.png", "wb"); fs:write(cs:newImageData():encode("png"):getString()); fs:close()
      pp.exports.debugBoxPress("sort", "dex_all")
      local cc = paintBox(); local fc = io.open(OUT .. "/panels-box-confirm.png", "wb"); fc:write(cc:newImageData():encode("png"):getString()); fc:close()
      pp.exports.debugBoxPress("confirm")
      local sorted = order()
      check(sorted == "1:1:1L5 1:2:4L21 1:3:16L30 1:4:16L22 1:5:16L3 1:6:19L28 1:7:58L33 1:8:72L50 1:9:129L25 1:10:egg 3:4:150L70",
        "living dex, repeats side by side, eggs last, locked box untouched: " .. sorted)
      paintBox(); check(pp.exports.debugBoxPress("undo"), "Undo is offered after sorting")
      check(order() == original, "Undo puts the PC back")
      paintBox(); pp.exports.debugBoxPress("openSort"); paintBox(); pp.exports.debugBoxPress("sort", "dex_simple"); paintBox(); pp.exports.debugBoxPress("confirm")
      check(order() == "1:1:1L5 1:2:4L21 1:3:16L30 1:4:19L28 1:5:58L33 1:6:72L50 1:7:129L25 1:8:16L22 1:9:16L3 1:10:egg 3:4:150L70",
        "living dex, repeats at the end: " .. order())
      paintBox(); pp.exports.debugBoxPress("openSort"); paintBox(); pp.exports.debugBoxPress("sort", "level_down"); paintBox(); pp.exports.debugBoxPress("confirm")
      check(order():sub(1, 18) == "1:1:72L50 1:2:58L3", "level, high to low: " .. order())
      paintBox(); pp.exports.debugBoxPress("openSort"); paintBox(); pp.exports.debugBoxPress("sort", "level_up"); paintBox(); pp.exports.debugBoxPress("confirm")
      check(order():sub(1, 16) == "1:1:16L3 1:2:1L5", "level, low to high: " .. order())
      paintBox(); pp.exports.debugBoxPress("openSort"); paintBox(); pp.exports.debugBoxPress("sort", "species_level"); paintBox(); pp.exports.debugBoxPress("confirm")
      check(order():find("1:3:16L3 1:4:16L22 1:5:16L30", 1, true) ~= nil, "species, then level: " .. order())
      -- something else moving after a sort ends the undo
      game.session.storage.boxes[2].mons[1] = mon(10, 40, { level = 2 })
      paintBox(); check(not pp.exports.debugBoxPress("undo"), "no Undo once the PC changed")
      local cf = paintBox(); local ff = io.open(OUT .. "/panels-box-sorted.png", "wb"); ff:write(cf:newImageData():encode("png"):getString()); ff:close()
      -- unlock box 3 again for the next tests
      for _ = 1, 3 do paintBox(); pp.exports.debugBoxPress("page", 1) end
      paintBox(); pp.exports.debugBoxPress("lock"); paintBox()
      battle.active = true
      game.session.storage = nil
    end
    local sheetW, sheetH, x, y, rowH = 1820, 3300, 0, 0, 0
    local sheet = G.newCanvas(sheetW, sheetH)
    for _, shot in ipairs(shots) do
      local c = G.newCanvas(shot[2], shot[3])
      G.setCanvas(c); G.clear(0, 0, 0, 1)
      G.push("all"); G.origin()
      if shot[1] == "dex" and shot[2] == 620 then pp.exports.debugPaint("dex", 560, 300); pp.exports.debugClick("dex", 60, 50) end
      local ok, err = pcall(pp.exports.debugPaint, shot[1], shot[2], shot[3])
      G.pop(); G.setCanvas()
      check(ok, "the " .. shot[1] .. " view draws at " .. shot[2] .. "x" .. shot[3] .. ": " .. tostring(err))
      if x + shot[2] > sheetW then x, y, rowH = 0, y + rowH + 10, 0 end
      G.setCanvas(sheet); G.setColor(1, 1, 1, 1); G.draw(c, x, y); G.setCanvas()
      x, rowH = x + shot[2] + 10, math.max(rowH, shot[3])
    end
    do
      battle.active = false
      for id = 400, 440 do game.session.bag[id] = 1 end
      pp.exports.debugAutoRepel(true)
      local out = G.newCanvas(1100, 560)
      local function put(kind, w2, h2, x2, y2, pre)
        local c = G.newCanvas(w2, h2)
        for pass = 1, 2 do
          G.setCanvas(c); G.clear(0, 0, 0, 1); G.push("all"); G.origin(); pcall(pp.exports.debugPaint, kind, w2, h2); G.pop(); G.setCanvas()
          if pass == 1 and pre then pre() end
        end
        G.setCanvas(out); G.setColor(1, 1, 1, 1); G.draw(c, x2, y2); G.setCanvas()
      end
      put("dex", 560, 260, 0, 0, function() pp.exports.debugClick("dex", 20, 15) end)
      put("bag", 520, 260, 570, 0, function() pp.exports.debugClick("bag", 60, 60) end)
      put("tools", 520, 280, 0, 270)
      put("wild", 520, 150, 570, 270)
      local f3 = io.open(OUT .. "/panels-pagers.png", "wb"); f3:write(out:newImageData():encode("png"):getString()); f3:close()
      pp.exports.debugAutoRepel(false)
      for id = 400, 440 do game.session.bag[id] = nil end
    end
    local f = io.open(OUT .. "/panels-2.0.png", "wb"); f:write(sheet:newImageData():encode("png"):getString()); f:close()
    battle.active = false
  end
  frames(3); save("panels-docked")
  -- a real companion window, to look at
  if os.getenv("KG_HOST") then
    spawnMode = "real"
    api.show("trainer_lens.radar", "window"); api.show("second_screen", "window")
    local t0 = love.timer.getTime()
    while love.timer.getTime() - t0 < 6 do frames(1); love.timer.sleep(0.03) end
    check(select(2, api.windowPorts():gsub(":", ":")) == 2, "two real windows connect: " .. api.windowPorts())
    os.execute(("import -window root %s/dock-floating-desktop.png 2>/dev/null"):format(OUT))
    dock.hooks_["core.quit_to_launcher"](function() end)
    love.timer.sleep(1.5)
    check(tonumber(io.popen("pgrep -f [d]isplay-companion | wc -l"):read("*a")) == 0, "leaving the game closes the floating windows")
  end
  check(#logs == 0, "no warnings in the new checks")
  print("ALL DOCK CHECKS PASSED")
  love.event.quit()
end
