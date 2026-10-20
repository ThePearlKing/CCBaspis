local K = {}
local unpack = table.unpack or unpack
local input = { char=true, key=true, key_up=true, paste=true, mouse_click=true,
  mouse_up=true, mouse_drag=true, mouse_scroll=true, file_transfer=true }
K.catalog = {
  {id="files", name="Files", detail="Browse, copy, move and recover files", icon="folder"},
  {id="terminal", name="Terminal", detail="Run ComputerCraft commands and Lua", icon="terminal"},
  {id="editor", name="Editor", detail="Write notes and Lua programs", icon="editor"},
  {id="code", name="Code Editor", detail="Lua, Peanut, Pistachio and Cashew", icon="editor"},
  {id="sketch", name="Sketch", detail="Draw and explore a rendered 3D scene", icon="sketch"},
  {id="pistachio", name="Pistachio", detail="Visual, event-driven programs", icon="editor"},
  {id="chatplus", name="Chat+", detail="Chat over a ComputerCraft modem", icon="terminal"},
  {id="browser", name="Callisto", detail="Browse the Europa network", icon="devices"},
  {id="server", name="Jupiter", detail="Host a Cashew website", icon="devices"},
  {id="settings", name="Settings", detail="Display mode and appearance", icon="settings"},
  {id="processes", name="Tasks", detail="Inspect and manage running apps", icon="tasks"},
  {id="devices", name="Devices", detail="Computer, disks and peripherals", icon="devices"},
  {id="help", name="Guide", detail="Shortcuts, recovery and app development", icon="help"},
}
-- Keep the original desktop layout. Registering an app only adds it to Apps.
K.desktop={files=true,terminal=true,editor=true,sketch=true,pistachio=true,
  browser=true,server=true,settings=true,processes=true,devices=true,help=true}
