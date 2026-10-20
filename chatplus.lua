-- Chat+ (chatplus) - compatible with CC:Tweaked old /rom/programs/rednet/chat.lua
-- Commands:
--   chatplus host <room>
--   chatplus join <room> <nickname> [password]
--   chatplus config server|client
--
-- Moderation:
--   /kick <name>      (SOFTKICK: client times out)
--   /hardkick <name>  (instant kick packet)
--   /ban <name> /unban <name>
--   /tell <name> <msg>
--   /who
--   /only on|off
--   /pass <text|off>
--   /files on|off

local args = { ... }

-- =========
-- "Libraries" (in-file modules)
-- =========
local Lib = {}

function Lib.ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

function Lib.loadTable(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  local s = f.readAll()
  f.close()
  local t = textutils.unserialize(s)
  if type(t) == "table" then return t end
  return nil
end

function Lib.saveTable(path, t)
  local dir = fs.getDir(path)
  if dir and #dir > 0 then Lib.ensureDir(dir) end
  local f = fs.open(path, "w")
  f.write(textutils.serialize(t))
  f.close()
end

local function deepCopy(x)
  if type(x) ~= "table" then return x end
  local t = {}
  for k, v in pairs(x) do t[k] = deepCopy(v) end
  return t
end

function Lib.mergeDefaults(loaded, defaults)
  -- returns a NEW table = defaults + loaded overrides
  local out = deepCopy(defaults)
  if type(loaded) ~= "table" then return out end
  for k, v in pairs(loaded) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = Lib.mergeDefaults(v, out[k])
    else
      out[k] = v
    end
  end
  return out
end

function Lib.lower(s) return type(s) == "string" and s:lower() or s end

function Lib.isAdvanced() return term.isColour() end

function Lib.colours()
  if Lib.isAdvanced() then
    return {
      barBg   = colours.lightBlue,
      barFg   = colours.white,
      userFg  = colours.lime,
      textFg  = colours.white,
      infoFg  = colours.yellow,
    }
  else
    return {
      barBg   = colours.black,
      barFg   = colours.white,
      userFg  = colours.white,
      textFg  = colours.white,
      infoFg  = colours.white,
    }
  end
end

-- Modem helpers (same approach as ROM chat.lua)
local sOpenedModem = nil
function Lib.openModem()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      if not rednet.isOpen(name) then
        rednet.open(name)
        sOpenedModem = name
      end
      return true
    end
  end
  print("No modems found.")
  return false
end

function Lib.closeModem()
  if sOpenedModem then
    rednet.close(sOpenedModem)
    sOpenedModem = nil
  end
end

-- =========
-- Constants / Paths
-- =========
local CHAT_PROTOCOL = "chat"     -- MUST match your ROM script
local CP_PROTOCOL   = "chatplus" -- chat+ extras

local ROOT_DIR   = ".chatplus"
local SERVER_CFG = fs.combine(ROOT_DIR, "server.cfg")
local CLIENT_CFG = fs.combine(ROOT_DIR, "client.cfg")
local BANS_DB    = fs.combine(ROOT_DIR, "bans.db")
local BOTS_DIR   = fs.combine(ROOT_DIR, "bots")

-- =========
-- Defaults
-- =========
local SERVER_DEFAULT = {
  chatplusOnly   = false,
  password       = nil,

  legacyWarning  = true,
  warnPrefix     = "[Chat+ Server]", -- chat+ clients hide these lines by default
  motd           = "This is a Chat+ server. Install Chat+ for full features.",

  allowFiles     = false,
  maxFileBytes   = 200000,        -- safety limit for small-file mode

  pingSeconds    = 15,            -- IMPORTANT: fixes your crash
  softKickByDefault = true,       -- /kick does softkick, /hardkick does instant
    -- Ops / permissions
  opsByComputer = {},        -- computer IDs (numbers)
  opsOnlyModeration = true,  -- if true: only ops can /kick /ban /unban /only /pass /files

}

local CLIENT_DEFAULT = {
  showLegacyWarnings = false,
  downloadDir = "downloads",
  statusInBar = true,
}

-- =========
-- Bot system
-- =========
local function loadBots()
  Lib.ensureDir(ROOT_DIR)
  Lib.ensureDir(BOTS_DIR)

  local bots = {}
  for _, file in ipairs(fs.list(BOTS_DIR)) do
    if file:sub(-4) == ".lua" then
      local path = fs.combine(BOTS_DIR, file)
      local ok, mod = pcall(dofile, path)
      if ok and type(mod) == "table" then
        mod.name = mod.name or file
        bots[#bots + 1] = mod
        print("Loaded bot: " .. tostring(mod.name))
      else
        print("Failed bot: " .. file)
      end
    end
  end
  return bots
end

local function callBots(bots, hook, ...)
  for _, b in ipairs(bots) do
    local fn = b[hook]
    if type(fn) == "function" then
      pcall(fn, ...)
    end
  end
end

-- =========
-- Config editor
-- =========
local function runConfig(which)
  Lib.ensureDir(ROOT_DIR)
  local path, def
  if which == "server" then path, def = SERVER_CFG, SERVER_DEFAULT
  elseif which == "client" then path, def = CLIENT_CFG, CLIENT_DEFAULT
  else
    return false
  end
  local loaded = Lib.loadTable(path)
  local merged = Lib.mergeDefaults(loaded, def)
  Lib.saveTable(path, merged)
  print("Editing " .. which .. " config: " .. path)
  shell.run("edit", path)
  return true
end

-- =========
-- Server
-- =========
local function runHost(room)
  if not room then
    print("Usage: chatplus host <room>")
    return
  end
  if not Lib.openModem() then return end

  Lib.ensureDir(ROOT_DIR)
  local cfg = Lib.mergeDefaults(Lib.loadTable(SERVER_CFG), SERVER_DEFAULT)
  Lib.saveTable(SERVER_CFG, cfg)

  local bans = Lib.mergeDefaults(Lib.loadTable(BANS_DB), { byName = {}, byComputer = {} })
  Lib.saveTable(BANS_DB, bans)

  rednet.host(CHAT_PROTOCOL, room)
  rednet.host(CP_PROTOCOL, room)

  term.clear()
  term.setCursorPos(1, 1)
  print(("Chat+ hosting room '%s'"):format(room))
  print(("chatplusOnly=%s password=%s allowFiles=%s pingSeconds=%s"):format(
    tostring(cfg.chatplusOnly),
    cfg.password and "<set>" or "<none>",
    tostring(cfg.allowFiles),
    tostring(cfg.pingSeconds)
  ))
  print("Commands: /kick /hardkick /ban /unban /tell /who /only /pass /files")

  -- Users are keyed by nUserID like ROM chat server
  -- user = { nID=computerId, nUserID=userId, sUsername=nick, bChatPlus=bool, bVerified=bool, bPingPonged=bool }
  local users = {}
  local usersCount = 0

  local shadow = {}       -- nUserID -> true (softkicked/ignored until timeout cleanup)
  local pingTimers = {}   -- timerId -> nUserID
  local nonces = {}       -- nUserID -> nonce (verification)
  local bots = loadBots()

  local function saveBans()
    Lib.saveTable(BANS_DB, bans)
  end

local function isBanned(nID)
  return bans.byComputer[nID] == true
end

  
local function sendText(text, toUserID)
  if toUserID then
    if shadow[toUserID] then return end
    local u = users[toUserID]
    if u then
      rednet.send(u.nID, { sType="text", nUserID=toUserID, sText=text }, CHAT_PROTOCOL)
    end
  else
    for uid, u in pairs(users) do
      if not shadow[uid] then
        rednet.send(u.nID, { sType="text", nUserID=uid, sText=text }, CHAT_PROTOCOL)
      end
    end
  end
end


local function isOpUser(u)
  if not u then return false end
  if type(cfg.opsByComputer) ~= "table" then return false end
  return cfg.opsByComputer[u.nID] == true
end



local function requireOp(u, cmd)
  if not cfg.opsOnlyModeration then return true end
  if isOpUser(u) then return true end
  sendText("* You are not an operator. Command blocked: /" .. cmd, u.nUserID)
  return false
end


  local function findUserByName(name)
    local want = Lib.lower(name)
    for uid, u in pairs(users) do
      if Lib.lower(u.sUsername) == want then return uid, u end
    end
    return nil
  end

  local function tagFor(u)
    return u.bVerified and " [chat+]" or " [chat]"
  end

 local function resolveComputerId(token)
  -- If it's a number, treat as computer id
  local asNum = tonumber(token)
  if asNum then return asNum end

  -- Otherwise treat as username, resolve to current user -> computer id
  local uid, u = findUserByName(token)
  if u then return u.nID end

  return nil
end



  local function hardKick(uid)
    local u = users[uid]
    if not u then return end
    rednet.send(u.nID, { sType="kick", nUserID=uid }, CHAT_PROTOCOL)
    users[uid] = nil
    shadow[uid] = nil
    usersCount = math.max(0, usersCount - 1)
  end

  local function softKick(uid)
    -- Make them timeout: ignore pings + stop sending them anything.
    shadow[uid] = true
  end

  local function ping(uid)
    if shadow[uid] then return end
    local u = users[uid]
    if not u then return end

    rednet.send(u.nID, { sType="ping to client", nUserID=uid }, CHAT_PROTOCOL)
    u.bPingPonged = false

    local seconds = tonumber(cfg.pingSeconds) or SERVER_DEFAULT.pingSeconds
    local timer = os.startTimer(seconds)
    pingTimers[timer] = uid

    if u.bChatPlus and not u.bVerified then
      local nonce = math.random(1, 2147483647)
      nonces[uid] = nonce
      rednet.send(u.nID, { t="PING", nUserID=uid, nonce=nonce }, CP_PROTOCOL)
    end
  end

  local function ctxForBots()
    return {
      broadcast = function(t) sendText(t, nil) end,
      send = function(t, uid) sendText(t, uid) end,
      pm = function(fromName, uid, msg)
        sendText(("* [PM] %s: %s"):format(fromName, msg), uid)
      end,
      kick = function(uid)
      if cfg.softKickByDefault then
      	softKick(uid)
      else
    	hardKick(uid)
      end
   end,
      hardkick = function(uid) hardKick(uid) end,
      softkick = function(uid) softKick(uid) end,
      findUser = function(name) return findUserByName(name) end,
      listUsers = function()
        local out = {}
        for uid, u in pairs(users) do
          out[#out+1] = {
            userId = uid,
            name = u.sUsername,
            verified = u.bVerified,
            shadow = shadow[uid] == true,
            computerId = u.nID,
          }
        end
        return out
      end,
      config = cfg,
    }
  end
    
 local function handleCommand(u, cmd, content)
  local ctx = ctxForBots()

  if cmd == "who" or cmd == "users" then
    sendText("* Connected users:", u.nUserID)
    local line = "*"
    for _, uu in pairs(users) do
      local s = ("%s(#%d)%s"):format(uu.sUsername, uu.nID, tagFor(uu))

      if shadow[uu.nUserID] then s = s .. " (disconnecting)" end
      line = line .. " " .. s
    end
    sendText(line, u.nUserID)
    return true

  elseif cmd == "tell" then
    local target, msg = content:match("^(%S+)%s+(.+)$")
    if not target or not msg then
      sendText("* Usage: /tell <name> <message>", u.nUserID)
      return true
    end
    local tuid, tu = findUserByName(target)
    if not tu then
      sendText("* Unknown user: " .. target, u.nUserID)
      return true
    end
    sendText(("* [PM] %s -> %s: %s"):format(u.sUsername, tu.sUsername, msg), tuid)
    sendText(("* [PM] %s -> %s: %s"):format(u.sUsername, tu.sUsername, msg), u.nUserID)
    return true

  elseif cmd == "kick" or cmd == "hardkick" or cmd == "ban" or cmd == "unban" then
    -- GATE moderation commands
    if not requireOp(u, cmd) then return true end

    local target = content:match("^(%S+)$")
    if not target then
      sendText("* Usage: /" .. cmd .. " <name>", u.nUserID)
      return true
    end

if cmd == "unban" then
  local compId = resolveComputerId(target)
  if not compId then
    sendText("* Usage: /unban <computerId|name>", u.nUserID)
    return true
  end
  bans.byComputer[compId] = nil
  saveBans()
  sendText("* Unbanned computer #" .. tostring(compId), u.nUserID)
  return true
end


    local tuid, tu = findUserByName(target)
    if not tu then
      sendText("* Unknown user: " .. target, u.nUserID)
      return true
    end

    if cmd == "ban" then
      bans.byName[Lib.lower(tu.sUsername)] = true
      bans.byComputer[tu.nID] = true
      saveBans()
      sendText("* " .. tu.sUsername .. " was banned.", nil)
      if cfg.softKickByDefault then softKick(tuid) else hardKick(tuid) end
      return true
    end

    if cmd == "hardkick" then
      sendText("* " .. tu.sUsername .. " was kicked.", nil)
      hardKick(tuid)
      return true
    end

    -- cmd == kick
    sendText("* " .. tu.sUsername .. " was disconnected.", nil)
    if cfg.softKickByDefault then
      softKick(tuid)
    else
      hardKick(tuid)
    end
    return true

  elseif cmd == "only" then
    -- GATE server-control commands
    if not requireOp(u, cmd) then return true end

    if content == "on" or content == "off" then
      cfg.chatplusOnly = (content == "on")
      Lib.saveTable(SERVER_CFG, cfg)
      sendText("* chatplusOnly=" .. tostring(cfg.chatplusOnly), u.nUserID)
    else
      sendText("* Usage: /only on|off", u.nUserID)
    end
    return true

  elseif cmd == "pass" then
    -- GATE server-control commands
    if not requireOp(u, cmd) then return true end

    if content == "off" then
      cfg.password = nil
      Lib.saveTable(SERVER_CFG, cfg)
      sendText("* Password cleared.", u.nUserID)
    elseif #content > 0 then
      cfg.password = content
      Lib.saveTable(SERVER_CFG, cfg)
      sendText("* Password set.", u.nUserID)
    else
      sendText("* Usage: /pass <text> OR /pass off", u.nUserID)
    end
    return true

  elseif cmd == "files" then
    -- GATE server-control commands
    if not requireOp(u, cmd) then return true end

    if content == "on" or content == "off" then
      cfg.allowFiles = (content == "on")
      Lib.saveTable(SERVER_CFG, cfg)
      sendText("* allowFiles=" .. tostring(cfg.allowFiles), u.nUserID)
    else
      sendText("* Usage: /files on|off", u.nUserID)
    end
    return true
  end

  -- let bots try to handle it
  local handled = false
  callBots(bots, "onCommand", ctx, u, cmd, content, function() handled = true end)
  return handled
end


  -- Main loop (event-driven, like ROM script)
  while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "timer" then
      local timer = p1
      local uid = pingTimers[timer]
      if uid and users[uid] then
        local u = users[uid]
        pingTimers[timer] = nil

        if shadow[uid] then
          -- We are intentionally not pinging them: let their client timeout.
          -- Cleanup will happen when they fail ping/pong timer below.
          -- If they are shadowed, treat as "not ponged".
          sendText("* " .. u.sUsername .. " has timed out", nil)
          users[uid] = nil
          shadow[uid] = nil
          usersCount = math.max(0, usersCount - 1)
        else
          if not u.bPingPonged then
            sendText("* " .. u.sUsername .. " has timed out", nil)
            users[uid] = nil
            usersCount = math.max(0, usersCount - 1)
            callBots(bots, "onLeave", ctxForBots(), u)
          else
            ping(uid)
          end
        end
      end

      callBots(bots, "onTick", ctxForBots())

    elseif ev == "rednet_message" then
      local senderID, msg, proto = p1, p2, p3

      -- Chat+ extras
      if proto == CP_PROTOCOL and type(msg) == "table" then
        if msg.t == "PONG" then
          local uid = msg.nUserID
          local u = uid and users[uid]
          if u and u.nID == senderID and u.bChatPlus and not u.bVerified then
            if msg.nonce and nonces[uid] == msg.nonce then
              u.bVerified = true
              sendText("* " .. u.sUsername .. " is verified on Chat+.", nil)
            end
          end

        elseif msg.t == "FILE_OFFER" then
          if not cfg.allowFiles then goto continue end
          local fromUID = msg.fromUID
          local toName  = msg.toName
          local name    = msg.name
          local size    = msg.size
          local data    = msg.data

          local fromU = fromUID and users[fromUID]
          if not fromU or fromU.nID ~= senderID then goto continue end
          if not fromU.bVerified then goto continue end
          if type(name) ~= "string" or type(data) ~= "string" or type(size) ~= "number" then goto continue end
          if size > (tonumber(cfg.maxFileBytes) or SERVER_DEFAULT.maxFileBytes) then goto continue end

          local toUID, toU = findUserByName(toName or "")
          if not toU or not toU.bVerified then goto continue end

          local tid = ("%d-%d"):format(os.getComputerID(), math.random(100000, 999999))
          -- store transfer in bot dir? small: keep in memory
          -- Send offer
          rednet.send(toU.nID, { t="FILE_OFFER", tid=tid, from=fromU.sUsername, name=name, size=size }, CP_PROTOCOL)
          -- stash payload on server until accepted
          -- (simple store)
          if not _G.__chatplusTransfers then _G.__chatplusTransfers = {} end
          _G.__chatplusTransfers[tid] = { toUID = toUID, name=name, size=size, data=data }

        elseif msg.t == "FILE_ACCEPT" then
          if not cfg.allowFiles then goto continue end
          local tid = msg.tid
          local uid = msg.uid
          if not tid or not uid then goto continue end
          local u = users[uid]
          if not u or u.nID ~= senderID then goto continue end
          local tr = _G.__chatplusTransfers and _G.__chatplusTransfers[tid]
          if not tr or tr.toUID ~= uid then goto continue end

          rednet.send(u.nID, { t="FILE_DATA", tid=tid, name=tr.name, size=tr.size, data=tr.data }, CP_PROTOCOL)
          _G.__chatplusTransfers[tid] = nil
        end

        goto continue
      end

      -- Legacy chat protocol (table messages)
      if proto == CHAT_PROTOCOL and type(msg) == "table" then
        if msg.sType == "login" then
          local uid = msg.nUserID
          local name = msg.sUsername
          local pass = msg.sPassword
          local wantsChatPlus = msg.bChatPlus == true

          if not uid or not name then goto continue end

          if isBanned(senderID) then
            rednet.send(senderID, { sType="kick", nUserID=uid }, CHAT_PROTOCOL)
            goto continue
          end

          if cfg.chatplusOnly and not wantsChatPlus then
            if cfg.legacyWarning then
              rednet.send(senderID, { sType="text", nUserID=uid, sText=cfg.warnPrefix .. " Chat+ only room." }, CHAT_PROTOCOL)
            end
            rednet.send(senderID, { sType="kick", nUserID=uid }, CHAT_PROTOCOL)
            goto continue
          end

          if cfg.password and pass ~= cfg.password then
            if cfg.legacyWarning then
              rednet.send(senderID, { sType="text", nUserID=uid, sText=cfg.warnPrefix .. " Wrong password." }, CHAT_PROTOCOL)
            end
            rednet.send(senderID, { sType="kick", nUserID=uid }, CHAT_PROTOCOL)
            goto continue
          end

          users[uid] = {
            nID = senderID,
            nUserID = uid,
            sUsername = name,
            bChatPlus = wantsChatPlus,
            bVerified = false,
            bPingPonged = true,
          }
          usersCount = usersCount + 1

          if (not wantsChatPlus) and cfg.legacyWarning then
            rednet.send(senderID, { sType="text", nUserID=uid, sText=cfg.warnPrefix .. " " .. cfg.motd }, CHAT_PROTOCOL)
          end

          sendText("* " .. name .. " has joined the chat", nil)
          callBots(bots, "onJoin", ctxForBots(), users[uid])
          ping(uid)

        else
          local uid = msg.nUserID
          local u = uid and users[uid]
          if not u or u.nID ~= senderID then goto continue end

          if shadow[uid] then
            -- ignore everything from shadowed user until they timeout
            goto continue
          end

          if msg.sType == "logout" then
            sendText("* " .. u.sUsername .. " has left the chat", nil)
            users[uid] = nil
            usersCount = math.max(0, usersCount - 1)
            callBots(bots, "onLeave", ctxForBots(), u)

          elseif msg.sType == "chat" then
            local text = msg.sText
            if not text then goto continue end

            local cmd = text:match("^/([a-z]+)")
            if cmd then
              local content = text:sub(#cmd + 3)

              -- keep original /me, /nick
              if cmd == "me" then
                if #content > 0 then sendText("* " .. u.sUsername .. " " .. content, nil)
                else sendText("* Usage: /me [words]", uid) end

              elseif cmd == "nick" then
                if #content > 0 then
                  local old = u.sUsername
                  u.sUsername = content
                  sendText("* " .. old .. " is now known as " .. u.sUsername, nil)
                else
                  sendText("* Usage: /nick [nickname]", uid)
                end

              elseif cmd == "logout" then
                sendText("* " .. u.sUsername .. " has left the chat", nil)
                users[uid] = nil
                usersCount = math.max(0, usersCount - 1)
                callBots(bots, "onLeave", ctxForBots(), u)

              else
                if not handleCommand(u, cmd, content) then
                  sendText("* Unrecognised command: /" .. cmd, uid)
                end
              end
            else
              local line = "<" .. u.sUsername .. tagFor(u) .. "> " .. text
              sendText(line, nil)
              callBots(bots, "onChat", ctxForBots(), u, text)
            end

          elseif msg.sType == "ping to server" then
            -- If shadowed, do nothing -> they timeout.
            rednet.send(u.nID, { sType="pong to client", nUserID=uid }, CHAT_PROTOCOL)

          elseif msg.sType == "pong to server" then
            u.bPingPonged = true
          end
        end
      end

      ::continue::
    end
  end
end
-- =========
-- Client (join) - nicer UI like ROM chat, plus chat+ verification and files
-- =========
local function runJoin(room, nickname, password)
  if not room or not nickname then
    print("Usage: chatplus join <room> <nickname> [password]")
    return
  end
  if not Lib.openModem() then return end

  Lib.ensureDir(ROOT_DIR)
  local cfg = Lib.mergeDefaults(Lib.loadTable(CLIENT_CFG), CLIENT_DEFAULT)
  Lib.saveTable(CLIENT_CFG, cfg)

  write("Looking up " .. room .. "... ")
  local hostID = rednet.lookup(CHAT_PROTOCOL, room)
  if not hostID then
    print("Failed.")
    return
  end
  print("Success.")

  local uid = math.random(1, 2147483647)

  -- login (legacy protocol), but declare chat+ capable
  rednet.send(hostID, {
    sType = "login",
    nUserID = uid,
    sUsername = nickname,
    bChatPlus = true,
    sPassword = password,
  }, CHAT_PROTOCOL)

  local C = Lib.colours()

  local parent = term.current()
  local w, h = parent.getSize()
  local titleW  = window.create(parent, 1, 1, w, 1, true)
  local histW   = window.create(parent, 1, 2, w, h - 2, true)
  local promptW = window.create(parent, 1, h, w, 1, true)
  histW.setCursorPos(1, h - 2)

  term.clear()
  term.setCursorPos(1, 1)

  local verified = false

  local function drawTitle(status)
    titleW.setBackgroundColour(C.barBg)
    titleW.setTextColour(C.barFg)
    titleW.setCursorPos(1, 1)
    titleW.clearLine()

    local left = (" Chat+  room:%s  user:%s "):format(room, nickname)
    local right = status and (" " .. status .. " ") or ""
    local ww = titleW.getSize()

    titleW.setCursorPos(1, 1)
    titleW.write(left:sub(1, ww))

    if cfg.statusInBar and #right > 0 and #right < ww then
      titleW.setCursorPos(ww - #right + 1, 1)
      titleW.write(right)
    end
  end

  local function shouldHideLine(line)
    if cfg.showLegacyWarnings then return false end
    return type(line) == "string" and line:find(SERVER_DEFAULT.warnPrefix, 1, true) == 1
  end

  local function printMessage(msg)
    term.redirect(histW)
    print()

    if msg:match("^%*") then
      term.setTextColour(C.infoFg)
      write(msg)
      term.setTextColour(C.textFg)
    else
      local userBit = msg:match("^<[^>]*>")
      if userBit then
        term.setTextColour(C.userFg)
        write(userBit)
        term.setTextColour(C.textFg)
        write(msg:sub(#userBit + 1))
      else
        term.setTextColour(C.textFg)
        write(msg)
      end
    end

    term.redirect(promptW)
    promptW.restoreCursor()
  end

  -- normal ping/pong for legacy timeout behavior
  local bPingPonged = true
  local pingTimer = os.startTimer(0)
  local function ping()
    rednet.send(hostID, { sType="ping to server", nUserID=uid }, CHAT_PROTOCOL)
    bPingPonged = false
    pingTimer = os.startTimer(SERVER_DEFAULT.pingSeconds)
  end

  -- files
  if not fs.exists(cfg.downloadDir) then fs.makeDir(cfg.downloadDir) end

  drawTitle("connecting...")

  local ok, err = pcall(parallel.waitForAny,
    function()
      while true do
        local e, a = os.pullEvent()
        if e == "timer" and a == pingTimer then
          if not bPingPonged then
            printMessage("Server timeout.")
            return
          else
            ping()
          end
        elseif e == "term_resize" then
          w, h = parent.getSize()
          titleW.reposition(1, 1, w, 1)
          histW.reposition(1, 2, w, h - 2)
          promptW.reposition(1, h, w, 1)
          drawTitle(verified and "verified" or "chat mode")
        end
      end
    end,

    function()
      while true do
        local sender, tMessage = rednet.receive(CHAT_PROTOCOL)
        if sender == hostID and type(tMessage) == "table" and tMessage.nUserID == uid then
          if tMessage.sType == "text" then
            if tMessage.sText and not shouldHideLine(tMessage.sText) then
              printMessage(tMessage.sText)
            end
          elseif tMessage.sType == "ping to client" then
            rednet.send(sender, { sType="pong to server", nUserID=uid }, CHAT_PROTOCOL)
          elseif tMessage.sType == "pong to client" then
            bPingPonged = true
          elseif tMessage.sType == "kick" then
            return
          end
        end
      end
    end,

    function()
      while true do
        local sender, pkt = rednet.receive(CP_PROTOCOL)
        if sender == hostID and type(pkt) == "table" then
          if pkt.t == "PING" and pkt.nUserID == uid then
            rednet.send(hostID, { t="PONG", nUserID=uid, nonce=pkt.nonce }, CP_PROTOCOL)
            verified = true
            drawTitle("verified")

          elseif pkt.t == "FILE_OFFER" then
            printMessage(("* File offer from %s: %s (%d bytes). Type /accept %s"):format(
              tostring(pkt.from), tostring(pkt.name), tonumber(pkt.size) or 0, tostring(pkt.tid)
            ))

          elseif pkt.t == "FILE_DATA" then
            local name = tostring(pkt.name)
            local data = pkt.data
            if type(data) == "string" then
              local out = fs.combine(cfg.downloadDir, name)
              local f = fs.open(out, "wb")
              f.write(data)
              f.close()
              printMessage("* Saved file to " .. out)
            end
          end
        end
      end
    end,

    function()
      local sendHist = {}
      while true do
        promptW.setCursorPos(1, 1)
        promptW.clearLine()
        promptW.setTextColour(C.userFg)
        promptW.write(": ")
        promptW.setTextColour(C.textFg)

        local line = read(nil, sendHist)

        if line:match("^/logout") then
          break

        elseif line:match("^/accept%s+") then
          local tid = line:match("^/accept%s+(%S+)")
          if tid then
            rednet.send(hostID, { t="FILE_ACCEPT", tid=tid, uid=uid }, CP_PROTOCOL)
          end

        elseif line:match("^/sendfile%s+") then
          local toName, path = line:match("^/sendfile%s+(%S+)%s+(.+)$")
          if toName and path then
            if not fs.exists(path) or fs.isDir(path) then
              printMessage("* File not found.")
            else
              local size = fs.getSize(path)
              local f = fs.open(path, "rb")
              local data = f.readAll()
              f.close()
              rednet.send(hostID, {
                t="FILE_OFFER",
                fromUID = uid,
                toName = toName,
                name = fs.getName(path),
                size = size,
                data = data,
              }, CP_PROTOCOL)
            end
          else
            printMessage("* Usage: /sendfile <name> <path>")
          end

        else
          rednet.send(hostID, { sType="chat", nUserID=uid, sText=line }, CHAT_PROTOCOL)
          table.insert(sendHist, line)
        end
      end
    end
  )

  term.redirect(parent)
  local _, hh = term.getSize()
  term.setCursorPos(1, hh)
  term.clearLine()
  term.setCursorBlink(false)
  if not ok then printError(err) end

  rednet.send(hostID, { sType="logout", nUserID=uid }, CHAT_PROTOCOL)
  Lib.closeModem()
  print("Disconnected.")
end

-- =========
-- Entry
-- =========
local function printUsage()
  local programName = arg[0] or fs.getName(shell.getRunningProgram())
  print("Usages:")
  print(programName .. " host <room>")
  print(programName .. " join <room> <nickname> [password]")
  print(programName .. " config server")
  print(programName .. " config client")
end

math.randomseed(os.clock() * 100000)

if #args == 0 then
  printUsage()
  return
end

if args[1] == "host" then
  runHost(args[2])
elseif args[1] == "join" then
  runJoin(args[2], args[3], args[4])
elseif args[1] == "config" then
  if not runConfig(args[2]) then printUsage() end
else
  printUsage()
end
