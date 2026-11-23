-- One desktop window per extra panel. The host shows a second display by
-- starting a minimal copy of itself that draws frames received over a loopback
-- ENet link; a panel window is one more such companion, fed by this mod.
-- Frames only: panel windows are not touch targets and their input is ignored.
return function(mod)
  local Windows = { list = {}, lastStart = -math.huge }
  local okEnet, enet = pcall(require, "enet")
  local okShell, HostShell = pcall(require, "src.core.HostShell")
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  local START_GAP, CONNECT_TIMEOUT, RETRY = 0.7, 12, 3

  local function now() return love.timer.getTime() end

  function Windows.usable()
    if Windows.unusable then return false end
    return okEnet and type(enet) == "table" and okShell and type(HostShell) == "table"
      and type(HostShell.spawnSelfDetached) == "function"
      and okPlatform and type(Platform) == "table" and Platform.canSpawnProcess() == true
      and love.data ~= nil and love.data.compress ~= nil
  end

  local function destroy(win, sendQuit)
    if win.peer and sendQuit then
      pcall(win.peer.send, win.peer, "Q" .. win.token, 1, "reliable")
      if win.host then pcall(win.host.flush, win.host) end
    end
    if win.peer then pcall(win.peer.disconnect_now, win.peer) end
    if win.host then pcall(win.host.destroy, win.host) end
    win.host, win.peer, win.token, win.port, win.last = nil, nil, nil, nil, nil
  end

  local function token()
    local seed = table.concat({ tostring(os.time()), tostring(now()), tostring({}), tostring(math.random()) }, ":")
    return love.data.encode("string", "hex", love.data.hash("sha256", seed)):sub(1, 24)
  end

  local function start(win)
    local base = 49152 + math.floor(now() * 1000) % 12000
    for attempt = 0, 31 do
      local port = 49152 + (base - 49152 + attempt * 37) % 12000
      local ok, host = pcall(enet.host_create, ("127.0.0.1:%d"):format(port), 1, 2)
      if ok and host then
        win.host, win.port, win.token, win.startedAt = host, port, token(), now()
        local okSpawn, launched = pcall(HostShell.spawnSelfDetached,
          { ("--display-companion=%d,%s"):format(port, win.token) })
        if okSpawn and launched then
          Windows.lastStart = now()
          return true
        end
        destroy(win, false)
        break
      end
    end
    win.retryAt = now() + RETRY
    win.failures = (win.failures or 0) + 1
    return false
  end

  local function service(win)
    while win.host do
      local ok, event = pcall(win.host.service, win.host, 0)
      if not ok then
        destroy(win, false)
        win.retryAt = now() + RETRY
        return
      end
      if not event then break end
      if event.type == "receive" then
        local data = event.data or ""
        if data == "H" .. win.token then
          win.peer, win.last, win.failures = event.peer, nil, 0
          -- The companion's own UDP port tells its window apart from the others.
          win.port = tonumber(tostring(event.peer):match(":(%d+)$"))
        elseif event.peer == win.peer and data == "C" .. win.token then
          -- The player closed this window. Leave it closed until asked again.
          win.closed = true
          destroy(win, false)
          return
        end
      elseif event.type == "disconnect" and event.peer == win.peer then
        destroy(win, false)
        win.retryAt = now() + RETRY
        return
      end
    end
    if win.host and not win.peer and now() - (win.startedAt or 0) > CONNECT_TIMEOUT then
      destroy(win, false)
      win.failures = (win.failures or 0) + 1
      win.retryAt = now() + RETRY * win.failures
    end
    if win.peer and now() >= (win.heartbeatAt or 0) then
      win.heartbeatAt = now() + 1
      pcall(win.peer.send, win.peer, "P" .. win.token, 1, "unreliable")
    end
  end

  -- Keeps `count` windows alive. `mayStart` holds new windows back (the Gear's
  -- own window opens first, so the windows keep a stable order).
  function Windows.update(count, mayStart)
    for index = #Windows.list, count + 1, -1 do
      destroy(Windows.list[index], true)
      Windows.list[index] = nil
    end
    for index = 1, count do
      local win = Windows.list[index]
      if not win then
        win = {}
        Windows.list[index] = win
      end
      local previous = Windows.list[index - 1]
      if not win.host and not win.closed and (win.failures or 0) < 5
          and mayStart and (index == 1 or previous.peer or previous.closed)
          and now() >= (win.retryAt or 0) and now() - Windows.lastStart >= START_GAP then
        start(win)
      end
      service(win)
    end
  end

  -- "1:50123,2:50177": which UDP port each connected panel window talks from.
  function Windows.ports()
    local parts = {}
    for index, win in ipairs(Windows.list) do
      if win.peer and win.port then parts[#parts + 1] = index .. ":" .. win.port end
    end
    return table.concat(parts, ",")
  end

  function Windows.connected(index)
    local win = Windows.list[index]
    return win ~= nil and win.peer ~= nil
  end

  -- Sends a panel image; an unchanged image is not sent again.
  function Windows.push(index, imageData, background, preference)
    local win = Windows.list[index]
    if not (win and win.peer and imageData) then return false end
    local w, h = imageData:getDimensions()
    local raw = imageData:getString()
    if raw == win.last then return true end
    local header = ("F%s\n%d,%d,%u,%s\n"):format(win.token, w, h,
      tonumber(background) or 0, (tostring(preference or "auto"):gsub("[^%w_:.-]", "")))
    local sent = pcall(win.peer.send, win.peer,
      header .. love.data.compress("string", "lz4", raw, 1), 0, "reliable")
    if sent then win.last = raw end
    return sent
  end

  -- Reopens windows the player closed and retries ones that failed to start.
  function Windows.reset()
    for _, win in ipairs(Windows.list) do
      win.closed, win.failures, win.retryAt = nil, 0, 0
    end
  end

  function Windows.closeAll()
    for index = #Windows.list, 1, -1 do
      destroy(Windows.list[index], true)
      Windows.list[index] = nil
    end
  end

  return Windows
end