function K.new(ctx)
  local self = { tasks={}, nextID=0, focus=nil, keys={}, launcher=nil, notice=nil,
    running=true, ctx=ctx, clockTimer=nil, drag=nil }
  local UI, Pixels, Storage = ctx.load("system/ui"), ctx.load("system/pixels"), ctx.load("system/storage")
  local Paths=ctx.load('system/paths')
  self.ui, self.pixels, self.storage = UI, Pixels, Storage
  local base = ctx.target or term.current()
  self.base = base
  local width,height = base.getSize()
  self.width,self.height = width,height
  self.frame = window.create(base,1,1,width,height,false)
  function self.theme() return ctx.configModule.theme(ctx.config) end
  function self.notify(message)
    self.notice = tostring(message); self.noticeUntil = os.clock()+6
  end
  function self.log(message)
    pcall(function()
      local path = fs.combine(ctx.root,"home/.system/system.log")
      if fs.exists(path) and fs.getSize(path) > 32768 then
        local old = path .. ".1"
        if fs.exists(old) then fs.delete(old) end
        fs.move(path,old)
      end
      local h = assert(fs.open(path,"a")); h.writeLine(os.clock() .. " " .. message); h.close()
    end)
  end
  function self.get(id)
    for _, p in ipairs(self.tasks) do if p.id == id then return p end end
  end
  function self.focusTask(id)
    local p = self.get(id)
    if not p then return end
    p.minimized = false; self.focus = id
    for i,v in ipairs(self.tasks) do if v == p then table.remove(self.tasks,i); break end end
    self.tasks[#self.tasks+1] = p
  end
  function self.remove(id)
    for i,p in ipairs(self.tasks) do
      if p.id == id then
        for _,fn in ipairs(p.cleanup or {}) do pcall(fn) end
        p.cleanup={}; table.remove(self.tasks,i); break
      end
    end
    if self.focus == id then
      self.focus = nil
      for i=#self.tasks,1,-1 do
        if not self.tasks[i].minimized then self.focus=self.tasks[i].id; break end
      end
    end
  end
  function self.resume(p,event)
    if p.state ~= "running" then return end
    local previous = term.current()
    term.redirect(p.redirect or p.win)
    local ok, filter = coroutine.resume(p.co, unpack(event or {}))
    p.redirect = term.current()
    term.redirect(previous)
    if not ok then
      p.state, p.error = "crashed", tostring(filter)
      for _,fn in ipairs(p.cleanup or {}) do pcall(fn) end
      p.cleanup={}
      self.log(p.title .. ": " .. p.error)
      self.notify(p.title .. " stopped. Details in Tasks.")
      term.redirect(p.win)
      local t = self.theme(); UI.clear(t)
      UI.text(2,2,"Application stopped",t.danger,t.bg)
      for i,line in ipairs(UI.wrap(p.error,p.w-4)) do UI.text(2,i+3,line,t.text,t.bg) end
      term.redirect(previous)
    elseif coroutine.status(p.co) == "dead" then
      self.remove(p.id)
    else p.filter = filter end
    if p.closeAfterDialog and self.get(p.id) and p.state=='running' then
      p.closeAfterDialog=nil; self.deliver(p,{'sacabam_close'},true)
    end
  end
  function self.deliver(p,event,force)
    if p and (force or p.filter == nil or p.filter == event[1] or event[1] == "terminate") then self.resume(p,event) end
  end
  function self.geometry(p)
    if p.maximized then p.x,p.y,p.w,p.h = 1,2,self.width,self.height-2
    else
      p.w = math.min(self.width,math.max(20,p.w))
      p.h = math.min(self.height-2,math.max(8,p.h))
      p.x = math.max(1,math.min(p.x,self.width-p.w+1))
      p.y = math.max(2,math.min(p.y,self.height-p.h))
    end
    p.win.reposition(p.x+1,p.y+1,math.max(1,p.w-2),math.max(1,p.h-2),self.frame)
  end
  function self.maximize(p)
    if not p then return end
    if p.maximized then
      p.maximized = false
      if p.restore then p.x,p.y,p.w,p.h = unpack(p.restore) end
    else p.restore={p.x,p.y,p.w,p.h}; p.maximized=true end
    self.geometry(p); self.deliver(p,{"term_resize"},true)
  end
  function self.minimize(p)
    if not p then return end
    p.minimized=true; self.focus=nil
    for i=#self.tasks,1,-1 do if not self.tasks[i].minimized then self.focus=self.tasks[i].id; break end end
  end
  function self.requestClose(p)
    if not p then return end
    if p.state == "crashed" then self.remove(p.id)
    else self.deliver(p,{"sacabam_close"},true) end
  end
  function self.saveConfig()
    ctx.config = ctx.configModule.normalize(ctx.config,ctx.caps)
    local ok,err = Storage.save(fs.combine(ctx.root,"home/.system/settings.tbl"),ctx.config)
    if not ok then self.notify(err); return nil,err end
    local list={}; for _,p in ipairs(self.tasks) do list[#list+1]=p end
    for _,p in ipairs(list) do
      if self.get(p.id) then os.queueEvent("sacabam_theme",p.id) end
    end
    self.wallpaper=nil
    return true
  end
  function self.openContext(x,y,items)
    self.context={x=x,y=y,items=items,index=1}
  end
  function self.desktopContext(x,y)
    for _,hit in ipairs(self.desktopHits or {}) do
      if x>=hit.x and x<hit.x+9 and y>=hit.y and y<=hit.y+3 then
        self.openContext(x,y,{
          {label="Open",run=function() self.launch(hit.id) end},
          {label="Remove shortcut",run=function()
            local previous=ctx.config.hiddenShortcuts[hit.id]
            ctx.config.hiddenShortcuts[hit.id]=true
            if not self.saveConfig() then ctx.config.hiddenShortcuts[hit.id]=previous end
          end}})
        return
      end
    end
    self.openContext(x,y,{
      {label="Open Terminal",run=function() self.launch('terminal') end},
      {label="Applications",run=function() self.launcher={query='',index=1} end},
      {label="Restore shortcuts",run=function()
        local previous=ctx.config.hiddenShortcuts; ctx.config.hiddenShortcuts={}
        if not self.saveConfig() then ctx.config.hiddenShortcuts=previous end
      end}})
  end
  function self.launchAt(directory,id,...)
    local item
    for _,v in ipairs(K.catalog) do if v.id == id then item=v end end
    if not item then self.notify("Unknown app: " .. tostring(id)); return end
    local ok,app = pcall(ctx.load,"apps/"..id)
    if not ok then self.notify(app); self.log(tostring(app)); return end
    self.nextID=self.nextID+1
    local p={id=self.nextID,app=id,title=item.name,state="running",started=os.clock(),
      x=2+(#self.tasks%3),y=3+(#self.tasks%2),w=math.min(width-2,47),h=math.min(height-3,16),
      maximized=ctx.config.mode=="basic" or self.width<40}
    p.restore={p.x,p.y,p.w,p.h}
    p.win=window.create(self.frame,1,1,10,5,false)
    self.geometry(p)
    local paths=Paths.context(directory or '/'..fs.combine(ctx.root,'home'))
    p.paths=paths
    local api={root=ctx.root,home=fs.combine(ctx.root,"home"),id=p.id,ui=UI,pixels=Pixels,storage=Storage,
      theme=self.theme,config=function() return ctx.config end,caps=ctx.caps,
      notify=self.notify,launch=function(id,...) return self.launchAt(paths.dir(),id,...) end,saveConfig=self.saveConfig,
      dir=paths.dir,resolve=paths.resolve,setDir=paths.setDir,
      deferClose=function() p.closeAfterDialog=true end,
      keyDown=function(key) return self.keys[key] == true end,
      setTitle=function(title) p.title=tostring(title) end,
      processes=function()
        local out={}
        for _,v in ipairs(self.tasks) do out[#out+1]={id=v.id,title=v.title,state=v.state,
          error=v.error,started=v.started,minimized=v.minimized} end
        table.sort(out,function(a,b) return a.id<b.id end); return out
      end,
      focus=self.focusTask,close=function(id) self.requestClose(self.get(id)) end,
      kill=function(id) if id~=p.id then self.remove(id) end end,
      requestExit=function(action) self.power=action or "exit" end,
      shell=ctx.shell,password=ctx.password,changePassword=ctx.changePassword,load=ctx.load,
      isEncrypted=ctx.isEncrypted or function() return true end,setEncryption=ctx.setEncryption,
      cryptoProgress=ctx.cryptoProgress,
      onExit=function(fn) p.cleanup=p.cleanup or {}; p.cleanup[#p.cleanup+1]=fn end}
    local args={...}
    p.co=coroutine.create(function() app(api,unpack(args)) end)
    self.tasks[#self.tasks+1]=p; self.focusTask(p.id)
    self.resume(p,{})
    return p.id
  end
  function self.launch(id,...) return self.launchAt(nil,id,...) end
  function self.forShell(caller)
    return {version=ctx.configModule.version,
      launch=function(id,...) return self.launchAt(Paths.resolve(caller.dir()),id,...) end,
      resolve=function(path) return Paths.resolve(path,caller.dir()) end,
      dir=function() return Paths.resolve(caller.dir()) end}
  end
  function self.icon(item,x,y,selected)
    local t=self.theme()
    if ctx.config.mode=="render" then
      local b=Pixels.new(10,9,t.desktop)
      local c=selected and colors.white or colors.cyan
      if item.icon=="folder" then b.rect(1,3,10,7,colors.yellow); b.rect(2,1,4,3,colors.yellow)
      elseif item.icon=="terminal" then
        b.rect(1,1,10,9,colors.black); b.line(2,3,4,5,c); b.line(4,5,2,7,c); b.line(6,7,8,7,c)
      elseif item.icon=="editor" or item.icon=="help" then
        b.rect(2,1,7,9,colors.white); for yy=3,7,2 do b.line(3,yy,7,yy,colors.blue) end
      elseif item.icon=="sketch" then
        b.rect(1,1,10,9,colors.lightBlue); b.line(1,8,5,3,colors.white); b.line(5,3,10,8,colors.white)
      else
        b.rect(2,2,7,7,c); b.rect(4,4,3,3,colors.blue)
      end
      Pixels.draw(b,term,x+1,y,5,3)
    else
      UI.text(x+1,y,"+---+",t.desktopText,t.desktop)
      UI.text(x+1,y+1,"| "..item.name:sub(1,1).." |",t.desktopText,t.desktop)
      UI.text(x+1,y+2,"+---+",t.desktopText,t.desktop)
    end
    UI.text(x,y+3,item.name,selected and t.onAccent or t.desktopText,selected and t.accent or t.desktop,9)
  end
  function self.render()
    local previous=term.current(); term.redirect(self.frame)
    local t=self.theme(); UI.clear(t)
    UI.fill(1,2,self.width,self.height-2,t.desktop)
    if ctx.config.mode=="basic" and ctx.config.wallpaper then
      -- Sparse stippling gives the desktop its own texture on monochrome screens.
      for y=2,self.height-1,2 do
        for x=2+(math.floor(y/2)%2)*2,self.width,4 do UI.text(x,y,".",t.wallpaperFar,t.desktop) end
      end
    end
    if ctx.config.mode=="render" and ctx.config.wallpaper then
      if not self.wallpaper then
        local b=Pixels.new(self.width*2,(self.height-2)*3,t.desktop)
        for x=1,b.w do
          local ridge=math.floor(b.h*.56+math.sin(x/15)*7+math.sin(x/7)*3)
          for y=math.max(1,ridge),b.h do b.set(x,y,t.wallpaperFar) end
          local front=math.floor(b.h*.78+math.sin(x/21+2)*6)
          for y=math.max(1,front),b.h do b.set(x,y,t.wallpaperNear) end
        end
        self.wallpaper=b
      end
      Pixels.draw(self.wallpaper,term,1,2)
    end
    local mono=ctx.config.mode=="basic"
    local barBG,barFG=t.bar,t.barText
    UI.text(1,1," CCSacabam",barFG,barBG,self.width)
    local clock=textutils.formatTime(os.time(),ctx.config.clock24)
    UI.text(self.width-#clock,1,clock,barFG,barBG)
    self.desktopHits={}
    local cols=math.max(1,math.floor((self.width-2)/11))
    local index=0
    for _,item in ipairs(K.catalog) do
      if K.desktop[item.id] and not ctx.config.hiddenShortcuts[item.id] then
        local x,y=2+(index%cols)*11,3+math.floor(index/cols)*5
        if y+3 < self.height-1 then
          self.icon(item,x,y,false)
          self.desktopHits[#self.desktopHits+1]={x=x,y=y,id=item.id}
        end
        index=index+1
      end
    end
    for _,p in ipairs(self.tasks) do if not p.minimized then
      local border=p.id==self.focus and t.frame or t.inactiveFrame
      local frameText=p.id==self.focus and t.frameText or t.inactiveFrameText
      UI.fill(p.x,p.y,p.w,p.h,border)
      local mono=ctx.config.mode=="basic"
      local titleBG=p.id==self.focus and t.title or t.inactiveTitle
      local titleFG=p.id==self.focus and t.titleText or t.inactiveTitleText
      if mono then
        for y=p.y+1,p.y+p.h-2 do
          UI.text(p.x,y,"|",frameText,border); UI.text(p.x+p.w-1,y,"|",frameText,border)
        end
        UI.text(p.x,p.y,"+"..string.rep("-",p.w-2).."+",frameText,border)
        UI.text(p.x,p.y+p.h-1,"+"..string.rep("-",p.w-2).."+",frameText,border)
      end
      UI.text(p.x+1,p.y,p.title,titleFG,titleBG,p.w-12)
      local left=p.x+p.w-10
      UI.text(left,p.y,mono and "[-]" or " - ",t.controlText,t.minimize,3)
      UI.text(left+3,p.y,mono and "[+]" or " + ",t.controlText,t.maximize,3)
      UI.text(left+6,p.y,mono and "[X]" or " X ",t.closeText,t.close,3)
      p.win.setVisible(true); p.win.setVisible(false)
      if not mono then UI.text(p.x+1,p.y+p.h-1,"F3 hide  F4 close  F6 size",frameText,border,p.w-2) end
      if not p.maximized then
        local gripBG=p.id==self.focus and t.resize or t.resizeInactive
        UI.text(p.x+p.w-3,p.y+p.h-1,mono and "../" or "  /",t.resizeText,gripBG,3)
      end
    end end
    UI.text(1,self.height,"",barFG,barBG,self.width)
    UI.text(1,self.height," Apps    ",t.onAccent,t.accent,9)
    self.taskHits={}
    local tx=10
    local tabWidth=math.max(4,math.min(13,math.floor((self.width-10)/math.max(1,#self.tasks))))
    for _,p in ipairs(self.tasks) do
      if tx+tabWidth-1<=self.width then
        UI.text(tx,self.height,(p.minimized and "_" or " ")..p.title,p.id==self.focus and (mono and t.onAccent or t.text) or barFG,
          p.id==self.focus and (mono and t.accent or t.bg) or barBG,tabWidth)
        self.taskHits[#self.taskHits+1]={x=tx,w=tabWidth,id=p.id}; tx=tx+tabWidth
      end
    end
    if self.notice and os.clock()<(self.noticeUntil or 0) then
      UI.text(1,self.height-1," "..self.notice,t.text,t.panel,self.width)
    end
    if self.launcher then
      local menu=self.launcher; local mw=math.min(40,self.width-2)
      local mh=math.min(#K.catalog+4,self.height-2)
      local mx,my=2,2
      UI.fill(mx,my,mw,mh,t.panel)
      UI.text(mx+1,my,"Applications  /  type to search",t.text,t.panel,mw-2)
      UI.text(mx+1,my+1,"> "..menu.query,t.onAccent,t.accent,mw-2)
      menu.matches={}
      for _,v in ipairs(K.catalog) do
        if v.name:lower():find(menu.query:lower(),1,true) then menu.matches[#menu.matches+1]=v end
      end
      menu.index=math.max(1,math.min(menu.index,#menu.matches))
      local first=math.max(1,menu.index-(mh-4)+1)
      menu.hits={}
      for row=1,mh-4 do
        local index=first+row-1; local v=menu.matches[index]
        if v then
          UI.text(mx+1,my+1+row,(index==menu.index and "> " or "  ")..v.name,
            index==menu.index and t.onAccent or t.text,index==menu.index and t.accent or t.panel,mw-2)
          menu.hits[my+1+row]=v.id
        end
      end
      UI.text(mx+1,my+mh-1,"Arrows / Enter / F5",t.muted,t.panel,mw-2)
    end
    if self.transform then
      UI.text(1,self.height-1," "..self.transform.mode..": arrows | Enter done | F5 cancel",t.text,t.panel,self.width)
    end
    if self.context then
      local menu=self.context; local mw=0
      for _,item in ipairs(menu.items) do mw=math.max(mw,#item.label+4) end
      menu.w=math.min(self.width,mw); menu.h=#menu.items+2
      menu.x=math.max(1,math.min(menu.x,self.width-menu.w+1))
      menu.y=math.max(2,math.min(menu.y,self.height-menu.h))
      UI.fill(menu.x,menu.y,menu.w,menu.h,t.frame)
      if mono then
        UI.text(menu.x,menu.y,"+"..string.rep("-",menu.w-2).."+",t.text,t.bg)
        UI.text(menu.x,menu.y+menu.h-1,"+"..string.rep("-",menu.w-2).."+",t.text,t.bg)
        for y=menu.y+1,menu.y+menu.h-2 do
          UI.text(menu.x,y,"|",t.text,t.bg); UI.text(menu.x+menu.w-1,y,"|",t.text,t.bg)
        end
      end
      for i,item in ipairs(menu.items) do
        UI.text(menu.x+1,menu.y+i,(i==menu.index and '> ' or '  ')..item.label,
          i==menu.index and t.onAccent or t.text,i==menu.index and t.accent or t.bg,menu.w-2)
      end
    end
    if self.power then
      UI.fill(2,math.max(2,math.floor(self.height/2)-1),self.width-2,4,t.panel)
      UI.text(3,math.max(2,math.floor(self.height/2)-1),"Close apps? Unsaved work may be lost.",t.text,t.panel,self.width-4)
      UI.text(3,math.max(2,math.floor(self.height/2)-1)+2,"Enter: "..self.power.."  F5: cancel",t.text,t.panel,self.width-4)
    end
    self.frame.setVisible(true); self.frame.setVisible(false)
    local p=self.get(self.focus)
    base.setCursorBlink(false)
    if p and not self.launcher and not self.context and not self.power and not p.minimized and p.win.getCursorBlink() then
      local x,y=p.win.getCursorPos()
      if x>=1 and x<=p.w-2 and y>=1 and y<=p.h-2 then
        base.setCursorPos(p.x+x,p.y+y); base.setTextColor(p.win.getTextColor()); base.setCursorBlink(true)
      end
    end
    term.redirect(previous)
  end
  function self.step(e)
    local name=e[1]
    if name=="key" then self.keys[e[2]]=true elseif name=="key_up" then self.keys[e[2]]=nil end
    if name=="term_resize" then
      self.width,self.height=base.getSize()
      self.frame.reposition(1,1,self.width,self.height); self.wallpaper=nil
      local list={}; for _,p in ipairs(self.tasks) do list[#list+1]=p end
      for _,p in ipairs(list) do self.geometry(p); self.deliver(p,{"term_resize"},true) end
      self.render(); return
    end
    if self.context and input[name] then
      local menu=self.context
      local function choose(index)
        local item=menu.items[index]; self.context=nil
        if item then item.run() end
      end
      if name=='key' then
        if e[2]==keys.f5 then self.context=nil
        elseif e[2]==keys.up then menu.index=math.max(1,menu.index-1)
        elseif e[2]==keys.down then menu.index=math.min(#menu.items,menu.index+1)
        elseif e[2]==keys.enter then choose(menu.index) end
      elseif name=='mouse_click' then
        local row=e[4]-menu.y
        if e[2]==1 and e[3]>menu.x and e[3]<menu.x+menu.w-1 and row>=1 and row<=#menu.items then choose(row)
        else self.context=nil end
      elseif name=='mouse_scroll' then menu.index=math.max(1,math.min(#menu.items,menu.index+e[2])) end
    elseif self.transform and input[name] then
      local move=self.transform; local p=self.get(move.id)
      if not p then self.transform=nil
      elseif name=="key" then
        if e[2]==keys.enter then self.transform=nil
        elseif e[2]==keys.f5 then p.x,p.y,p.w,p.h=unpack(move.before); self.transform=nil
        else
          local dx=e[2]==keys.left and -1 or e[2]==keys.right and 1 or 0
          local dy=e[2]==keys.up and -1 or e[2]==keys.down and 1 or 0
          if move.mode=="Move" then p.x,p.y=p.x+dx,p.y+dy else p.w,p.h=p.w+dx,p.h+dy end
        end
        self.geometry(p); self.deliver(p,{"term_resize"},true)
      end
    elseif self.power and input[name] then
      if name=="key" and e[2]==keys.enter then self.running=false; self.action=self.power
      elseif name=="key" and e[2]==keys.f5 then self.power=nil end
    elseif name=="key" and e[2]==keys.f1 then
      self.launcher=self.launcher and nil or {query="",index=1}
    elseif self.launcher and input[name] then
      local m=self.launcher
      if name=="char" then m.query=m.query..e[2]; m.index=1
      elseif name=="key" then
        if e[2]==keys.f5 then self.launcher=nil
        elseif e[2]==keys.backspace then m.query=m.query:sub(1,-2); m.index=1
        elseif e[2]==keys.up then m.index=math.max(1,m.index-1)
        elseif e[2]==keys.down then m.index=math.min(#(m.matches or {}),m.index+1)
        elseif e[2]==keys.enter and m.matches and m.matches[m.index] then
          local id=m.matches[m.index].id; self.launcher=nil; self.launch(id)
        end
      elseif name=="mouse_click" then
        if e[3]>=3 and e[3]<=math.min(40,self.width-2)+1 and m.hits[e[4]] then
          local id=m.hits[e[4]]; self.launcher=nil; self.launch(id)
        else self.launcher=nil end
      end
    elseif name=="key" and e[2]==keys.f2 then
      local first=self.tasks[1]; if first then self.focusTask(first.id) end
    elseif name=="key" and e[2]==keys.f3 then self.minimize(self.get(self.focus))
    elseif name=="key" and e[2]==keys.f4 then self.requestClose(self.get(self.focus))
    elseif name=="key" and e[2]==keys.f6 then self.maximize(self.get(self.focus))
    elseif name=="key" and (e[2]==keys.f7 or e[2]==keys.f8) then
      local p=self.get(self.focus)
      if p then
        if p.maximized then self.maximize(p) end
        self.transform={id=p.id,mode=e[2]==keys.f7 and "Move" or "Resize",before={p.x,p.y,p.w,p.h}}
      end
    elseif name=="key" and e[2]==keys.f9 then
      if not ctx.isEncrypted or ctx.isEncrypted() then self.power="lock"
      else self.notify("Encryption is off. No password or lock is needed.") end
    elseif name=="key" and e[2]==keys.f10 then self.power="exit"
    elseif name=="mouse_up" and self.drag then self.drag=nil
    elseif name=="mouse_drag" and self.drag then
      local p=self.get(self.drag.id)
      if p then
        if self.drag.resize then
          p.w,p.h=e[3]-p.x+1,e[4]-p.y+1; self.geometry(p); self.deliver(p,{"term_resize"},true)
        else p.x,p.y=e[3]-self.drag.dx,e[4]-self.drag.dy; self.geometry(p) end
      end
    elseif name=="mouse_click" and e[2]~=1 then
      local x,y=e[3],e[4]; local hit
      for i=#self.tasks,1,-1 do local p=self.tasks[i]
        if not p.minimized and x>=p.x and x<p.x+p.w and y>=p.y and y<p.y+p.h then hit=p; break end
      end
      if hit then
        self.focusTask(hit.id)
        if y==hit.y and e[2]==2 then
          self.openContext(x,y,{
            {label='Minimize',run=function() self.minimize(hit) end},
            {label=hit.maximized and 'Restore' or 'Maximize',run=function() self.maximize(hit) end},
            {label='Close',run=function() self.requestClose(hit) end}})
        elseif x>hit.x and x<hit.x+hit.w-1 and y>hit.y and y<hit.y+hit.h-1 then
          self.deliver(hit,{name,e[2],x-hit.x,y-hit.y})
        end
      elseif e[2]==2 and y>1 and y<self.height then self.desktopContext(x,y) end
    elseif name=="mouse_click" then
      local x,y=e[3],e[4]
      if y==1 or (y==self.height and x<10) then self.launcher={query="",index=1}
      elseif y==self.height then
        for _,hit in ipairs(self.taskHits or {}) do if x>=hit.x and x<hit.x+hit.w then self.focusTask(hit.id); break end end
      else
        local hit
        for i=#self.tasks,1,-1 do local p=self.tasks[i]
          if not p.minimized and x>=p.x and x<p.x+p.w and y>=p.y and y<p.y+p.h then hit=p; break end
        end
        if hit then
          self.focusTask(hit.id)
          if y==hit.y then
            local button=x-(hit.x+hit.w-10)
            if button>=6 and button<9 then self.requestClose(hit)
            elseif button>=3 and button<6 then self.maximize(hit)
            elseif button>=0 and button<3 then self.minimize(hit)
            elseif not hit.maximized then self.drag={id=hit.id,dx=x-hit.x,dy=y-hit.y} end
          elseif not hit.maximized and y==hit.y+hit.h-1 and x>=hit.x+hit.w-3 then
            self.drag={id=hit.id,resize=true}
          elseif x>hit.x and x<hit.x+hit.w-1 and y<hit.y+hit.h-1 then
            self.deliver(hit,{name,e[2],x-hit.x,y-hit.y})
          end
        else
          self.focus=nil
          for _,v in ipairs(self.desktopHits or {}) do
            if x>=v.x and x<v.x+9 and y>=v.y and y<=v.y+3 then self.launch(v.id); break end
          end
        end
      end
    elseif input[name] or name=="terminate" then
      local p=self.get(self.focus)
      if name=="terminate" then self.requestClose(p)
      elseif p then
        if name:sub(1,6)=="mouse_" then
          local x,y=e[3]-p.x,e[4]-p.y
          if x>=1 and y>=1 and x<=p.w-2 and y<=p.h-2 then self.deliver(p,{name,e[2],x,y}) end
        else self.deliver(p,e) end
      end
    else
      if name=="timer" and e[2]==self.clockTimer then self.clockTimer=os.startTimer(1) end
      local list={}; for _,p in ipairs(self.tasks) do list[#list+1]=p end
      for _,p in ipairs(list) do
        if self.get(p.id) then
          if name=="sacabam_theme" then
            if e[2]==p.id then self.deliver(p,{"sacabam_theme"},true) end
          else self.deliver(p,e) end
        end
      end
    end
    self.render()
  end
  function self.run()
    self.clockTimer=os.startTimer(1)
    self.render()
    while self.running do self.step({os.pullEventRaw()}) end
    os.cancelTimer(self.clockTimer)
    while #self.tasks>0 do self.remove(self.tasks[#self.tasks].id) end
    return self.action
  end
  return self
end
return K
