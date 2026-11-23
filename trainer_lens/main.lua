-- Trainer Lens: information panels for the native Gen 3 games (FireRed/LeafGreen).
--
-- With Trainer Desk installed, every panel is docked around the game and drawn
-- at the size its dock gives it; without it, up to five panels open as desktop
-- windows (windows.lua, with the Windows-only window keeper in wm_worker.lua).
--
-- This file builds models from game state; ui.lua turns them into pictures.
-- Panels only read the game, with three exceptions the player starts with a
-- click: the Tools panel uses field moves and key items through the game's own
-- functions (and Auto Repel uses a Repel when one wears off), and the Party
-- panel swaps two members through the game's own reorder.
-- See docs/ARCHITECTURE.md for a map of this file.
return function(mod)
  local G = love.graphics
  local floor, max, min = math.floor, math.max, math.min
  local function load_(name, ...)
    return assert(load(assert(mod:read(name)), "@trainer_lens/" .. name))()(...)
  end

  mod.options:define({
    { key = "placement", label = "PANEL PLACEMENT", type = "choice", default = "dock",
      choices = { { "IDE (TRAINER DESK)", "dock" }, { "OWN WINDOWS", "windows" } },
      description = "IDE docks the panels inside the game window when the Trainer Desk mod is enabled. Own Windows opens each panel as a separate desktop window; it is also what happens when Trainer Desk is not there." },
    { key = "panels", label = "PANEL WINDOWS", type = "choice", default = 3,
      choices = { { "OFF", 0 }, { "1", 1 }, { "2", 2 }, { "3", 3 }, { "4", 4 }, { "5", 5 } },
      description = "How many panel windows to open. Each one can be moved and resized. A window you close reopens when you change this." },
    { key = "panel_1", label = "PANEL 1", type = "choice", default = "wild",
      choices = { { "AREA POKEMON", "wild" }, { "PARTY", "party" }, { "OPPONENT", "enemy" }, { "ITEM RADAR", "radar" }, { "MY POKEMON", "ally" } } },
    { key = "panel_2", label = "PANEL 2", type = "choice", default = "party",
      choices = { { "AREA POKEMON", "wild" }, { "PARTY", "party" }, { "OPPONENT", "enemy" }, { "ITEM RADAR", "radar" }, { "MY POKEMON", "ally" } } },
    { key = "panel_3", label = "PANEL 3", type = "choice", default = "enemy",
      choices = { { "AREA POKEMON", "wild" }, { "PARTY", "party" }, { "OPPONENT", "enemy" }, { "ITEM RADAR", "radar" }, { "MY POKEMON", "ally" } } },
    { key = "panel_4", label = "PANEL 4", type = "choice", default = "radar",
      choices = { { "AREA POKEMON", "wild" }, { "PARTY", "party" }, { "OPPONENT", "enemy" }, { "ITEM RADAR", "radar" }, { "MY POKEMON", "ally" } } },
    { key = "panel_5", label = "PANEL 5", type = "choice", default = "ally",
      choices = { { "AREA POKEMON", "wild" }, { "PARTY", "party" }, { "OPPONENT", "enemy" }, { "ITEM RADAR", "radar" }, { "MY POKEMON", "ally" } } },
    { key = "battle_sheet", label = "OPPONENT IN BATTLE", type = "toggle", default = true,
      description = "In battle, panel 1 shows the opponent unless another panel already does." },
    { key = "language", label = "LANGUAGE", type = "choice", default = "en",
      choices = { { "ENGLISH", "en" }, { "ESPANOL", "es" }, { "PORTUGUES", "pt" }, { "JAPANESE", "ja" } },
      description = "Language of the panels. Names that come from the game (Pokemon, moves, items) stay in the game's language." },
    { key = "remember_windows", label = "REMEMBER WINDOWS", type = "toggle", default = true,
      description = "Windows only. Remember where you put the panel and second-screen windows and put them back when they open." },
    { key = "remember_game_window", label = "REMEMBER GAME WINDOW", type = "toggle", default = true,
      description = "Windows only. Also remember the place and size of the main game window." },
    { key = "raise_windows", label = "BRING WINDOWS FORWARD", type = "toggle", default = true,
      description = "Windows only. When the game gains focus from another program, bring its other windows forward too." },
  })
  local function option(key) return mod.options:get(key) end

  ---------------------------------------------------------------------------
  -- Text
  ---------------------------------------------------------------------------
  -- Each language lives in lang/<code>.lua; i18n.lua picks the chosen one and
  -- makes fonts that can also draw Japanese.
  local I18n = assert(load(assert(mod:read("i18n.lua")), "@trainer_lens/i18n.lua"))()(mod, function() return option("language") end)
  local T = I18n.T
  local function typeLabel(id)
    local types = T("TYPES")
    return type(types) == "table" and types[id] or id or "???"
  end

  -- Game text can carry control tags and symbols the font lacks.
  local function clean(value)
    value = tostring(value or ""):gsub("{[^{}]*}", ""):gsub("♂", " M"):gsub("♀", " F")
    local out = {}
    for ch in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      out[#out + 1] = (ch == "\n" or ch == "\r") and " " or ch
    end
    return (table.concat(out):gsub("^%s+", ""):gsub("%s+$", ""))
  end
  -- ROM names are capitals; read them as names.
  local function nameCase(value)
    value = clean(value)
    if value:find("%l") or not value:find("%u") then return value end
    return (value:gsub("(%a)([%w']*)", function(first, rest) return first .. rest:lower() end))
  end

  ---------------------------------------------------------------------------
  -- Drawing: views live in ui.lua and draw into whatever room they are given
  ---------------------------------------------------------------------------
  local W, H = 480, 432       -- a view's size when nobody says how much room it has
  local UI = load_("ui.lua", { T = T, typeLabel = typeLabel, font = I18n.font })


  ---------------------------------------------------------------------------
  -- Game data (native Gen 3 engine, read-only)
  ---------------------------------------------------------------------------
  local game
  local Host
  local function host()
    if Host then return Host end
    local h = {
      P = require("src.core.game3.pokemon"), Moves = require("src.core.game3.battle.moves"),
      Types = require("src.core.game3.battle.types"), Battle = require("src.core.game3.battle"),
      Summary = require("src.core.game3.summary_data"), Items = require("src.core.game3.items_data"),
      Dex = require("src.core.game3.dex"),
    }
    local okAnim, Anim = pcall(require, "src.core.game3.battle.anim")
    h.Anim = okAnim and Anim or nil
    h.typeName = {}
    for name, id in pairs(h.Types.ID) do h.typeName[id] = name end
    Host = h
    return h
  end
  local function try(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
  end
  local STATUS_NAMES = { "PSN", "PAR", "SLP", "FRZ", "BRN", [7] = "FNT" }

  local function monBasics(mon)
    local h = host()
    local species = h.P.speciesOf(mon)
    local egg = try(h.P.isEgg, mon) == true
    local nick = mon.nickname
    local out = {
      species = species, egg = egg,
      name = egg and T("EGG") or nameCase((nick and nick ~= "") and nick or try(h.P.name, species) or "?"),
      level = tonumber(mon.level) or 0, hp = max(0, floor(tonumber(mon.hp) or 0)),
      maxHp = max(1, floor(tonumber(mon.maxHp) or 1)),
      gender = try(h.Summary.gender, mon), shiny = try(h.P.isShiny, mon) == true,
    }
    out.status = STATUS_NAMES[try(h.Summary.statusAilment, mon) or 0]
    local item = mon.heldItem or mon.item
    if item and item ~= 0 and item ~= "" then
      local label = try(h.Items.displayName, item)
      out.item = label and nameCase(label) or nil
    end
    return out
  end

  local function partyModel()
    local h, rows = host(), {}
    for index, mon in ipairs(game.session.party or {}) do
      local row = monBasics(mon)
      row.levelText, row.hpText = T("LV") .. row.level, row.hp .. "/" .. row.maxHp
      row.pic = try(h.P.monIcon, mon)
      rows[index] = row
    end
    return { rows = rows }
  end
  local partyState = { hits = {}, selected = nil }

  local NATURE_SLOT = { ATK = 0, DEF = 1, SPE = 2, SPA = 3, SPD = 4 }
  local STAT_ROWS = { { "HP", "maxHp", "hp" }, { "ATK", "attack", "atk" }, { "DEF", "defense", "def" },
    { "SPA", "spAtk", "spa" }, { "SPD", "spDef", "spd" }, { "SPE", "speed", "spe" } }

  -- The sheet both the opponent and the "my Pokémon" views show for one mon.
  local function sheetModel(mon, pokemon)
    local h = host()
    if pokemon.hp > 0 and pokemon.status == "FNT" then pokemon.status = nil end
    if pokemon.hp <= 0 then pokemon.status = "FNT" end
    pokemon.levelText, pokemon.hpText = T("LV") .. pokemon.level, pokemon.hp .. "/" .. pokemon.maxHp
    local types = try(h.P.types, pokemon.species) or {}
    pokemon.type = h.typeName[types[1]]
    pokemon.type2 = h.typeName[types[2]] or pokemon.type
    if pokemon.type == "MYSTERY" then pokemon.type = nil end

    local natureId, natureLabel = try(h.Summary.nature, mon)
    natureId = tonumber(natureId)
    local up, down = natureId and floor(natureId / 5), natureId and natureId % 5
    local abilityId = mon.ability or mon.abilityId or try(h.P.abilityId, pokemon.species, mon.personality)
    local ability = abilityId and try(h.P.abilityName, abilityId)
    if ability and tostring(ability):match("^%-+$") then ability = nil end
    local facts = {
      { label = T("NATURE"), value = natureLabel and nameCase(natureLabel) or nil },
      { label = T("ABILITY"), value = ability and nameCase(ability) or nil },
      { label = T("ITEM"), value = pokemon.item or T("NO_ITEM") },
    }
    local rows = {}
    for index, def in ipairs(STAT_ROWS) do
      local slot = NATURE_SLOT[def[1]]
      rows[index] = {
        key = def[1], label = T(def[1]), stat = tonumber(mon[def[2]]),
        iv = type(mon.ivs) == "table" and tonumber(mon.ivs[def[3]]) or nil,
        ev = type(mon.evs) == "table" and tonumber(mon.evs[def[3]]) or 0,
        nature = (slot and up and up ~= down) and (slot == up and 1 or slot == down and -1) or nil,
      }
    end
    local moves = {}
    for slot = 1, 4 do
      local id = type(mon.moves) == "table" and mon.moves[slot]
      if type(id) == "table" then id = id.id end
      if id and id ~= 0 and id ~= "" then
        local row = try(h.Moves.get, id)
        local pp = type(mon.pp) == "table" and tonumber(mon.pp[slot])
        local maxPp = type(mon.maxPp) == "table" and tonumber(mon.maxPp[slot]) or row and tonumber(row.pp)
        moves[slot] = {
          name = nameCase(try(h.Moves.displayName, id) or tostring(id)),
          type = row and h.typeName[row.type] or nil,
          pp = pp and (maxPp and (pp .. "/" .. maxPp) or tostring(pp)) or nil,
        }
      end
    end
    return {
      pokemon = pokemon, facts = facts, rows = rows, moves = moves,
      pic = try(h.P.frontPic, try(h.P.monPicSpecies, mon) or pokemon.species, nil, pokemon.shiny, mon.personality),
    }
  end

  local function enemyModel()
    local h = host()
    if not h.Battle.isActive() then return nil end
    local st = h.Battle.getState()
    if not st then return nil end
    local battler, key = st.enemy, "enemy"
    if st.double and type(st.battlers) == "table" then
      for _, id in ipairs({ 1, 3 }) do
        local candidate = st.battlers[id]
        if candidate and candidate.mon and not (st.absent and st.absent[id])
            and (tonumber(candidate.mon.hp) or 0) > 0 then
          battler, key = candidate, id
          break
        end
      end
    end
    if not (battler and battler.mon) then return nil end
    -- Follow the battler and HP the game is showing while it animates.
    local shown = h.Anim and try(h.Anim.shownBattler, key, battler) or battler
    local mon = shown and shown.mon or battler.mon
    local pokemon = monBasics(mon)
    if h.Anim then
      local _, hp, maxHp = try(h.Anim.displayHpRatio, key, shown)
      if tonumber(hp) and tonumber(maxHp) then pokemon.hp, pokemon.maxHp = max(0, floor(hp)), max(1, floor(maxHp)) end
    end
    local model = sheetModel(mon, pokemon)
    local team
    if not st.wild and type(st.foeParty) == "table" and #st.foeParty > 1 then
      team = {}
      for index, member in ipairs(st.foeParty) do
        local alive = (tonumber(member.hp) or 0) > 0
        team[index] = not alive and "fainted" or (try(h.Summary.statusAilment, member) or 0) ~= 0 and "status" or "ok"
      end
    end
    model.team, model.kindLabel = team, T(st.wild and "WILD" or "TRAINER")
    return model
  end


  -- Which of the player's Pokémon to show: the one on a summary screen, under
  -- the PC box cursor or the party menu cursor; else the one battling; else
  -- the first of the party.
  local uiCache = {}
  local function ui(name)
    if uiCache[name] == nil then uiCache[name] = try(require, name) or false end
    return uiCache[name] or nil
  end
  local function boxMon(box)
    local session = box._session or game.session
    local party = type(session) == "table" and session.party or {}
    local target = box._actionTarget
    if box.mode == "action_menu" and type(target) == "table" and target.mon then return target.mon end
    local slot = tonumber(box.cursorSlot) or 0
    local mon
    if box.mode == "party_drawer" or (box.drawerOpen and box._actionSource == "party") then
      mon = party[tonumber(box.partyCursor) or 1]
    elseif slot >= 1 and slot <= 30 then
      local Storage = ui("src.core.game3.storage")
      local storage = Storage and try(Storage.ensure, session)
      local current = type(storage) == "table" and type(storage.boxes) == "table" and storage.boxes[storage.currentBox or 1]
      mon = type(current) == "table" and type(current.mons) == "table" and current.mons[slot] or nil
    elseif slot <= -1 and slot >= -6 then
      mon = party[-slot]
    end
    if type(mon) == "table" and mon ~= box.holdingMon then return mon end
    -- nothing under the cursor: the one being carried
    if type(box.holdingMon) == "table" then return box.holdingMon, "HELD" end
  end
  local function allyTarget()
    local h = host()
    local summary = ui("src.ui.game3.summary_menu")
    if summary and summary.open == true and not summary._enemyParty and type(summary._party) == "table" then
      local mon = summary._party[tonumber(summary._cursor) or 1]
      if type(mon) == "table" then return mon, "SUMMARY" end
    end
    local box = ui("src.ui.game3.box_storage_ui")
    if box and box.open == true then
      local mon, label = boxMon(box)
      if mon then return mon, label or "BOX" end
    end
    local menu = ui("src.ui.game3.party_menu")
    if menu and menu.open == true and type(menu._party) == "table" then
      local mon = menu._party[tonumber(menu.cursor) or 0]
      if type(mon) == "table" then return mon, "MENU" end
    end
    if h.Battle.isActive() then
      local st = h.Battle.getState()
      local battler, key = st and st.player, "player"
      if st and st.double and type(st.battlers) == "table" then
        for _, id in ipairs({ 0, 2 }) do
          local candidate = st.battlers[id]
          if candidate and candidate.mon and not (st.absent and st.absent[id])
              and (tonumber(candidate.mon.hp) or 0) > 0 then
            battler, key = candidate, id
            break
          end
        end
      end
      if battler and battler.mon then return battler.mon, "IN_BATTLE", battler, key end
    end
    local first = game.session.party[1]
    if type(first) == "table" then return first, "LEAD" end
  end
  local function allyModel()
    local h = host()
    local mon, label, battler, key = allyTarget()
    if not mon then return nil end
    local pokemon = monBasics(mon)
    if pokemon.egg then return { egg = true, label = T(label) } end
    if battler and h.Anim then
      -- in battle, follow the HP bar the game is animating
      local shown = try(h.Anim.shownBattler, key, battler) or battler
      if shown and shown.mon and shown.mon ~= mon then mon = shown.mon; pokemon = monBasics(mon) end
      local _, hp, maxHp = try(h.Anim.displayHpRatio, key, shown)
      if tonumber(hp) and tonumber(maxHp) then pokemon.hp, pokemon.maxHp = max(0, floor(hp)), max(1, floor(maxHp)) end
    end
    local model = sheetModel(mon, pokemon)
    model.kindLabel = T(label)
    model.showEvs, model.evTotal = true, 0
    for _, row in ipairs(model.rows) do model.evTotal = model.evTotal + (row.ev or 0) end
    return model
  end

  -- Slot odds within one encounter method, as the native picker weighs them.
  local POOLS = {
    { key = "land", first = 1, weights = { 20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1 } },
    { key = "water", method = "SURF", first = 1, weights = { 60, 30, 5, 4, 1 } },
    { key = "rocks", method = "ROCK", first = 1, weights = { 60, 30, 5, 4, 1 } },
    { key = "fishing", method = "OLD", first = 1, weights = { 70, 30 } },
    { key = "fishing", method = "GOOD", first = 3, weights = { 60, 20, 20 } },
    { key = "fishing", method = "SUPER", first = 6, weights = { 40, 40, 15, 4, 1 } },
  }
  local WILD_PER_PAGE, WILD_PAGE_SECONDS = 14, 6
  local wildCache
  local function areaName(mapId, def)
    local hoenn = try(function()
      return require("src.core.game3.profile").forSession(game.session).family == "rse"
    end)
    local name
    if hoenn then
      local entry = try(function() return require("src.ui.game3.rse.mapsec").entry(def.regionMapSectionId) end)
      name = entry and entry.name
    else
      local info = try(function()
        return require("src.import.gba.map_sections_extract").getInfo(def.regionMapSectionId, mapId, def.floorNum)
      end)
      name = info and info.resolved and info.rawName
    end
    if type(name) ~= "string" or not name:find("%S") then
      name = tostring(mapId):gsub("^%u%u_", ""):gsub("_", " ")
    end
    return nameCase(name), hoenn == true
  end
  local function wildRows(mapId)
    local h = host()
    local data = game.data or {}
    local def = data.maps and data.maps[mapId] or {}
    local area, hoenn = areaName(mapId, def)
    local source = data.gen3Encounters and data.gen3Encounters[mapId]
    local rows = {}
    for _, pool in ipairs(POOLS) do
      local encounter = source and source[pool.key]
      if encounter and (pool.key == "fishing" or (tonumber(encounter.rate) or 0) > 0) then
        local slots, count, total = encounter.slots or {}, #pool.weights, 100
        local variable = not hoenn and pool.key ~= "fishing"
        if variable then
          count, total = #slots, 0
          for index = 1, count do total = total + (pool.weights[index] or 1) end
        end
        local bySpecies = {}
        for index = 1, count do
          local slot = slots[pool.first + index - 1]
          local chance = variable and (pool.weights[index] or 1) * 100 / max(1, total) or pool.weights[index]
          if slot and tonumber(slot.species) and tonumber(slot.species) > 0 then
            local row = bySpecies[slot.species]
            if not row then
              row = { species = slot.species, chance = 0, minLevel = slot.minLevel, maxLevel = slot.maxLevel,
                method = pool.method and T(pool.method) or nil, order = #rows }
              bySpecies[slot.species] = row
              rows[#rows + 1] = row
            end
            row.chance = row.chance + chance
            row.minLevel = min(row.minLevel or slot.minLevel, slot.minLevel)
            row.maxLevel = max(row.maxLevel or slot.maxLevel, slot.maxLevel)
          end
        end
      end
    end
    for _, row in ipairs(rows) do
      row.name = nameCase(try(h.P.name, row.species) or "?")
      row.caught = try(h.Dex.isCaught, game.session.dex, row.species) == true
      local low, high = tonumber(row.minLevel), tonumber(row.maxLevel)
      row.levelText = T("LV") .. (low and (high and high ~= low and ("%d-%d"):format(low, high) or tostring(low)) or "?")
      row.chanceText = ("%d%%"):format(floor(row.chance + 0.5))
      row.pic = try(h.P.icon, row.species)
    end
    return rows, area
  end
  local wildState = { hits = {}, detail = nil, page = 1, pageUntil = 0 }
  local function wildModel(now)
    local mapId = game.session.map
    if not wildCache or wildCache.mapId ~= mapId or now - wildCache.at >= 2 or wildCache.language ~= option("language") then
      local rows, area = wildRows(mapId)
      wildCache = { mapId = mapId, at = now, rows = rows, area = area, language = option("language") }
    end
    local source = wildCache.rows
    local pages = max(1, math.ceil(#source / WILD_PER_PAGE))
    local page = floor(now / WILD_PAGE_SECONDS) % pages + 1
    -- a page chosen with the wheel stays for a while before the pages turn by themselves again
    if now < wildState.pageUntil then
      wildState.page = max(1, min(pages, wildState.page))
      page = wildState.page
    else
      wildState.page = page
    end
    local rows = {}
    for index = (page - 1) * WILD_PER_PAGE + 1, min(#source, page * WILD_PER_PAGE) do rows[#rows + 1] = source[index] end
    return { rows = rows, page = page, pages = pages, area = wildCache.area }
  end

  -- Items still on the current map: item balls on the ground and hidden items.
  -- Read from the imported event data and the save's flags; nothing is run.
  local ITEM_BALL_GFX = 92
  local function foundItemId(scripts, key)
    local value
    for _, command in ipairs(scripts and scripts[key] or {}) do
      if (command.op == "setvar" or command.op == "setorcopyvar") and (command.var or command[1]) == 0x8000 then
        value = command.value or command[2]
      elseif (command.op == "callstd" or command.op == "gotostd") and command.std == 1 then
        return value, true
      end
    end
    return nil, false
  end
  local function radarModel()
    local h = host()
    local mapId = game.session.map
    local def = game.data and game.data.maps and game.data.maps[mapId] or {}
    local model = { items = {}, area = areaName(mapId, def), visibleLeft = 0, visibleTotal = 0,
      hiddenLeft = 0, hiddenTotal = 0, message = T("NO_ITEMS") }
    local Space = require("src.core.game3.scripting.space")
    local Flags = require("src.core.game3.scripting.flags")
    local bundle = Space.bundle
    local event = bundle and bundle.events and bundle.events[mapId]
    if not event then
      model.message = T("NO_DATA")
      return model
    end
    local store = try(Space.getStore) or game.session
    local function taken(flag)
      flag = tonumber(flag)
      return flag ~= nil and flag ~= 0 and flag ~= 65535 and Flags.getFlag(store, nil, flag) == true
    end
    local px, py = tonumber(game.session.x) or 0, tonumber(game.session.y) or 0
    local Player, Map = try(require, "src.core.game3.player"), try(require, "src.core.game3.map")
    if Player and Map and Map.current == mapId and tonumber(Player.cellX) then px, py = Player.cellX, Player.cellY end
    local dirs = T("DIRS")
    local function add(x, y, itemId, hidden)
      local dx, dy = (tonumber(x) or 0) - px, (tonumber(y) or 0) - py
      local steps = math.abs(dx) + math.abs(dy)
      local where = T("HERE")
      if steps > 0 then
        -- eight compass points, north up (map y grows southward)
        local sector = floor((math.atan2(dx, -dy) / (math.pi / 4)) + 0.5) % 8
        where = steps .. " " .. dirs[sector + 1]
      end
      local label = itemId and try(h.Items.displayName, itemId)
      model.items[#model.items + 1] = { dx = dx, dy = dy, steps = steps, hidden = hidden, where = where,
        name = label and nameCase(label) or "?" }
    end
    for _, obj in ipairs(event.objects or {}) do
      if not obj.cloneTarget then
        local itemId, found = foundItemId(bundle.scripts, obj.scriptKey)
        if found or (obj.graphicsId or obj.graphics) == ITEM_BALL_GFX and obj.scriptKey == nil then
          model.visibleTotal = model.visibleTotal + 1
          if not taken(obj.flag) then
            model.visibleLeft = model.visibleLeft + 1
            add(obj.x, obj.y, itemId, false)
          end
        end
      end
    end
    local hiddenBase = Flags.IDS and Flags.IDS.FLAG_HIDDEN_ITEMS_START or 0x3E8
    for _, bg in ipairs(event.bgEvents or {}) do
      if bg.type == "hidden_item" then
        local flag = bg.flag or bg.hiddenItemId and (hiddenBase + bg.hiddenItemId)
        model.hiddenTotal = model.hiddenTotal + 1
        if not taken(flag) then
          model.hiddenLeft = model.hiddenLeft + 1
          add(bg.x, bg.y, bg.item, true)
        end
      end
    end
    table.sort(model.items, function(a, b)
      if a.steps ~= b.steps then return a.steps < b.steps end
      return a.name < b.name
    end)
    if #model.items == 0 and model.visibleTotal + model.hiddenTotal > 0 then model.message = T("ALL_FOUND") end
    return model
  end

  ---------------------------------------------------------------------------
  -- Panels and their windows
  ---------------------------------------------------------------------------
  local Windows = load_("windows.lua", mod)
  local KINDS = { wild = true, party = true, enemy = true, radar = true, ally = true }
  local DEFAULTS = { "wild", "party", "enemy", "radar", "ally" }
  local HEADINGS = { enemy = "OPPONENT", party = "PARTY", wild = "AREA", radar = "RADAR", ally = "ALLY" }
  local canvases, logged = {}, {}
  local nextPaint, paintKey, suspended, windowSignature = 0, nil, false, nil

  local function inGame()
    return game ~= nil and game.generation == 3 and type(game.session) == "table"
      and game.session.map ~= nil and type(game.session.party) == "table"
  end
  local function count()
    if suspended or not game or not Windows.usable() then return 0 end
    return max(0, min(5, floor(tonumber(option("panels")) or 0)))
  end
  local function kinds(n, battling)
    local out, hasEnemy = {}, false
    for index = 1, n do
      local kind = option("panel_" .. index)
      out[index] = KINDS[kind] and kind or DEFAULTS[index]
      hasEnemy = hasEnemy or out[index] == "enemy"
    end
    if n > 0 and battling and not hasEnemy and option("battle_sheet") ~= false then out[1] = "enemy" end
    return out
  end
  ---------------------------------------------------------------------------
  -- Tools: field moves and key items, used with one click
  ---------------------------------------------------------------------------
  local FIELD = { "CUT", "SURF", "STRENGTH", "FLASH", "ROCK_SMASH", "WATERFALL", "DIG", "TELEPORT", "SWEET_SCENT" }
  local ITEM_BIKE, ITEM_SEEKER, ITEM_ROPE = 360, 362, 85
  local RODS, REPELS = { 262, 263, 264 }, { 86, 83, 84 }
  -- Steps left on the repel in use: the game's own counter, as its encounter check reads it.
  local function repelLeft()
    local ok, Sem = pcall(require, "src.core.game3.field_semantics")
    local value = ok and type(Sem) == "table" and Sem.getVar and try(Sem.getVar, game.session, "repelSteps")
    return tonumber(value) or tonumber(game.session.repelSteps) or 0
  end
  local toolState = { hits = {}, flash = nil }
  local AUTO_KEY = "autorepel"
  toolState.autoRepel = mod.cache and mod.cache.read and mod.cache:read(AUTO_KEY) == "1" or false
  local function toolHost()
    local h = host()
    if h.toolsReady == nil then
      local function opt(name) local ok, m = pcall(require, name) return ok and m or nil end
      h.World, h.FM, h.Bag = opt("src.world.game3.WorldAPI"), opt("src.core.game3.field_moves"), opt("src.core.game3.bag")
      h.ItemUse, h.VsSeeker, h.Message = opt("src.core.game3.item_use"), opt("src.core.game3.vs_seeker"), opt("src.ui.game3.message")
      h.Player = opt("src.core.game3.player")
      h.BagChrome = opt("src.ui.game3.bag_chrome")
      h.toolsReady = h.World ~= nil and h.Bag ~= nil and h.ItemUse ~= nil
    end
    return h
  end
  local function bagCount(h, id)
    local bag = game.session.bag
    if not bag then return 0 end
    local n = try(h.Bag.get, bag, id)
    if type(n) == "table" then n = n.qty or n.quantity or n.count end
    if tonumber(n) then return tonumber(n) end
    return try(h.Bag.has, bag, id, 1) == true and 1 or 0
  end
  local function itemLabel(h, id)
    local label = try(h.Items.displayName, id)
    return label and nameCase(label) or ("#" .. id)
  end
  local itemPics = {}
  local function itemPic(h, id)
    if itemPics[id] == nil then
      local image = h.BagChrome and h.BagChrome.iconImage and try(h.BagChrome.iconImage, id)
      itemPics[id] = image and { image = image } or false
    end
    return itemPics[id] or nil
  end
  local function toolsModel()
    local h = toolHost()
    local model = { tools = {}, flash = toolState.flash }
    if not h.toolsReady then return model end
    toolState.world = toolState.world or h.World.new(game, "trainer_lens")
    local battling = try(h.Battle.isActive) == true
    local available, why = {}, nil
    if not battling then
      local list, reason = try(toolState.world.availableFieldActions, toolState.world)
      why = reason
      for _, action in ipairs(type(list) == "table" and list or {}) do available[action.id] = action end
    end
    local free = not battling and why == nil
    model.note = battling and T("IN_BATTLE_TOOLS") or (why and T("BUSY")) or T("TOOLS_HINT")
    local repel = repelLeft()
    if repel > 0 and free then model.note = T("REPEL_ON"):format(repel) end
    local tools, session = model.tools, game.session
    if bagCount(h, ITEM_BIKE) > 0 then
      local riding = h.Player and h.Player.biking == true
      tools[#tools + 1] = { id = "bicycle", action = "bicycle", label = T(riding and "BIKE_OFF" or "BIKE"), on = riding, pic = itemPic(h, ITEM_BIKE),
        ready = available.bicycle ~= nil }
    end
    for _, move in ipairs(FIELD) do
      local user = h.FM and try(h.FM.partyMoveUser, session.party, move, { game = game })
      if type(user) == "table" then
        local id = move:lower()
        local moveId = h.FM.MOVES and h.FM.MOVES[move]
        local label = moveId and try(h.Moves.displayName, moveId) or move:gsub("_", " ")
        local nick = user.nickname
        tools[#tools + 1] = { id = id, action = id, label = nameCase(label), pic = try(h.P.monIcon, user),
          sub = nameCase((nick and nick ~= "") and nick or try(h.P.name, h.P.speciesOf(user)) or ""),
          ready = available[id] ~= nil }
      end
    end
    local canFish = free and h.ItemUse.canFish and try(h.ItemUse.canFish) == true
    for _, id in ipairs(RODS) do
      if bagCount(h, id) > 0 then tools[#tools + 1] = { id = "item" .. id, item = id, label = itemLabel(h, id), ready = canFish, pic = itemPic(h, id) } end
    end
    if bagCount(h, ITEM_SEEKER) > 0 and h.VsSeeker then
      local charge = tonumber(try(h.VsSeeker.getBattery, session)) or 0
      local full = tonumber(h.VsSeeker.MAX_CHARGE) or 100
      tools[#tools + 1] = { id = "item" .. ITEM_SEEKER, item = ITEM_SEEKER, label = itemLabel(h, ITEM_SEEKER), pic = itemPic(h, ITEM_SEEKER),
        sub = charge >= full and T("CHARGED") or (T("CHARGE") .. " " .. charge .. "/" .. full), ready = free and charge >= full }
    end
    local anyRepel = false
    for _, id in ipairs(REPELS) do anyRepel = anyRepel or bagCount(h, id) > 0 end
    if anyRepel or toolState.autoRepel then
      tools[#tools + 1] = { id = "autorepel", toggle = "autorepel", label = T("AUTO_REPEL"), on = toolState.autoRepel,
        sub = T(toolState.autoRepel and "AUTO_ON" or "AUTO_OFF"), ready = true, pic = itemPic(h, REPELS[1]) }
    end
    for _, id in ipairs(REPELS) do
      local n = bagCount(h, id)
      if n > 0 then tools[#tools + 1] = { id = "item" .. id, item = id, label = itemLabel(h, id), badge = "x" .. n, ready = free and repel <= 0, pic = itemPic(h, id) } end
    end
    local ropes = bagCount(h, ITEM_ROPE)
    if ropes > 0 then tools[#tools + 1] = { id = "item" .. ITEM_ROPE, item = ITEM_ROPE, label = itemLabel(h, ITEM_ROPE), badge = "x" .. ropes, ready = free, pic = itemPic(h, ITEM_ROPE) } end
    -- only what can be used right now is shown
    local usable = {}
    for _, tool in ipairs(tools) do
      if tool.ready then usable[#usable + 1] = tool end
    end
    model.tools = usable
    return model
  end
  local function say(h, text)
    if text and text ~= "" and h.Message and h.Message.show then
      pcall(h.Message.show, text, function() pcall(h.Message.close) end)
    end
  end
  -- A click on the tools view: use what is under it, and say so on the panel.
  local function toolClick(x, y)
    if not inGame() then return end
    for _, hit in ipairs(toolState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        local h, tool = toolHost(), hit.tool
        if tool.toggle == "autorepel" then
          toolState.autoRepel = not toolState.autoRepel
          if mod.cache and mod.cache.write then mod.cache:write(AUTO_KEY, toolState.autoRepel and "1" or "0") end
          return
        end
        local ok, text
        if tool.action then
          ok = try(toolState.world.useFieldAction, toolState.world, tool.action) == true
        else
          local used, _, message = try(h.ItemUse.useField, game.session, game.session.bag, tool.item)
          ok, text = used == true, message
          say(h, text)
        end
        toolState.flash = { text = ok and T("USED"):format(tool.label) or T("NOT_HERE"), untilAt = love.timer.getTime() + 2.5 }
        return
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Trainer and progress
  ---------------------------------------------------------------------------
  local BADGE_NAMES = { "Boulder", "Cascade", "Thunder", "Rainbow", "Soul", "Marsh", "Volcano", "Earth" }
  local STAT_ORDER = { 5, 7, 8, 9, 11, 12, 13, 14, 15 }
  -- The badge pictures of the game's own trainer card: one 128x16 sheet.
  local badgePics
  local function badgeSheet()
    if badgePics ~= nil then return badgePics or nil end
    badgePics = false
    pcall(function()
      local CacheFs = require("src.import.CacheFs")
      -- read through the game's cache layer, never by path into the cache folder
      local path = "trainer_card/badges.rgba"
      local raw = (CacheFs.readActive and CacheFs.readActive(path)) or (CacheFs.read and CacheFs.read(path))
      if raw and #raw < 128 * 16 * 4 then raw = nil end
      if not raw then return end
      local image = G.newImage(love.image.newImageData(128, 16, "rgba8", raw))
      image:setFilter("nearest", "nearest")
      local pics = {}
      for index = 1, 8 do
        pics[index] = { image = image, w = 16, h = 16, quads = { [0] = G.newQuad((index - 1) * 16, 0, 16, 16, 128, 16) } }
      end
      badgePics = pics
    end)
    return badgePics or nil
  end
  local function trainerModel()
    local h, s = host(), game.session
    local model = { name = clean(tostring(s.name or s.playerName or "?")), badges = {}, badgeCount = 0, badgeNames = BADGE_NAMES,
      id = ("%05d"):format((tonumber(s.trainerId or s.id) or 0) % 65536), dex = {}, stats = {} }
    local money = max(0, floor(tonumber(s.money) or 0))
    model.money = "$ " .. tostring(money):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    local pt = s.playtime or s.playTime or {}
    model.time = ("%d:%02d"):format(tonumber(pt.hours) or 0, tonumber(pt.minutes) or 0)
    -- the trainer card knows every way a save may record a badge
    local okCard, Card = pcall(require, "src.ui.game3.trainer_card")
    if okCard and type(Card) == "table" and Card.isBadgeUnlocked then
      local keep = Card._session
      Card._session = s
      for index = 1, 8 do
        model.badges[index] = try(Card.isBadgeUnlocked, index) == true
        if model.badges[index] then model.badgeCount = model.badgeCount + 1 end
      end
      Card._session = keep
    end
    model.badgePics = badgeSheet()
    local dex = s.dex
    if dex and h.Dex and h.Dex.countCaught then
      local kanto = tonumber(h.Dex.KANTO_MAX) or 151
      local seen, caught = try(h.Dex.countSeen, dex, "kanto") or 0, try(h.Dex.countCaught, dex, "kanto") or 0
      model.dex[1] = { label = T("SEEN"), have = seen, total = kanto, fill = "seen" }
      model.dex[2] = { label = T("CAUGHT"), have = caught, total = kanto }
      local all = try(h.Dex.countCaught, dex, "national") or 0
      if all > caught then
        model.dex[3] = { label = T("CAUGHT") .. " (" .. T("NATIONAL") .. ")", have = all, total = tonumber(h.Dex.NATIONAL_MAX) or 386 }
      end
    end
    local stats = type(s.gameStats) == "table" and s.gameStats or {}
    for _, id in ipairs(STAT_ORDER) do
      local value = tonumber(stats[id])
      if value and value > 0 then model.stats[#model.stats + 1] = { label = T("STAT_NAMES")[id], value = tostring(floor(value)) } end
    end
    return model
  end

  -- Every area with wild Pokémon, and how many of its species are caught.
  local areaList
  local progressState = { page = 1, fits = 12 }
  local function progressModel()
    local h, s = host(), game.session
    local data = game.data or {}
    if not areaList then
      local byName, list = {}, {}
      for mapId, source in pairs(data.gen3Encounters or {}) do
        local def = data.maps and data.maps[mapId]
        if def and type(source) == "table" then
          local name = areaName(mapId, def)
          local area = byName[name]
          if not area then
            area = { name = name, species = {}, count = 0, maps = {} }
            byName[name] = area
            list[#list + 1] = area
          end
          area.maps[mapId] = true
          for _, pool in ipairs(POOLS) do
            local encounter = source[pool.key]
            for _, slot in ipairs(type(encounter) == "table" and encounter.slots or {}) do
              local species = tonumber(slot.species)
              if species and species > 0 and not area.species[species] then
                area.species[species] = true
                area.count = area.count + 1
              end
            end
          end
        end
      end
      table.sort(list, function(a, b) return a.name < b.name end)
      areaList = list
    end
    local model = { areas = {}, done = 0, here = { name = "", caught = 0, total = 0, items = 0, itemsTotal = 0 } }
    local current = s.map
    for _, area in ipairs(areaList) do
      if area.count > 0 then
        local caught = 0
        for species in pairs(area.species) do
          if try(h.Dex.isCaught, s.dex, species) == true then caught = caught + 1 end
        end
        local row = { name = area.name, caught = caught, total = area.count, current = area.maps[current] == true }
        if caught >= area.count then model.done = model.done + 1 end
        if row.current then model.here.caught, model.here.total = caught, area.count end
        model.areas[#model.areas + 1] = row
      end
    end
    -- where the player is first, then the ones closest to complete, the finished ones last
    table.sort(model.areas, function(a, b)
      if a.current ~= b.current then return a.current end
      local da, db = a.caught >= a.total, b.caught >= b.total
      if da ~= db then return db end
      local ra, rb = a.caught / a.total, b.caught / b.total
      if ra ~= rb then return ra > rb end
      return a.name < b.name
    end)
    local def = data.maps and data.maps[current] or {}
    model.here.name = areaName(current, def)
    local radar = try(radarModel)
    if radar then
      model.here.itemsTotal = (radar.visibleTotal or 0) + (radar.hiddenTotal or 0)
      model.here.items = model.here.itemsTotal - (radar.visibleLeft or 0) - (radar.hiddenLeft or 0)
    end
    model.pages = max(1, math.ceil(#model.areas / max(1, progressState.fits)))
    progressState.page = max(1, min(model.pages, progressState.page))
    model.page = progressState.page
    return model
  end

  ---------------------------------------------------------------------------
  -- Maps
  ---------------------------------------------------------------------------
  local mapState = { }
  local function mapHost()
    local h = host()
    if h.mapReady == nil then
      local function opt(name) local ok, m = pcall(require, name) return ok and m or nil end
      h.Collision, h.MapMod, h.Objects = opt("src.core.game3.collision"), opt("src.core.game3.map"), opt("src.core.game3.objects")
      h.Conn, h.Player = opt("src.core.game3.connections"), h.Player or opt("src.core.game3.player")
      h.Tiles = opt("src.core.game3.tileset_native")
      h.RegionExtract, h.RegionPos, h.RegionGpu = opt("src.import.gba.region_map_extract"), opt("src.ui.game3.region_map_position"),
        opt("src.ui.game3.region_map_gpu")
      h.mapReady = h.Collision ~= nil and h.Conn ~= nil and h.Player ~= nil
    end
    return h
  end
  local EXIT_MARK = { north = "^", south = "v", west = "<", east = ">" }
  -- The area drawn with the game's own tiles, kept as one picture and redrawn
  -- only when the map, its tiles or something on it (a cut tree) changes.
  local function overrideMark(layout)
    local n, sum = 0, 0
    for _, cell in pairs(type(layout.overrides) == "table" and layout.overrides or {}) do
      n, sum = n + 1, sum + (tonumber(type(cell) == "table" and cell.mid) or 0)
    end
    return n .. ":" .. sum
  end
  local function nativePicture(h, def, now)
    local layout = def.midLayout
    if not (h.Tiles and type(layout) == "table" and layout.midAt) then return nil end
    local width, height = tonumber(layout.trueWidth or layout.width), tonumber(layout.trueHeight or layout.height)
    if not width or not height or width < 1 or height < 1 or width * height > 40000 then return nil end
    local atlas = try(h.Tiles.get, def.pair or layout.pair)
    if not (atlas and atlas.image) then return nil end
    local art = mapState.art
    local mark = overrideMark(layout)
    if art and art.layout == layout and art.cells == layout.cells and art.texture == atlas.image and art.mark == mark then return art end
    -- at most one rebuild a second, however fast things change
    if art and art.layout == layout and now < (art.builtAt or 0) + 1 then return art end
    local scale = min(1, 4096 / (width * 16), 4096 / (height * 16))
    local canvas
    local ok = pcall(function()
      local under = G.newSpriteBatch(atlas.image, width * height, "static")
      local over = atlas.layered and atlas.overImage and G.newSpriteBatch(atlas.overImage, width * height, "static") or nil
      for y = 0, height - 1 do
        for x = 0, width - 1 do
          local slot = h.Tiles.slotFor(atlas, layout:midAt(x, y))
          if slot then
            under:add(h.Tiles.quad(atlas, slot), x * 16, y * 16)
            if over then over:add(h.Tiles.overQuad(atlas, slot), x * 16, y * 16) end
          end
        end
      end
      canvas = G.newCanvas(max(1, floor(width * 16 * scale)), max(1, floor(height * 16 * scale)), { dpiscale = 1 })
      G.push("all")
      G.setCanvas(canvas)
      G.origin(); G.setScissor(); G.setShader(); G.setBlendMode("alpha"); G.setColor(1, 1, 1, 1)
      G.clear(0, 0, 0, 1)
      G.scale(scale, scale)
      G.draw(under)
      if over then G.draw(over) end
      G.pop()
      under:release()
      if over then over:release() end
      canvas:setFilter("linear", "nearest")
    end)
    if not ok or not canvas then return nil end
    if art and art.canvas then pcall(art.canvas.release, art.canvas) end
    art = { canvas = canvas, layout = layout, cells = layout.cells, texture = atlas.image, mark = mark, builtAt = now,
      width = width, height = height }
    mapState.art = art
    return art
  end
  -- The current map as one pixel per cell, redrawn now and then: trees get cut and rocks broken.
  local function localMapModel(now)
    local h = mapHost()
    if not h.mapReady then return nil end
    local mapId = (h.MapMod and h.MapMod.current) or game.session.map
    local def = game.data and game.data.maps and game.data.maps[mapId]
    if not def then return nil end
    local width, height = h.Conn.sizeOf(def)
    width, height = floor(tonumber(width) or 0), floor(tonumber(height) or 0)
    if width < 1 or height < 1 or width > 400 or height > 400 then return nil end
    local cache = mapState.cache
    if not cache or cache.id ~= mapId or now >= cache.untilAt then
      local C = h.Collision
      local data = love.image.newImageData(width, height)
      local T2 = UI.terrain
      for y = 0, height - 1 do
        for x = 0, width - 1 do
          local c = T2.blocked
          if try(C.warpAt, x, y) ~= nil then c = T2.warp
          elseif try(C.isWater, x, y) == true then c = T2.water
          elseif try(C.isGrass, x, y) == true then c = T2.grass
          elseif try(C.isWalkable, x, y) == true then c = T2.walk end
          data:setPixel(x, y, c[1], c[2], c[3], 1)
        end
      end
      if cache and cache.image then pcall(cache.image.release, cache.image) end
      local image = G.newImage(data)
      image:setFilter("nearest", "nearest")
      local exits = {}
      for _, c in ipairs(try(h.Conn.each, def) or {}) do
        local other = game.data.maps[c.map]
        if other and EXIT_MARK[c.dir] then exits[#exits + 1] = { mark = EXIT_MARK[c.dir], name = (areaName(c.map, other)) } end
      end
      cache = { id = mapId, image = image, exits = exits, name = (areaName(mapId, def)), untilAt = now + 2 }
      mapState.cache = cache
    end
    local P = h.Player
    local model = { image = cache.image, width = width, height = height, name = cache.name, exits = cache.exits, markers = {},
      player = { x = tonumber(P.cellX) or 0, y = tonumber(P.cellY) or 0, facing = P.facing } }
    local art = nativePicture(h, def, now)
    if art then model.image, model.native, model.width, model.height = art.canvas, true, art.width, art.height end
    local seen = {}
    local radar = try(radarModel)
    for _, item in ipairs(radar and radar.items or {}) do
      local x, y = model.player.x + item.dx, model.player.y + item.dy
      seen[x .. ":" .. y] = true
      model.markers[#model.markers + 1] = { kind = item.hidden and "hidden" or "item", x = x, y = y }
    end
    local O = h.Objects
    for _, id in ipairs(O and O._order or {}) do
      local eo = O._byId and O._byId[id]
      if eo and eo.visible and not eo.hidden and eo.cellX and not seen[eo.cellX .. ":" .. eo.cellY] then
        local d = eo.def or {}
        local trainer = (tonumber(d.trainerType) or 0) > 0 or (d.trainerType ~= nil and d.trainerType ~= 0 and d.trainerType ~= "TRAINER_TYPE_NONE")
        if not d.item then model.markers[#model.markers + 1] = { kind = trainer and "trainer" or "npc", x = eo.cellX, y = eo.cellY } end
      end
    end
    return model
  end

  -- The region: every route and town reached from here through the maps' own
  -- edges, laid side by side the way they join. Built once per group of maps.
  local REGION_IMAGES = { [0] = "kanto_map", "sevii123_map", "sevii45_map", "sevii67_map" }
  local REGION_NAMES = { [0] = "Kanto", "Sevii 1-3", "Sevii 4-5", "Sevii 6-7" }
  -- The Town Map as the game draws it, with the player's place on it.
  local function townMapModel()
    local h = mapHost()
    if not (h.RegionExtract and h.RegionPos and h.RegionGpu) then return nil end
    local maps, s = game.data and game.data.maps or {}, game.session
    local def = maps[s.map]
    if not (def and def.regionMapSectionId) then return nil end
    if not mapState.regionReady then
      if not pcall(h.RegionExtract.ensureGenerated) then return nil end
      mapState.regionReady = true
    end
    local okRegion, region = pcall(h.RegionPos.regionFor, def.regionMapSectionId, h.RegionExtract.LAYOUTS)
    if not okRegion or not REGION_IMAGES[region] then return nil end
    local okImage, image = pcall(h.RegionGpu.image, REGION_IMAGES[region])
    if not okImage or not image then return nil end
    local found, cx, cy = pcall(h.RegionPos.playerCell, {
      map = s.map, x = s.x, y = s.y, escapeWarp = s.escapeWarp, dynamicWarp = s.dynamicWarp,
      def = function(id) return maps[id] end,
    }, h.RegionExtract.GEOMETRY)
    mapState.regionQuads = mapState.regionQuads or {}
    local quad = mapState.regionQuads[image]
    if not quad then
      -- without the margin the game keeps around its own map screen
      quad = G.newQuad(24, 16, 192, 144, image:getDimensions())
      mapState.regionQuads[image] = quad
    end
    return { town = true, image = image, quad = quad, width = 192, height = 144,
      title = REGION_NAMES[region] .. "  ·  " .. (areaName(s.map, def)),
      playerX = found and tonumber(cx) and cx * 8 + 12 or nil, playerY = found and tonumber(cy) and cy * 8 + 20 or nil }
  end
  local function regionModel()
    local town = townMapModel()
    if town then return town end
    local h = mapHost()
    if not h.mapReady then return nil end
    local maps = game.data and game.data.maps or {}
    local mapId = (h.MapMod and h.MapMod.current) or game.session.map
    local def = maps[mapId]
    local outdoor = def and #(try(h.Conn.each, def) or {}) > 0
    if outdoor then mapState.lastOutdoor = mapId end
    local anchor = mapState.lastOutdoor
    if not anchor or not maps[anchor] then return nil end
    local layout = mapState.layout
    if not layout or not layout.placed[anchor] then
      local placed, order, queue = {}, {}, { anchor }
      local aw, ah = h.Conn.sizeOf(maps[anchor])
      placed[anchor] = { x = 0, y = 0, w = aw, h = ah }
      while #queue > 0 and #order < 200 do
        local id = table.remove(queue, 1)
        order[#order + 1] = id
        local at = placed[id]
        for _, c in ipairs(try(h.Conn.each, maps[id]) or {}) do
          local other = maps[c.map]
          if other and not placed[c.map] then
            local w2, h2 = h.Conn.sizeOf(other)
            local x, y
            if c.dir == "north" then x, y = at.x + c.offset, at.y - h2
            elseif c.dir == "south" then x, y = at.x + c.offset, at.y + at.h
            elseif c.dir == "west" then x, y = at.x - w2, at.y + c.offset
            elseif c.dir == "east" then x, y = at.x + at.w, at.y + c.offset end
            if x and w2 > 0 and h2 > 0 then
              placed[c.map] = { x = x, y = y, w = w2, h = h2 }
              queue[#queue + 1] = c.map
            end
          end
        end
      end
      layout = { placed = placed, order = order }
      mapState.layout = layout
    end
    local model = { areas = {}, minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
    local encounters = game.data.gen3Encounters or {}
    local dex = game.session.dex
    for _, id in ipairs(layout.order) do
      local at = layout.placed[id]
      local source = encounters[id]
      local total, caught, counted = 0, 0, {}
      for _, pool in ipairs(POOLS) do
        local encounter = type(source) == "table" and source[pool.key]
        for _, slot in ipairs(type(encounter) == "table" and encounter.slots or {}) do
          local species = tonumber(slot.species)
          if species and species > 0 and not counted[species] then
            counted[species] = true
            total = total + 1
            if try(host().Dex.isCaught, dex, species) == true then caught = caught + 1 end
          end
        end
      end
      model.areas[#model.areas + 1] = { x = at.x, y = at.y, w = at.w, h = at.h, name = (areaName(id, maps[id])),
        town = total == 0, ratio = total > 0 and caught / total or nil, complete = total > 0 and caught >= total,
        current = id == anchor }
      model.minX, model.minY = min(model.minX, at.x), min(model.minY, at.y)
      model.maxX, model.maxY = max(model.maxX, at.x + at.w), max(model.maxY, at.y + at.h)
    end
    local hereName = areaName(anchor, maps[anchor])
    if outdoor then
      local at, P = layout.placed[anchor], h.Player
      model.player = { x = at.x + (tonumber(P.cellX) or 0) + 0.5, y = at.y + (tonumber(P.cellY) or 0) + 0.5, facing = P.facing }
      model.title = hereName
    else
      model.title = T("INSIDE"):format((areaName(mapId, def or {})), hereName)
    end
    return model
  end

  ---------------------------------------------------------------------------
  -- Bag, moves, Day-Care, encounter counter
  ---------------------------------------------------------------------------
  local POCKET_KEYS = { "ITEMS", "KEY_ITEMS", "POKE_BALLS", "TM_CASE", "BERRY_POUCH" }
  local bagState = { pocket = 1, page = 1, fits = 10, hits = {}, selected = nil }
  local function bagModel()
    local h = toolHost()
    local model = { pockets = {}, rows = {}, pocket = bagState.pocket, page = 1, pages = 1 }
    local bag = game.session.bag
    for index, key in ipairs(POCKET_KEYS) do
      local rows = h.Bag and bag and try(h.Bag.listPocket, bag, key) or {}
      model.pockets[index] = { label = T("POCKETS")[key], count = #rows }
      if index == bagState.pocket then
        for at, row in ipairs(rows) do
          model.rows[at] = { id = row.id, qty = row.qty, name = nameCase(clean(row.name or "?")), pic = itemPic(h, row.id),
            description = clean(row.description or "") }
        end
      end
    end
    model.pages = max(1, math.ceil(#model.rows / max(1, bagState.fits)))
    bagState.page = max(1, min(model.pages, bagState.page))
    model.page = bagState.page
    model.selectedIndex = bagState.selected
    model.selected = bagState.selected and model.rows[bagState.selected] or nil
    return model
  end
  local function bagClick(x, y)
    for _, hit in ipairs(bagState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        if hit.page then bagState.page = max(1, bagState.page + hit.page)
        elseif hit.pocket then bagState.pocket, bagState.page, bagState.selected = hit.pocket, 1, nil
        else bagState.selected = bagState.selected ~= hit.row and hit.row or nil end
        return
      end
    end
  end

  local function movesModel()
    local h = host()
    local mon = allyTarget()
    if type(mon) ~= "table" then return nil end
    local basics = monBasics(mon)
    if basics.egg then return nil end
    local model = { title = T("MOVES_OF"):format(basics.name), moves = {} }
    local st = try(h.Battle.isActive) == true and try(h.Battle.getState) or nil
    local foe = st and st.enemy and st.enemy.mon
    local foeTypes = foe and try(h.P.types, h.P.speciesOf(foe)) or nil
    for slot = 1, 4 do
      local id = type(mon.moves) == "table" and mon.moves[slot]
      if type(id) == "table" then id = id.id end
      if id and id ~= 0 and id ~= "" then
        local row = try(h.Moves.get, id) or {}
        local name = try(h.Moves.displayName, id) or tostring(id)
        local power = tonumber(row.power) or 0
        local pp = type(mon.pp) == "table" and tonumber(mon.pp[slot])
        local maxPp = type(mon.maxPp) == "table" and tonumber(mon.maxPp[slot]) or tonumber(row.pp)
        local move = { name = nameCase(name), type = h.typeName[row.type], power = power > 1 and power or nil,
          accuracy = (tonumber(row.accuracy) or 0) > 0 and (row.accuracy .. "%") or nil,
          pp = pp and ("PP " .. pp .. (maxPp and ("/" .. maxPp) or "")) or nil,
          category = power <= 0 and T("STATUS_MOVE") or (h.Types.PHYSICAL and h.Types.PHYSICAL[row.type]) and T("PHYSICAL") or T("SPECIAL") }
        local text = try(h.Summary.moveDescription, id, name)
        if type(text) == "string" and text ~= "---" then move.description = clean(text) end
        if foeTypes and power > 0 and h.Types.effectiveness then
          local k = tonumber(try(h.Types.effectiveness, row.type, foeTypes[1], foeTypes[2]))
          if k and k ~= 100 then
            move.effect = { label = k == 0 and "x0" or ("x" .. (k / 100)), good = k > 100, bad = k < 100 and k > 0 }
          end
        end
        model.moves[slot] = move
      end
    end
    return model
  end

  local function daycareModel()
    local h = host()
    local ok, DC = pcall(require, "src.core.game3.daycare")
    if not ok or type(DC) ~= "table" then return nil end
    local function entry(mon, steps)
      local basics = monBasics(mon)
      local gained = tonumber(try(DC.levelsGained, mon, steps)) or 0
      return { name = basics.name, pic = try(h.P.monIcon, mon), gained = gained,
        levels = T("LEVELS"):format(basics.level, basics.level + gained, gained), steps = T("STEPS_N"):format(steps),
        cost = T("COST"):format(tonumber(try(DC.cost, mon, steps)) or 100) }
    end
    local model = { places = {} }
    local dc = try(DC.stateOf, game.session)
    local main = { name = T("DAYCARE"), mons = {}, egg = dc and try(DC.isEggPending, dc) == true }
    for index = 1, 2 do
      local mon = dc and try(DC.mon, dc, index)
      if type(mon) == "table" and (tonumber(try(h.P.speciesOf, mon)) or 0) > 0 then
        main.mons[#main.mons + 1] = entry(mon, tonumber(type(dc.steps) == "table" and dc.steps[index]) or 0)
      end
    end
    model.places[1] = main
    local r5 = try(DC.route5Of, game.session)
    local single = { name = T("DAYCARE_R5"), mons = {} }
    local mon = r5 and (r5.mon or r5[1])
    if type(mon) == "table" and (tonumber(try(h.P.speciesOf, mon)) or 0) > 0 then
      single.mons[1] = entry(mon, tonumber(r5.steps) or 0)
    end
    model.places[2] = single
    return model
  end

  -- Wild encounters since the last reset, kept between sessions.
  local COUNTER_KEY = "counter/v1"
  local counter
  local function counterLoad()
    if counter then return counter end
    counter = { total = 0, since = 0, shinies = 0, species = {}, hits = {} }
    local saved = mod.cache and mod.cache.read and mod.cache:read(COUNTER_KEY)
    for key, value in tostring(saved or ""):gmatch("([%w]+)=(%d+)") do
      local species = tonumber(key:match("^s(%d+)$"))
      if species then counter.species[species] = tonumber(value)
      elseif key == "total" or key == "since" or key == "shinies" then counter[key] = tonumber(value) end
    end
    return counter
  end
  local function counterSave()
    local parts = { "total=" .. counter.total, "since=" .. counter.since, "shinies=" .. counter.shinies }
    for species, n in pairs(counter.species) do parts[#parts + 1] = "s" .. species .. "=" .. n end
    if mod.cache and mod.cache.write then mod.cache:write(COUNTER_KEY, table.concat(parts, "\n")) end
  end
  -- Called every frame: a wild battle that has just begun is one more encounter.
  local function counterWatch()
    if not inGame() then return end
    local h = host()
    local st = try(h.Battle.isActive) == true and try(h.Battle.getState) or nil
    local c = counterLoad()
    if not st then c.battle = nil return end
    if c.battle == st then return end
    local foe = st.wild and st.enemy and st.enemy.mon
    if not foe then return end
    c.battle = st
    local species = tonumber(try(h.P.speciesOf, foe))
    c.total, c.since = c.total + 1, c.since + 1
    if species then c.species[species] = (c.species[species] or 0) + 1 end
    if try(h.P.isShiny, foe) == true then
      c.shinies, c.since = c.shinies + 1, 0
      if c.notify then c.notify(T("N_SHINY"), nameCase(try(h.P.name, species) or ""), "gold") end
    end
    counterSave()
  end
  local function counterModel()
    local h, c = host(), counterLoad()
    local model = { total = c.total, since = c.since, shinies = c.shinies, rows = {}, top = 1 }
    local luck = (1 - (8191 / 8192) ^ c.since) * 100
    model.luck, model.luckHigh = ("%.1f%%"):format(luck), luck >= 50
    for species, n in pairs(c.species) do
      model.rows[#model.rows + 1] = { count = n, name = nameCase(try(h.P.name, species) or ("#" .. species)), pic = try(h.P.icon, species) }
      model.top = max(model.top, n)
    end
    table.sort(model.rows, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.name < b.name end)
    return model
  end
  local function counterClick(x, y)
    local c = counterLoad()
    for _, hit in ipairs(c.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h and hit.action == "reset" then
        c.total, c.since, c.shinies, c.species = 0, 0, 0, {}
        counterSave()
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Party order, Pokédex, notices
  ---------------------------------------------------------------------------
  -- Click one, click another: they trade places, through the game's own reorder.
  local function partyClick(x, y)
    for _, hit in ipairs(partyState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        local from = partyState.selected
        if not from then partyState.selected = hit.slot return end
        partyState.selected = nil
        if from == hit.slot then return end
        local h = toolHost()
        if not h.toolsReady then return end
        toolState.world = toolState.world or h.World.new(game, "trainer_lens")
        if try(toolState.world.canReorderParty, toolState.world) == true then
          try(toolState.world.reorderParty, toolState.world, from, hit.slot)
        end
        return
      end
    end
    partyState.selected = nil
  end

  local dexState = { page = 1, fits = 20, hits = {}, detail = nil, missing = false }
  local BASE_KEYS = { HP = { "hp" }, ATK = { "atk", "attack" }, DEF = { "def", "defense" }, SPE = { "spe", "speed" },
    SPA = { "spa", "spAtk", "spatk" }, SPD = { "spd", "spDef", "spdef" } }
  -- force: show everything even for a species not seen yet (the area list names them anyway)
  local function dexDetail(number, force)
    local h, s = host(), game.session
    local species = try(h.P.speciesFromNational, number) or number
    local seen, caught = try(h.Dex.isSeen, s.dex, species) == true, try(h.Dex.isCaught, s.dex, species) == true
    seen = seen or caught or force == true
    local d = { number = number, seen = seen, caught = caught, name = seen and nameCase(try(h.P.name, species) or "?") or "?????",
      pic = try(h.P.frontPic, species, nil, false, 0) or try(h.P.icon, species), facts = {} }
    if not seen then return d end
    local types = try(h.P.types, species) or {}
    d.type, d.type2 = h.typeName[types[1]], h.typeName[types[2]]
    if d.type == "MYSTERY" then d.type = nil end
    local names = {}
    for _, id in ipairs(try(h.P.abilities, species) or {}) do
      local name = (tonumber(id) or 0) > 0 and try(h.P.abilityName, id)
      if name and not names[name] then names[name] = true; names[#names + 1] = nameCase(name) end
    end
    d.abilities = table.concat(names, " / ")
    local targets = {}
    for _, evo in ipairs(try(h.P.evolutions, species) or {}) do
      local target = type(evo) == "table" and tonumber(evo.target or evo[3])
      if target and target > 0 then targets[#targets + 1] = nameCase(try(h.P.name, target) or "?") end
    end
    d.evolves = table.concat(targets, ", ")
    local entry = try(h.P.dexEntry, species)
    if caught and type(entry) == "table" then
      d.category = entry.categoryName and nameCase(clean(entry.categoryName)) or nil
      if entry.heightFormatted then d.facts[#d.facts + 1] = clean(entry.heightFormatted) end
      if entry.weightFormatted then d.facts[#d.facts + 1] = clean(entry.weightFormatted) end
      if type(entry.description) == "string" then d.description = clean(entry.description) end
    end
    local base = try(h.P.stats, species)
    if type(base) == "table" then
      d.base, d.baseTotal = {}, 0
      for key, names2 in pairs(BASE_KEYS) do
        for _, field in ipairs(names2) do d.base[key] = d.base[key] or tonumber(base[field]) end
        d.baseTotal = d.baseTotal + (d.base[key] or 0)
      end
      d.baseTotal = tostring(d.baseTotal)
    end
    -- the areas whose wild Pokémon include it (the list the Progress view builds)
    try(progressModel)
    local places = {}
    for _, area in ipairs(areaList or {}) do
      if area.species[species] then places[#places + 1] = area.name end
    end
    d.where = #places > 0 and table.concat(places, ", ") or nil
    return d
  end
  local function dexModel()
    local h, s = host(), game.session
    if dexState.detail then return { detail = dexDetail(dexState.detail) } end
    local kanto = tonumber(h.Dex.KANTO_MAX) or 151
    local caughtKanto = try(h.Dex.countCaught, s.dex, "kanto") or 0
    local caughtAll = try(h.Dex.countCaught, s.dex, "national") or caughtKanto
    local last = caughtAll > caughtKanto and (tonumber(h.Dex.NATIONAL_MAX) or 386) or kanto
    local model = { rows = {}, filtered = dexState.missing, filterLabel = T(dexState.missing and "ONLY_MISSING" or "ALL") }
    local seenCount, caughtCount = 0, 0
    for number = 1, last do
      local species = try(h.P.speciesFromNational, number) or number
      local seen, caught = try(h.Dex.isSeen, s.dex, species) == true, try(h.Dex.isCaught, s.dex, species) == true
      if seen then seenCount = seenCount + 1 end
      if caught then caughtCount = caughtCount + 1 end
      if not (dexState.missing and caught) then
        model.rows[#model.rows + 1] = { number = number, seen = seen or caught, caught = caught,
          name = (seen or caught) and nameCase(try(h.P.name, species) or "?") or nil, pic = (seen or caught) and try(h.P.icon, species) or nil }
      end
    end
    model.summary = T("DEX_SUMMARY"):format(seenCount, caughtCount, last)
    model.pages = max(1, math.ceil(#model.rows / max(1, dexState.fits)))
    dexState.page = max(1, min(model.pages, dexState.page))
    model.page = dexState.page
    return model
  end
  local function dexClick(x, y)
    for _, hit in ipairs(dexState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        if hit.page then dexState.page = max(1, dexState.page + hit.page)
        elseif hit.back then dexState.detail = nil
        elseif hit.filter then dexState.missing, dexState.page = not dexState.missing, 1
        elseif hit.entry then dexState.detail = hit.entry end
        return
      end
    end
  end

  -- The area list: a click opens the species in full, with how it appears here.
  local function wildDetail()
    local h = host()
    local species = wildState.detail
    local national = try(h.P.national, species)
    local number = tonumber(national) or species
    local d = dexDetail(number, true)
    local lines = {}
    for _, row in ipairs(wildCache and wildCache.rows or {}) do
      if row.species == species then
        lines[#lines + 1] = (row.method and (row.method .. "  ") or "") .. row.levelText .. "  " .. row.chanceText
      end
    end
    d.here = table.concat(lines, "   ·   ")
    return { detail = d }
  end
  local function wildClick(x, y)
    for _, hit in ipairs(wildState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        if hit.page then
          wildState.page = max(1, wildState.page + hit.page)
          wildState.pageUntil = love.timer.getTime() + 30
        elseif hit.back then wildState.detail = nil
        elseif hit.species then wildState.detail, wildState.map = hit.species, game.session.map end
        return
      end
    end
  end

  -- PC boxes. Looking reads the save's storage directly, never through anything
  -- that could create, move, deposit or withdraw. The one thing that writes is
  -- Sort, which the player starts by hand: it rearranges the Pokémon of the
  -- boxes that are not locked, moving only table references between slots (a
  -- box holds mons[1..30], nil = empty), and keeps one step of undo.
  local boxState = { box = nil, selected = nil, hits = {}, view = nil, flash = nil, undo = nil }
  local function boxView(mon)
    -- a boxed Pokémon may carry no computed stats: work them out to show, on a copy
    if tonumber(mon.maxHp) and tonumber(mon.attack) then return mon end
    local h = host()
    local species = h.P.speciesOf(mon)
    local stats = h.P.calcStats and try(h.P.calcStats, species, tonumber(mon.level) or 1, mon.ivs, mon.evs, mon.personality)
    if type(stats) ~= "table" then return mon end
    local copy = setmetatable({}, { __index = mon })
    for key, value in pairs(stats) do copy[key] = value end
    copy.hp = tonumber(mon.hp) or stats.maxHp
    return copy
  end

  -- Locked boxes, per save (trainer id and name), in the cache as
  -- "<id>:<name>=1,4,7" lines. The lock only means Sort leaves the box alone;
  -- the game itself can still change it.
  local LOCKS_KEY = "box_locks/v1"
  local locks = nil
  local function saveKey()
    local s = game.session
    return ("%d:%s"):format(tonumber(s.trainerId or s.id) or 0, (clean(tostring(s.name or s.playerName or "?")):gsub("[=\n]", "")))
  end
  local function lockSet()
    if not locks then
      locks = {}
      local saved = mod.cache and mod.cache.read and mod.cache:read(LOCKS_KEY) or ""
      for line in tostring(saved):gmatch("[^\n]+") do
        local key, list = line:match("^(.-)=(.*)$")
        if key then
          locks[key] = {}
          for n in list:gmatch("%d+") do locks[key][tonumber(n)] = true end
        end
      end
    end
    local key = saveKey()
    locks[key] = locks[key] or {}
    return locks[key]
  end
  local function saveLocks()
    local lines = {}
    for key, set in pairs(locks or {}) do
      local list = {}
      for n in pairs(set) do list[#list + 1] = n end
      table.sort(list)
      if #list > 0 then lines[#lines + 1] = key .. "=" .. table.concat(list, ",") end
    end
    table.sort(lines)
    if mod.cache and mod.cache.write then mod.cache:write(LOCKS_KEY, table.concat(lines, "\n")) end
  end

  -- The orders Sort offers. Eggs always go last; ties keep their old order.
  local SORTS = { "dex_all", "dex_simple", "species_level", "level_up", "level_down", "compact" }
  local SORT_LABELS = { dex_all = "SORT_DEX_ALL", dex_simple = "SORT_DEX_SIMPLE", species_level = "SORT_SPECIES",
    level_up = "SORT_LV_UP", level_down = "SORT_LV_DOWN", compact = "SORT_COMPACT" }
  local function sortEntries(entries, order)
    if order == "compact" then return end   -- the order they are in now, gaps taken out
    if order == "dex_simple" then
      -- the first of each species (highest level, then the one found first) keeps
      -- its place in the living dex; the repeats follow, in dex order too
      local best = {}
      for _, e in ipairs(entries) do
        local b = not e.egg and best[e.dex]
        if not e.egg and (not b or e.level > b.level) then best[e.dex] = e end
      end
      for _, e in ipairs(entries) do e.extra = (e.egg or best[e.dex] ~= e) and 1 or 0 end
    end
    table.sort(entries, function(a, b)
      if a.egg ~= b.egg then return b.egg end
      if order == "dex_simple" and a.extra ~= b.extra then return a.extra < b.extra end
      if order == "level_up" and a.level ~= b.level then return a.level < b.level end
      if order == "level_down" and a.level ~= b.level then return a.level > b.level end
      if a.dex ~= b.dex then return a.dex < b.dex end
      if order == "species_level" and a.level ~= b.level then return a.level < b.level end
      if (order == "dex_all" or order == "dex_simple") and a.level ~= b.level then return a.level > b.level end
      return a.index < b.index
    end)
  end

  -- Sorting changes the save, so only in the field with no menu, script or battle.
  local function pcFree()
    local h = toolHost()
    if not h.toolsReady then return false end
    if try(h.Battle.isActive) == true then return false end
    toolState.world = toolState.world or h.World.new(game, "trainer_lens")
    local list, why = try(toolState.world.availableFieldActions, toolState.world)
    return type(list) == "table" and why == nil
  end

  local function sortPlan(order)
    local storage, h = game.session.storage, host()
    local set, boxes, entries = lockSet(), {}, {}
    for b = 1, #storage.boxes do
      if not set[b] and type(storage.boxes[b]) == "table" then
        boxes[#boxes + 1] = b
        local mons = storage.boxes[b].mons or {}
        for slot = 1, 30 do
          local mon = mons[slot]
          if type(mon) == "table" then
            local egg = try(h.P.isEgg, mon) == true
            local species = try(h.P.speciesOf, mon) or 0
            entries[#entries + 1] = { mon = mon, egg = egg, index = #entries + 1, level = tonumber(mon.level) or 0,
              dex = tonumber((try(h.P.national, species))) or tonumber(species) or 9999 }
          end
        end
      end
    end
    if order then sortEntries(entries, order) end
    return boxes, entries
  end

  -- The slots in order, from the first unlocked box on: a Pokémon, or false for
  -- a slot left empty. The living dex orders keep one empty slot for each
  -- species missing below the highest Pokédex number there is.
  local function placement(order, entries)
    if order ~= "dex_all" and order ~= "dex_simple" then
      local seq = {}
      for i, e in ipairs(entries) do seq[i] = e.mon end
      return seq
    end
    local groups, top, eggs, extras = {}, 0, {}, {}
    for _, e in ipairs(entries) do
      if e.egg then eggs[#eggs + 1] = e.mon
      elseif order == "dex_simple" and e.extra == 1 then extras[#extras + 1] = e.mon
      else
        groups[e.dex] = groups[e.dex] or {}
        table.insert(groups[e.dex], e.mon)
        if e.dex > top then top = e.dex end
      end
    end
    local seq = {}
    for n = 1, top do
      if groups[n] then
        for _, mon in ipairs(groups[n]) do seq[#seq + 1] = mon end
      else
        seq[#seq + 1] = false
      end
    end
    for _, mon in ipairs(extras) do seq[#seq + 1] = mon end
    for _, mon in ipairs(eggs) do seq[#seq + 1] = mon end
    return seq
  end

  local function layoutOf(boxes)
    local storage, out = game.session.storage, {}
    for _, b in ipairs(boxes) do
      local mons, copy = storage.boxes[b].mons or {}, {}
      for slot = 1, 30 do copy[slot] = mons[slot] end
      out[b] = copy
    end
    return out
  end
  local function sameLayout(saved)
    local storage = game.session.storage
    for b, copy in pairs(saved) do
      local mons = storage.boxes[b] and storage.boxes[b].mons or {}
      for slot = 1, 30 do if mons[slot] ~= copy[slot] then return false end end
    end
    return true
  end
  local function putLayout(saved)
    local storage = game.session.storage
    for b, copy in pairs(saved) do
      storage.boxes[b].mons = storage.boxes[b].mons or {}
      for slot = 1, 30 do storage.boxes[b].mons[slot] = copy[slot] end
    end
  end

  local function flash(key, ...)
    boxState.flash = { text = select("#", ...) > 0 and T(key):format(...) or T(key), at = love.timer.getTime() }
  end
  local function runSort(order)
    if not pcFree() then return flash("SORT_BUSY") end
    local boxes, entries = sortPlan(order)
    if #boxes == 0 then return flash("ALL_LOCKED") end
    if #entries == 0 then return flash("SORT_NONE") end
    local seq = placement(order, entries)
    if #seq > #boxes * 30 then return flash("SORT_NO_ROOM", #seq, #boxes * 30) end
    local before = layoutOf(boxes)
    local storage, n = game.session.storage, 0
    for _, b in ipairs(boxes) do
      storage.boxes[b].mons = storage.boxes[b].mons or {}
      for slot = 1, 30 do
        n = n + 1
        storage.boxes[b].mons[slot] = seq[n] or nil
      end
    end
    boxState.undo = { before = before, after = layoutOf(boxes) }
    boxState.selected = nil
    flash("SORT_DONE", #entries)
  end
  local function undoSort()
    local undo = boxState.undo
    boxState.undo = nil
    if not undo then return end
    if not pcFree() then boxState.undo = undo return flash("SORT_BUSY") end
    -- only while nothing else has moved since: otherwise undoing would lose that
    if not sameLayout(undo.after) then return flash("UNDO_GONE") end
    putLayout(undo.before)
    boxState.selected = nil
    flash("UNDONE")
  end

  local function boxModel()
    local storage = game.session.storage
    if type(storage) ~= "table" or type(storage.boxes) ~= "table" or #storage.boxes == 0 then return nil end
    local h = host()
    local boxes = #storage.boxes
    boxState.box = max(1, min(boxes, boxState.box or tonumber(storage.currentBox) or 1))
    local box = storage.boxes[boxState.box] or {}
    local mons = type(box.mons) == "table" and box.mons or {}
    local set = lockSet()
    local lockedCount = 0
    for b = 1, boxes do if set[b] then lockedCount = lockedCount + 1 end end
    if boxState.undo and not sameLayout(boxState.undo.after) then boxState.undo = nil end
    local now = love.timer.getTime()
    if boxState.flash and now - boxState.flash.at > 6 then boxState.flash = nil end
    local model = { box = boxState.box, boxes = boxes, slots = {}, count = 0,
      name = nameCase(clean(tostring(box.name or ("BOX " .. boxState.box)))),
      locked = set[boxState.box] == true, lockedCount = lockedCount, canUndo = boxState.undo ~= nil,
      flash = boxState.flash and boxState.flash.text, view = boxState.view }
    if type(boxState.view) == "table" then
      local unlocked, entries = sortPlan(nil)
      model.confirm = { title = T(SORT_LABELS[boxState.view.order]),
        line = T("SORT_CONFIRM"):format(#entries, #unlocked), note = T("SORT_WARN") }
    elseif boxState.view == "sort" then
      model.sorts = {}
      for _, id in ipairs(SORTS) do model.sorts[#model.sorts + 1] = { id = id, label = T(SORT_LABELS[id]) } end
      model.sortNote = T("SORT_NOTE"):format(lockedCount)
    end
    for slot = 1, 30 do
      local mon = mons[slot]
      if type(mon) == "table" then
        local egg = try(h.P.isEgg, mon) == true
        model.count = model.count + 1
        local species = try(h.P.speciesOf, mon)
        local number = not egg and (tonumber((try(h.P.national, species))) or tonumber(species)) or nil
        model.slots[slot] = { pic = try(h.P.monIcon, mon), shiny = not egg and try(h.P.isShiny, mon) == true,
          level = not egg and mon.level and (T("LV") .. mon.level) or nil,
          number = number and T("DEX_NO"):format(number) or nil }
      end
    end
    local chosen = boxState.selected and mons[boxState.selected]
    if type(chosen) ~= "table" then boxState.selected = nil end
    model.selected = boxState.selected
    if type(chosen) == "table" and not boxState.view then
      local view = boxView(chosen)
      local pokemon = monBasics(view)
      if not pokemon.egg then
        local detail = sheetModel(view, pokemon)
        detail.showEvs, detail.evTotal = true, 0
        for _, row in ipairs(detail.rows) do detail.evTotal = detail.evTotal + (row.ev or 0) end
        local species = try(h.P.speciesOf, chosen)
        local number = tonumber((try(h.P.national, species))) or tonumber(species)
        detail.kindLabel = model.name .. "  ·  " .. boxState.selected .. (number and ("  ·  " .. T("DEX_NO"):format(number)) or "")
        model.detail = detail
      end
    end
    return model
  end
  local function boxClick(x, y)
    for _, hit in ipairs(boxState.hits) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        if hit.page then boxState.box, boxState.selected = (boxState.box or 1) + hit.page, nil
        elseif hit.back then boxState.selected = nil
        elseif hit.lock then
          local set = lockSet()
          set[boxState.box] = not set[boxState.box] or nil
          saveLocks()
        elseif hit.openSort then boxState.view, boxState.selected = "sort", nil
        elseif hit.sort then boxState.view = { order = hit.sort }
        elseif hit.confirm then
          local order = type(boxState.view) == "table" and boxState.view.order
          boxState.view = nil
          if order then runSort(order) end
        elseif hit.cancel then boxState.view = nil
        elseif hit.undo then undoSort()
        elseif hit.slot then boxState.selected = boxState.selected ~= hit.slot and hit.slot or nil end
        return
      end
    end
  end

  -- Notices: a short feed of what changed, newest first.
  local notices = { rows = {}, last = {}, nextAt = 0 }
  local function notify(title, detail, tone)
    table.insert(notices.rows, 1, { title = title, detail = detail, tone = tone, at = love.timer.getTime(), clock = os.date("%H:%M") })
    while #notices.rows > 30 do table.remove(notices.rows) end
  end
  counterLoad().notify = notify
  -- Auto Repel: when the last one wears off somewhere wild Pokémon appear, the
  -- weakest repel in the bag is used. Towns and buildings are left alone.
  local function wildHere()
    local source = game.data and game.data.gen3Encounters and game.data.gen3Encounters[game.session.map]
    if type(source) ~= "table" then return false end
    local function live(pool) return type(pool) == "table" and (tonumber(pool.rate) or 0) > 0 and #(pool.slots or {}) > 0 end
    local P = toolHost().Player
    return live(source.land) or ((P and P.surfing == true) and live(source.water))
  end
  local function autoRepel()
    if not toolState.autoRepel then return end
    local h, s = toolHost(), game.session
    if not h.toolsReady or repelLeft() > 0 or not wildHere() then return end
    if try(h.Battle.isActive) == true then return end
    toolState.world = toolState.world or h.World.new(game, "trainer_lens")
    local _, why = try(toolState.world.availableFieldActions, toolState.world)
    if why ~= nil then return end                      -- a dialogue, a menu, a script: not now
    for _, id in ipairs(REPELS) do
      if bagCount(h, id) > 0 then
        if try(h.ItemUse.useField, s, s.bag, id) == true then
          notify(T("N_AUTO"):format(itemLabel(h, id)), T("N_AUTO_LEFT"):format(bagCount(h, id)))
          toolState.outSaid = nil
        end
        return
      end
    end
    if not toolState.outSaid then
      toolState.outSaid = true
      notify(T("N_AUTO_OUT"), nil, "bad")
    end
  end
  local function noticeWatch()
    local now = love.timer.getTime()
    if now < notices.nextAt or not inGame() then return end
    notices.nextAt = now + 0.5
    local h, s, last = toolHost(), game.session, notices.last
    -- the bot, when it stops by itself
    local other = mod.find and mod.find("trainer_pilot")
    local bot = other and other.exports and other.exports.bot
    if type(bot) == "table" then
      if last.botRunning and not bot.running and bot.reason and bot.reason ~= "player" and bot.reason ~= "quit" then
        local text = type(bot.reasonText) == "function" and try(bot.reasonText, bot.reason) or tostring(bot.reason)
        local good = bot.reason == "hunt_found" or bot.reason == "shiny" or bot.reason == "caught"
        notify(T("N_BOT"), text, good and "gold" or "bad")
      end
      last.botRunning = bot.running == true
    end
    if h.VsSeeker then
      local charge, full = tonumber(try(h.VsSeeker.getBattery, s)) or 0, tonumber(h.VsSeeker.MAX_CHARGE) or 100
      if last.charge and last.charge < full and charge >= full and bagCount(h, ITEM_SEEKER) > 0 then notify(T("N_SEEKER"), (areaName(s.map, game.data.maps[s.map] or {}))) end
      last.charge = charge
    end
    pcall(autoRepel)
    local repel = repelLeft()
    if last.repel and last.repel > 0 and repel <= 0 and not toolState.autoRepel then notify(T("N_REPEL"), (areaName(s.map, game.data.maps[s.map] or {}))) end
    last.repel = repel
    for slot, mon in ipairs(s.party or {}) do
      local hp = tonumber(mon.hp) or 0
      local key = "hp" .. tostring(mon.personality) .. ":" .. slot
      if last[key] and last[key] > 0 and hp <= 0 then notify(T("N_FAINT"):format(monBasics(mon).name), nil, "bad") end
      last[key] = hp
    end
    local okDc, DC = pcall(require, "src.core.game3.daycare")
    if okDc and type(DC) == "table" then
      local dc = try(DC.stateOf, s)
      local egg = dc and try(DC.isEggPending, dc) == true
      if last.egg == false and egg then notify(T("N_EGG"), nil, "gold") end
      last.egg = egg
      for index = 1, 2 do
        local mon = dc and try(DC.mon, dc, index)
        if type(mon) == "table" and (tonumber(try(host().P.speciesOf, mon)) or 0) > 0 then
          local level = (tonumber(mon.level) or 0) + (tonumber(try(DC.levelsGained, mon, type(dc.steps) == "table" and dc.steps[index] or 0)) or 0)
          local key = "dc" .. index
          if last[key] and level > last[key] then notify(T("N_DAYCARE"):format(monBasics(mon).name, level)) end
          last[key] = level
        else
          last["dc" .. index] = nil
        end
      end
    end
  end

  local function paint(kind, now, w, h)
    w, h = w or W, h or H
    if not inGame() then
      UI.notice(w, h, { T("NO_GAME") })
    elseif kind == "enemy" then
      local model = enemyModel()
      if model then UI.sheet(model, w, h, not model.team and model.kindLabel or nil)
      else UI.notice(w, h, { T("NO_BATTLE") }) end
    elseif kind == "ally" then
      local model = allyModel()
      if model and not model.egg then UI.sheet(model, w, h, model.kindLabel)
      else UI.notice(w, h, { model and T("EGG") or T("NO_PARTY"), model and model.label or nil }) end
    elseif kind == "party" then
      local model = partyModel()
      if partyState.selected and partyState.selected > #model.rows then partyState.selected = nil end
      model.selected = partyState.selected
      partyState.hits = UI.party(model, w, h) or {}
    elseif kind == "dex" then
      local model = dexModel()
      dexState.hits = UI.dex(model, w, h) or {}
      dexState.fits = model.fits or dexState.fits
    elseif kind == "notices" then
      UI.notices(notices, w, h, now)
    elseif kind == "box" then
      local model = boxModel()
      if model then boxState.hits = UI.box(model, w, h) or {} else UI.notice(w, h, { T("NO_PC") }) end
    elseif kind == "radar" then
      UI.radar(radarModel(), w, h, now)
    elseif kind == "tools" then
      toolState.hits = UI.tools(toolsModel(), w, h, now) or {}
    elseif kind == "trainer" then
      UI.trainer(trainerModel(), w, h)
    elseif kind == "bag" then
      local model = bagModel()
      bagState.hits = UI.bag(model, w, h) or {}
      bagState.fits = model.fits or bagState.fits
    elseif kind == "moves" then
      local model = movesModel()
      if model then UI.moves(model, w, h) else UI.notice(w, h, { T("NO_PARTY") }) end
    elseif kind == "daycare" then
      local model = daycareModel()
      if model then UI.daycare(model, w, h) else UI.notice(w, h, { T("NO_MAP") }) end
    elseif kind == "counter" then
      counterLoad().hits = UI.counter(counterModel(), w, h) or {}
    elseif kind == "map" then
      local model = localMapModel(now)
      if model then UI.map(model, w, h, now) else UI.notice(w, h, { T("NO_MAP") }) end
    elseif kind == "region" then
      local model = regionModel()
      if model then UI.region(model, w, h, now) else UI.notice(w, h, { T("NO_REGION") }) end
    elseif kind == "progress" then
      local model = progressModel()
      progressState.hits = UI.progress(model, w, h) or {}
      progressState.fits = model.fits or progressState.fits
    else
      if wildState.detail and wildState.map ~= game.session.map then wildState.detail = nil end
      if wildState.detail then
        wildModel(now)
        wildState.hits = UI.dex(wildDetail(), w, h) or {}
      else
        wildState.hits = UI.wild(wildModel(now), w, h) or {}
      end
    end
  end
  local function render(index, kind, now)
    local canvas = canvases[index]
    if not canvas then
      canvas = G.newCanvas(W, H, { dpiscale = 1 })
      canvases[index] = canvas
    end
    local depth = G.getStackDepth()
    G.push("all")
    G.setCanvas(canvas)
    G.origin(); G.setScissor(); G.setShader(); G.setBlendMode("alpha"); G.setLineWidth(1)
    G.clear(0, 0, 0, 1)
    local ok, err = pcall(paint, kind, now, W, H)
    if not ok then
      -- A view that fails shows why and is logged once; the game goes on.
      while G.getStackDepth() > depth + 1 do G.pop() end
      G.setCanvas(canvas); G.origin(); G.setScissor()
      local message = clean(tostring(err):gsub("^.-trainer_lens/", ""))
      pcall(UI.notice, W, H, { T("ERROR"), message })
      if not logged[kind] then
        logged[kind] = true
        mod.log:warn("panel %s: %s", kind, tostring(err))
      end
    end
    while G.getStackDepth() > depth do G.pop() end
  end

  -- For tests: what the my-Pokémon view would show, and painting one view.
  mod.exports = mod.exports or {}
  mod.exports.debugAlly = function()
    local model = allyModel()
    if not model then return nil end
    local _, label = allyTarget()
    return model.pokemon and model.pokemon.name or nil, label
  end
  mod.exports.debugToolClick = function(x, y) return toolClick(x, y) end
  mod.exports.debugAutoRepel = function(on) toolState.autoRepel = on == true end
  mod.exports.debugClick = function(kind, x, y)
    if kind == "box" then return boxClick(x, y) elseif kind == "wild" then return wildClick(x, y) elseif kind == "party" then return partyClick(x, y) elseif kind == "dex" then return dexClick(x, y)
    elseif kind == "bag" then return bagClick(x, y) elseif kind == "counter" then return counterClick(x, y) end
  end
  -- the PC panel's clickable places, for the tests: clicks a hit that has `field`
  mod.exports.debugBoxPress = function(field, value)
    for _, hit in ipairs(boxState.hits) do
      if hit[field] ~= nil and (value == nil or hit[field] == value) then
        return boxClick(hit.x + 1, hit.y + 1) or true
      end
    end
    return false
  end
  mod.exports.debugPaint = function(kind, w, h)
    paint(kind, love.timer.getTime(), w, h)
  end

  -- Trainer Desk, when it is installed, enabled and laying out the window.
  local docked            -- { api, language } while the panels live in the dock
  local DOCK_KINDS = { "party", "wild", "enemy", "radar", "ally", "tools", "trainer", "progress", "map", "region", "bag", "moves", "daycare", "counter", "dex", "notices", "box" }
  local function dockApi()
    if suspended or option("placement") == "windows" or not mod.find then return nil end
    local other = mod.find("trainer_desk")
    local api = other and other.exports and other.exports.dock
    if type(api) == "table" and api.api == 1 and api.active() then return api end
  end
  local function undock()
    if not docked then return end
    for _, kind in ipairs(DOCK_KINDS) do pcall(docked.api.unregister, "trainer_lens." .. kind) end
    docked = nil
  end
  -- Every view becomes a dock panel; the dock decides where each one sits.
  local SIDES = { party = "right" }
  local function syncDock(api)
    local language = tostring(option("language"))
    if docked and docked.api == api and docked.language == language then return end
    undock()
    for _, kind in ipairs(DOCK_KINDS) do
      api.register({
        id = "trainer_lens." .. kind, title = T("TABS")[kind], width = W, height = H, pixel = 1, responsive = true,
        interval = kind == "radar" and 0.08 or 0.2, side = SIDES[kind] or "bottom",
        pointer = kind == "tools" and function(action, x, y)
          if action == "down" then
            local ok, err = pcall(toolClick, x, y)
            if not ok and not logged.toolClick then logged.toolClick = true; mod.log:warn("tools: %s", tostring(err)) end
          end
        end or kind == "bag" and function(action, x, y, amount)
          if action == "wheel" then bagState.page = max(1, bagState.page + ((tonumber(amount) or 0) > 0 and -1 or 1))
          elseif action == "down" then pcall(bagClick, x, y) end
        end or kind == "wild" and function(action, x, y, amount)
          if action == "wheel" then
            wildState.page = max(1, wildState.page + ((tonumber(amount) or 0) > 0 and -1 or 1))
            wildState.pageUntil = love.timer.getTime() + 30
          elseif action == "down" then pcall(wildClick, x, y) end
        end or kind == "party" and function(action, x, y)
          if action == "down" then pcall(partyClick, x, y) end
        end or kind == "dex" and function(action, x, y, amount)
          if action == "wheel" then dexState.page = max(1, dexState.page + ((tonumber(amount) or 0) > 0 and -1 or 1))
          elseif action == "down" then pcall(dexClick, x, y) end
        end or kind == "box" and function(action, x, y, amount)
          if action == "wheel" then boxState.box, boxState.selected = (boxState.box or 1) + ((tonumber(amount) or 0) > 0 and -1 or 1), nil
          elseif action == "down" then pcall(boxClick, x, y) end
        end or kind == "counter" and function(action, x, y)
          if action == "down" then pcall(counterClick, x, y) end
        end or kind == "progress" and function(action, x, y, amount)
          -- the wheel, or the page buttons, turn the pages of the list
          if action == "wheel" then progressState.page = progressState.page + ((tonumber(amount) or 0) > 0 and -1 or 1)
          elseif action == "down" then
            for _, hit in ipairs(progressState.hits or {}) do
              if hit.page and x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
                progressState.page = progressState.page + hit.page
              end
            end
          end
          if progressState.page < 1 then progressState.page = 1 end
        end or nil,
        -- a dock that knows responsive panels says how much room there is
        draw = function(clock, w, h)
          if api.theme then UI.theme(api.theme().colors) end
          paint(kind, clock, w, h)
        end,
      })
    end
    docked = { api = api, language = language }
  end

  local function update()
    local api = dockApi()
    if api then
      if #Windows.list > 0 then Windows.closeAll() end
      syncDock(api)
      return
    end
    undock()
    local n = count()
    if n == 0 then
      if #Windows.list > 0 then Windows.closeAll() end
      return
    end
    local now = love.timer.getTime()
    local signature = tostring(option("panels"))
    if signature ~= windowSignature then
      windowSignature = signature
      Windows.reset()
    end
    Windows.update(n, true)
    local battling = inGame() and try(function() return host().Battle.isActive() end) == true
    local list = kinds(n, battling)
    local key = table.concat(list, ":") .. ":" .. tostring(option("language"))
    if now < nextPaint and key == paintKey then return end
    -- The radar's sweep turns, so a radar window is refreshed more often.
    local sweeping = false
    for _, kind in ipairs(list) do sweeping = sweeping or kind == "radar" end
    nextPaint, paintKey = now + (sweeping and 0.08 or 0.2), key
    for index, kind in ipairs(list) do
      if Windows.connected(index) then
        render(index, kind, now)
        Windows.push(index, canvases[index]:newImageData(), 0x0d0f14, "secondary:fit:auto")
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Window keeper thread (Windows only)
  ---------------------------------------------------------------------------
  local keeper
  local function startKeeper()
    if not (jit and jit.os == "Windows") then return end
    local ok, err = pcall(function()
      local epoch = tostring(love.timer.getTime()) .. ":" .. tostring(math.random(1, 1e9))
      -- A keeper left over from an earlier load of the mod stops when it
      -- sees a newer one take over.
      local owner = love.thread.getChannel("trainer_lens_keeper")
      owner:clear(); owner:push(epoch)
      local control, results = love.thread.newChannel(), love.thread.newChannel()
      local source = "local __epoch, __owner = select(4, ...), select(5, ...)\n"
        .. assert(mod:read("wm_worker.lua"))
      local thread = love.thread.newThread(source)
      local saved = mod.cache and mod.cache.read and mod.cache:read("windows/layout2") or ""
      thread:start(control, results, saved, epoch, owner)
      keeper = { thread = thread, control = control, results = results }
    end)
    if not ok then mod.log:warn("window keeper unavailable: %s", tostring(err)) end
  end
  local function serviceKeeper()
    if not keeper then return end
    local config = (option("raise_windows") ~= false and "1" or "0") .. (option("remember_windows") ~= false and "1" or "0")
      .. (option("remember_game_window") ~= false and "1" or "0")
    if config ~= keeper.config then
      keeper.config = config
      keeper.control:push({ raise = option("raise_windows") ~= false, remember = option("remember_windows") ~= false,
        main = option("remember_game_window") ~= false })
    end
    local ports = Windows.ports()
    -- windows of panels taken out of the IDE are kept in place too
    local other = mod.find and mod.find("trainer_desk")
    local dock = other and other.exports and other.exports.dock
    if type(dock) == "table" and type(dock.windowPorts) == "function" then
      local ok, extra = pcall(dock.windowPorts)
      if ok and type(extra) == "string" and extra ~= "" then ports = ports ~= "" and ports .. "," .. extra or extra end
    end
    if ports ~= keeper.ports then
      keeper.ports = ports
      keeper.control:push({ ports = ports })
    end
    local message = keeper.results:pop()
    while message ~= nil do
      if type(message) == "string" and message:sub(1, 1) == "!" then
        if not keeper.warned then keeper.warned = true; mod.log:warn("window keeper: %s", message:sub(2)) end
      elseif type(message) == "string" and mod.cache and mod.cache.write then
        mod.cache:write("windows/layout2", message)
      end
      message = keeper.results:pop()
    end
    local failure = not keeper.reported and keeper.thread:getError()
    if failure then keeper.reported = true; mod.log:warn("window keeper stopped: %s", tostring(failure)) end
  end

  local failed
  mod.hooks:wrap("core.update", function(next, updateGame, dt)
    if not failed then
      pcall(counterWatch)
      pcall(noticeWatch)
      local ok, err = pcall(function() update(); serviceKeeper() end)
      if not ok then
        failed = true
        pcall(Windows.closeAll)
        mod.log:warn("Trainer Lens stopped: %s", tostring(err))
      end
    end
    return next(updateGame, dt)
  end, 900)
  mod.hooks:wrap("core.quit_to_launcher", function(next)
    suspended = true
    pcall(undock)
    pcall(Windows.closeAll)
    return next()
  end, 900)
  mod.events:on("game.ready", function(payload)
    game, suspended, wildCache = payload and payload.game, false, nil
    if not keeper then startKeeper() end
    mod.log:info("ready (generation %s)", tostring(game and game.generation))
  end)
end
