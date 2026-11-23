-- How the panels look. Every view is drawn into whatever room it is given
-- (width and height in pixels) and rearranges itself to fit: nothing here
-- knows the game, only the models main.lua builds.
return function(env)
  local G = love.graphics
  local T, typeLabel = env.T, env.typeLabel
  local floor, max, min, pi = math.floor, math.max, math.min, math.pi
  local UI = {}

  local function hex(value)
    return { tonumber(value:sub(1, 2), 16) / 255, tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255 }
  end
  local C = {
    bg = hex("0f1216"), card = hex("1b1f26"), raised = hex("252b34"), line = hex("2f3742"),
    text = hex("e6ebf2"), muted = hex("9aa5b4"), faint = hex("5d6875"), accent = hex("4f9cf7"),
    hp = hex("3fcf6b"), hpMid = hex("f2b33d"), hpLow = hex("ef5350"), gold = hex("f2c14e"),
    up = hex("ff7a70"), down = hex("6aa8ff"), iv = hex("3fcf6b"), ev = hex("4f9cf7"), stat = hex("b48cff"),
    male = hex("5aa2ff"), female = hex("ff70a0"), white = { 1, 1, 1 }, black = { 0, 0, 0 },
  }
  UI.colors = C
  -- A dock theme, when there is one, gives the surfaces and the text their colours.
  function UI.theme(colors)
    if type(colors) ~= "table" then return end
    C.bg, C.card, C.raised = colors.panel or C.bg, colors.dock or C.card, colors.tabActive or C.raised
    C.text, C.muted, C.faint = colors.textActive or C.text, colors.text or C.muted, colors.empty or C.faint
    C.accent, C.ev = colors.accent or C.accent, colors.accent or C.ev
  end
  local TYPE = { NORMAL = "a8a878", FIRE = "f08030", WATER = "5890f0", ELECTRIC = "f0c020", GRASS = "70c048",
    ICE = "68c8d0", FIGHTING = "c03028", POISON = "a040a0", GROUND = "d8b058", FLYING = "a890f0", PSYCHIC = "f85888",
    BUG = "a8b820", ROCK = "b8a038", GHOST = "705898", DRAGON = "7038f8", DARK = "705848", STEEL = "b8b8d0" }
  for key, value in pairs(TYPE) do TYPE[key] = hex(value) end
  local STATUS = { PSN = hex("a040c0"), PAR = hex("e8b818"), SLP = hex("8890a0"), FRZ = hex("58b8e8"),
    BRN = hex("e86030"), FNT = hex("d04040") }

  ---------------------------------------------------------------------------
  -- Small pieces
  ---------------------------------------------------------------------------
  local fonts = {}
  local function font(size)
    size = max(8, floor(size))
    if not fonts[size] then fonts[size] = env.font and env.font(size) or G.newFont(size) end
    return fonts[size]
  end
  local function color(c, a) G.setColor(c[1], c[2], c[3], a or 1) end
  local function mix(a, b, k) return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k } end
  local function widthOf(value, size) return font(size):getWidth(tostring(value)) end
  -- Text that does not fit loses its end, on a whole character.
  local function fit(value, room, size)
    value = tostring(value or "")
    if widthOf(value, size) <= room then return value end
    local chars = {}
    for ch in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    while #chars > 0 and widthOf(table.concat(chars) .. "..", size) > room do chars[#chars] = nil end
    return table.concat(chars) .. ".."
  end
  -- align: nil (left of x), "right" (ends at x), "center" (around x)
  local function text(value, x, y, c, size, align)
    value = tostring(value)
    size = size or 12
    G.setFont(font(size))
    if align == "right" then x = x - widthOf(value, size) elseif align == "center" then x = x - widthOf(value, size) / 2 end
    color(c or C.text)
    G.print(value, floor(x), floor(y))
  end
  local function card(x, y, w, h, fill, radius)
    color(fill or C.card)
    G.rectangle("fill", x, y, w, h, radius or 8, radius or 8)
  end
  local function pill(label, x, y, fill, size)
    size = size or 10
    local w = widthOf(label, size) + 12
    color(fill)
    G.rectangle("fill", x, y, w, size + 6, (size + 6) / 2, (size + 6) / 2)
    local lum = fill[1] * 0.3 + fill[2] * 0.59 + fill[3] * 0.11
    text(label, x + 6, y + 2, lum > 0.62 and C.black or C.white, size)
    return w
  end
  local function hpColor(ratio) return ratio > 0.5 and C.hp or ratio > 0.2 and C.hpMid or C.hpLow end
  local function bar(x, y, w, h, ratio, fill)
    ratio = max(0, min(1, ratio or 0))
    color(C.line)
    G.rectangle("fill", x, y, w, h, h / 2, h / 2)
    local size = max(ratio > 0 and h or 0, w * ratio)
    if size > 0 then
      color(fill)
      G.rectangle("fill", x, y, size, h, h / 2, h / 2)
    end
  end
  local function sprite(pic, x, y, size, dim)
    if not (pic and pic.image) then return end
    local quad = pic.quads and (pic.quads[0] or pic.quads[1])
    local w, h = pic.w or pic.image:getWidth(), pic.h or pic.image:getHeight()
    local scale = min(size / w, size / h)
    -- whole multiples keep the pixel art crisp
    if scale >= 1 then scale = floor(scale) end
    local shade = dim and 0.4 or 1
    G.setColor(shade, shade, shade, 1)
    pcall(pic.image.setFilter, pic.image, "nearest", "nearest")
    local dx, dy = floor(x + (size - w * scale) / 2), floor(y + (size - h * scale) / 2)
    if quad then G.draw(pic.image, quad, dx, dy, 0, scale, scale) else G.draw(pic.image, dx, dy, 0, scale, scale) end
  end
  local function avatar(pic, x, y, size, dim)
    color(C.raised)
    G.circle("fill", x + size / 2, y + size / 2, size / 2)
    sprite(pic, x + 2, y + 2, size - 4, dim)
  end
  -- The male and female signs, drawn: the font has no glyph for them.
  local function genderMark(value, x, y, size)
    if value ~= "M" and value ~= "F" then return 0 end
    local r = max(3, size * 0.30)
    local cx, cy = x + r + 1, y + size * 0.62
    G.setLineWidth(max(1.5, size / 8))
    if value == "M" then
      color(C.male)
      cy = cy + r * 0.35
      G.circle("line", cx, cy, r)
      local tx, ty = cx + r * 2.0, cy - r * 2.0
      G.line(cx + r * 0.7, cy - r * 0.7, tx, ty)
      G.line(tx - r * 1.1, ty, tx, ty, tx, ty + r * 1.1)
    else
      color(C.female)
      cy = cy - r * 0.55
      G.circle("line", cx, cy, r)
      G.line(cx, cy + r, cx, cy + r * 2.7)
      G.line(cx - r * 0.85, cy + r * 1.85, cx + r * 0.85, cy + r * 1.85)
    end
    G.setLineWidth(1)
    return r * 3 + 5
  end
  local function star(cx, cy, r, c)
    local points = {}
    for index = 0, 9 do
      local a = -pi / 2 + index * pi / 5
      local d = index % 2 == 0 and r or r * 0.45
      points[#points + 1], points[#points + 2] = cx + math.cos(a) * d, cy + math.sin(a) * d
    end
    color(c or C.gold)
    for index = 0, 9 do
      local nextIndex = (index + 1) % 10
      G.polygon("fill", cx, cy, points[index * 2 + 1], points[index * 2 + 2], points[nextIndex * 2 + 1], points[nextIndex * 2 + 2])
    end
  end
  -- A Poké Ball for what is caught; only its outline for what is not.
  local function pokeball(cx, cy, r, caught)
    if not caught then
      color(C.line)
      G.setLineWidth(1.5)
      G.circle("line", cx, cy, r)
      G.line(cx - r, cy, cx - r * 0.35, cy)
      G.line(cx + r * 0.35, cy, cx + r, cy)
      G.circle("line", cx, cy, r * 0.35)
      G.setLineWidth(1)
      return
    end
    color(hex("f5f5f5"))
    G.circle("fill", cx, cy, r)
    color(hex("e5383b"))
    G.arc("fill", cx, cy, r, pi, 2 * pi)
    color(hex("20242b"))
    G.setLineWidth(max(1.5, r * 0.28))
    G.line(cx - r, cy, cx + r, cy)
    G.setLineWidth(max(1, r * 0.18))
    G.circle("line", cx, cy, r)
    G.circle("fill", cx, cy, r * 0.42)
    color(hex("f5f5f5"))
    G.circle("fill", cx, cy, r * 0.22)
    G.setLineWidth(1)
  end
  local function triangle(x, y, up, c)
    color(c)
    if up then G.polygon("fill", x, y + 6, x + 4, y, x + 8, y + 6) else G.polygon("fill", x, y, x + 8, y, x + 4, y + 6) end
  end
  local function background(w, h)
    color(C.bg)
    G.rectangle("fill", 0, 0, w, h)
  end
  -- Back and forward buttons with "page/pages" between them, ending at `right`.
  -- Adds the two buttons to `hits` as { page = -1 | 1 } and returns the room taken.
  local function pager(right, y, page, pages, hits)
    if not pages or pages <= 1 then return 0 end
    local label = page .. "/" .. pages
    local lw = widthOf(label, 11) + 12
    local bw, bh = 24, 22
    local x = right - (bw * 2 + lw)
    for index, mark in ipairs({ "<", ">" }) do
      local bx = index == 1 and x or right - bw
      local live = (index == 1 and page > 1) or (index == 2 and page < pages)
      color(live and C.raised or C.card)
      G.rectangle("fill", bx, y, bw, bh, 6, 6)
      text(mark, bx + bw / 2, y + 4, live and C.text or C.faint, 12, "center")
      if live then hits[#hits + 1] = { x = bx, y = y, w = bw, h = bh, page = index == 1 and -1 or 1 } end
    end
    text(label, x + bw + lw / 2, y + 4, C.muted, 11, "center")
    return bw * 2 + lw + 8
  end
  -- A view with nothing to show says why, in the middle.
  function UI.notice(w, h, lines)
    background(w, h)
    local y = h / 2 - #lines * 9
    for index, line in ipairs(lines) do
      text(fit(line, w - 24, 13), w / 2, y + (index - 1) * 18, index == 1 and C.muted or C.faint, 13, "center")
    end
  end

  ---------------------------------------------------------------------------
  -- Web charts: six axes from the middle, HP at the top
  ---------------------------------------------------------------------------
  local AXES = { "HP", "ATK", "DEF", "SPE", "SPD", "SPA" }      -- clockwise from the top
  local function axisPoint(cx, cy, r, index, k)
    local a = -pi / 2 + (index - 1) * pi / 3
    return cx + math.cos(a) * r * k, cy + math.sin(a) * r * k
  end
  local function web(cx, cy, r)
    for ring = 1, 3 do
      local points = {}
      for index = 1, 6 do
        local x, y = axisPoint(cx, cy, r, index, ring / 3)
        points[#points + 1], points[#points + 2] = x, y
      end
      color(ring == 3 and C.line or C.raised)
      G.setLineWidth(1)
      G.polygon("line", points)
    end
    for index = 1, 6 do
      local x, y = axisPoint(cx, cy, r, index, 1)
      color(C.raised)
      G.line(cx, cy, x, y)
    end
  end
  -- values: six numbers 0..1 in AXES order. The shape may bend inwards, so it
  -- is filled as a fan of triangles from the middle.
  local function shape(cx, cy, r, values, c, fillAlpha)
    local points = {}
    for index = 1, 6 do
      local x, y = axisPoint(cx, cy, r, index, max(0.03, min(1, values[index] or 0)))
      points[#points + 1], points[#points + 2] = x, y
    end
    if fillAlpha and fillAlpha > 0 then
      color(c, fillAlpha)
      for index = 0, 5 do
        local nextIndex = (index + 1) % 6
        G.polygon("fill", cx, cy, points[index * 2 + 1], points[index * 2 + 2], points[nextIndex * 2 + 1], points[nextIndex * 2 + 2])
      end
    end
    color(c)
    G.setLineWidth(2)
    G.polygon("line", points)
    for index = 0, 5 do G.circle("fill", points[index * 2 + 1], points[index * 2 + 2], 2.5) end
    G.setLineWidth(1)
  end
  -- Where a corner's caption goes: outside the web, pushed away from the middle.
  local function caption(cx, cy, r, index, lines, size)
    local x, y = axisPoint(cx, cy, r + 8, index, 1)
    local a = -pi / 2 + (index - 1) * pi / 3
    local align = math.abs(math.cos(a)) < 0.2 and "center" or (math.cos(a) > 0 and nil or "right")
    local height = #lines * (size + 2)
    local top = y - height / 2
    if index == 1 then top = y - height elseif index == 4 then top = y end
    for row, line in ipairs(lines) do
      if line.mark then
        local tw = widthOf(line.text, line.size or size)
        local tx = align == "right" and x - tw or (align == "center" and x - tw / 2 or x)
        triangle(tx - 11, top + (row - 1) * (size + 2) + 3, line.mark > 0, line.color)
      end
      text(line.text, x, top + (row - 1) * (size + 2), line.color, line.size or size, align)
    end
  end

  -- One web for a Pokémon: its stats, its IVs and (for the player's own) its EVs,
  -- each in its own colour, with the numbers written at every corner.
  local function legend(label, x, y, c)
    color(c)
    G.circle("fill", x + 4, y + 7, 4)
    text(label, x + 12, y, C.muted, 11)
    return widthOf(label, 11) + 26
  end
  local function drawWebs(model, x, y, w, h)
    local byKey = {}
    for _, row in ipairs(model.rows) do byKey[row.key] = row end
    local evs = model.showEvs == true
    local lx = x + 4
    lx = lx + legend(T("STATS"), lx, y, C.stat)
    lx = lx + legend("IV", lx, y, C.iv)
    if evs then
      legend("EV", lx, y, C.ev)
      text(model.evTotal .. "/510", x + w - 4, y, model.evTotal >= 510 and C.gold or C.muted, 11, "right")
    end
    local lines = evs and 4 or 3
    local function radius(size)
      local labelW = widthOf("000", size + 1)
      for _, key in ipairs(AXES) do labelW = max(labelW, widthOf(T("SHORT")[key], size)) end
      return min(w / 2 - labelW - 22, (h - 20) / 2 - (lines * (size + 2) + 10))
    end
    local size = 11
    if radius(size) < 40 then size = 10 end
    local r = radius(size)
    if r < 26 then
      -- no room for a web worth reading: the same numbers as a small table
      local rowH = max(12, min(20, (h - 36) / 6))
      local colStat, colIv, colEv = x + w * (evs and 0.55 or 0.68), x + w * (evs and 0.76 or 0.94), x + w * 0.96
      for index, row in ipairs(model.rows) do
        local ry = y + 22 + (index - 1) * rowH
        local tint = row.nature == 1 and C.up or row.nature == -1 and C.down or C.text
        text(fit(row.label, colStat - x - 40, 11), x + 4, ry, C.muted, 11)
        if row.nature then triangle(colStat - widthOf(row.stat or "--", 12) - 12, ry + 4, row.nature > 0, tint) end
        text(row.stat or "--", colStat, ry, row.stat and tint or C.faint, 12, "right")
        text(row.iv or "--", colIv, ry, row.iv and (row.iv >= 31 and C.gold or C.iv) or C.faint, 12, "right")
        if evs then text(row.ev or 0, colEv, ry, (row.ev or 0) >= 252 and C.gold or (row.ev or 0) > 0 and C.ev or C.faint, 12, "right") end
      end
      return
    end
    local cx, cy = x + w / 2, y + 20 + (h - 20) / 2
    web(cx, cy, r)
    local top = 1
    for _, key in ipairs(AXES) do top = max(top, byKey[key] and byKey[key].stat or 0) end
    local stats, ivs, evValues, known = {}, {}, {}, false
    for index, key in ipairs(AXES) do
      local row = byKey[key] or {}
      stats[index], ivs[index], evValues[index] = (row.stat or 0) / top, (row.iv or 0) / 31, (row.ev or 0) / 252
      known = known or row.iv ~= nil
    end
    shape(cx, cy, r, stats, C.stat, 0.22)
    if known then shape(cx, cy, r, ivs, C.iv, 0.16) end
    if evs then shape(cx, cy, r, evValues, C.ev, 0.10) end
    for index, key in ipairs(AXES) do
      local row = byKey[key] or {}
      local tint = row.nature == 1 and C.up or row.nature == -1 and C.down or C.stat
      local rows = {
        { text = T("SHORT")[key], color = C.muted },
        { text = row.stat and tostring(row.stat) or "--", color = row.stat and tint or C.faint, size = size + 1, mark = row.nature },
        { text = row.iv and tostring(row.iv) or "--", color = row.iv and (row.iv >= 31 and C.gold or C.iv) or C.faint },
      }
      if evs then rows[4] = { text = tostring(row.ev or 0), color = (row.ev or 0) >= 252 and C.gold or (row.ev or 0) > 0 and C.ev or C.faint } end
      caption(cx, cy, r, index, rows, size)
    end
  end

  ---------------------------------------------------------------------------
  -- One Pokémon in full: the opponent, or one of the player's own
  ---------------------------------------------------------------------------
  local function drawHero(model, x, y, w, h)
    local mon = model.pokemon
    card(x, y, w, h)
    local accent = TYPE[mon.type] or C.faint
    color(accent)
    G.rectangle("fill", x, y + 10, 3, h - 20, 1.5, 1.5)
    local size = h - 16
    avatar(model.pic, x + 12, y + 8, size, mon.hp <= 0)
    local tx, right = x + 12 + size + 12, x + w - 12
    text(mon.levelText, right, y + 9, C.muted, 13, "right")
    local room = right - tx - widthOf(mon.levelText, 13) - 40
    local name = fit(mon.name, room, 16)
    text(name, tx, y + 7, C.text, 16)
    local cursor = tx + widthOf(name, 16) + 6
    cursor = cursor + genderMark(mon.gender, cursor, y + 9, 13)
    if mon.shiny then star(cursor + 7, y + 17, 7) end
    local px = tx
    if mon.type then
      px = px + pill(typeLabel(mon.type), px, y + 31, TYPE[mon.type] or C.faint) + 4
      if mon.type2 and mon.type2 ~= mon.type then px = px + pill(typeLabel(mon.type2), px, y + 31, TYPE[mon.type2] or C.faint) + 4 end
    end
    if mon.status then px = px + pill(mon.status, px, y + 31, STATUS[mon.status] or C.faint) + 4 end
    if mon.shiny and px + widthOf(T("SHINY"), 10) + 12 <= right then pill(T("SHINY"), px, y + 31, C.gold) end
    local ratio = mon.hp / max(1, mon.maxHp)
    local hpW = widthOf(mon.hpText, 12)
    bar(tx, y + h - 20, max(20, right - tx - hpW - 10), 8, ratio, hpColor(ratio))
    text(mon.hpText, right, y + h - 24, C.text, 12, "right")
  end
  local function drawFacts(model, x, y, w, h)
    card(x, y, w, h)
    local cell = (w - 16) / #model.facts
    for index, fact in ipairs(model.facts) do
      local cx = x + 12 + (index - 1) * cell
      text(fit(fact.label, cell - 8, 10), cx, y + 6, C.muted, 10)
      text(fit(fact.value or "--", cell - 8, 13), cx, y + 20, fact.value and C.text or C.faint, 13)
    end
  end
  local function drawMoves(model, x, y, w, h, columns)
    local rows = 4 / columns
    local gap = 6
    local cw, ch = (w - gap * (columns - 1)) / columns, (h - gap * (rows - 1)) / rows
    for slot = 1, 4 do
      local move = model.moves[slot]
      local mx, my = x + ((slot - 1) % columns) * (cw + gap), y + floor((slot - 1) / columns) * (ch + gap)
      if move then
        local c = TYPE[move.type] or C.faint
        card(mx, my, cw, ch, mix(C.card, c, 0.16), 6)
        color(c)
        G.rectangle("fill", mx + 5, my + 6, 3, ch - 12, 1.5, 1.5)
        local ppW = move.pp and widthOf(move.pp, 11) + 8 or 0
        text(fit(move.name, cw - 20 - ppW, 13), mx + 14, my + ch / 2 - 8, C.text, 13)
        if move.pp then text(move.pp, mx + cw - 8, my + ch / 2 - 7, C.muted, 11, "right") end
      else
        card(mx, my, cw, ch, C.card, 6)
        text("--", mx + cw / 2, my + ch / 2 - 7, C.faint, 12, "center")
      end
    end
  end
  function UI.sheet(model, w, h, note)
    background(w, h)
    local pad, gap = 8, 8
    local heroH, factsH = 76, 44
    local team = model.team or {}
    local top = pad
    if #team > 0 or note then
      -- the trainer's team as dots, or what kind of encounter this is
      for index, state in ipairs(team) do
        color(state == "fainted" and C.faint or state == "status" and C.gold or state == "none" and C.line or C.hp)
        G.circle("fill", w - pad - (#team - index) * 14 - 5, top + 6, 4.5)
      end
      if note then text(fit(note, w - 2 * pad - #team * 14 - 8, 11), pad + 2, top - 1, C.muted, 11) end
      top = top + 18
    end
    local wide = w >= 600 and w >= (h - top) * 1.25
    if wide then
      local left = floor(min(380, w * 0.42))
      drawHero(model, pad, top, left, heroH)
      drawFacts(model, pad, top + heroH + gap, left, factsH)
      local my = top + heroH + factsH + gap * 2
      local movesH = max(60, min(150, h - pad - my))
      drawMoves(model, pad, my, left, movesH, movesH >= 120 and 1 or 2)
      local sx = pad + left + gap
      card(sx, top, w - pad - sx, h - pad - top)
      drawWebs(model, sx + 6, top + 8, w - pad - sx - 12, h - pad - top - 14)
    else
      local inner = w - pad * 2
      drawHero(model, pad, top, inner, heroH)
      drawFacts(model, pad, top + heroH + gap, inner, factsH)
      local movesH = inner >= 520 and 30 or 66
      local sy = top + heroH + factsH + gap * 2
      local sh = max(120, h - pad - movesH - gap - sy)
      card(pad, sy, inner, sh)
      drawWebs(model, pad + 6, sy + 8, inner - 12, sh - 14)
      drawMoves(model, pad, sy + sh + gap, inner, movesH, inner >= 520 and 4 or 2)
    end
  end

  ---------------------------------------------------------------------------
  -- The team
  ---------------------------------------------------------------------------
  function UI.party(model, w, h)
    background(w, h)
    local pad, gap = 8, 6
    local count = #model.rows
    if count == 0 then return UI.notice(w, h, { T("NO_PARTY") }) end
    local columns = (w >= 560 and (h - pad * 2) / count < 48) and 2 or 1
    local perColumn = math.ceil(6 / columns)
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    local ch = max(40, min(66, (h - pad * 2 - gap * (perColumn - 1)) / perColumn))
    local hits = {}
    for index, mon in ipairs(model.rows) do
      local x = pad + floor((index - 1) / perColumn) * (cw + gap)
      local y = pad + ((index - 1) % perColumn) * (ch + gap)
      local fainted = not mon.egg and mon.hp <= 0
      hits[#hits + 1] = { x = x, y = y, w = cw, h = ch, slot = index }
      card(x, y, cw, ch, fainted and mix(C.card, C.bg, 0.5) or C.card)
      if model.selected == index then
        -- picked up: the next one clicked trades places with it
        color(C.accent)
        G.setLineWidth(2)
        G.rectangle("line", x + 1, y + 1, cw - 2, ch - 2, 8, 8)
        G.setLineWidth(1)
      end
      local size = ch - 10
      avatar(mon.pic, x + 6, y + 5, size, fainted)
      local tx, right = x + size + 16, x + cw - 10
      if mon.egg then
        text(mon.name, tx, y + ch / 2 - 8, C.muted, 14)
      else
        text(mon.levelText, right, y + 6, C.muted, 12, "right")
        local name = fit(mon.name, right - tx - widthOf(mon.levelText, 12) - 26, 14)
        text(name, tx, y + 5, fainted and C.muted or C.text, 14)
        local cursor = tx + widthOf(name, 14) + 5
        genderMark(mon.gender, cursor, y + 6, 12)
        local ratio = mon.hp / max(1, mon.maxHp)
        local by = y + ch - 15
        local hpW = widthOf(mon.hpText, 11)
        bar(tx, by, max(20, right - tx - hpW - 8), 7, ratio, hpColor(ratio))
        text(mon.hpText, right, by - 4, C.text, 11, "right")
        if ch >= 52 then
          local px = tx
          if mon.status then px = px + pill(mon.status, px, y + 24, STATUS[mon.status] or C.faint, 9) + 6 end
          if mon.item then text(fit(mon.item, right - px, 10), px, y + 25, C.faint, 10) end
        elseif mon.status then
          pill(mon.status, right - widthOf(mon.levelText, 12) - widthOf(mon.status, 9) - 20, y + 5, STATUS[mon.status] or C.faint, 9)
        end
      end
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Wild Pokémon of the area
  ---------------------------------------------------------------------------
  function UI.wild(model, w, h)
    background(w, h)
    local pad, gap = 8, 6
    local hits = {}
    local used = pager(w - pad, pad - 2, model.page, model.pages, hits)
    text(fit(model.area or "", w - pad * 2 - used - 4, 12), pad + 2, pad + 2, C.muted, 12)
    local top = pad + 26
    local count = #model.rows
    if count == 0 then
      text(T("NO_WILD"), w / 2, h / 2 - 8, C.faint, 13, "center")
      return hits
    end
    -- as few columns as keep every row on screen with room to read it
    local columns = max(1, floor((w - pad * 2 + gap) / 190))
    local limit = max(columns, floor((w - pad * 2 + gap) / 128))
    local rows, ch
    while true do
      rows = math.ceil(count / columns)
      ch = (h - top - pad - gap * (rows - 1)) / rows
      if ch >= 38 or columns >= limit then break end
      columns = columns + 1
    end
    ch = max(30, min(52, ch))
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    for index, row in ipairs(model.rows) do
      local x = pad + ((index - 1) % columns) * (cw + gap)
      local y = top + floor((index - 1) / columns) * (ch + gap)
      if y + ch <= h then
        hits[#hits + 1] = { x = x, y = y, w = cw, h = ch, species = row.species }
        card(x, y, cw, ch, C.card, 6)
        local size = ch - 6
        sprite(row.pic, x + 4, y + 3, size)
        local tx, right = x + size + 10, x + cw - 8
        pokeball(right - 7, y + ch / 2 - (ch >= 38 and 8 or 0), 7, row.caught)
        if ch >= 38 then
          text(fit(row.name, right - tx - 18, 13), tx, y + ch / 2 - 16, C.text, 13)
          text(row.chanceText, right, y + ch / 2 + 1, C.text, 11, "right")
          local level = row.levelText .. (row.method and ("  " .. row.method) or "")
          text(fit(level, right - tx - widthOf(row.chanceText, 11) - 6, 11), tx, y + ch / 2 + 1, C.muted, 11)
        else
          local tail = row.levelText .. "  " .. row.chanceText
          text(tail, right - 18, y + ch / 2 - 7, C.muted, 11, "right")
          text(fit(row.name, right - 18 - tx - widthOf(tail, 11) - 6, 13), tx, y + ch / 2 - 8, C.text, 13)
        end
      end
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Item radar: a scope with the player in the middle, and the nearest items
  ---------------------------------------------------------------------------
  local REACH = 8           -- tiles from the middle to the rim
  local SCOPE, SWEEP, VISIBLE, HIDDEN = hex("0c1712"), hex("3fcf6b"), hex("f2b33d"), hex("58c8e8")
  local function mark(x, y, hidden, r, a)
    if hidden then
      color(HIDDEN, a)
      G.setLineWidth(2)
      G.polygon("line", x, y - r, x + r, y, x, y + r, x - r, y)
      G.setLineWidth(1)
    else
      color(VISIBLE, a)
      G.circle("fill", x, y, r * 0.8)
    end
  end
  function UI.radar(model, w, h, now)
    background(w, h)
    local pad = 8
    local wide = w >= h * 1.35
    local scope = wide and min(h - pad * 2, w * 0.6) or min(w - pad * 2, h - pad * 2 - 96)
    scope = max(80, scope)
    local sx, sy = wide and pad or (w - scope) / 2, pad
    local cx, cy, r = sx + scope / 2, sy + scope / 2, scope / 2
    color(SCOPE)
    G.circle("fill", cx, cy, r)
    -- the sweep and its fading tail
    local angle = (now * 1.6) % (2 * pi)
    for k = 0, 11 do
      color(SWEEP, 0.16 * (1 - k / 12))
      G.arc("fill", cx, cy, r, angle - (k + 1) * 0.06, angle - k * 0.06)
    end
    color(SWEEP, 0.18)
    for ring = 1, 3 do G.circle("line", cx, cy, r * ring / 4) end
    G.line(cx - r, cy, cx + r, cy)
    G.line(cx, cy - r, cx, cy + r)
    color(SWEEP, 0.9)
    G.line(cx, cy, cx + math.cos(angle) * r, cy + math.sin(angle) * r)
    for index = #model.items, 1, -1 do
      local item = model.items[index]
      local distance = math.sqrt(item.dx * item.dx + item.dy * item.dy)
      local inside = distance <= REACH
      local k = inside and distance / REACH or 0.94
      local dirX, dirY = distance > 0 and item.dx / distance or 0, distance > 0 and item.dy / distance or 0
      local blink = inside and (floor(now / 0.35 + index) % 2 == 0) and 1 or 0.55
      mark(cx + dirX * r * k, cy + dirY * r * k, item.hidden, inside and max(4, r / 22) or max(3, r / 34), inside and blink or 0.5)
    end
    color(SWEEP, 0.5)
    G.circle("line", cx, cy, r)
    color(C.white)
    G.circle("fill", cx, cy, 3.5)

    -- the readout: where, how many are left, and the nearest ones
    local lx = wide and sx + scope + 12 or pad
    local ly = wide and pad or sy + scope + 8
    local lw = w - pad - lx
    card(lx, ly, lw, h - pad - ly)
    text(fit(model.area or "", lw - 20, 13), lx + 10, ly + 8, C.text, 13)
    local left, total = model.visibleLeft + model.hiddenLeft, model.visibleTotal + model.hiddenTotal
    local cy2 = ly + 30
    mark(lx + 15, cy2 + 6, false, 5, 1)
    text(model.visibleLeft, lx + 25, cy2 - 1, C.text, 12)
    mark(lx + 60, cy2 + 6, true, 5, 1)
    text(model.hiddenLeft, lx + 70, cy2 - 1, C.text, 12)
    text(left .. "/" .. total .. " " .. T("LEFT"), lx + lw - 10, cy2 - 1, C.muted, 11, "right")
    local y = cy2 + 22
    if #model.items == 0 then
      text(fit(model.message or "", lw - 20, 12), lx + 10, y, C.faint, 12)
    end
    for index = 1, #model.items do
      if y + 18 > h - pad then break end
      local item = model.items[index]
      mark(lx + 15, y + 7, item.hidden, 4.5, 1)
      text(item.where, lx + lw - 10, y, C.muted, 11, "right")
      text(fit(item.name, lw - 40 - widthOf(item.where, 11), 12), lx + 26, y - 1, C.text, 12)
      y = y + 18
    end
  end

  ---------------------------------------------------------------------------
  -- Tools: one click for what the game hides behind several menus.
  -- Returns the places that can be clicked: { x, y, w, h, tool }.
  ---------------------------------------------------------------------------
  function UI.tools(model, w, h, now)
    background(w, h)
    local pad, gap = 8, 6
    local hits = {}
    local note = model.flash and now < model.flash.untilAt and model.flash.text or model.note
    text(fit(note or "", w - pad * 2, 12), pad + 2, pad, model.flash and now < model.flash.untilAt and C.gold or C.muted, 12)
    local top = pad + 22
    local count = #model.tools
    if count == 0 then
      text(T("NO_TOOLS"), w / 2, h / 2 - 8, C.faint, 13, "center")
      return hits
    end
    local columns = max(1, floor((w - pad * 2 + gap) / 170))
    local limit = max(columns, floor((w - pad * 2 + gap) / 120))
    local rows, ch
    while true do
      rows = math.ceil(count / columns)
      ch = (h - top - pad - gap * (rows - 1)) / rows
      if ch >= 40 or columns >= limit then break end
      columns = columns + 1
    end
    ch = max(30, min(54, ch))
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    for index, tool in ipairs(model.tools) do
      local x = pad + ((index - 1) % columns) * (cw + gap)
      local y = top + floor((index - 1) / columns) * (ch + gap)
      if y + ch <= h then
        local tint = tool.on and C.gold or C.accent
        card(x, y, cw, ch, tool.ready and mix(C.card, tint, 0.22) or C.card, 6)
        color(tool.ready and tint or C.line)
        G.rectangle("fill", x + 5, y + 7, 3, ch - 14, 1.5, 1.5)
        local right = x + cw - 8
        local badgeW = tool.badge and widthOf(tool.badge, 11) + 8 or 0
        -- its picture: the item's own icon, or the Pokémon that knows the move
        local iconSize = min(32, ch - 8)
        local hasIcon = tool.pic ~= nil and cw >= 110
        if hasIcon then
          sprite(tool.pic, x + 12, y + (ch - iconSize) / 2, iconSize, not tool.ready)
          x, cw = x + iconSize + 4, cw - iconSize - 4
        end
        if tool.badge then text(tool.badge, right, y + (ch >= 40 and 7 or ch / 2 - 7), tool.ready and C.text or C.faint, 11, "right") end
        if ch >= 40 and tool.sub then
          text(fit(tool.label, cw - 24 - badgeW, 13), x + 14, y + ch / 2 - 16, tool.ready and C.text or C.faint, 13)
          text(fit(tool.sub, cw - 22, 10), x + 14, y + ch / 2 + 2, tool.ready and C.muted or C.faint, 10)
        else
          text(fit(tool.label, cw - 24 - badgeW, 13), x + 14, y + ch / 2 - 8, tool.ready and C.text or C.faint, 13)
        end
        if hasIcon then x, cw = x - iconSize - 4, cw + iconSize + 4 end
        if tool.ready then hits[#hits + 1] = { x = x, y = y, w = cw, h = ch, tool = tool } end
      end
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Trainer: who is playing, the badges, the Pokédex and the save's numbers
  ---------------------------------------------------------------------------
  local function stat(label, value, x, y, w)
    text(fit(label, w, 10), x, y, C.muted, 10)
    text(fit(value, w, 14), x, y + 13, C.text, 14)
  end
  local function progress(label, have, total, x, y, w, fill)
    text(label, x, y, C.muted, 11)
    text(have .. "/" .. total, x + w, y, C.text, 11, "right")
    bar(x, y + 17, w, 6, have / max(1, total), have >= total and C.gold or fill)
  end
  function UI.trainer(model, w, h)
    background(w, h)
    local pad, gap = 8, 8
    local wide = w >= 640
    local colW = wide and (w - pad * 2 - gap) / 2 or w - pad * 2
    local x, y = pad, pad
    -- who
    card(x, y, colW, 72)
    text(fit(model.name, colW - 110, 18), x + 12, y + 9, C.text, 18)
    text("ID " .. model.id, x + colW - 12, y + 13, C.muted, 12, "right")
    local third = (colW - 24) / 2
    stat(T("MONEY"), model.money, x + 12, y + 34, third - 6)
    stat(T("TIME"), model.time, x + 12 + third, y + 34, third - 6)
    y = y + 72 + gap
    -- badges
    local bh = 78
    card(x, y, colW, bh)
    text(T("BADGES"), x + 12, y + 7, C.muted, 11)
    text(model.badgeCount .. "/8", x + colW - 12, y + 7, model.badgeCount >= 8 and C.gold or C.text, 11, "right")
    local slot = (colW - 24) / 8
    for index = 1, 8 do
      local cx, cy = x + 12 + (index - 0.5) * slot, y + 40
      local r = min(16, slot / 2 - 3)
      local got = model.badges[index]
      local pic = model.badgePics and model.badgePics[index]
      if pic then
        -- the badge itself, as the trainer card draws it; faded until it is won
        if not got then
          color(C.line)
          G.circle("line", cx, cy, r)
        end
        local size = r * 2
        if got then sprite(pic, cx - r, cy - r, size) else
          G.setColor(0.35, 0.38, 0.42, 0.35)
          local scale = max(1, floor(size / 16))
          G.draw(pic.image, pic.quads[0], floor(cx - 8 * scale), floor(cy - 8 * scale), 0, scale, scale)
        end
      else
        color(got and C.gold or C.line)
        G.circle(got and "fill" or "line", cx, cy, r)
        text(index, cx, cy - 7, got and C.black or C.faint, 11, "center")
      end
      if slot >= 46 then text(fit(model.badgeNames[index], slot - 2, 9), cx, y + 58, got and C.muted or C.faint, 9, "center") end
    end
    if wide then x, y = pad + colW + gap, pad else y = y + bh + gap end
    -- Pokédex
    local rows = #model.dex
    card(x, y, colW, 26 + rows * 34)
    text(T("POKEDEX"), x + 12, y + 7, C.muted, 11)
    for index, row in ipairs(model.dex) do
      progress(row.label, row.have, row.total, x + 12, y + 26 + (index - 1) * 34, colW - 24, row.fill == "seen" and C.accent or C.hp)
    end
    y = y + 26 + rows * 34 + gap
    -- the save's counters
    local left = h - pad - y
    if #model.stats > 0 and left >= 40 then
      card(x, y, colW, left)
      local columns = colW >= 420 and 3 or 2
      local cell = (colW - 24) / columns
      for index, row in ipairs(model.stats) do
        local sx = x + 12 + ((index - 1) % columns) * cell
        local sy = y + 8 + floor((index - 1) / columns) * 36
        if sy + 30 <= y + left then stat(row.label, row.value, sx, sy, cell - 8) end
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Progress: how much of each area's wild Pokémon is caught
  ---------------------------------------------------------------------------
  function UI.progress(model, w, h)
    background(w, h)
    local pad, gap = 8, 6
    local y = pad
    card(pad, y, w - pad * 2, 58)
    text(fit(model.here.name, w - 150, 14), pad + 12, y + 8, C.text, 14)
    text(T("HERE_NOW"), w - pad - 12, y + 10, C.muted, 11, "right")
    local half = (w - pad * 2 - 36) / 2
    progress("Pokémon", model.here.caught, model.here.total, pad + 12, y + 28, half, C.hp)
    progress(T("ITEMS"), model.here.items, model.here.itemsTotal, pad + 24 + half, y + 28, half, C.gold)
    y = y + 58 + gap
    local hits = {}
    pager(w - pad, y - 2, model.page, model.pages, hits)
    text(T("AREAS"):format(model.done, #model.areas), pad + 2, y + 3, C.muted, 11)
    y = y + 26
    local columns = max(1, floor((w - pad * 2 + gap) / 230))
    local rowH = 26
    local perColumn = max(1, floor((h - pad - y + 4) / rowH))
    model.fits = columns * perColumn
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    for index = 1, model.fits do
      local area = model.areas[(model.page - 1) * model.fits + index]
      if area then
        local x = pad + floor((index - 1) / perColumn) * (cw + gap)
        local ry = y + ((index - 1) % perColumn) * rowH
        local complete = area.caught >= area.total
        local count = area.caught .. "/" .. area.total
        text(count, x + cw - 6, ry + 1, complete and C.gold or C.text, 11, "right")
        text(fit(area.name, cw - widthOf(count, 11) - 20, 12), x + 6, ry, area.current and C.accent or (complete and C.muted or C.text), 12)
        bar(x + 6, ry + 17, cw - 12, 4, area.caught / max(1, area.total), complete and C.gold or C.hp)
      end
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Maps: the area being walked, cell by cell, and the region around it
  ---------------------------------------------------------------------------
  UI.terrain = { blocked = hex("171b21"), walk = hex("3a4350"), grass = hex("2f7d4a"), water = hex("2c6fb3"),
    warp = hex("f2b33d"), ledge = hex("4a5564") }
  local function arrowHead(cx, cy, r, facing)
    local a = facing == "up" and -pi / 2 or facing == "down" and pi / 2 or facing == "left" and pi or 0
    color(C.black)
    G.circle("fill", cx, cy, r + 1.5)
    color(C.white)
    G.polygon("fill", cx + math.cos(a) * r, cy + math.sin(a) * r,
      cx + math.cos(a + 2.5) * r, cy + math.sin(a + 2.5) * r, cx + math.cos(a - 2.5) * r, cy + math.sin(a - 2.5) * r)
  end
  function UI.map(model, w, h, now)
    background(w, h)
    local pad = 8
    text(fit(model.name or "", w - pad * 2 - 80, 13), pad + 2, pad, C.text, 13)
    text(model.width .. " x " .. model.height, w - pad - 2, pad + 1, C.faint, 11, "right")
    local top = pad + 24
    local bottom = #model.exits > 0 and 20 or 0
    local roomW, roomH = w - pad * 2, h - top - pad - bottom
    if not model.image or roomW < 20 or roomH < 20 then return end
    local cell = min(roomW / model.width, roomH / model.height)
    -- the game's own tiles are shown no bigger than twice their size
    if model.native then cell = min(cell, 32) end
    if cell >= 1 and not model.native then cell = floor(cell) end
    -- a map too big to read whole is followed around the player instead
    local MIN_CELL = 8
    local follow = model.native and cell < MIN_CELL
    if follow then cell = MIN_CELL end
    local mw, mh = model.width * cell, model.height * cell
    local ox, oy = floor(pad + (roomW - mw) / 2), floor(top + (roomH - mh) / 2)
    if follow then
      local function along(room, size, at, start)
        if size <= room then return floor(start + (room - size) / 2) end
        return floor(start + max(room - size, min(0, room / 2 - at)))
      end
      ox = along(roomW, mw, (model.player.x + 0.5) * cell, pad)
      oy = along(roomH, mh, (model.player.y + 0.5) * cell, top)
    end
    G.setScissor(pad, top, roomW, roomH)
    G.setColor(1, 1, 1, 1)
    G.draw(model.image, ox, oy, 0, mw / model.image:getWidth(), mh / model.image:getHeight())
    color(C.line)
    G.rectangle("line", ox - 0.5, oy - 0.5, mw + 1, mh + 1)
    local dot = max(2, min(6, cell * 0.45))
    for _, marker in ipairs(model.markers) do
      local mx, my = ox + (marker.x + 0.5) * cell, oy + (marker.y + 0.5) * cell
      if marker.kind == "item" then
        color(VISIBLE)
        G.circle("fill", mx, my, dot)
      elseif marker.kind == "hidden" then
        color(HIDDEN)
        G.setLineWidth(1.5)
        G.polygon("line", mx, my - dot, mx + dot, my, mx, my + dot, mx - dot, my)
        G.setLineWidth(1)
      elseif marker.kind == "trainer" then
        color(C.hpLow)
        G.rectangle("fill", mx - dot, my - dot, dot * 2, dot * 2, 1, 1)
      else
        color(C.muted)
        G.circle("fill", mx, my, dot * 0.8)
      end
    end
    local px, py = ox + (model.player.x + 0.5) * cell, oy + (model.player.y + 0.5) * cell
    color(C.white, 0.25 + 0.2 * math.sin(now * 4))
    G.circle("line", px, py, max(7, cell) + 3)
    arrowHead(px, py, max(5, min(9, cell * 0.8)), model.player.facing)
    G.setScissor()
    -- where the edges lead
    local parts = {}
    for _, exit in ipairs(model.exits) do parts[#parts + 1] = exit.mark .. " " .. exit.name end
    if #parts > 0 then text(fit(table.concat(parts, "     "), w - pad * 2, 11), pad + 2, h - pad - 14, C.muted, 11) end
  end

  function UI.region(model, w, h, now)
    background(w, h)
    local pad = 8
    text(fit(model.title or "", w - pad * 2, 13), pad + 2, pad, C.text, 13)
    local top = pad + 24
    local roomW, roomH = w - pad * 2, h - top - pad
    if model.town then
      -- the game's Town Map, in whole multiples of its size when there is room
      if roomW < 20 or roomH < 20 then return end
      local k = min(roomW / model.width, roomH / model.height)
      if k >= 1 then k = floor(k * 2) / 2 end
      local ox, oy = floor(pad + (roomW - model.width * k) / 2), floor(top + (roomH - model.height * k) / 2)
      G.setColor(1, 1, 1, 1)
      G.draw(model.image, model.quad, ox, oy, 0, k, k)
      if model.playerX then
        local px, py = ox + model.playerX * k, oy + model.playerY * k
        local pulse = 0.5 + 0.5 * math.sin(now * 5)
        color(C.black)
        G.circle("fill", px, py, 4 * max(1, k * 0.6) + 1.5)
        color(hex("ff3b30"))
        G.circle("fill", px, py, 4 * max(1, k * 0.6))
        color(C.white, 0.9 - 0.6 * pulse)
        G.setLineWidth(2)
        G.circle("line", px, py, (6 + 6 * pulse) * max(1, k * 0.6))
        G.setLineWidth(1)
      end
      return
    end
    local spanW, spanH = model.maxX - model.minX, model.maxY - model.minY
    if spanW <= 0 or spanH <= 0 or roomW < 20 or roomH < 20 then return end
    local k = min(roomW / spanW, roomH / spanH)
    local ox, oy = pad + (roomW - spanW * k) / 2, top + (roomH - spanH * k) / 2
    local current
    for _, area in ipairs(model.areas) do
      local x, y = ox + (area.x - model.minX) * k, oy + (area.y - model.minY) * k
      local aw, ah = max(2, area.w * k - 1), max(2, area.h * k - 1)
      local fill = area.town and mix(C.card, C.accent, 0.45) or mix(C.card, C.hp, area.ratio and (0.18 + 0.4 * area.ratio) or 0.2)
      if area.complete then fill = mix(C.card, C.gold, 0.5) end
      color(fill)
      G.rectangle("fill", x, y, aw, ah, 2, 2)
      if area.current then current = { x = x, y = y, w = aw, h = ah, area = area } end
      local label = area.name
      local size = (aw >= 70 and ah >= 16) and 10 or 9
      if widthOf(label, size) + 4 <= aw and ah >= size + 3 then
        text(label, x + aw / 2, y + ah / 2 - size / 2 - 1, C.text, size, "center")
      end
    end
    if current then
      color(C.white, 0.7 + 0.3 * math.sin(now * 4))
      G.setLineWidth(2)
      G.rectangle("line", current.x - 1, current.y - 1, current.w + 2, current.h + 2, 3, 3)
      G.setLineWidth(1)
      if model.player then
        local px, py = ox + (model.player.x - model.minX) * k, oy + (model.player.y - model.minY) * k
        arrowHead(px, py, 5, model.player.facing)
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Bag, moves, Day-Care and the encounter counter
  ---------------------------------------------------------------------------
  -- Text over several lines, cut to a number of them.
  local function para(value, x, y, w, c, size, lines)
    G.setFont(font(size))
    local _, wrapped = font(size):getWrap(tostring(value or ""), max(20, w))
    color(c)
    for index = 1, min(lines, #wrapped) do
      local line = wrapped[index]
      if index == lines and #wrapped > lines then line = fit(line .. "..", w, size) end
      G.print(line, floor(x), floor(y + (index - 1) * (size + 3)))
    end
    return min(lines, #wrapped) * (size + 3)
  end
  local function chip(label, x, y, active)
    local w = widthOf(label, 11) + 16
    color(active and C.accent or C.card)
    G.rectangle("fill", x, y, w, 22, 11, 11)
    text(label, x + 8, y + 4, active and C.white or C.muted, 11)
    return w
  end

  -- Returns the places that can be clicked: { x, y, w, h, pocket = n } or { ..., row = n }.
  function UI.bag(model, w, h)
    background(w, h)
    local pad, gap = 8, 4
    local hits = {}
    local x = pad
    for index, pocket in ipairs(model.pockets) do
      local cw = chip(pocket.label .. " " .. pocket.count, x, pad, index == model.pocket)
      hits[#hits + 1] = { x = x, y = pad, w = cw, h = 22, pocket = index }
      x = x + cw + 6
    end
    local top = pad + 30
    -- the page buttons sit under the list, clear of the pocket buttons
    local paged = (model.pages or 1) > 1
    local footer = (model.selected and 46 or 0) + (paged and 28 or 0)
    local rowH = 28
    local columns = max(1, floor((w - pad * 2 + gap) / 240))
    local perColumn = max(1, floor((h - top - pad - footer) / rowH))
    model.fits = columns * perColumn
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    if #model.rows == 0 then text(T("EMPTY"), w / 2, top + 20, C.faint, 12, "center") end
    for index = 1, model.fits do
      local at = (model.page - 1) * model.fits + index
      local row = model.rows[at]
      if row then
        local rx = pad + floor((index - 1) / perColumn) * (cw + gap)
        local ry = top + ((index - 1) % perColumn) * rowH
        if at == model.selectedIndex then card(rx, ry, cw, rowH - 2, C.raised, 5) end
        sprite(row.pic, rx + 4, ry + 1, 24)
        text("x" .. row.qty, rx + cw - 8, ry + 6, C.muted, 11, "right")
        text(fit(row.name, cw - 44 - widthOf("x" .. row.qty, 11), 12), rx + 34, ry + 5, C.text, 12)
        hits[#hits + 1] = { x = rx, y = ry, w = cw, h = rowH, row = at }
      end
    end
    if paged then pager(w - pad, h - pad - footer + 4, model.page, model.pages, hits) end
    if model.selected then
      card(pad, h - pad - 42, w - pad * 2, 42)
      para(model.selected.description, pad + 10, h - pad - 37, w - pad * 2 - 20, C.muted, 11, 2)
    end
    return hits
  end

  function UI.moves(model, w, h)
    background(w, h)
    local pad, gap = 8, 6
    text(fit(model.title or "", w - pad * 2, 12), pad + 2, pad, C.muted, 12)
    local top = pad + 22
    local columns = (w >= 560 and (h - top) < 330) and 2 or 1
    local rows = math.ceil(4 / columns)
    local cw, ch = (w - pad * 2 - gap * (columns - 1)) / columns, (h - top - pad - gap * (rows - 1)) / rows
    ch = max(44, min(110, ch))
    for slot = 1, 4 do
      local move = model.moves[slot]
      local x, y = pad + ((slot - 1) % columns) * (cw + gap), top + floor((slot - 1) / columns) * (ch + gap)
      if y + ch <= h + 1 then
        if move then
          local c = TYPE[move.type] or C.faint
          card(x, y, cw, ch, mix(C.card, c, 0.12), 6)
          color(c)
          G.rectangle("fill", x + 5, y + 7, 3, ch - 14, 1.5, 1.5)
          local right = x + cw - 10
          text(move.pp or "", right, y + 8, C.muted, 11, "right")
          local name = fit(move.name, cw - 150, 14)
          text(name, x + 14, y + 6, C.text, 14)
          local px = x + 14 + widthOf(name, 14) + 8
          if move.type then px = px + pill(typeLabel(move.type), px, y + 7, c) + 4 end
          if move.effect then pill(move.effect.label, px, y + 7, move.effect.good and C.hp or move.effect.bad and C.hpLow or C.faint) end
          local line = ("%s   %s %s   %s %s"):format(move.category or "", T("POWER"), move.power or "--", T("ACCURACY"), move.accuracy or "--")
          text(fit(line, cw - 24, 11), x + 14, y + 27, C.muted, 11)
          if ch >= 62 and move.description then
            para(move.description, x + 14, y + 44, cw - 26, C.faint, 11, max(1, floor((ch - 48) / 14)))
          end
        else
          card(x, y, cw, ch, C.card, 6)
          text("--", x + cw / 2, y + ch / 2 - 7, C.faint, 12, "center")
        end
      end
    end
  end

  function UI.daycare(model, w, h)
    background(w, h)
    local pad, gap = 8, 8
    local y = pad
    for _, place in ipairs(model.places) do
      local rows = max(1, #place.mons)
      local ch = 30 + rows * 46 + (place.egg and 26 or 0)
      card(pad, y, w - pad * 2, ch)
      text(place.name, pad + 12, y + 8, C.muted, 11)
      if #place.mons == 0 then text(T("DAYCARE_EMPTY"), pad + 12, y + 34, C.faint, 12) end
      for index, mon in ipairs(place.mons) do
        local ry = y + 28 + (index - 1) * 46
        avatar(mon.pic, pad + 10, ry, 40)
        text(fit(mon.name, w - 250, 14), pad + 60, ry + 3, C.text, 14)
        text(mon.levels, pad + 60, ry + 22, mon.gained > 0 and C.hp or C.muted, 12)
        text(mon.steps, w - pad - 12, ry + 4, C.muted, 11, "right")
        text(mon.cost, w - pad - 12, ry + 22, C.text, 12, "right")
      end
      if place.egg then
        pill(T("EGG_READY"), pad + 12, y + ch - 26, C.gold, 11)
      end
      y = y + ch + gap
    end
  end

  -- Returns the places that can be clicked: { x, y, w, h, action = "reset" }.
  function UI.counter(model, w, h)
    background(w, h)
    local pad, gap = 8, 6
    local hits = {}
    card(pad, pad, w - pad * 2, 64)
    local third = (w - pad * 2 - 24) / 3
    stat(T("ENCOUNTERS"), model.total, pad + 12, pad + 8, third - 6)
    stat(T("SINCE_SHINY"), model.since, pad + 12 + third, pad + 8, third - 6)
    stat(T("SHINIES"), model.shinies, pad + 12 + third * 2, pad + 8, third - 6)
    text(fit(T("LUCK"):format(model.luck), w - pad * 2 - 110, 11), pad + 12, pad + 44, model.luckHigh and C.gold or C.muted, 11)
    local bw = widthOf(T("RESET"), 11) + 20
    card(w - pad - bw - 8, pad + 38, bw, 20, C.raised, 10)
    text(T("RESET"), w - pad - 8 - bw / 2, pad + 41, C.text, 11, "center")
    hits[#hits + 1] = { x = w - pad - bw - 8, y = pad + 36, w = bw, h = 24, action = "reset" }
    local top = pad + 64 + gap
    local columns = max(1, floor((w - pad * 2 + gap) / 200))
    local rowH = 30
    local perColumn = max(1, floor((h - top - pad) / rowH))
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    for index = 1, min(#model.rows, columns * perColumn) do
      local row = model.rows[index]
      local x = pad + floor((index - 1) / perColumn) * (cw + gap)
      local y = top + ((index - 1) % perColumn) * rowH
      sprite(row.pic, x + 2, y, 28)
      text(row.count, x + cw - 6, y + 7, C.text, 12, "right")
      text(fit(row.name, cw - 46 - widthOf(row.count, 12), 12), x + 36, y + 7, C.text, 12)
      color(C.line)
      G.rectangle("fill", x + 36, y + rowH - 4, cw - 42, 2)
      color(C.accent)
      G.rectangle("fill", x + 36, y + rowH - 4, (cw - 42) * row.count / max(1, model.top), 2)
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Pokédex: every species in a grid, and one of them in full
  ---------------------------------------------------------------------------
  -- Returns the places that can be clicked: { x, y, w, h, entry = n | filter = true | back = true }.
  function UI.dex(model, w, h)
    background(w, h)
    local pad, gap = 8, 4
    local hits = {}
    if model.detail then
      local d = model.detail
      local bw = chip("<  " .. T("BACK"), pad, pad, false)
      hits[#hits + 1] = { x = pad, y = pad, w = bw, h = 22, back = true }
      text(("#%03d"):format(d.number), w - pad - 2, pad + 4, C.muted, 12, "right")
      local top = pad + 30
      local wide = w >= 560
      local leftW = wide and floor(min(300, w * 0.42)) or w - pad * 2
      card(pad, top, leftW, 104)
      avatar(d.pic, pad + 10, top + 10, 84, not d.seen)
      local tx = pad + 104
      text(fit(d.name, leftW - 114, 16), tx, top + 10, C.text, 16)
      if d.category then text(fit(d.category, leftW - 114, 11), tx, top + 32, C.muted, 11) end
      local px = tx
      if d.type then
        px = px + pill(typeLabel(d.type), px, top + 50, TYPE[d.type] or C.faint) + 4
        if d.type2 and d.type2 ~= d.type then pill(typeLabel(d.type2), px, top + 50, TYPE[d.type2] or C.faint) end
      end
      text(fit(table.concat(d.facts, "   "), leftW - 114, 11), tx, top + 74, C.muted, 11)
      pokeball(pad + leftW - 16, top + 16, 7, d.caught)
      local y = top + 104 + 8
      local textW = leftW - 20
      local function block(title, body, lines)
        if not body or body == "" or y + 30 > h then return end
        text(title, pad + 10, y, C.muted, 10)
        y = y + 14 + para(body, pad + 10, y + 14, textW, C.text, 11, lines) + 6
      end
      block(T("HERE_LIST"), d.here, 4)
      block(T("ABILITY"), d.abilities, 1)
      block(T("EVOLVES"), d.evolves, 2)
      block(T("WHERE"), d.where, wide and 6 or 3)
      if d.description then block(T("ENTRY"), d.description, 5) end
      if d.base then
        local sx, sy = wide and pad + leftW + 8 or pad, wide and top or y + 4
        local sw, sh = w - pad - sx, h - pad - sy
        if sh >= 150 and sw >= 200 then
          card(sx, sy, sw, sh)
          text(T("BASE"), sx + 10, sy + 8, C.muted, 11)
          text(d.baseTotal, sx + sw - 10, sy + 8, C.text, 11, "right")
          local size = 11
          local r = min(sw / 2 - 58, (sh - 30) / 2 - 34)
          if r >= 24 then
            local cx, cy = sx + sw / 2, sy + 24 + (sh - 24) / 2
            web(cx, cy, r)
            local values = {}
            for index, key in ipairs(AXES) do values[index] = (d.base[key] or 0) / 160 end
            shape(cx, cy, r, values, C.stat, 0.25)
            for index, key in ipairs(AXES) do
              caption(cx, cy, r, index, { { text = T("SHORT")[key], color = C.muted },
                { text = tostring(d.base[key] or "--"), color = C.text, size = size + 1 } }, size)
            end
          end
        end
      end
      return hits
    end
    local fw0 = widthOf(model.filterLabel, 11) + 130
    text(fit(model.summary, w - pad * 2 - fw0, 12), pad + 2, pad + 4, C.muted, 12)
    local fw = widthOf(model.filterLabel, 11) + 16
    local used = pager(w - pad, pad, model.page, model.pages, hits)
    chip(model.filterLabel, w - pad - fw - used, pad, model.filtered)
    hits[#hits + 1] = { x = w - pad - fw - used, y = pad, w = fw, h = 22, filter = true }
    local top = pad + 30
    local columns = max(1, floor((w - pad * 2 + gap) / 170))
    local rowH = 30
    local perColumn = max(1, floor((h - top - pad) / rowH))
    model.fits = columns * perColumn
    local cw = (w - pad * 2 - gap * (columns - 1)) / columns
    for index = 1, model.fits do
      local entry = model.rows[(model.page - 1) * model.fits + index]
      if entry then
        local x = pad + floor((index - 1) / perColumn) * (cw + gap)
        local y = top + ((index - 1) % perColumn) * rowH
        card(x, y, cw, rowH - 3, C.card, 5)
        if entry.seen then sprite(entry.pic, x + 3, y, 27, not entry.caught) end
        text(("%03d"):format(entry.number), x + 34, y + 7, C.faint, 10)
        text(fit(entry.seen and entry.name or "?????", cw - 84, 12), x + 60, y + 6, entry.seen and C.text or C.faint, 12)
        pokeball(x + cw - 12, y + 13, 6, entry.caught)
        hits[#hits + 1] = { x = x, y = y, w = cw, h = rowH - 3, entry = entry.number }
      end
    end
    return hits
  end

  ---------------------------------------------------------------------------
  -- Notices: things worth knowing that happened while playing
  ---------------------------------------------------------------------------
  function UI.notices(model, w, h, now)
    background(w, h)
    local pad, gap = 8, 6
    if #model.rows == 0 then
      text(T("NO_NOTICES"), w / 2, h / 2 - 8, C.faint, 13, "center")
      return
    end
    local y = pad
    for _, row in ipairs(model.rows) do
      if y + 46 > h then break end
      local fresh = now - row.at < 12
      local tint = row.tone == "gold" and C.gold or row.tone == "bad" and C.hpLow or C.accent
      card(pad, y, w - pad * 2, 44, fresh and mix(C.card, tint, 0.22) or C.card)
      color(tint)
      G.rectangle("fill", pad + 5, y + 7, 3, 30, 1.5, 1.5)
      text(row.clock, w - pad - 10, y + 6, C.faint, 10, "right")
      text(fit(row.title, w - pad * 2 - 70, 13), pad + 14, y + 5, C.text, 13)
      text(fit(row.detail or "", w - pad * 2 - 28, 11), pad + 14, y + 24, C.muted, 11)
      y = y + 44 + gap
    end
  end

  ---------------------------------------------------------------------------
  -- PC boxes: one box as a grid; a click shows that Pokémon's sheet.
  -- Only shown: nothing here moves, deposits or withdraws anything.
  ---------------------------------------------------------------------------
  -- Returns the places that can be clicked: { slot = n } | { page = -1|1 } | { back = true }.
  -- A small padlock: shut for a locked box, open otherwise.
  local function padlock(x, y, size, shut, tone)
    color(tone)
    local bw, bh = size * 0.8, size * 0.55
    local bx, by = x + (size - bw) / 2, y + size - bh
    G.rectangle("fill", bx, by, bw, bh, 2, 2)
    G.setLineWidth(max(1.5, size / 9))
    local r = bw * 0.32
    local cx = x + size / 2
    if shut then
      G.arc("line", "open", cx, by, r, math.pi, 2 * math.pi)
    else
      G.arc("line", "open", cx + r * 0.9, by - r * 0.35, r, math.pi, 2 * math.pi)
    end
    G.setLineWidth(1)
  end
  -- A button in the PC footer; returns its width.
  local function footButton(label, x, y, tone, hits, hit)
    local bw = widthOf(label, 11) + 18
    color(tone or C.raised)
    G.rectangle("fill", x, y, bw, 22, 6, 6)
    text(label, x + bw / 2, y + 4, C.text, 11, "center")
    hit.x, hit.y, hit.w, hit.h = x, y, bw, 22
    hits[#hits + 1] = hit
    return bw
  end

  -- Returns the places that can be clicked: { page }, { back }, { slot }, { lock },
  -- { openSort }, { sort = id }, { confirm }, { cancel }, { undo }.
  function UI.box(model, w, h)
    background(w, h)
    local pad, gap = 8, 4
    local hits = {}
    local detail = model.detail
    local wide = w >= 620
    if detail and not wide then
      -- narrow: the sheet takes the panel, with a way back to the box
      local bw = chip("<  " .. model.name, pad, pad, false)
      hits[#hits + 1] = { x = pad, y = pad, w = bw, h = 22, back = true }
      G.push()
      G.translate(0, 32)
      UI.sheet(detail, w, h - 32, detail.kindLabel)
      G.pop()
      return hits
    end
    local gw = (detail and wide) and floor(min(w * 0.46, 380)) or w
    local used = pager(gw - pad, pad - 2, model.box, model.boxes, hits)
    -- the padlock in front of the name locks and unlocks this box
    padlock(pad, pad, 16, model.locked, model.locked and C.gold or C.faint)
    hits[#hits + 1] = { x = pad - 2, y = pad - 3, w = 22, h = 22, lock = true }
    text(fit(model.name, gw - pad * 2 - used - 82, 13), pad + 22, pad + 1, C.text, 13)
    text(model.count .. "/30", gw - pad - used - 4, pad + 3, C.muted, 11, "right")
    local top, footH = pad + 28, 30
    local bottom = h - footH

    if model.sorts or model.confirm then
      -- the sort choices, or the question before sorting, in place of the grid
      local x, y = pad + 4, top + 2
      if model.confirm then
        text(fit(model.confirm.title, gw - pad * 2, 13), x, y, C.text, 13)
        y = y + 24
        text(fit(model.confirm.line, gw - pad * 2 - 8, 12), x, y, C.text, 12)
        y = y + 20
        y = y + para(model.confirm.note, x, y, gw - pad * 2 - 8, C.muted, 11, 3) + 8
        local bw = footButton(T("SORT_GO"), x, y, C.accent, hits, { confirm = true })
        footButton(T("CANCEL"), x + bw + 8, y, nil, hits, { cancel = true })
      else
        text(T("SORT_TITLE"), x, y, C.text, 13)
        y = y + 22
        local rowH = max(24, min(30, floor((bottom - y - 34) / #model.sorts)))
        for _, sort in ipairs(model.sorts) do
          card(x, y, gw - pad * 2 - 8, rowH - 4, C.card, 6)
          text(fit(sort.label, gw - pad * 2 - 24, 12), x + 10, y + (rowH - 4) / 2 - 7, C.text, 12)
          hits[#hits + 1] = { x = x, y = y, w = gw - pad * 2 - 8, h = rowH - 4, sort = sort.id }
          y = y + rowH
        end
        para(model.sortNote, x, y + 2, gw - pad * 2 - 8, C.muted, 11, 3)
        footButton(T("CANCEL"), x, bottom + 4, nil, hits, { cancel = true })
      end
      return hits
    end

    local cell = min((gw - pad * 2 - gap * 5) / 6, (bottom - top - gap * 5) / 5)
    cell = max(20, floor(cell))
    local ox = floor((gw - (cell * 6 + gap * 5)) / 2)
    for slot = 1, 30 do
      local x = ox + ((slot - 1) % 6) * (cell + gap)
      local y = top + floor((slot - 1) / 6) * (cell + gap)
      local entry = model.slots[slot]
      local chosen = model.selected == slot
      local tone = entry and (chosen and mix(C.card, C.accent, 0.3) or C.card) or mix(C.card, C.bg, 0.55)
      if model.locked then tone = mix(tone, C.gold, 0.08) end
      card(x, y, cell, cell, tone, 6)
      if entry then
        sprite(entry.pic, x + 2, y + 2, cell - 4)
        if entry.shiny then star(x + cell - 7, y + 7, min(6, cell / 7)) end
        if cell >= 40 and entry.level then text(entry.level, x + cell - 4, y + cell - 14, C.muted, 10, "right") end
        if cell >= 40 and entry.number then text(entry.number, x + 4, y + 3, C.faint, 9) end
        hits[#hits + 1] = { x = x, y = y, w = cell, h = cell, slot = slot }
      end
      if chosen then
        color(C.accent)
        G.setLineWidth(2)
        G.rectangle("line", x + 1, y + 1, cell - 2, cell - 2, 6, 6)
        G.setLineWidth(1)
      end
    end
    if model.count == 0 then text(T("BOX_EMPTY"), gw / 2, top + cell * 2.5, C.faint, 12, "center") end

    -- footer: lock, sort, undo, and what just happened
    local fy, fx = bottom + 4, pad
    fx = fx + footButton(model.locked and T("UNLOCK_BOX") or T("LOCK_BOX"), fx, fy, model.locked and mix(C.raised, C.gold, 0.35) or nil, hits, { lock = true }) + 6
    fx = fx + footButton(T("SORT"), fx, fy, nil, hits, { openSort = true }) + 6
    if model.canUndo then fx = fx + footButton(T("UNDO"), fx, fy, nil, hits, { undo = true }) + 6 end
    local message = model.flash or (not detail and model.count > 0 and T("BOX_HINT")) or nil
    if message and gw - fx - pad > 40 then text(fit(message, gw - fx - pad, 11), fx + 4, fy + 4, model.flash and C.text or C.faint, 11) end

    if detail and wide then
      -- wide: the sheet beside the box
      G.push()
      G.translate(gw, 0)
      UI.sheet(detail, w - gw, h, detail.kindLabel)
      G.pop()
    end
    return hits
  end

  return UI
end
