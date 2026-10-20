-- CCSacabam 1.0.0: standalone offline installer
local package={version="1.0.0",files={
  ["apps/browser.lua"]={sha256="9b7c646cf69dc37aea9d5d59b81d8470d3902ea1d1e6a7686925e84c59562a1b",data=[=[
return function(api,initial)
  local ui=api.ui; local E=api.load('system/europa'); local C=api.load('system/cashew'); local P=api.load('system/pistachio')
  local peanut=api.load('system/peanut'); local G=api.load('system/ganymede')
  local url='about:home'; local history={}; local page; local state; local scroll,focus=0,1
  local timers={}; local controls={}; local closed=false; local status='Europa / modem network'
  local bookmarkPath='/.system/bookmarks.peanut'; local bookmarks=peanut.read(bookmarkPath) or {}
  if type(bookmarks)~='table' then bookmarks={} end
  local home=[[<cashew title="Callisto"><h1>CALLISTO</h1>
<p>A window onto Europa. Jupiter hosts the pages. Io is still doing the I/O.</p>
<p>Press G or click the address bar to visit a domain or computer ID.</p>
<p>Examples: europa://workshop.cc/ or europa://12/</p>
<a href="file:///Sites/welcome/index.cashew">Open your sample Cashew site</a>
<p>Start Jupiter on a computer with a modem to publish a folder.</p>
<p>Tab selects links and buttons. Enter activates them. Use arrows or the mouse wheel to scroll.</p>
<p>Sites cannot read your private files. Europa traffic is not encrypted or authenticated.</p></cashew>]]
  local function cancelTimers()
    for id in pairs(timers) do os.cancelTimer(id) end; timers={}
  end
  api.onExit(cancelTimers)
  local function install(response,newURL)
    cancelTimers(); state=nil; page=nil; scroll,focus=0,1
    if response.mime=='text/cashew' and response.status==200 then
      page=C.parse(response.body)
      local ast=P.parse(table.concat(page.scripts,'\n')); C.safeScript(ast)
      state=P.runtime(ast,{caps=api.caps,config=api.config,notify=api.notify},peanut); state.initialize()
    elseif response.mime=='text/pistachio' and response.status==200 then
      local ast=P.parse(response.body); C.safeScript(ast)
      state=P.runtime(ast,{caps=api.caps,config=api.config,notify=api.notify},peanut); state.initialize()
      page={title=state.title,scriptOnly=true}
    else page={title='Response '..response.status,plain=response.body} end
    url=newURL; status=response.status==200 and (response.server and 'Computer #'..response.server or 'Local page') or 'Status '..response.status
    if state then for _,timer in ipairs(state.timers) do timers[os.startTimer(timer.interval)]=timer end end
    api.setTitle('Callisto - '..(page.title or 'Page'))
  end
  local function navigate(address,back)
    if not address or address=='' then return end
    local prior=url
    local ok,err=pcall(function()
      local response
      if address=='about:home' then response={status=200,body=home,mime='text/cashew'}
      else
        local why,cancelled; response,why,cancelled=E.fetch(address)
        if cancelled then closed=true; return end
        assert(response,why); address=response.url
      end
      install(response,address)
      if not back and prior~=address then history[#history+1]=prior end
    end)
    if not ok then
      cancelTimers(); state=nil; page={title='Page error',plain=tostring(err)}; status='Could not open page'; api.notify(err)
    end
  end
  navigate(initial or 'about:home',true)
  local function layout()
    local w=term.getSize(); local t=api.theme(); local output={}; local y=1
    local function add(kind,text,attrs)
      attrs=attrs or {}; attrs.kind=kind; attrs.value=text; attrs.x=2; attrs.y=y; attrs.w=math.max(1,w-3)
      output[#output+1]=attrs; y=y+1
    end
    local function paragraph(text,kind)
      text=text:gsub('%s+',' '):match('^%s*(.-)%s*$')
      for _,line in ipairs(ui.wrap(text,math.max(1,w-3))) do add(kind or 'label',line) end
      y=y+1
    end
    if page.plain then
      for _,line in ipairs(ui.wrap(page.plain,math.max(1,w-3))) do add('label',line) end
    elseif page.scriptOnly then
      for _,v in ipairs(state.layout()) do output[#output+1]=v; y=math.max(y,v.y+1) end
    else
      local function walk(node)
        local tag=node.tag; local attrs=node.attributes or {}; local vars=state and state.vars or {}
        if tag=='script' then return
        elseif tag=='title' then page.title=C.text(node,vars)
        elseif tag=='text' then if node.text:match('%S') then paragraph(C.text(node,vars)) end
        elseif tag=='h1' or tag=='h2' then
          local title=C.text(node,vars):gsub('%s+',' '):match('^%s*(.-)%s*$')
          add(api.config().mode=='render' and tag=='h1' and 'banner' or 'heading',title); y=y+(tag=='h1' and 2 or 1)
        elseif tag=='p' or tag=='label' then paragraph(C.text(node,vars))
        elseif tag=='pre' then
          for _,line in ipairs(ui.wrap(C.text(node,vars),math.max(1,w-3))) do add('label',line) end; y=y+1
        elseif tag=='a' then add('link',C.text(node,vars):gsub('%s+',' '),{href=attrs.href or '',id=attrs.id or 'link'}); y=y+1
        elseif tag=='button' then add('button',C.text(node,vars),{id=attrs.on or attrs.id or 'button'}); y=y+1
        elseif tag=='input' then
          local name=attrs.name or attrs.id; assert(name and name:match('^[%a_][%w_]*$'),'Input needs a variable name')
          if vars[name]==nil then vars[name]=attrs.value or '' end
          add('input',vars[name],{bind=name,id=attrs.on or name}); y=y+1
        elseif tag=='br' then y=y+1
        elseif tag=='hr' then add('label',string.rep('-',math.max(1,w-3)))
        else for _,child in ipairs(node.children or {}) do walk(child) end end
      end
      walk(page)
    end
    return output,y
  end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); controls={}
    ui.text(1,1,' '..url,t.onAccent,t.accent,w)
    ui.text(1,2,' Back  Home  Address  Bookmark',t.text,t.panel,w)
    local items,total=layout(); scroll=math.max(0,math.min(scroll,math.max(0,total-h+4)))
    for _,v in ipairs(items) do
      local isControl=v.kind=='link' or v.kind=='button' or v.kind=='input' or v.kind=='checkbox'
      if isControl then controls[#controls+1]=v; v.controlIndex=#controls end
      local sy=v.y+2-scroll; v.screenY=sy
      if sy>=3 and sy<h then
        if v.kind=='banner' then
          if sy+1<h then
            local b=api.pixels.new(v.w*2,6,t.bg); api.load('system/font').draw(b,1,1,tostring(v.value),t.accent)
            api.pixels.draw(b,term,v.x,sy,v.w,2)
          end
        elseif isControl then
          local view={x=v.x,y=sy,w=v.w,value=v.value,kind=v.kind=='link' and 'button' or v.kind,id=v.id}
          G.control(view,t,focus==v.controlIndex)
        else ui.text(v.x,sy,tostring(v.value),v.kind=='heading' and t.accent or t.text,t.bg,v.w) end
      end
    end
    focus=math.max(1,math.min(focus,#controls))
    ui.text(1,h,status..' | G address  Tab links',t.muted,t.panel,w)
  end
  local function promptAddress() navigate(ui.prompt(api,'Europa address',url=='about:home' and 'europa://' or url)) end
  local function back() local previous=table.remove(history); if previous then navigate(previous,true) end end
  local function bookmark()
    bookmarks[#bookmarks+1]=url
    if #bookmarks>40 then table.remove(bookmarks,1) end
    local ok,err=peanut.write(bookmarkPath,bookmarks); api.notify(ok and 'Bookmarked. Press L for the list.' or err)
  end
  local function action(control)
    if not control then return end
    if control.kind=='link' then
      if url:sub(1,9)=='europa://' and control.href:sub(1,7)=='file://' then api.notify('Remote pages cannot open local files.'); return end
      navigate(E.relative(control.href,url))
    elseif state and control.kind~='input' then
      if control.kind=='checkbox' then state.vars[control.bind]=not state.vars[control.bind] end
      state.dispatch(control.id)
    end
  end
  while not closed do
    local drawn,drawError=pcall(draw)
    if not drawn then cancelTimers(); state=nil; page={plain=tostring(drawError),title='Page error'}; draw() end
    local e,a,b,c=os.pullEventRaw(); local selected=controls[focus]
    if e=='sacabam_close' or e=='terminate' then break end
    local ok,err=pcall(function()
      if e=='timer' and timers[a] and state then
        local timer=timers[a]; timers[a]=nil; state.tick(timer); timers[os.startTimer(timer.interval)]=timer
      elseif e=='key' then
        if a==keys.tab then
          local shift=api.keyDown(keys.leftShift) or api.keyDown(keys.rightShift)
          focus=((focus-1+(shift and -1 or 1))%math.max(1,#controls))+1
          if controls[focus] then
            local _,h=term.getSize(); local row=controls[focus].y
            if row<scroll+1 then scroll=row-1 elseif row>scroll+h-4 then scroll=row-h+4 end
          end
        elseif a==keys.enter then action(selected)
        elseif a==keys.up then scroll=scroll-1 elseif a==keys.down then scroll=scroll+1
        elseif a==keys.pageUp then local _,h=term.getSize(); scroll=scroll-h+4
        elseif a==keys.pageDown then local _,h=term.getSize(); scroll=scroll+h-4
        elseif a==keys.backspace then
          if selected and selected.kind=='input' and state then state.vars[selected.bind]=tostring(state.vars[selected.bind]):sub(1,-2); state.dispatch(selected.id)
          else back() end
        elseif a==keys.l and (api.keyDown(keys.leftCtrl) or api.keyDown(keys.rightCtrl)) then promptAddress() end
      elseif e=='char' or e=='paste' then
        if selected and selected.kind=='input' and state then
          state.vars[selected.bind]=(tostring(state.vars[selected.bind])..a:gsub('[%c]','')):sub(1,1024); state.dispatch(selected.id)
        elseif e=='char' then
          if a=='g' then promptAddress() elseif a=='h' then navigate('about:home') elseif a=='b' then bookmark()
          elseif a=='l' then
            local lines={}; for i,address in ipairs(bookmarks) do lines[#lines+1]=i..' '..address end
            api.notify(table.concat(lines,' | ')); local choice=tonumber(ui.prompt(api,'Bookmark number (1-'..#bookmarks..')'))
            if choice and bookmarks[choice] then navigate(bookmarks[choice]) end
          end
        end
      elseif e=='mouse_scroll' then scroll=scroll+a*3
      elseif e=='mouse_click' then
        if c==1 then promptAddress()
        elseif c==2 then if b<=6 then back() elseif b<=12 then navigate('about:home') elseif b<=21 then promptAddress() else bookmark() end
        else for i,v in ipairs(controls) do if c==v.screenY and b>=v.x and b<v.x+v.w then focus=i; action(v); break end end end
      end
    end)
    if not ok then api.notify(err); status='Script stopped: '..tostring(err); cancelTimers(); state=nil end
    if state and state.quit then state=nil; cancelTimers(); page={plain='Page program finished.',title='Finished'} end
  end
  cancelTimers()
end
]=]},
  ["apps/chatplus.lua"]={sha256="3ef0042dcea6b94d38d3c959d709d4c146b8ce19f3c41ffb5177821b43a63f0e",data=[[
-- Chat+ uses the same standard shell as every other Lua program.
return function(api)
  api.setTitle("Chat+ / Terminal")
  api.notify("Type: chatplus host <room>  or  chatplus join <room> <name>")
  return api.load("apps/terminal")(api)
end
]]},
  ["apps/devices.lua"]={sha256="99d30d1e6b8fa008e87f34f946ad676eea300a6ca090c460b79a1aaab53d6ef3",data=[[
return function(api)
  local ui=api.ui; local scroll=0; local timer=os.startTimer(2)
  while true do
    local t=api.theme(); local w,h=term.getSize(); local free=fs.getFreeSpace(api.home)
    local lines={"COMPUTER", "ID: "..os.getComputerID(),"Label: "..(os.getComputerLabel() or "not set"),
      "Display: "..(api.caps.color and "advanced / color" or "basic / monochrome"),
      "Mode: "..api.config().mode,"Host: "..api.caps.host,
      "Vault free: "..tostring(free).." bytes","HTTP: "..(http and "available" or "unavailable"),"", "PERIPHERALS"}
    local names=peripheral and peripheral.getNames() or {}; table.sort(names)
    for _,name in ipairs(names) do
      local kind=peripheral.getType(name); lines[#lines+1]=name.." : "..tostring(kind)
      if kind=="modem" then
        local ok,wireless=pcall(peripheral.call,name,"isWireless")
        lines[#lines+1]="  "..(ok and wireless and "Wireless" or "Wired").." / "..(rednet.isOpen(name) and "Rednet open" or "Rednet closed")
      end
    end
    if #names==0 then lines[#lines+1]="No peripherals attached." end
    if turtle then lines[#lines+1]=""; lines[#lines+1]="Turtle fuel: "..tostring(turtle.getFuelLevel()) end
    local wrapped={}
    for _,line in ipairs(lines) do for _,part in ipairs(ui.wrap(line,w-2)) do wrapped[#wrapped+1]=part end end
    scroll=math.max(0,math.min(scroll,math.max(0,#wrapped-h+2)))
    ui.clear(t); ui.bar(1," System & devices",t)
    for y=2,h-1 do ui.text(2,y,wrapped[y-1+scroll] or "",t.text,t.bg,w-2) end
    ui.text(1,h,"Arrows / wheel scroll. Hotplug supported.",t.muted,t.panel,w)
    local e,a=os.pullEventRaw()
    if e=="sacabam_close" or e=="terminate" then os.cancelTimer(timer); return
    elseif e=="timer" and a==timer then timer=os.startTimer(2)
    elseif e=="mouse_scroll" then scroll=scroll+a*3
    elseif e=="key" and a==keys.up then scroll=scroll-1 elseif e=="key" and a==keys.down then scroll=scroll+1 end
  end
end
]]},
  ["apps/editor.lua"]={sha256="5ab549dfb35e7a175b9f73a2e81edb23722608a7acfef874351c9ad49546600e",data=[[
return function(api,path)
  local ui=api.ui
  local lines={""}; local x,y,top,left=1,1,1,0
  local saved=""; local undo={}; local redo={}; local query=""
  local function contents() return table.concat(lines,"\n") end
  local function dirty() return contents()~=saved end
  local function split(raw)
    lines={}; for line in (raw:gsub("\r\n","\n").."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
    if #lines==0 then lines={""} end
  end
  local function snapshot()
    undo[#undo+1]={text=contents(),x=x,y=y}; if #undo>50 then table.remove(undo,1) end; redo={}
  end
  local function discard() return not dirty() or ui.confirm(api,"Discard unsaved changes?") end
  local function open(file)
    if fs.isDir(file) then api.notify("That is a folder."); return end
    local raw=""
    if fs.exists(file) then
      if fs.getSize(file)>131072 then api.notify("Editor limit is 128 KiB."); return end
      local err; raw,err=api.storage.read(file)
      if not raw then api.notify(err); return end
    end
    path=file; split(raw); saved=contents(); x,y,top,left=1,1,1,0; undo={}; redo={}
  end
  if path then open(path) end
  local function save(as)
    local target=path
    if not target or as then target=ui.prompt(api,"Save path",target or fs.combine(api.home,"Documents/untitled.txt")) end
    if not target or target=="" then return false end
    if target~=path and fs.exists(target) and not ui.confirm(api,"Replace "..fs.getName(target).."?") then return false end
    local ok,err=api.storage.write(target,contents())
    if ok then path=target; saved=contents(); api.notify("Saved in encrypted drive.") else api.notify(err) end
    return ok
  end
  local function insert(value)
    value=value:gsub("\r\n","\n"):gsub("\r","\n")
    if #contents()+#value>131072 then api.notify("Editor limit is 128 KiB."); return end
    snapshot()
    local before,after=lines[y]:sub(1,x-1),lines[y]:sub(x)
    local parts={}; for p in (value.."\n"):gmatch("(.-)\n") do parts[#parts+1]=p end
    if #parts==1 then lines[y]=before..value..after; x=x+#value
    else
      lines[y]=before..parts[1]
      for i=2,#parts do table.insert(lines,y+i-1,parts[i]) end
      y=y+#parts-1; x=#parts[#parts]+1; lines[y]=lines[y]..after
    end
  end
  local function find()
    query=ui.prompt(api,"Find text",query) or ""
    if query=="" then return end
    for offset=0,#lines do
      local row=((y+offset-1)%#lines)+1
      local pos=lines[row]:find(query,offset==0 and x+1 or 1,true)
      if pos then x,y=pos,row; return end
    end
    api.notify("Text not found.")
  end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); local gutter=w>24 and 5 or 0
    x=math.max(1,math.min(x,#lines[y]+1))
    if y<top then top=y elseif y>=top+h-2 then top=y-h+3 end
    if x<=left then left=x-1 elseif x>left+w-gutter then left=x-w+gutter end
    ui.clear(t)
    ui.bar(1," Save  Open  Find  Undo  Redo",t)
    for row=2,h-1 do
      local index=top+row-2
      if lines[index] then
        if gutter>0 then ui.text(1,row,string.format("%4d ",index),t.muted,t.panel,gutter) end
        local fg=lines[index]:match("^%s*%-%-") and t.muted or t.text
        ui.text(gutter+1,row,lines[index]:sub(left+1),fg,t.bg,w-gutter)
      end
    end
    ui.text(1,h,(dirty() and "* " or "  ")..(path and fs.getName(path) or "Untitled").."  "..y..":"..x.."  Ctrl+S save",t.text,t.panel,w)
    api.setTitle("Editor - "..(path and fs.getName(path) or "Untitled")..(dirty() and " *" or ""))
    term.setCursorPos(gutter+x-left,2+y-top); term.setCursorBlink(true)
  end
  local function history(from,to)
    local item=table.remove(from)
    if item then to[#to+1]={text=contents(),x=x,y=y}; split(item.text); x,y=item.x,item.y end
  end
  local function action(name)
    if name=="save" then save(api.keyDown(keys.leftShift) or api.keyDown(keys.rightShift))
    elseif name=="open" then
      if discard() then local file=ui.prompt(api,"Open path",api.home.."/Documents/"); if file and file~="" then open(file) end end
    elseif name=="find" then find()
    elseif name=="undo" then history(undo,redo)
    elseif name=="redo" then history(redo,undo) end
  end
  while true do
    draw()
    local e,a,b,c=os.pullEventRaw()
    local ctrl=api.keyDown(keys.leftCtrl) or api.keyDown(keys.rightCtrl)
    if e=="sacabam_close" or e=="terminate" then if discard() then return end
    elseif e=="char" and not ctrl then insert(a)
    elseif e=="paste" then insert(a)
    elseif e=="key" then
      if ctrl then
        local actions={[keys.s]="save",[keys.o]="open",[keys.f]="find",[keys.z]="undo",[keys.y]="redo"}
        if actions[a] then action(actions[a])
        elseif a==keys.n and discard() then path=nil; lines={""}; saved=""; x,y,top,left=1,1,1,0; undo={}; redo={} end
      elseif a==keys.left then
        if x>1 then x=x-1 elseif y>1 then y=y-1; x=#lines[y]+1 end
      elseif a==keys.right then
        if x<=#lines[y] then x=x+1 elseif y<#lines then y=y+1; x=1 end
      elseif a==keys.up then y=math.max(1,y-1)
      elseif a==keys.down then y=math.min(#lines,y+1)
      elseif a==keys.home then x=1
      elseif a==keys["end"] then x=#lines[y]+1
      elseif a==keys.pageUp then local _,h=term.getSize(); y=math.max(1,y-h+2)
      elseif a==keys.pageDown then local _,h=term.getSize(); y=math.min(#lines,y+h-2)
      elseif a==keys.enter then insert("\n")
      elseif a==keys.tab then insert("  ")
      elseif a==keys.backspace then
        if x>1 then snapshot(); lines[y]=lines[y]:sub(1,x-2)..lines[y]:sub(x); x=x-1
        elseif y>1 then snapshot(); x=#lines[y-1]+1; lines[y-1]=lines[y-1]..lines[y]; table.remove(lines,y); y=y-1 end
      elseif a==keys.delete then
        if x<=#lines[y] then snapshot(); lines[y]=lines[y]:sub(1,x-1)..lines[y]:sub(x+1)
        elseif y<#lines then snapshot(); lines[y]=lines[y]..lines[y+1]; table.remove(lines,y+1) end
      end
    elseif e=="mouse_click" then
      local w,h=term.getSize(); local gutter=w>24 and 5 or 0
      if c==1 then
        if b<=6 then action("save") elseif b<=12 then action("open") elseif b<=18 then action("find")
        elseif b<=24 then action("undo") else action("redo") end
      elseif c<h then y=math.max(1,math.min(#lines,top+c-2)); x=math.max(1,math.min(#lines[y]+1,b-gutter+left)) end
    elseif e=="mouse_scroll" then
      local _,h=term.getSize(); top=math.max(1,math.min(math.max(1,#lines-h+3),top+a*3))
      y=math.max(top,math.min(y,top+h-3))
    end
  end
end
]]},
  ["apps/files.lua"]={sha256="48f6c74761922ef0fde604f0449f4cfe2599f1a2ba87538e9e52e168d31bfd8c",data=[[
return function(api,start)
  local ui=api.ui; local dir=start or api.home
  local selection,scroll=1,0; local entries={}; local clip; local showHidden=false
  local trash=fs.combine(api.home,".Trash")
  local function refresh()
    if not fs.isDir(dir) then dir=api.home end
    entries={}
    for _,name in ipairs(fs.list(dir)) do
      if showHidden or name:sub(1,1)~="." or dir==trash then
        local path=fs.combine(dir,name); local label=name
        if dir==trash then local meta=api.storage.load(fs.combine(path,"info.tbl"),{}); label=meta.original and fs.getName(meta.original) or name end
        entries[#entries+1]={name=name,label=label,path=path,folder=fs.isDir(path)}
      end
    end
    table.sort(entries,function(a,b) if a.folder~=b.folder then return a.folder end return a.label:lower()<b.label:lower() end)
    selection=math.max(1,math.min(selection,#entries))
  end
  local function selected() return entries[selection] end
  local function navigate(path)
    if fs.isDir(path) then dir=fs.combine("",path); selection,scroll=1,0; refresh() else api.notify("Folder not found.") end
  end
  local function restore()
    local item=selected(); if not item then return end
    local info=api.storage.load(fs.combine(item.path,"info.tbl"),{})
    if not info.original then api.notify("No recovery information."); return end
    if fs.exists(info.original) then api.notify("Original path exists; rename it before restoring."); return end
    fs.move(fs.combine(item.path,"content"),info.original); fs.delete(item.path)
    api.notify("Restored "..fs.getName(info.original)); refresh()
  end
  local function open()
    local item=selected(); if not item then return end
    if dir==trash then restore()
    elseif item.folder then navigate(item.path)
    elseif item.name:match("%.sketch$") then api.launch("sketch",item.path)
    elseif item.name:match("%.pist$") then api.launch("pistachio",item.path)
    elseif item.name:match("%.lua$") then api.launch("terminal",item.path)
    else api.launch("editor",item.path) end
  end
  local function new(folder)
    local name=ui.prompt(api,folder and "New folder name" or "New file name")
    if not name then return end
    if not api.storage.name(name) then api.notify("Use a name without slashes."); return end
    local path=fs.combine(dir,name)
    if fs.exists(path) then api.notify("That name already exists."); return end
    if folder then fs.makeDir(path) else local ok,err=api.storage.write(path,""); if not ok then error(err) end; api.launch("editor",path) end
    refresh()
  end
  local function action(key)
    local item=selected()
    if key=="open" then open()
    elseif key=="up" then navigate(fs.getDir(dir))
    elseif key=="home" then navigate(api.home)
    elseif key=="location" then local path=ui.prompt(api,"Go to folder",dir); if path then navigate(path) end
    elseif key=="new" then new(false)
    elseif key=="folder" then new(true)
    elseif key=="rename" and item then
      local name=ui.prompt(api,"Rename",item.name)
      if name and api.storage.name(name) then
        local target=fs.combine(dir,name)
        if target~=item.path then fs.move(item.path,target); refresh() end
      end
    elseif (key=="copy" or key=="cut") and item then clip={path=item.path,cut=key=="cut"}; api.notify(key=="cut" and "Ready to move. Open a folder and Paste." or "Copied. Open a folder and Paste.")
    elseif key=="paste" and clip then
      local target=fs.combine(dir,fs.getName(clip.path))
      if fs.exists(target) then api.notify("Destination exists; rename it first."); return end
      if clip.cut then fs.move(clip.path,target); clip=nil else fs.copy(clip.path,target) end
      refresh()
    elseif key=="trash" and item then
      if dir==trash then
        if ui.confirm(api,"Permanently delete "..item.label.."?") then fs.delete(item.path); refresh() end
      elseif not fs.isReadOnly(item.path) and item.path~="" and item.path~=api.home and not api.storage.within(item.path,trash) then
        if not ui.confirm(api,"Move "..item.label.." to Trash?") then return end
        fs.makeDir(trash)
        local slot=api.storage.unique(trash,"item-"..tostring(math.floor(os.clock()*1000)))
        fs.makeDir(slot)
        assert(api.storage.save(fs.combine(slot,"info.tbl"),{original=item.path}))
        fs.move(item.path,fs.combine(slot,"content")); refresh()
      else api.notify("Only personal files can be moved to Trash.") end
    elseif key=="showtrash" then navigate(trash)
    elseif key=="run" and item and not item.folder then api.launch("terminal",item.path)
    elseif key=="edit" and item and not item.folder then api.launch("editor",item.path)
    elseif key=="hidden" then showHidden=not showHidden; refresh() end
  end
  local toolbar={{"Up","up"},{"Home","home"},{"New","new"},{"Folder","folder"},{"Copy","copy"},{"Paste","paste"},{"Trash","showtrash"}}
  local hits={}
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.text(1,1,"/"..dir,t.onAccent,t.accent,w)
    hits={}; local col=1
    for _,button in ipairs(toolbar) do
      local label=" "..button[1].." "
      if col+#label-1<=w then ui.text(col,2,label,t.text,t.panel); hits[#hits+1]={x=col,w=#label,action=button[2]}; col=col+#label end
    end
    local count=math.max(1,h-4)
    if selection<=scroll then scroll=selection-1 elseif selection>scroll+count then scroll=selection-count end
    for row=1,count do
      local index=scroll+row; local item=entries[index]
      if item then
        local active=index==selection
        local label=(item.folder and "+ " or "  ")..item.label
        ui.text(1,row+2,label,active and t.onAccent or t.text,active and t.accent or t.bg,w)
      end
    end
    if #entries==0 then ui.text(2,4,"This folder is empty.",t.muted,t.bg) end
    ui.text(1,h-1,"Enter open  N new  D folder  R rename",t.text,t.panel,w)
    ui.text(1,h,dir==trash and "Enter restore | Delete permanently removes" or "C/X/V copy/cut/paste  Del trash  G path",t.muted,t.panel,w)
    api.setTitle(dir==trash and "Trash" or "Files - "..(fs.getName(dir)~="" and fs.getName(dir) or "/"))
  end
  refresh()
  local lastClick,lastTime
  while true do
    draw(); local e,a,b,c=os.pullEventRaw(); local cmd
    if e=="sacabam_close" or e=="terminate" then return
    elseif e=="key" then
      if a==keys.up then selection=math.max(1,selection-1)
      elseif a==keys.down then selection=math.min(#entries,selection+1)
      elseif a==keys.enter then cmd="open"
      elseif a==keys.backspace then cmd="up"
      elseif a==keys.delete then cmd="trash" end
    elseif e=="char" then
      cmd=({n="new",d="folder",r="rename",c="copy",x="cut",v="paste",t="showtrash",g="location",h="home",p="run",e="edit",["."]="hidden"})[a:lower()]
    elseif e=="mouse_scroll" then selection=math.max(1,math.min(#entries,selection+a*3))
    elseif e=="mouse_click" then
      local _,h=term.getSize()
      if c==1 then cmd="location"
      elseif c==2 then for _,hit in ipairs(hits) do if b>=hit.x and b<hit.x+hit.w then cmd=hit.action end end
      elseif c>2 and c<h-1 then
        local index=scroll+c-2
        if entries[index] then
          selection=index
          if lastClick==index and os.clock()-(lastTime or 0)<0.4 then cmd="open" end
          lastClick,lastTime=index,os.clock()
        end
      end
    elseif e=="disk" or e=="disk_eject" then refresh() end
    if cmd then local ok,err=pcall(action,cmd); if not ok then api.notify(err) end end
  end
end
]]},
  ["apps/help.lua"]={sha256="c2ef450f4afdfa07dc9f370649b79646271b7d18fb95aee9d3700abda96ab453",data=[[
return function(api)
  local ui=api.ui; local scroll=0
  local content={
    "Welcome to CCSacabam", "Your workspace, on any computer.", "",
    "WINDOWS", "F1: app launcher (type to search)","F2: cycle running apps", "F3: minimize current window", "F4: close current window",
    "F6: maximize / restore", "F7: move window with arrow keys", "F8: resize window with arrow keys", "Enter finishes; Esc cancels move/resize.",
    "F9: lock encrypted drive", "F10: exit to CraftOS", "",
    "Advanced: drag title bars to move. Drag the bottom-right corner to resize. Click _ / + / X to minimize, maximize or close.", "",
    "FILES & PROGRAMS", "Double-click or Enter opens a file. Lua and Pistachio programs run in windows. E edits the selected file. N creates a file, D a folder. C/X/V copy, cut, paste. Delete moves to encrypted Trash; T opens Trash. Enter restores a trashed item.","",
    "EDITOR", "Ctrl+S save, Ctrl+Shift+S save as.","Ctrl+O open, Ctrl+N new, Ctrl+F find.","Ctrl+Z undo, Ctrl+Y redo.","",
    "PERSONAL DRIVE", "The password decrypts your files into memory. Names, content, temporary files and Trash are encrypted on disk. Normal filesystem paths in apps use this drive. /rom and the installed OS are read-only; /host shows your existing physical files for importing.",
    "Save before locking or exiting. Unsaved app buffers are discarded. There is no password reset. Back up the vault/data.scv file while locked.","",
    "PISTACHIO SCRIPT", "Open Pistachio from the launcher for a sample visual app. Examples are in Programs. Edit a .pist file with E in Files, then open it to run. Tab selects controls; Enter activates buttons. The same program works with monochrome and color displays.","",
    "CHAT+", "Chat+ is pre-installed. Open it from the launcher or type chatplus in Terminal. It requires a modem for hosting or joining. Its network traffic follows Chat+'s own protocol; vault encryption protects local files only.","",
    "RECOVERY", "Run boot.lua --basic for a monochrome session. A failed app does not close other apps; open Tasks to inspect it. The encrypted system log is in /.system/system.log.",
    "ComputerCraft programs share a Lua machine. Only run trusted code. The vault is encryption at rest, not protection against modified OS code or a server administrator inspecting live memory."
  }
  while true do
    local t=api.theme(); local w,h=term.getSize(); local lines={}
    for _,line in ipairs(content) do for _,part in ipairs(ui.wrap(line,w-3)) do lines[#lines+1]=part end end
    scroll=math.max(0,math.min(scroll,math.max(0,#lines-h+2)))
    ui.clear(t); ui.bar(1," CCSacabam / field guide",t)
    for y=2,h-1 do ui.text(2,y,lines[scroll+y-1] or "",t.text,t.bg,w-2) end
    ui.text(1,h,"Arrows / PageUp / PageDown / wheel",t.muted,t.panel,w)
    local e,a=os.pullEventRaw()
    if e=="sacabam_close" or e=="terminate" then return
    elseif e=="mouse_scroll" then scroll=scroll+a*3
    elseif e=="key" then
      if a==keys.up then scroll=scroll-1 elseif a==keys.down then scroll=scroll+1
      elseif a==keys.pageUp then scroll=scroll-h+2 elseif a==keys.pageDown then scroll=scroll+h-2
      elseif a==keys.home then scroll=0 end
    end
  end
end
]]},
  ["apps/pistachio.lua"]={sha256="7db496e6bca19a03e440b768363ffadd14ebf1d1743e1f74af4ff041a65364ea",data=[[
return function(api,path)
  local ui=api.ui
  path=path or fs.combine(api.home,'Programs/counter.pist')
  local source,err=api.storage.read(path); assert(source,err)
  local lang=api.load('system/pistachio'); local peanut=api.load('system/peanut')
  local state=lang.runtime(lang.parse(source),api,peanut); state.initialize()
  local timers={}
  for _,timer in ipairs(state.timers) do timers[os.startTimer(timer.interval)]=timer end
  local controls={}; local focus=1
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); controls={}
    api.setTitle(state.title)
    for _,v in ipairs(state.layout()) do
      v.w=math.max(1,math.min(v.w,w)); local text=tostring(v.value or '')
      if v.kind=='panel' then
        ui.fill(v.x,v.y,v.w,math.min(v.h,h),t.panel)
      elseif v.kind=='label' then ui.text(v.x,v.y,text,t.text,t.bg,v.w)
      elseif v.kind=='banner' and api.config().mode=='render' then
        local b=api.pixels.new(v.w*2,6,t.bg)
        api.load('system/font').draw(b,1,1,text,t.accent); api.pixels.draw(b,term,v.x,v.y,v.w,2)
      elseif v.kind=='banner' then ui.text(v.x,v.y,text:upper(),t.text,t.bg,v.w)
      elseif v.kind=='progress' then
        local value=math.max(0,math.min(100,tonumber(v.value) or 0))
        local size=math.max(1,v.w-2); local filled=math.floor(size*value/100)
        ui.text(v.x,v.y,'['..string.rep('=',filled)..string.rep(' ',size-filled)..']',t.text,t.panel,v.w)
      else
        controls[#controls+1]=v; local active=#controls==focus
        api.load('system/ganymede').control(v,t,active)
      end
    end
    focus=math.max(1,math.min(focus,#controls))
    ui.text(1,h,'Tab: next  Enter: activate  F4: close',t.muted,t.panel,w)
  end
  local function activate(control)
    if not control then return end
    if control.kind=='checkbox' then state.vars[control.bind]=not state.vars[control.bind] end
    if control.kind~='input' then state.dispatch(control.id) end
  end
  while not state.quit do
    draw(); local e,a,b,c=os.pullEventRaw()
    local control=controls[focus]
    if e=='sacabam_close' or e=='terminate' then break
    elseif e=='timer' and timers[a] then
      local timer=timers[a]; timers[a]=nil; state.tick(timer); timers[os.startTimer(timer.interval)]=timer
    elseif e=='key' then
      if a==keys.tab then
        local backwards=api.keyDown(keys.leftShift) or api.keyDown(keys.rightShift)
        focus=((focus-1+(backwards and -1 or 1))%math.max(1,#controls))+1
      elseif a==keys.enter then activate(control)
      elseif a==keys.space and control and control.kind~='input' then activate(control)
      elseif a==keys.backspace and control and control.kind=='input' then state.vars[control.bind]=tostring(state.vars[control.bind]):sub(1,-2); state.dispatch(control.id) end
    elseif (e=='char' or e=='paste') and control and control.kind=='input' then
      state.vars[control.bind]=(tostring(state.vars[control.bind])..a:gsub('[%c]','')):sub(1,1024); state.dispatch(control.id)
    elseif e=='mouse_click' then
      for i,v in ipairs(controls) do if b>=v.x and b<v.x+v.w and c==v.y then focus=i; activate(v); break end end
    end
  end
  for id in pairs(timers) do os.cancelTimer(id) end
end
]]},
  ["apps/processes.lua"]={sha256="ed8d00268966be4c3a968c6a803d56332947291d94f1ac2cff37ed8f8d42a616",data=[[
return function(api)
  local selected=1; local ui=api.ui; local timer=os.startTimer(1)
  while true do
    local t=api.theme(); local w,h=term.getSize(); local items=api.processes()
    selected=math.max(1,math.min(selected,#items)); ui.clear(t); ui.bar(1," ID   Application / state",t)
    local first=math.max(1,selected-h+4)
    for row=2,h-2 do local i=first+row-2; local p=items[i]
      if p then ui.text(1,row,string.format(" %3d  %s [%s]",p.id,p.title,p.minimized and "hidden" or p.state),i==selected and t.onAccent or t.text,i==selected and t.accent or t.bg,w) end
    end
    ui.text(1,h-1,"Enter focus | C close | K force stop",t.text,t.panel,w)
    ui.text(1,h,"E error details | F2 switch apps",t.muted,t.panel,w)
    local e,a,b,c=os.pullEventRaw(); local p=items[selected]
    if e=="sacabam_close" or e=="terminate" then os.cancelTimer(timer); return
    elseif e=="timer" and a==timer then timer=os.startTimer(1)
    elseif e=="key" then
      if a==keys.up then selected=selected-1 elseif a==keys.down then selected=selected+1
      elseif a==keys.enter and p then api.focus(p.id) end
    elseif e=="mouse_click" and c>=2 and c<h-1 then selected=first+c-2
    elseif e=="char" and p then
      if a=="c" then api.close(p.id)
      elseif a=="k" and p.id~=api.id and ui.confirm(api,"Force stop "..p.title.."?") then api.kill(p.id)
      elseif a=="e" then api.notify(p.error or "No error reported.") end
    end
  end
end
]]},
  ["apps/server.lua"]={sha256="e7e0047d68aeb137e35fe32abd2b97dcabc66eb1aef56a753f57fb0734c5291d",data=[[
return function(api,domain,root)
  local ui=api.ui; local E=api.load('system/europa'); local server
  domain=domain or 'computer-'..os.getComputerID()..'.cc'
  root=root or '/Sites/welcome'; local message='Offline. Choose a domain and site folder.'
  local function stop() if server then server.stop(); server=nil end end
  api.onExit(stop)
  local function start()
    if server then stop(); message='Server stopped.'; return end
    server=E.start(domain,root); message='Serving europa://'..domain..'/ and computer #'..os.getComputerID()
  end
  while true do
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); ui.bar(1,' Jupiter / Europa web server',t)
    ui.text(2,3,'Domain: '..domain,t.text,t.bg,w-2)
    ui.text(2,5,'Folder: '..root,t.text,t.bg,w-2)
    ui.text(2,7,server and '[ Stop server ]' or '[ Start server ]',t.onAccent,t.accent,18)
    ui.text(2,9,'Requests: '..(server and server.requests or 0),t.text,t.bg,w-2)
    ui.text(2,10,'Home page: index.cashew',t.muted,t.bg,w-2)
    ui.text(1,h-1,message,t.text,t.panel,w)
    ui.text(1,h,'Enter start/stop | D domain | R folder',t.muted,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then stop(); return end
    local ok,err=pcall(function()
      if e=='rednet_message' and server then server.receive(a,b,c)
      elseif e=='key' and a==keys.enter then start()
      elseif e=='char' then
        if a=='d' and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif a=='r' and not server then root=ui.prompt(api,'Published folder',root) or root end
      elseif e=='mouse_click' then
        if c==3 and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif c==5 and not server then root=ui.prompt(api,'Published folder',root) or root
        elseif c==7 then start() end
      end
    end)
    if not ok then message=tostring(err); api.notify(err) end
  end
end
]]},
  ["apps/settings.lua"]={sha256="b677c5acfbf8dca90aa3959201c4f33860123c735b650afc693c0669dce81ea8",data=[[
return function(api)
  local ui=api.ui; local selected=1; local offset=0
  local function options()
    local c=api.config()
    return {"Display: "..c.mode,"Theme: "..c.theme,"Wallpaper: "..tostring(c.wallpaper),
      "Welcome guide: "..tostring(c.welcome),"Lock personal drive","Change passphrase",
      "Exit to CraftOS","Restart computer","Shut down computer"}
  end
  local function choose(n)
    local c=api.config()
    if n==1 then
      if not api.caps.color then c.mode="basic"; api.notify("This computer has a monochrome display.")
      elseif c.mode=="basic" then c.mode="color" elseif c.mode=="color" and api.caps.blit then c.mode="render" else c.mode="basic" end
    elseif n==2 then c.theme=c.theme=="dark" and "light" or "dark"
    elseif n==3 then c.wallpaper=not c.wallpaper
    elseif n==4 then c.welcome=not c.welcome
    elseif n==5 then api.requestExit("lock")
    elseif n==6 then
      local password,entropy=api.password("New passphrase",{"At least 12 characters. No password reset."})
      if password then
        local again=api.password("Confirm new passphrase")
        if again~=password then api.notify("Passphrases did not match.")
        else local ok,err=api.changePassword(password,entropy); api.notify(ok and "Passphrase changed." or err) end
      end
    elseif n==7 then api.requestExit("exit") elseif n==8 then api.requestExit("reboot") elseif n==9 then api.requestExit("shutdown") end
    if n<=4 then api.saveConfig() end
  end
  while true do
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.bar(1," Settings",t)
    local items=options(); local rows=math.max(1,h-3)
    if selected<=offset then offset=selected-1 elseif selected>offset+rows then offset=selected-rows end
    for row=1,rows do local i=row+offset
      if items[i] then ui.text(1,row+1,(selected==i and "> " or "  ")..i.." "..items[i],selected==i and t.onAccent or t.text,selected==i and t.accent or t.bg,w) end
    end
    ui.text(1,h-1,"Saved files are encrypted automatically.",t.muted,t.bg,w)
    ui.text(1,h,"Arrows + Enter / click / number",t.text,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=="sacabam_close" or e=="terminate" then return
    elseif e=="key" then
      if a==keys.up then selected=math.max(1,selected-1) elseif a==keys.down then selected=math.min(#items,selected+1)
      elseif a==keys.enter then choose(selected) end
    elseif e=="char" and tonumber(a) and tonumber(a)>=1 and tonumber(a)<=#items then selected=tonumber(a); choose(selected)
    elseif e=="mouse_click" and c>1 and c<=rows+1 and items[offset+c-1] then selected=offset+c-1; choose(selected)
    elseif e=="mouse_scroll" then selected=math.max(1,math.min(#items,selected+a)) end
  end
end
]]},
  ["apps/sketch.lua"]={sha256="39b51c024a24417db90f4be2aec915491d628336f5cfff38df172a580a1d3715",data=[=[
return function(api,path)
  local ui,pixels=api.ui,api.pixels
  local hex='0123456789abcdef'; local color=colors.cyan; local cx,cy=1,1
  local canvas=pixels.new(80,39,colors.black); local dirty=false; local demo=false; local angle=0
  local timer; local last; local message='Arrows move; Space draws'
  local function serialize()
    local rows={}
    for y=1,canvas.h do local row={}
      for x=1,canvas.w do local n=0; local c=canvas.data[y][x]; while c>1 do c=c/2; n=n+1 end; row[x]=hex:sub(n+1,n+1) end
      rows[y]=table.concat(row)
    end
    return {format='ccsacabam-sketch-1',width=canvas.w,height=canvas.h,rows=rows}
  end
  local function open(file)
    local peanut=api.load('system/peanut'); local data,err=peanut.read(file)
    assert(data,err); assert(data.format=='ccsacabam-sketch-1','Not a CCSacabam sketch')
    assert(type(data.width)=='number' and data.width>=1 and data.width<=160 and data.width%1==0,'Invalid width')
    assert(type(data.height)=='number' and data.height>=1 and data.height<=90 and data.height%1==0,'Invalid height')
    local fresh=pixels.new(data.width,data.height,colors.black)
    for y=1,fresh.h do
      local row=data.rows[y]; assert(type(row)=='string' and #row==fresh.w and not row:find('[^0-9a-f]'),'Invalid pixels')
      for x=1,fresh.w do fresh.set(x,y,2^tonumber(row:sub(x,x),16)) end
    end
    canvas=fresh; path=file; dirty=false; cx,cy=1,1
  end
  if path then open(path) end
  local function discard() return not dirty or ui.confirm(api,'Discard unsaved drawing?') end
  local function save()
    local file=ui.prompt(api,'Save sketch',path or fs.combine(api.home,'Pictures/untitled.sketch'))
    if not file then return end
    if file~=path and fs.exists(file) and not ui.confirm(api,'Replace existing sketch?') then return end
    local ok,err=api.load('system/peanut').write(file,serialize())
    if ok then path=file; dirty=false; api.notify('Sketch saved in encrypted drive.') else api.notify(err) end
  end
  local function cube(w,h)
    local b=pixels.new(w,h,colors.black); local points={}; local scale=math.min(w,h)*0.29
    local vertices={{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}
    for i,v in ipairs(vertices) do
      local x=v[1]*math.cos(angle)-v[3]*math.sin(angle); local z=v[1]*math.sin(angle)+v[3]*math.cos(angle)
      local y=v[2]*math.cos(angle*.7)-z*math.sin(angle*.7); z=v[2]*math.sin(angle*.7)+z*math.cos(angle*.7)
      local f=3/(z+4); points[i]={math.floor(w/2+x*scale*f),math.floor(h/2+y*scale*f)}
    end
    for _,edge in ipairs({{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}) do
      local a,bp=points[edge[1]],points[edge[2]]; b.line(a[1],a[2],bp[1],bp[2],api.config().mode=='basic' and colors.white or colors.cyan)
    end
    return b
  end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.bar(1,' Save  Open  New  3D demo',t)
    local display=demo and cube(w*2,math.max(3,(h-4)*3)) or canvas
    if api.config().mode~='basic' then pixels.draw(display,term,1,3,w,h-4)
    else
      for yy=1,math.min(h-4,math.ceil(display.h/3)) do
        for xx=1,math.min(w,math.ceil(display.w/2)) do
          local on=false
          for dy=0,2 do for dx=0,1 do local row=display.data[(yy-1)*3+dy+1]; if row and row[(xx-1)*2+dx+1] and row[(xx-1)*2+dx+1]~=colors.black then on=true end end end
          ui.text(xx,yy+2,on and '#' or ' ',t.text,t.bg)
        end
      end
    end
    for i=0,15 do
      if api.config().mode=='basic' then if i<2 then ui.text(1+i*4,2,i==0 and ' ink' or 'wipe',t.text,t.panel,4) end
      else ui.text(i*2+1,2,color==2^i and '<>' or '  ',i==15 and colors.white or colors.black,2^i,2) end
    end
    ui.text(1,h-1,'S save O open N new D demo [ ] color',t.text,t.panel,w)
    ui.text(1,h,message,t.muted,t.panel,w)
    if not demo then
      term.setCursorPos(math.ceil(cx/2),math.ceil(cy/3)+2); term.setCursorBlink(true)
    end
    api.setTitle('Sketch'..(dirty and ' *' or '')..(demo and ' / 3D' or ''))
  end
  local function command(cmd)
    if cmd=='s' then save()
    elseif cmd=='o' and discard() then local file=ui.prompt(api,'Open sketch',api.home..'/Pictures/'); if file then open(file) end
    elseif cmd=='n' and discard() then canvas=pixels.new(80,39,colors.black); dirty=false
    elseif cmd=='d' then demo=not demo; if demo then timer=os.startTimer(.1) elseif timer then os.cancelTimer(timer); timer=nil end
    elseif cmd=='[' then color=color/2; if color<1 then color=32768 end
    elseif cmd==']' then color=color*2; if color>32768 then color=1 end end
  end
  while true do
    draw(); local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then if discard() then if timer then os.cancelTimer(timer) end; return end
    elseif e=='timer' and a==timer and demo then angle=angle+.07; timer=os.startTimer(.1)
    elseif e=='char' then local ok,err=pcall(command,a:lower()); if not ok then api.notify(err) end
    elseif e=='key' and not demo then
      local w,h=term.getSize()
      if a==keys.left then cx=math.max(1,cx-1) elseif a==keys.right then cx=math.min(canvas.w,w*2,cx+1)
      elseif a==keys.up then cy=math.max(1,cy-1) elseif a==keys.down then cy=math.min(canvas.h,(h-4)*3,cy+1)
      elseif a==keys.space then canvas.set(cx,cy,api.config().mode=='basic' and colors.white or color); dirty=true
      elseif a==keys.backspace then canvas.set(cx,cy,colors.black); dirty=true end
      message='Pixel '..cx..', '..cy..' | Space ink / Backspace erase'
    elseif e=='mouse_up' then last=nil
    elseif e=='mouse_click' or e=='mouse_drag' then
      local _,h=term.getSize()
      if c==1 and e=='mouse_click' then
        local cmd=b<=6 and 's' or b<=12 and 'o' or b<=17 and 'n' or 'd'
        local ok,err=pcall(command,cmd); if not ok then api.notify(err) end
      elseif c==2 then color=2^math.min(15,math.floor((b-1)/2))
      elseif c>=3 and c<=h-2 and not demo then
        cx,cy=math.min(canvas.w,(b-1)*2+1),math.min(canvas.h,(c-3)*3+1)
        local ink=a==2 and colors.black or color
        if last then canvas.line(last[1],last[2],cx,cy,ink) end
        canvas.rect(cx,cy,2,3,ink); last={cx,cy}; dirty=true
      end
    end
  end
end
]=]},
  ["apps/terminal.lua"]={sha256="2f7c31e6ccecf0618865f0e7f5b1b0800be96b77bd6f6e80ca0912c64a835c21",data=[[
return function(api,program)
  local parent={}; for k,v in pairs(api.shell) do parent[k]=v end
  parent.dir=function() return api.home end
  parent.path=function() return ".:"..fs.combine(api.home,"Programs")..":"..api.shell.path() end
  local t=api.theme(); term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorPos(1,1)
  print("CCSacabam encrypted terminal")
  print("Save files in /"..api.home)
  print("F1 apps | F2 switch | F4 close")
  local function shellTask()
    if program then
      os.run({shell=parent,multishell=false},"/rom/programs/shell.lua",'"'..program..'"')
      print("Program finished. Press any key."); os.pullEvent("key")
    else os.run({shell=parent,multishell=false},"/rom/programs/shell.lua") end
  end
  parallel.waitForAny(shellTask,function()
    while true do
      local e=os.pullEventRaw()
      if e=="sacabam_close" or e=="terminate" then return end
    end
  end)
end
]]},
  ["boot.lua"]={sha256="98483b00e6eaefed3408e3d1a6c71fba0d943589af9fa194ecdb575d599cab8b",data=[[
-- Entry point: login, encrypted personal drive, then the desktop session.
local args={...}
local root=fs.getDir(shell.getRunningProgram())
local original=term.current()
local originalDir=shell.dir()
local physicalEnv=_ENV
local activeVault
local function main()
  local function physicalModule(name) return assert(loadfile(fs.combine(root,name..".lua"),"t",physicalEnv))() end
  assert(window and window.create and term.blit and bit32,"CCSacabam needs CC: Tweaked / ComputerCraft with blit, window and bit32.")
  local configModule=physicalModule("system/config")
  local storage=physicalModule("system/storage")
  local caps=configModule.capabilities(original)
  assert(caps.width>=20 and caps.height>=10,"Display must be at least 20 columns by 10 rows.")
  fs.makeDir(fs.combine(root,"vault"))
  fs.makeDir(fs.combine(root,"config"))
  local vault=physicalModule("system/vault").new(physicalModule("system/crypto"),storage,fs.combine(root,"vault/data.scv"))
  activeVault=vault
  vault.recoverPending()
  local login=physicalModule("system/login")
  local session=physicalModule("system/session")
  while login.unlock(vault) do
    local function desktop()
      local env=session.environment(vault.filesystem(fs.combine(root,"home")),physicalEnv)
      local cache={}
      local function module(name)
        if not cache[name] then cache[name]=assert(env.loadfile(fs.combine(root,name..".lua")))() end
        return cache[name]
      end
      local defaults=storage.load(fs.combine(root,"config/display.tbl"),{})
      local config=configModule.normalize(module("system/storage").load(fs.combine(root,"home/.system/settings.tbl"),defaults),caps)
      if args[1]=="--basic" then config.mode="basic" end
      if not env.fs.exists(fs.combine(root,"home/.examples-installed")) then
        for _,name in ipairs(fs.list(fs.combine(root,"examples"))) do
          local destination=fs.combine(root,"home/Programs/"..name)
          if not env.fs.exists(destination) then env.fs.copy(fs.combine(root,"examples/"..name),destination) end
        end
        local chat=fs.combine(root,"home/Programs/chatplus.lua")
        if not env.fs.exists(chat) then env.fs.copy(fs.combine(root,"chatplus.lua"),chat) end
        if not env.fs.exists("/Sites/welcome") then env.fs.copy(fs.combine(root,"sites/welcome"),"/Sites/welcome") end
        assert(module("system/storage").write(fs.combine(root,"home/.examples-installed"),"1"))
      end
      local ctx={root=root,load=module,config=config,configModule=configModule,caps=caps,target=original,shell=shell,
        password=login.password,
        changePassword=function(password,entropy) return vault.changePassword(password,entropy,login.progress) end}
      local kernel=module("system/kernel").new(ctx)
      env.ccsacabam={launch=kernel.launch,version=configModule.version}
      if config.welcome then kernel.launch("help") end
      return kernel.run()
    end
    local ok,action=pcall(desktop)
    vault.lock()
    if collectgarbage then pcall(collectgarbage,"collect") end
    term.redirect(original)
    if not ok then error(action,0) end
    if action=="reboot" then os.reboot() elseif action=="shutdown" then os.shutdown()
    elseif action~="lock" then return end
  end
end
local ok,err=pcall(main)
if activeVault then activeVault.lock(); activeVault=nil end
term.redirect(original)
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.setCursorBlink(false)
term.clear(); term.setCursorPos(1,1)
if fs.exists(originalDir) and fs.isDir(originalDir) then shell.setDir(originalDir) end
if not ok then
  print("CCSacabam could not continue:")
  printError(tostring(err))
  print("The personal drive is locked.")
  print("Try: "..fs.combine(root,"boot.lua").." --basic")
  return false
end
print("CCSacabam closed. Your personal drive is locked.")
return true
]]},
  ["chatplus.lua"]={sha256="a80ee463acddf7e00fa2a7476a55bde634d5726650ae455a9e8f030851fe454d",data=[[
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
]]},
  ["examples/clock.pist"]={sha256="b8dce552c14f4cd3452006ca23d03aaa635753c373ae995269e908bbbdb1cf9a",data=[[
app "Pistachio / Timer"
let seconds = 0
let running = true
label title 2 2 30 "Your session timer"
label elapsed 2 4 30 "Seconds: {seconds}"
checkbox runningToggle 2 6 24 running
button reset 2 8 16 "Reset"
every 1
  if running
    set seconds = seconds + 1
  end
end
on reset
  set seconds = 0
end
]]},
  ["examples/counter.pist"]={sha256="b95892ff0442cfecc0863181efa228ddeb6479832cee6503b84f16f6565dce85",data=[[
# The same app runs on basic and advanced computers.
app "Pistachio / Counter"
let count = 0
banner heading 2 2 32 "PISTACHIO"
label explanation 2 5 36 "A native CCSacabam application"
button add 2 7 15 "Add one"
button reset 19 7 15 "Reset"
label value 2 9 35 "Count: {count}"
if advanced
  label device 2 11 36 "Advanced hardware detected"
else
  label device 2 11 36 "Basic hardware: keyboard ready"
end
on add
  set count = count + 1
end
on reset
  set count = 0
end
]]},
  ["examples/europa.lua"]={sha256="26e0c24b08490d6cfe4cafd29179052fdc70d584b2d7cd26c8fd543dc069d815",data=[[
local command,a,b=...
assert(ccsacabam,'Use this launcher inside CCSacabam')
if command=='host' then ccsacabam.launch('server',a,b)
elseif command=='open' then ccsacabam.launch('browser',a)
else print('europa host <domain> [site-folder]'); print('europa open <europa://domain/path>') end
]]},
  ["examples/ganymede-demo.lua"]={sha256="7553dc980a58a0a90c3b76fde7c792c6c658fb8fa7def39d14a880bd8ec69b30",data=[[
local ganymede = require('ganymede')
local form = ganymede.form('Ganymede / Lua UI')
local count = 0
form.label('heading',2,3,35,'Lua programs can use native controls too.')
form.label('count',2,5,30,'Count: 0')
form.button('add',2,7,15,'Add one',function()
  count=count+1
  form.set('count','Count: '..count)
end)
form.button('quit',20,7,12,'Close',function() form.close() end)
form.run()
]]},
  ["examples/greeting.pist"]={sha256="92c50cd08da5e8375ea1308de5fbaa2748c9261605ae3958b274ce788099d90d",data=[[
app "Pistachio / Hello"
let name = "friend"
let message = "Enter a name and press Greet."
label title 2 2 35 "What should I call you?"
input nameField 2 4 30 name
button greet 2 6 14 "Greet"
button save 19 6 14 "Save"
label result 2 8 36 message
on greet
  set message = "Hello, " .. name .. "!"
end
on save
  save message "/Documents/greeting.peanut"
  notify "Greeting saved as Peanut data."
end
]]},
  ["examples/peanut-demo.lua"]={sha256="78d1b7714116374b316cef4abc3437d1ce4976379e566ab59a44fa41eb027a4c",data=[[
local peanut = require('peanut')
local path = '/Documents/example.peanut'
local value = {name='CCSacabam', enabled=true, count=42, tags=peanut.array({'lua','pistachio'}), optional=peanut.null}
assert(peanut.write(path,value))
local restored = assert(peanut.read(path))
print('Saved and read encrypted Peanut data:')
print(peanut.encode(restored,true))
]]},
  ["examples/pistachio.lua"]={sha256="70badd04b0c3bdb0e7568a6afaf5e984e1fd06723ddc3e10947877940eef97f8",data=[[
local path = ...
if not path then print('Usage: pistachio <file.pist>'); return end
assert(ccsacabam,'Run this command inside CCSacabam').launch('pistachio',shell.resolve(path))
]]},
  ["sites/welcome/about.cashew"]={sha256="6a1c3347dc8f6ec27c51a813c3030452f5f5d6bb855438be47942c8a7b19b580",data=[[
<cashew title="About Europa">
<h1>SMALL WEB, BIG MOONS</h1>
<p>Save .cashew pages in a site folder. Start Jupiter with a domain such as workshop.cc. Other computers can visit europa://workshop.cc/ or use the server computer's numeric ID.</p>
<p>Both computers need modems within range, or a connected wired network. Server and browser also work together on one computer.</p>
<p>Cashew supports headings, paragraphs, links, buttons, inputs, and inline Pistachio. Use Tab and Enter on a basic computer.</p>
<a href="index.cashew">Back home</a>
</cashew>
]]},
  ["sites/welcome/index.cashew"]={sha256="ad8bea658db8ec5e6d0cd98456354c7040dea22625e75fe878b88c46a6bf24e6",data=[[
<cashew title="Your first site">
  <h1>HELLO, EUROPA</h1>
  <p>Jupiter hosts the site. Callisto visits it. Io does the I/O. The naming committee has been left unsupervised.</p>
  <p>This page uses Cashew markup and Pistachio events.</p>
  <label>Your name:</label>
  <input name="name" value="traveller" />
  <button id="greet">Say hello</button>
  <p>{message}</p>
  <a href="about.cashew">About this site</a>
  <script type="pistachio">
    let message = "The button above works on basic computers too."
    on greet
      set message = "Hello, " .. name .. "!"
    end
  </script>
</cashew>
]]},
  ["system/cashew.lua"]={sha256="566cf6d01994f354f140e98ee8bb2dc4b75a204a1c89c92f7ae82b2c828e0277",data=[[
-- Cashew: a deliberately small HTML-like document format with Pistachio events.
local C={}
local allowed={cashew=true,html=true,head=true,body=true,main=true,div=true,title=true,h1=true,h2=true,p=true,
  pre=true,a=true,button=true,input=true,label=true,br=true,hr=true,script=true}
local function entities(s)
  local named={amp='&',lt='<',gt='>',quot='"',apos="'"}
  return (s:gsub('&([#%w]+);',function(name)
    if named[name] then return named[name] end
    local n=name:match('^#x(%x+)$'); n=n and tonumber(n,16) or tonumber(name:match('^#(%d+)$'))
    if n and n>=32 and n<=255 then return string.char(n) end
    return '&'..name..';'
  end))
end
function C.parse(source)
  assert(type(source)=='string' and #source<=32768,'Cashew page exceeds 32 KiB')
  local doc={tag='document',children={},title='Cashew page',scripts={}}
  local stack={doc}; local pos,count=1,0
  while pos<=#source do
    if source:sub(pos,pos+3)=='<!--' then
      local ending=assert(source:find('-->',pos+4,true),'Unclosed comment'); pos=ending+3
    elseif source:sub(pos,pos)=='<' then
      -- Find the end of a tag while respecting quoted attribute values.
      local ending,quote
      for i=pos+1,#source do local c=source:sub(i,i)
        if quote then if c==quote then quote=nil end
        elseif c=='"' or c=="'" then quote=c elseif c=='>' then ending=i; break end
      end
      assert(ending,'Unclosed tag')
      local raw=source:sub(pos+1,ending-1); pos=ending+1
      local close=raw:match('^/%s*([%w]+)%s*$')
      if close then
        assert(#stack>1 and stack[#stack].tag==close:lower(),'Mismatched closing tag: '..close)
        table.remove(stack)
      else
        local name,rest=raw:match('^%s*([%w]+)%s*(.-)%s*$'); assert(name,'Invalid tag')
        name=name:lower(); assert(allowed[name],'Unsupported Cashew tag: '..name)
        local selfClosing=rest:sub(-1)=='/'; if selfClosing then rest=rest:sub(1,-2) end
        local node={tag=name,attributes={},children={}}
        while rest:match('%S') do
          local key,q,value,tail=rest:match('^%s*([%w_-]+)%s*=%s*(["\'])(.-)%2%s*(.*)$')
          assert(key,'Attributes must have quoted values'); assert(node.attributes[key]==nil,'Duplicate attribute: '..key)
          node.attributes[key]=entities(value); rest=tail
        end
        count=count+1; assert(count<=256,'Cashew has more than 256 elements')
        local parent=stack[#stack]; parent.children[#parent.children+1]=node
        if name=='cashew' or name=='html' then doc.title=node.attributes.title or doc.title end
        if name=='script' then
          assert(not node.attributes.src,'External scripts are not supported; use an inline Pistachio script')
          assert(not node.attributes.type or node.attributes.type=='pistachio','Only Pistachio scripts are allowed')
          local a,b=source:find('</script%s*>',pos); assert(a,'Unclosed script')
          doc.scripts[#doc.scripts+1]=source:sub(pos,a-1); pos=b+1
        elseif name~='br' and name~='hr' and name~='input' and not selfClosing then
          assert(#stack<32,'Cashew nesting limit exceeded'); stack[#stack+1]=node
        end
      end
    else
      local ending=source:find('<',pos,true) or #source+1
      local text=entities(source:sub(pos,ending-1)); pos=ending
      stack[#stack].children[#stack[#stack].children+1]={tag='text',text=text}
    end
  end
  assert(#stack==1,'Unclosed Cashew tag: '..stack[#stack].tag)
  return doc
end
function C.text(node,variables)
  local parts={}
  local function walk(n)
    if n.tag=='text' then parts[#parts+1]=n.text else for _,child in ipairs(n.children or {}) do walk(child) end end
  end
  walk(node)
  return (table.concat(parts):gsub('{([%a_][%w_]*)}',function(key)
    local value=variables and variables[key]; return value==nil and '{'..key..'}' or tostring(value)
  end))
end
function C.safeScript(ast)
  local safe={let=true,set=true,on=true,['function']=true,['if']=true,['repeat']=true,every=true,notify=true,call=true,quit=true,app=true,
    label=true,button=true,input=true,checkbox=true,progress=true,banner=true,panel=true}
  for _,node in ipairs(ast) do
    assert(safe[node.op],'Web pages cannot use '..node.op)
    if node.body then C.safeScript(node.body) end
    if node.other then C.safeScript(node.other) end
  end
  return true
end
return C
]]},
  ["system/config.lua"]={sha256="8c80b3498acf68980912bda01d17fc53b1bc631f28970a964b15d90a1e2a90af",data=[[
local M = {}
M.version = "1.0.0"
function M.capabilities(target)
  target = target or term.current()
  local w, h = target.getSize()
  return { color = target.isColor(), blit = type(target.blit) == "function",
    width = w, height = h, turtle = turtle ~= nil, pocket = pocket ~= nil,
    http = http ~= nil, host = _HOST or os.version() }
end
function M.normalize(c, caps)
  c = type(c) == "table" and c or {}
  local mode = c.mode
  if not caps.color then mode = "basic"
  elseif mode ~= "basic" and mode ~= "color" and mode ~= "render" then mode = "color" end
  if mode == "render" and not caps.blit then mode = "color" end
  return { mode = mode, theme = c.theme == "light" and "light" or "dark",
    wallpaper = c.wallpaper ~= false, clock24 = c.clock24 ~= false,
    welcome = c.welcome ~= false, version = M.version }
end
function M.theme(config)
  if config.mode == "basic" then
    return { bg = colors.black, panel = colors.black, text = colors.white,
      muted = colors.white, accent = colors.white, onAccent = colors.black,
      border = colors.white, desktop = colors.black, danger = colors.white }
  end
  if config.theme == "light" then
    return { bg = colors.white, panel = colors.lightGray, text = colors.black,
      muted = colors.gray, accent = colors.blue, onAccent = colors.white,
      border = colors.gray, desktop = colors.cyan, danger = colors.red }
  end
  return { bg = colors.black, panel = colors.gray, text = colors.white,
    muted = colors.lightGray, accent = colors.cyan, onAccent = colors.black,
    border = colors.gray, desktop = colors.blue, danger = colors.red }
end
return M
]]},
  ["system/crypto.lua"]={sha256="2cda78cb7e1d30944bd4e3911fdf371f95f6a1e97855c10ad5682081bcabb5d7",data=[[
-- SHA-256, HMAC-SHA-256, PBKDF2 and IETF ChaCha20. Pure Lua / bit32.
-- Encrypt-then-MAC envelope; see docs/SECURITY.md for the format and limits.
local C = {}
local unpack=table.unpack or unpack
assert(bit32, "CCSacabam encryption requires bit32 (CC: Tweaked recommended)")
local bx,ba,bn,rr,rs,ls,lr = bit32.bxor,bit32.band,bit32.bnot,bit32.rrotate,bit32.rshift,bit32.lshift,bit32.lrotate
local MOD = 4294967296
local H0={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local constants={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
function C.be(n) return string.char(rs(n,24),ba(rs(n,16),255),ba(rs(n,8),255),ba(n,255)) end
function C.number(s,p)
  local a,b,c,d=s:byte(p,p+3); return ((a*256+b)*256+c)*256+d
end
local function le(n) return string.char(ba(n,255),ba(rs(n,8),255),ba(rs(n,16),255),rs(n,24)) end
local function readle(s,p)
  local a,b,c,d=s:byte(p,p+3); return ((d*256+c)*256+b)*256+a
end
local function compress(h,s,p)
  local w={}
  for i=1,16 do w[i]=C.number(s,p+(i-1)*4) end
  for i=17,64 do
    local a,b=w[i-15],w[i-2]
    w[i]=(w[i-16]+bx(rr(a,7),rr(a,18),rs(a,3))+w[i-7]+bx(rr(b,17),rr(b,19),rs(b,10)))%MOD
  end
  local a,b,c,d,e,f,g,j=unpack(h)
  for i=1,64 do
    local t1=(j+bx(rr(e,6),rr(e,11),rr(e,25))+bx(ba(e,f),ba(bn(e),g))+constants[i]+w[i])%MOD
    local t2=(bx(rr(a,2),rr(a,13),rr(a,22))+bx(ba(a,b),ba(a,c),ba(b,c)))%MOD
    j,g,f,e,d,c,b,a=g,f,e,(d+t1)%MOD,c,b,a,(t1+t2)%MOD
  end
  local v={a,b,c,d,e,f,g,j}
  for i=1,8 do h[i]=(h[i]+v[i])%MOD end
end
local function finish(s,initial,prior)
  local h={}; for i=1,8 do h[i]=initial[i] end
  local n=#s+(prior or 0)
  s=s.."\128"..string.rep("\0",(55-#s)%64)..C.be(math.floor(n/536870912))..C.be((n*8)%MOD)
  for i=1,#s,64 do compress(h,s,i) end
  local out={}; for i=1,8 do out[i]=C.be(h[i]) end
  return table.concat(out)
end
function C.sha256(s) return finish(s,H0,0) end
function C.hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
function C.unhex(s)
  assert(#s%2==0 and not s:find("[^%da-fA-F]"),"Invalid hex")
  return (s:gsub("..",function(v) return string.char(tonumber(v,16)) end))
end
function C.hmacFunction(key)
  if #key>64 then key=C.sha256(key) end
  key=key..string.rep("\0",64-#key)
  local ip,op={},{}
  for i=1,64 do ip[i]=string.char(bx(key:byte(i),0x36)); op[i]=string.char(bx(key:byte(i),0x5c)) end
  local ih,oh={},{}; for i=1,8 do ih[i]=H0[i]; oh[i]=H0[i] end
  compress(ih,table.concat(ip),1); compress(oh,table.concat(op),1)
  return function(s) return finish(finish(s,ih,64),oh,64) end
end
function C.hmac(key,s) return C.hmacFunction(key)(s) end
function C.pbkdf2(password,salt,iterations,progress)
  assert(iterations>=1 and iterations%1==0,"Invalid PBKDF2 iteration count")
  local prf=C.hmacFunction(password)
  local u=prf(salt..C.be(1)); local result={u:byte(1,32)}
  for n=2,iterations do
    u=prf(u)
    for j=1,32 do result[j]=bx(result[j],u:byte(j)) end
    if progress and n%128==0 then progress(n,iterations) end
  end
  return string.char(unpack(result))
end
local function quarter(s,a,b,c,d)
  s[a]=(s[a]+s[b])%MOD; s[d]=lr(bx(s[d],s[a]),16)
  s[c]=(s[c]+s[d])%MOD; s[b]=lr(bx(s[b],s[c]),12)
  s[a]=(s[a]+s[b])%MOD; s[d]=lr(bx(s[d],s[a]),8)
  s[c]=(s[c]+s[d])%MOD; s[b]=lr(bx(s[b],s[c]),7)
end
function C.chachaBlock(key,nonce,counter)
  assert(#key==32 and #nonce==12,"Invalid ChaCha20 key/nonce")
  local state={0x61707865,0x3320646e,0x79622d32,0x6b206574}
  for i=1,8 do state[4+i]=readle(key,(i-1)*4+1) end
  state[13]=counter
  for i=1,3 do state[13+i]=readle(nonce,(i-1)*4+1) end
  local x={}; for i=1,16 do x[i]=state[i] end
  for _=1,10 do
    quarter(x,1,5,9,13); quarter(x,2,6,10,14); quarter(x,3,7,11,15); quarter(x,4,8,12,16)
    quarter(x,1,6,11,16); quarter(x,2,7,12,13); quarter(x,3,8,9,14); quarter(x,4,5,10,15)
  end
  local out={}; for i=1,16 do out[i]=le((x[i]+state[i])%MOD) end
  return table.concat(out)
end
function C.chacha20(key,nonce,text,counter)
  local out={}; counter=counter or 1
  for pos=1,#text,64 do
    local block=C.chachaBlock(key,nonce,counter); counter=counter+1
    local part={}
    for i=1,math.min(64,#text-pos+1) do part[i]=string.char(bx(text:byte(pos+i-1),block:byte(i))) end
    out[#out+1]=table.concat(part)
  end
  return table.concat(out)
end
function C.equal(a,b)
  if #a~=#b then return false end
  local v=0; for i=1,#a do v=bit32.bor(v,bx(a:byte(i),b:byte(i))) end
  return v==0
end
return C
]]},
  ["system/europa.lua"]={sha256="d4fc0048a19590cdb6c085e76e5ce85f5becc980c43ae93e3d9813f6ab8b3ac9",data=[[
-- Europa: small request/response networking over normal ComputerCraft Rednet.
local E={protocol='ccsacabam.europa.v1',maxBody=32768}
local hosts={}; local serial=0
function E.open()
  if not peripheral or not rednet then return nil,'Rednet is unavailable.' end
  local found=false
  for _,name in ipairs(peripheral.getNames()) do
    if (peripheral.hasType and peripheral.hasType(name,'modem')) or peripheral.getType(name)=='modem' then
      if not rednet.isOpen(name) then rednet.open(name) end
      found=true
    end
  end
  return found or nil,not found and 'Attach a modem to use Europa.' or nil
end
function E.path(path)
  assert(type(path)=='string' and #path<=256,'Invalid page path')
  path=path:match('^[^?#]*')
  path=path:gsub('%%(%x%x)',function(n) return string.char(tonumber(n,16)) end)
  assert(not path:find('[%%%c\\]'),'Invalid path encoding')
  for part in path:gmatch('[^/]+') do assert(part~='..' and part~='.' and part:sub(1,1)~='.', 'Private or parent paths cannot be served') end
  if path=='' or path:sub(-1)=='/' then path=path..'index.cashew' end
  return '/'..fs.combine('',path)
end
function E.address(address,base)
  assert(type(address)=='string' and #address<=512,'Invalid address')
  address=address:match('^%s*(.-)%s*$')
  if address:sub(1,7)=='file://' then return {localFile=address:sub(8),url=address} end
  if address:sub(1,9)=='europa://' then address=address:sub(10)
  elseif address:find('://',1,true) then error('Use europa://domain/path or europa://123/path',0)
  elseif base and not address:match('^[%w.-]+/') and not address:match('^[%w.-]+$') then
    local original=E.address(base)
    if address:sub(1,1)=='/' then return E.address('europa://'..original.host..address) end
    return E.address('europa://'..original.host..'/'..fs.combine(fs.getDir(original.path),address))
  end
  local host,path=address:match('^([^/]+)(/.*)$')
  if not host then host,path=address,'/' end
  assert(host:match('^[%w.-]+$') and #host<=63,'Invalid domain or computer ID')
  host=host:lower(); path=E.path(path)
  local id=tonumber(host)
  if id then assert(id>=0 and id%1==0 and id<2147483648,'Invalid computer ID') end
  return {host=host,id=id,path=path,url='europa://'..host..path}
end
function E.relative(link,current)
  if link:find('://',1,true) then return link end
  if not current or current=='about:home' then return 'europa://'..link end
  local parsed=E.address(current)
  if parsed.localFile then return 'file://'..fs.combine(fs.getDir(parsed.localFile),link) end
  return 'europa://'..parsed.host..(link:sub(1,1)=='/' and link or '/'..fs.combine(fs.getDir(parsed.path),link))
end
function E.serve(root,path)
  local ok,normalized=pcall(E.path,path)
  if not ok then return {status=400,body='Invalid page path.',mime='text/plain'} end
  local file=fs.combine(root,normalized:sub(2))
  if not fs.exists(file) or fs.isDir(file) then return {status=404,body='Page not found.',mime='text/plain'} end
  local mime=file:match('%.cashew$') and 'text/cashew' or file:match('%.pist$') and 'text/pistachio'
    or file:match('%.peanut$') and 'application/peanut' or file:match('%.txt$') and 'text/plain'
  if not mime then return {status=403,body='This file type is not published.',mime='text/plain'} end
  if fs.getSize(file)>E.maxBody then return {status=413,body='Page exceeds 32 KiB.',mime='text/plain'} end
  local h,err=fs.open(file,'r'); if not h then return {status=500,body='Cannot read page.',mime='text/plain'} end
  local body=h.readAll(); h.close()
  return {status=200,body=body,mime=mime}
end
function E.start(domain,root)
  domain=domain:lower()
  assert(domain:match('^[a-z0-9][a-z0-9.-]*$') and #domain<=63 and not tonumber(domain),'Choose a domain like workshop.cc')
  assert(fs.isDir(root),'Site folder does not exist')
  assert(not next(hosts),'A Jupiter server is already running on this computer')
  assert(E.open())
  rednet.host(E.protocol,domain)
  local host={domain=domain,root=root,requests=0,clients={},active=true}
  hosts[domain]=host
  function host.stop()
    if not host.active then return end
    host.active=false; hosts[domain]=nil; rednet.unhost(E.protocol)
  end
  function host.receive(sender,packet,protocol)
    if protocol~=E.protocol or type(packet)~='table' or packet.kind~='request' then return end
    if type(packet.id)~='string' or #packet.id>80 or type(packet.path)~='string' or #packet.path>256 then return end
    local now=math.floor(os.clock()); local client=host.clients[sender]
    if not client or client.time~=now then client={time=now,count=0}; host.clients[sender]=client end
    client.count=client.count+1; if client.count>10 then return end
    local reply=E.serve(root,packet.path); reply.kind='response'; reply.id=packet.id
    rednet.send(sender,reply,E.protocol); host.requests=host.requests+1
    -- Bound the rate-limit cache even on a busy public network.
    for id,entry in pairs(host.clients) do if entry.time<now-5 then host.clients[id]=nil end end
  end
  return host
end
function E.fetch(address)
  local parsed=E.address(address)
  if parsed.localFile then
    local file=parsed.localFile
    if not fs.exists(file) or fs.isDir(file) then return nil,'Local page not found.' end
    if fs.getSize(file)>E.maxBody then return nil,'Page exceeds 32 KiB.' end
    local h,err=fs.open(file,'r'); if not h then return nil,err end
    local body=h.readAll(); h.close()
    return {status=200,body=body,mime=file:match('%.pist$') and 'text/pistachio' or file:match('%.cashew$') and 'text/cashew' or 'text/plain',url=parsed.url}
  end
  local localHost=hosts[parsed.host]
  if parsed.id==os.getComputerID() then for _,h in pairs(hosts) do localHost=h end end
  if localHost then local reply=E.serve(localHost.root,parsed.path); reply.url=parsed.url; return reply end
  local opened,why=E.open(); if not opened then return nil,why end
  local id=parsed.id or rednet.lookup(E.protocol,parsed.host)
  if not id then return nil,'Domain not found. The host must be online and in modem range.' end
  serial=serial+1
  local request=tostring(os.getComputerID())..':'..tostring(os.clock())..':'..serial
  if not rednet.send(id,{kind='request',id=request,path=parsed.path},E.protocol) then return nil,'Modem is not open.' end
  local timer=os.startTimer(5)
  while true do
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then os.cancelTimer(timer); return nil,'Cancelled.',true
    elseif e=='timer' and a==timer then return nil,'Server did not respond within five seconds.'
    elseif e=='rednet_message' and a==id and c==E.protocol and type(b)=='table' and b.kind=='response' and b.id==request then
      if type(b.body)=='string' and #b.body<=E.maxBody and type(b.status)=='number'
        and (b.mime=='text/cashew' or b.mime=='text/pistachio' or b.mime=='text/plain' or b.mime=='application/peanut') then
        os.cancelTimer(timer); return {status=b.status,body=b.body,mime=b.mime,url=parsed.url,server=id}
      end
    end
  end
end
return E
]]},
  ["system/font.lua"]={sha256="9ef0391be9dde1d63814be2a36a9f8849665464dd1ed805e2bf3294c65ba4a40",data=[[
-- Small original 3x5 display font for graphical banners.
local F={}
local glyphs={
 A='010101111101101',B='110101110101110',C='011100100100011',D='110101101101110',E='111100110100111',
 F='111100110100100',G='011100101101011',H='101101111101101',I='111010010010111',J='001001001101010',
 K='101101110101101',L='100100100100111',M='101111111101101',N='101111111111101',O='010101101101010',
 P='110101110100100',Q='010101101111011',R='110101110101101',S='011100010001110',T='111010010010010',
 U='101101101101111',V='101101101101010',W='101101111111101',X='101101010101101',Y='101101010010010',Z='111001010100111',
 ['0']='111101101101111',['1']='010110010010111',['2']='110001010100111',['3']='110001010001110',
 ['4']='101101111001001',['5']='111100110001110',['6']='011100111101111',['7']='111001010010010',
 ['8']='111101111101111',['9']='111101111001110',['!']='010010010000010',['?']='110001010000010',
 ['.']='000000000000010',['-']='000000111000000',[':']='000010000010000',[' ']='000000000000000'}
function F.draw(buffer,x,y,text,color)
  for i=1,#text do
    local glyph=glyphs[text:sub(i,i):upper()] or glyphs['?']
    for row=0,4 do for col=0,2 do if glyph:sub(row*3+col+1,row*3+col+1)=='1' then buffer.set(x+(i-1)*4+col,y+row,color) end end end
  end
end
return F
]]},
  ["system/ganymede.lua"]={sha256="8987ac6bd0813015c2a502b8bd20593401d78151dfd85f5a77b3aa6a8a291719",data=[[
-- Ganymede: the portable UI toolkit. Draws into the current program's window.
local G={version='1.0'}
function G.theme()
  if term.isColor() then return {bg=colors.black,panel=colors.gray,text=colors.white,muted=colors.lightGray,accent=colors.cyan,onAccent=colors.black} end
  return {bg=colors.black,panel=colors.black,text=colors.white,muted=colors.white,accent=colors.white,onAccent=colors.black}
end
function G.text(x,y,value,fg,bg,width)
  local w,h=term.getSize(); if y<1 or y>h or x>w then return end
  value=tostring(value or ''); if x<1 then value=value:sub(2-x); x=1 end
  local n=math.max(0,math.min(width or #value,w-x+1)); value=value:sub(1,n)
  if width then value=value..string.rep(' ',n-#value) end
  term.setTextColor(fg or colors.white); term.setBackgroundColor(bg or colors.black)
  term.setCursorPos(x,y); term.write(value)
end
function G.control(v,t,active)
  local text=tostring(v.value==nil and '' or v.value)
  if v.kind=='button' then
    local inner=math.max(0,v.w-2); text=text:sub(1,inner)
    local pad=math.floor((inner-#text)/2)
    text=(active and '>' or '[')..string.rep(' ',pad)..text..string.rep(' ',inner-#text-pad)..(active and '<' or ']')
  elseif v.kind=='checkbox' then text=(v.value and '[x] ' or '[ ] ')..v.id
  elseif v.kind=='input' then text=text:sub(-math.max(1,v.w)) end
  G.text(v.x,v.y,text,active and t.onAccent or t.text,active and t.accent or t.panel,v.w)
end
function G.form(title)
  local form={title=title or 'Ganymede',widgets={},focus=1,closed=false,theme=G.theme}
  local function add(kind,id,x,y,width,value,callback)
    local v={kind=kind,id=id,x=x,y=y,w=width,value=value,callback=callback}
    form.widgets[#form.widgets+1]=v; return v
  end
  function form.label(id,x,y,width,text) return add('label',id,x,y,width,text) end
  function form.button(id,x,y,width,text,fn) return add('button',id,x,y,width,text,fn) end
  function form.input(id,x,y,width,text,fn) return add('input',id,x,y,width,text or '',fn) end
  function form.checkbox(id,x,y,width,value,fn) return add('checkbox',id,x,y,width,value or false,fn) end
  function form.get(id) for _,v in ipairs(form.widgets) do if v.id==id then return v.value end end end
  function form.set(id,value) for _,v in ipairs(form.widgets) do if v.id==id then v.value=value; return end end end
  function form.close() form.closed=true end
  function form.run()
    local shift=false
    while not form.closed do
      local t=form.theme(); local w,h=term.getSize(); local controls={}
      term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorBlink(false)
      G.text(1,1,form.title,t.onAccent,t.accent,w)
      for _,v in ipairs(form.widgets) do
        if v.kind=='label' then G.text(v.x,v.y,v.value,t.text,t.bg,v.w)
        else controls[#controls+1]=v; G.control(v,t,#controls==form.focus) end
      end
      G.text(1,h,'Tab select | Enter activate',t.muted,t.panel,w)
      local e,a,b,c=os.pullEventRaw(); local v=controls[form.focus]
      local function click(item)
        if not item then return end
        if item.kind=='checkbox' then item.value=not item.value end
        if item.kind~='input' and item.callback then item.callback(form,item) end
      end
      if e=='terminate' or e=='sacabam_close' then return
      elseif e=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shift=false
      elseif e=='key' then
        if a==keys.leftShift or a==keys.rightShift then shift=true
        elseif a==keys.tab then form.focus=((form.focus-1+(shift and -1 or 1))%math.max(1,#controls))+1
        elseif a==keys.enter or (a==keys.space and v and v.kind~='input') then click(v)
        elseif a==keys.backspace and v and v.kind=='input' then v.value=tostring(v.value):sub(1,-2); if v.callback then v.callback(form,v) end end
      elseif (e=='char' or e=='paste') and v and v.kind=='input' then
        v.value=(tostring(v.value)..a:gsub('[%c]','')):sub(1,4096); if v.callback then v.callback(form,v) end
      elseif e=='mouse_click' then
        for i,item in ipairs(controls) do if b>=item.x and b<item.x+item.w and c==item.y then form.focus=i; click(item); break end end
      end
    end
  end
  return form
end
return G
]]},
  ["system/kernel.lua"]={sha256="e74d974985420b68896fe6a012988ee9424793aa0a200432a90fbe19d1768a03",data=[=[
local K = {}
local unpack = table.unpack or unpack
local input = { char=true, key=true, key_up=true, paste=true, mouse_click=true,
  mouse_up=true, mouse_drag=true, mouse_scroll=true, file_transfer=true }
K.catalog = {
  {id="files", name="Files", detail="Browse, copy, move and recover files", icon="folder"},
  {id="terminal", name="Terminal", detail="Run ComputerCraft commands and Lua", icon="terminal"},
  {id="editor", name="Editor", detail="Write notes and Lua programs", icon="editor"},
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
function K.new(ctx)
  local self = { tasks={}, nextID=0, focus=nil, keys={}, launcher=nil, notice=nil,
    running=true, ctx=ctx, clockTimer=nil, drag=nil }
  local UI, Pixels, Storage = ctx.load("system/ui"), ctx.load("system/pixels"), ctx.load("system/storage")
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
  end
  function self.deliver(p,event,force)
    if p and (force or p.filter == nil or p.filter == event[1] or event[1] == "terminate") then self.resume(p,event) end
  end
  function self.geometry(p)
    if p.maximized then p.x,p.y,p.w,p.h = 1,2,self.width,self.height-2
    else
      p.w = math.max(8,math.min(p.w,self.width))
      p.h = math.max(4,math.min(p.h,self.height-2))
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
  function self.launch(id,...)
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
    local api={root=ctx.root,home=fs.combine(ctx.root,"home"),id=p.id,ui=UI,pixels=Pixels,storage=Storage,
      theme=self.theme,config=function() return ctx.config end,caps=ctx.caps,
      notify=self.notify,launch=self.launch,saveConfig=self.saveConfig,
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
      onExit=function(fn) p.cleanup=p.cleanup or {}; p.cleanup[#p.cleanup+1]=fn end}
    local args={...}
    p.co=coroutine.create(function() app(api,unpack(args)) end)
    self.tasks[#self.tasks+1]=p; self.focusTask(p.id)
    self.resume(p,{})
    return p.id
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
      UI.text(x+1,y,"+---+",t.text,t.desktop)
      UI.text(x+1,y+1,"| "..item.name:sub(1,1).." |",t.text,t.desktop)
      UI.text(x+1,y+2,"+---+",t.text,t.desktop)
    end
    UI.text(x,y+3,item.name,selected and t.onAccent or t.text,selected and t.accent or t.desktop,9)
  end
  function self.render()
    local previous=term.current(); term.redirect(self.frame)
    local t=self.theme(); UI.clear(t)
    UI.fill(1,2,self.width,self.height-2,t.desktop)
    if ctx.config.mode=="render" and ctx.config.wallpaper then
      if not self.wallpaper then
        local b=Pixels.new(self.width*2,(self.height-2)*3,t.desktop)
        for x=1,b.w do
          local ridge=math.floor(b.h*.56+math.sin(x/15)*7+math.sin(x/7)*3)
          for y=math.max(1,ridge),b.h do b.set(x,y,colors.cyan) end
          local front=math.floor(b.h*.78+math.sin(x/21+2)*6)
          for y=math.max(1,front),b.h do b.set(x,y,colors.black) end
        end
        self.wallpaper=b
      end
      Pixels.draw(self.wallpaper,term,1,2)
    end
    UI.text(1,1," CCSacabam | F1 Apps",t.onAccent,t.accent,self.width)
    local clock=textutils.formatTime(os.time(),ctx.config.clock24)
    UI.text(self.width-#clock,1,clock,t.onAccent,t.accent)
    self.desktopHits={}
    local cols=math.max(1,math.floor((self.width-2)/11))
    for i,item in ipairs(K.catalog) do
      local x,y=2+((i-1)%cols)*11,3+math.floor((i-1)/cols)*5
      if y+3 < self.height-1 then
        self.icon(item,x,y,false)
        self.desktopHits[#self.desktopHits+1]={x=x,y=y,id=item.id}
      end
    end
    if #self.tasks==0 and self.height>=17 then
      UI.text(3,self.height-3,"Your computer. Your workspace.",t.text,t.desktop,self.width-4)
      UI.text(3,self.height-2,"F1 apps  |  F2 switch  |  F10 exit",t.text,t.desktop,self.width-4)
    end
    for _,p in ipairs(self.tasks) do if not p.minimized then
      local border=p.id==self.focus and t.accent or t.border
      UI.fill(p.x,p.y,p.w,p.h,border)
      UI.text(p.x+1,p.y,p.title,t.onAccent,border,p.w-9)
      UI.text(p.x+p.w-8,p.y," _ + X ",t.onAccent,border,7)
      p.win.setVisible(true); p.win.setVisible(false)
      UI.text(p.x+1,p.y+p.h-1,"F3 hide  F4 close  F6 size",t.onAccent,border,p.w-2)
    end end
    UI.text(1,self.height," F1 Apps ",t.onAccent,t.accent,self.width)
    self.taskHits={}
    local tx=10
    local tabWidth=math.max(4,math.min(13,math.floor((self.width-10)/math.max(1,#self.tasks))))
    for _,p in ipairs(self.tasks) do
      if tx+tabWidth-1<=self.width then
        UI.text(tx,self.height,(p.minimized and "_" or " ")..p.title,p.id==self.focus and t.text or t.onAccent,
          p.id==self.focus and t.bg or t.accent,tabWidth)
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
      UI.text(mx+1,my+mh-1,"Arrows / Enter / Esc",t.muted,t.panel,mw-2)
    end
    if self.transform then
      UI.text(1,self.height-1," "..self.transform.mode..": arrows | Enter done | Esc cancel",t.text,t.panel,self.width)
    end
    if self.power then
      UI.fill(2,math.max(2,math.floor(self.height/2)-1),self.width-2,4,t.panel)
      UI.text(3,math.max(2,math.floor(self.height/2)-1),"Close apps? Unsaved work may be lost.",t.text,t.panel,self.width-4)
      UI.text(3,math.max(2,math.floor(self.height/2)-1)+2,"Enter: "..self.power.."  Esc: cancel",t.text,t.panel,self.width-4)
    end
    self.frame.setVisible(true); self.frame.setVisible(false)
    local p=self.get(self.focus)
    base.setCursorBlink(false)
    if p and not self.launcher and not self.power and not p.minimized and p.win.getCursorBlink() then
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
    if self.transform and input[name] then
      local move=self.transform; local p=self.get(move.id)
      if not p then self.transform=nil
      elseif name=="key" then
        if e[2]==keys.enter then self.transform=nil
        elseif e[2]==keys.escape then p.x,p.y,p.w,p.h=unpack(move.before); self.transform=nil
        else
          local dx=e[2]==keys.left and -1 or e[2]==keys.right and 1 or 0
          local dy=e[2]==keys.up and -1 or e[2]==keys.down and 1 or 0
          if move.mode=="Move" then p.x,p.y=p.x+dx,p.y+dy else p.w,p.h=p.w+dx,p.h+dy end
        end
        self.geometry(p); self.deliver(p,{"term_resize"},true)
      end
    elseif self.power and input[name] then
      if name=="key" and e[2]==keys.enter then self.running=false; self.action=self.power
      elseif name=="key" and e[2]==keys.escape then self.power=nil end
    elseif name=="key" and e[2]==keys.f1 then
      self.launcher=self.launcher and nil or {query="",index=1}
    elseif self.launcher and input[name] then
      local m=self.launcher
      if name=="char" then m.query=m.query..e[2]; m.index=1
      elseif name=="key" then
        if e[2]==keys.escape then self.launcher=nil
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
    elseif name=="key" and e[2]==keys.f9 then self.power="lock"
    elseif name=="key" and e[2]==keys.f10 then self.power="exit"
    elseif name=="mouse_up" and self.drag then self.drag=nil
    elseif name=="mouse_drag" and self.drag then
      local p=self.get(self.drag.id)
      if p then
        if self.drag.resize then
          p.w,p.h=e[3]-p.x+1,e[4]-p.y+1; self.geometry(p); self.deliver(p,{"term_resize"},true)
        else p.x,p.y=e[3]-self.drag.dx,e[4]-self.drag.dy; self.geometry(p) end
      end
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
            if x>=hit.x+hit.w-3 then self.requestClose(hit)
            elseif x>=hit.x+hit.w-5 then self.maximize(hit)
            elseif x>=hit.x+hit.w-8 then self.minimize(hit)
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
]=]},
  ["system/login.lua"]={sha256="58d5f09be51ed929b74e19561a66f9920fa9ecda779bae66c807525b2bb9820b",data=[[
local L={}
function L.password(label,subtitle)
  local value,entropy="",{}
  local function draw()
    local w,h=term.getSize()
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
    term.setCursorPos(2,2); term.write("CCSacabam")
    term.setCursorPos(2,4); term.write(label:sub(1,w-2))
    local y=6
    for _,line in ipairs(subtitle or {}) do term.setCursorPos(2,y); term.write(line:sub(1,w-2)); y=y+1 end
    local py=math.min(h-3,y+1)
    term.setCursorPos(2,py); term.write("> "..string.rep("*",math.min(#value,w-5)))
    term.setCursorBlink(true)
    term.setCursorPos(2,h-1); term.write(("Enter: unlock / Esc: leave"):sub(1,w-2))
    term.setCursorPos(math.min(w,4+#value),py)
  end
  draw()
  while true do
    local e,a=os.pullEventRaw()
    entropy[#entropy+1]=tostring(os.epoch and os.epoch("utc") or os.clock())..":"..os.clock()
    if e=="char" or e=="paste" then value=value..a:gsub("[%c]",""):sub(1,256-#value)
    elseif e=="key" and a==keys.backspace then value=value:sub(1,-2)
    elseif e=="key" and a==keys.enter then term.setCursorBlink(false); return value,table.concat(entropy,";")
    elseif e=="terminate" or (e=="key" and a==keys.escape) then term.setCursorBlink(false); return nil end
    draw()
  end
end
function L.progress(n,total)
  if n%1024==0 then
    local _,h=term.getSize(); term.setCursorPos(2,h-2); term.clearLine()
    term.write("Deriving key... "..math.floor(n/total*100).."%")
  end
  os.queueEvent("ccsacabam_crypto_yield")
  os.pullEvent("ccsacabam_crypto_yield")
end
function L.unlock(vault)
  local message
  while true do
    if not vault.exists() then
      local password,entropy=L.password("Create your encrypted personal drive",{
        "Use a passphrase of 12+ characters.","There is no password reset or back door.",message or "Keep a copy of your password somewhere safe."})
      if not password then return false end
      if #password<12 then message="Passphrase must have at least 12 characters."
      else
        local again=L.password("Confirm your passphrase",{"Enter the same passphrase again."})
        if not again then return false end
        if password~=again then message="Passphrases did not match."
        else
          local ok,err=vault.create(password,entropy,L.progress)
          password,again=nil,nil
          if ok then return true end
          message=err
        end
      end
    else
      local password=L.password("Unlock your personal drive",{message or "Your files are encrypted while locked."})
      if not password then return false end
      local ok,err=vault.unlock(password,L.progress)
      password=nil
      if ok then return true end
      message=err
      sleep(1)
    end
  end
end
return L
]]},
  ["system/peanut.lua"]={sha256="0e78b4c13bc932752e004b9b08e2964b5a40604e4fe1c66c44f70636e97c05bf",data=[[
-- Peanut 1: JSON data plus comments, identifier keys, '=' and trailing commas.
-- No code evaluation. Lua: local peanut = require('peanut')
local P={version=1}
local arrayMT={__peanut='array'}
P.null=setmetatable({},{__tostring=function() return 'null' end})
function P.array(value) return setmetatable(value or {},arrayMT) end
local function utf8(n)
  if n<128 then return string.char(n)
  elseif n<2048 then return string.char(192+math.floor(n/64),128+n%64)
  elseif n<65536 then return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)
  else return string.char(240+math.floor(n/262144),128+math.floor(n/4096)%64,128+math.floor(n/64)%64,128+n%64) end
end
function P.decode(text)
  assert(type(text)=='string','Peanut expects a string')
  assert(#text<=1048576,'Peanut input exceeds 1 MiB')
  local pos=1
  local function fail(message)
    local _,line=text:sub(1,pos-1):gsub('\n','')
    error('Peanut line '..(line+1)..': '..message,0)
  end
  local function skip()
    while true do
      local _,last=text:find('^%s*',pos); pos=(last or pos-1)+1
      if text:sub(pos,pos)=='#' or text:sub(pos,pos+1)=='//' then
        pos=(text:find('\n',pos,true) or #text)+1
      else return end
    end
  end
  local function quoted()
    pos=pos+1; local out={}
    while pos<=#text do
      local c=text:sub(pos,pos); pos=pos+1
      if c=='"' then return table.concat(out)
      elseif c=='\\' then
        local e=text:sub(pos,pos); pos=pos+1
        local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if escapes[e] then out[#out+1]=escapes[e]
        elseif e=='u' then
          local digits=text:sub(pos,pos+3)
          if #digits~=4 or digits:find('[^%da-fA-F]') then fail('Invalid Unicode escape') end
          local code=tonumber(digits,16); pos=pos+4
          if code>=0xd800 and code<=0xdbff then
            if text:sub(pos,pos+1)~='\\u' then fail('Missing low surrogate') end
            local low=tonumber(text:sub(pos+2,pos+5),16)
            if not low or low<0xdc00 or low>0xdfff then fail('Invalid low surrogate') end
            code=0x10000+(code-0xd800)*1024+low-0xdc00; pos=pos+6
          elseif code>=0xdc00 and code<=0xdfff then fail('Unexpected low surrogate') end
          out[#out+1]=utf8(code)
        else fail('Unknown escape') end
      elseif c:byte()<32 then fail('Control character in string')
      else out[#out+1]=c end
    end
    fail('Unclosed string')
  end
  local value
  value=function(depth)
    if depth>64 then fail('Maximum nesting exceeded') end
    skip(); local c=text:sub(pos,pos)
    if c=='"' then return quoted()
    elseif c=='{' or c=='[' then
      local array=c=='['; local close=array and ']' or '}'; pos=pos+1
      local result=array and P.array() or {}; local seen={}; skip()
      if text:sub(pos,pos)==close then pos=pos+1; return result end
      while true do
        skip(); local key
        if array then key=#result+1
        else
          if text:sub(pos,pos)=='"' then key=quoted()
          else key=text:match('^([%a_][%w_]*)',pos); if not key then fail('Expected object key') end; pos=pos+#key end
          if seen[key] then fail('Duplicate key: '..key) end; seen[key]=true
          skip(); local sep=text:sub(pos,pos)
          if sep~=':' and sep~='=' then fail("Expected ':' or '='") end
          pos=pos+1
        end
        result[key]=value(depth+1); skip(); local sep=text:sub(pos,pos); pos=pos+1
        if sep==close then return result end
        if sep~=',' then fail("Expected ',' or '"..close.."'") end
        skip(); if text:sub(pos,pos)==close then pos=pos+1; return result end
      end
    elseif text:sub(pos,pos+3)=='true' then pos=pos+4; return true
    elseif text:sub(pos,pos+4)=='false' then pos=pos+5; return false
    elseif text:sub(pos,pos+3)=='null' then pos=pos+4; return P.null
    else
      local number=text:match('^(-?%d+%.?%d*[eE][+-]?%d+)',pos) or text:match('^(-?%d+%.?%d*)',pos)
      if not number then fail('Expected a value') end
      if number:match('^-?0%d') or number:sub(-1)=='.' then fail('Invalid number') end
      pos=pos+#number; local n=tonumber(number)
      if not n or n==math.huge or n==-math.huge then fail('Number is not finite') end
      return n
    end
  end
  local result=value(0); skip(); if pos<=#text then fail('Unexpected trailing data') end
  return result
end
local function quote(s)
  local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  return '"'..s:gsub('[%z\1-\31\\"]',function(c) return escapes[c] or string.format('\\u%04x',c:byte()) end)..'"'
end
function P.encode(value,pretty)
  local seen={}
  local function encode(v,depth)
    if depth>64 then error('Peanut maximum nesting exceeded',0) end
    if v==P.null or v==nil then return 'null' end
    local kind=type(v)
    if kind=='string' then return quote(v)
    elseif kind=='boolean' then return tostring(v)
    elseif kind=='number' then
      assert(v==v and v~=math.huge and v~=-math.huge,'Peanut numbers must be finite'); return string.format('%.17g',v)
    elseif kind~='table' then error('Peanut cannot encode '..kind,0) end
    assert(not seen[v],'Peanut cannot encode cycles'); seen[v]=true
    local numeric,count,max=false,0,0
    for k in pairs(v) do
      count=count+1
      if type(k)=='number' and k>=1 and k%1==0 then numeric=true; max=math.max(max,k)
      elseif type(k)~='string' then error('Invalid Peanut object key',0) end
    end
    local array=getmetatable(v)==arrayMT or numeric
    local entries={}
    if array then
      assert(max==count,'Peanut arrays must be dense and cannot have object keys')
      for i=1,max do entries[#entries+1]=encode(v[i],depth+1) end
    else
      local names={}; for k in pairs(v) do names[#names+1]=k end; table.sort(names)
      for _,k in ipairs(names) do entries[#entries+1]=quote(k)..(pretty and ': ' or ':')..encode(v[k],depth+1) end
    end
    seen[v]=nil
    local first,last=array and '[' or '{',array and ']' or '}'
    if #entries==0 then return first..last end
    if pretty then
      local indent=string.rep('  ',depth+1)
      return first..'\n'..indent..table.concat(entries,',\n'..indent)..'\n'..string.rep('  ',depth)..last
    end
    return first..table.concat(entries,',')..last
  end
  return encode(value,0)
end
function P.read(path)
  local h,err=fs.open(path,'r'); if not h then return nil,err end
  local raw=h.readAll(); h.close()
  local ok,data=pcall(P.decode,raw); if not ok then return nil,data end; return data
end
function P.write(path,value)
  local ok,data=pcall(P.encode,value,true); if not ok then return nil,data end
  local h,err=fs.open(path,'w'); if not h then return nil,err end
  local worked,why=pcall(function() h.write(data); h.close() end)
  return worked or nil,why
end
P.parse=P.decode; P.stringify=P.encode
return P
]]},
  ["system/pistachio.lua"]={sha256="2edbebcd341e1d21eb72e43f97354241b1434e2da3116b7b218c3b1a052fb69b",data=[[
-- Pistachio Script: parsed application language, never evaluated as Lua.
local P={version='1.0'}
local function fail(line,message) error('Pistachio line '..tostring(line)..': '..message,0) end
local function tokens(source,line)
  local out={}; local i=1
  while i<=#source do
    local c=source:sub(i,i)
    if c:match('%s') then i=i+1
    elseif c=='"' then
      local value={}; i=i+1; local closed=false
      while i<=#source do
        c=source:sub(i,i); i=i+1
        if c=='"' then closed=true; break
        elseif c=='\\' then
          c=source:sub(i,i); i=i+1
          local map={n='\n',t='\t',r='\r',['"']='"',['\\']='\\'}
          if not map[c] then fail(line,'Unknown string escape') end
          value[#value+1]=map[c]
        else value[#value+1]=c end
      end
      if not closed then fail(line,'Unclosed string') end
      out[#out+1]={kind='string',value=table.concat(value)}
    elseif c:match('%d') or (c=='.' and source:sub(i+1,i+1):match('%d')) then
      local number=source:match('^(%d*%.?%d+[eE][+-]?%d+)',i) or source:match('^(%d*%.?%d+)',i)
      out[#out+1]={kind='number',value=tonumber(number)}; i=i+#number
    elseif c:match('[%a_]') then
      local name=source:match('^([%a_][%w_]*)',i)
      out[#out+1]={kind='name',value=name}; i=i+#name
    else
      local pair=source:sub(i,i+1)
      if pair=='==' or pair=='!=' or pair=='<=' or pair=='>=' or pair=='..' then c=pair; i=i+1 end
      if not ({['+']=true,['-']=true,['*']=true,['/']=true,['%']=true,['(']=true,[')']=true,
        ['<']=true,['>']=true,['==']=true,['!=']=true,['<=']=true,['>=']=true,['..']=true,
        [',']=true,['.']=true,['[']=true,[']']=true})[c] then fail(line,'Unexpected character '..c) end
      out[#out+1]={kind='symbol',value=c}; i=i+1
    end
  end
  out[#out+1]={kind='end',value=''}; return out
end
local precedence={['or']=1,['and']=2,['==']=3,['!=']=3,['<']=3,['>']=3,['<=']=3,['>=']=3,['..']=4,['+']=5,['-']=5,['*']=6,['/']=6,['%']=6}
function P.expression(source,line)
  line=line or 0; local list=tokens(source,line); local pos=1; local expression
  local function take(value)
    if list[pos].value~=value then fail(line,"Expected '"..value.."'") end
    pos=pos+1
  end
  local function atom()
    local t=list[pos]; pos=pos+1; local node
    if t.kind=='number' or t.kind=='string' then node={tag='literal',value=t.value}
    elseif t.value=='true' or t.value=='false' then node={tag='literal',value=t.value=='true'}
    elseif t.value=='not' or t.value=='-' then node={tag='unary',op=t.value,child=expression(7)}
    elseif t.value=='(' then node=expression(1); take(')')
    elseif t.kind=='name' then
      if list[pos].value=='(' then
        pos=pos+1; local args={}
        if list[pos].value~=')' then
          repeat
            args[#args+1]=expression(1)
            if list[pos].value~=',' then break end
            pos=pos+1
          until false
        end
        take(')'); node={tag='call',name=t.value,args=args}
      else node={tag='variable',name=t.value} end
    else fail(line,'Expected an expression') end
    while list[pos].value=='.' or list[pos].value=='[' do
      if list[pos].value=='.' then
        pos=pos+1; local key=list[pos]; if key.kind~='name' then fail(line,'Expected field name') end
        pos=pos+1; node={tag='index',object=node,key={tag='literal',value=key.value}}
      else pos=pos+1; local key=expression(1); take(']'); node={tag='index',object=node,key=key} end
    end
    return node
  end
  expression=function(min)
    local left=atom()
    while precedence[list[pos].value] and precedence[list[pos].value]>=min do
      local op=list[pos].value; pos=pos+1
      left={tag='binary',op=op,left=left,right=expression(precedence[op]+1)}
    end
    return left
  end
  local node=expression(1)
  if list[pos].kind~='end' then fail(line,'Unexpected expression suffix') end
  return node
end
local function strip(line)
  local quoted,escaped=false,false
  for i=1,#line do local c=line:sub(i,i)
    if quoted then
      if escaped then escaped=false elseif c=='\\' then escaped=true elseif c=='"' then quoted=false end
    elseif c=='"' then quoted=true elseif c=='#' then return line:sub(1,i-1) end
  end
  return line
end
function P.parse(source)
  assert(#source<=131072,'Pistachio source exceeds 128 KiB')
  local rows={}
  for line in (source..'\n'):gmatch('(.-)\n') do rows[#rows+1]=strip(line):match('^%s*(.-)%s*$') end
  local pos=1; local block
  block=function(depth)
    if depth>32 then fail(pos,'Block nesting exceeds 32') end
    local nodes={}
    while pos<=#rows do
      local raw=rows[pos]; local line=pos; pos=pos+1
      if raw=='end' or raw=='else' then return nodes,raw end
      if raw~='' then
        local op,rest=raw:match('^(%w+)%s*(.*)$')
        if not op then fail(line,'Expected a statement') end
        local node={op=op,line=line}
        local function expr(s) return P.expression(s,line) end
        if op=='if' or op=='repeat' or op=='on' or op=='every' or op=='function' then
          if op=='on' or op=='function' then
            if not rest:match('^[%a_][%w_]*$') then fail(line,'Expected handler name') end
            node.name=rest
          else node.value=expr(rest) end
          local stop; node.body,stop=block(depth+1)
          if stop=='else' and op=='if' then node.other,stop=block(depth+1) end
          if stop~='end' then fail(line,'Missing end for '..op) end
        elseif op=='let' or op=='set' then
          node.name,rest=rest:match('^([%a_][%w_]*)%s*=%s*(.+)$')
          if not node.name then fail(line,'Use '..op..' name = expression') end
          node.value=expr(rest)
        elseif op=='label' or op=='button' or op=='input' or op=='checkbox' or op=='progress' or op=='banner' then
          local id,x,y,w,text=rest:match('^([%a_][%w_]*)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$')
          if not id then fail(line,'Use '..op..' id x y width expression') end
          node.name,node.x,node.y,node.width,node.value=id,expr(x),expr(y),expr(w),expr(text)
          if op=='input' or op=='checkbox' then
            if not text:match('^[%a_][%w_]*$') then fail(line,op..' needs a variable name') end
            node.bind=text
          end
        elseif op=='panel' then
          local id,x,y,w,h=rest:match('^([%a_][%w_]*)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$')
          if not id then fail(line,'Use panel id x y width height') end
          node.name,node.x,node.y,node.width,node.height=id,expr(x),expr(y),expr(w),expr(h)
        elseif op=='load' then
          node.name,rest=rest:match('^([%a_][%w_]*)%s+(.+)$')
          if not node.name then fail(line,'Use load variable "path.peanut"') end
          node.value=expr(rest)
        elseif op=='save' then
          local name,path=rest:match('^([%a_][%w_]*)%s+(.+)$')
          if not name then fail(line,'Use save variable "path.peanut"') end
          node.name,node.value=name,expr(path)
        elseif op=='app' or op=='notify' then node.value=expr(rest)
        elseif op=='call' then
          if not rest:match('^[%a_][%w_]*$') then fail(line,'Expected function name') end; node.name=rest
        elseif op=='quit' then if rest~='' then fail(line,'quit takes no arguments') end
        else fail(line,'Unknown statement: '..op) end
        nodes[#nodes+1]=node
      end
    end
    return nodes,nil
  end
  local nodes,stop=block(0); if stop then fail(pos-1,'Unexpected '..stop) end
  return nodes
end
function P.runtime(ast,api,peanut)
  local state={vars={},handlers={},timers={},widgets={},quit=false,title='Pistachio',budget=10000,focus=1}
  local builtins={str=tostring,num=function(v) return tonumber(v) or 0 end,len=function(v) return #v end,
    min=math.min,max=math.max,abs=math.abs,floor=math.floor,round=function(n) return math.floor(n+0.5) end,
    peanut=peanut.decode,encode=peanut.encode,upper=string.upper,lower=string.lower}
  local eval
  eval=function(n)
    if n.tag=='literal' then
      if type(n.value)=='string' then return (n.value:gsub('{([%a_][%w_]*)}',function(k) local v=state.vars[k]; return v==nil and '{'..k..'}' or tostring(v) end)) end
      return n.value
    elseif n.tag=='variable' then
      if n.name=='advanced' then return api.caps.color elseif n.name=='color' then return api.config().mode~='basic'
      elseif n.name=='render' then return api.config().mode=='render'
      elseif n.name=='width' then return (term.getSize()) elseif n.name=='height' then local _,h=term.getSize(); return h
      elseif n.name=='null' then return peanut.null end
      if state.vars[n.name]==nil then error('Unknown variable: '..n.name,0) end
      return state.vars[n.name]
    elseif n.tag=='index' then return assert(eval(n.object),'Missing object')[eval(n.key)]
    elseif n.tag=='unary' then
      if n.op=='not' then return not eval(n.child) else return -eval(n.child) end
    elseif n.tag=='call' then
      local fn=builtins[n.name]; if not fn then error('Unknown function: '..n.name,0) end
      local args={}; for i,v in ipairs(n.args) do args[i]=eval(v) end; return fn((table.unpack or unpack)(args))
    elseif n.tag=='binary' then
      local a=eval(n.left)
      if n.op=='and' then return a and eval(n.right) elseif n.op=='or' then return a or eval(n.right) end
      local b=eval(n.right); local op=n.op
      if op=='+' then return a+b elseif op=='-' then return a-b elseif op=='*' then return a*b
      elseif op=='/' then assert(b~=0,'Division by zero'); return a/b elseif op=='%' then assert(b~=0,'Division by zero'); return a%b
      elseif op=='..' then return tostring(a)..tostring(b) elseif op=='==' then return a==b elseif op=='!=' then return a~=b
      elseif op=='<' then return a<b elseif op=='>' then return a>b elseif op=='<=' then return a<=b elseif op=='>=' then return a>=b end
    end
  end
  state.eval=eval
  local visual={label=true,button=true,input=true,checkbox=true,progress=true,banner=true,panel=true}
  local run
  run=function(nodes,phase)
    for _,n in ipairs(nodes) do
      state.budget=state.budget-1; if state.budget<0 then fail(n.line,'Instruction limit reached') end
      local ok,err=pcall(function()
        if n.op=='if' then run(eval(n.value) and n.body or n.other or {},phase)
        elseif n.op=='repeat' then
          local count=math.floor(tonumber(eval(n.value)) or -1); assert(count>=0 and count<=1000,'repeat range is 0..1000')
          for i=1,count do state.vars.index=i; run(n.body,phase) end
        elseif visual[n.op] then
          if phase=='render' then
            local widget={kind=n.op,id=n.name,x=math.floor(eval(n.x)),y=math.floor(eval(n.y)),w=math.floor(eval(n.width)),bind=n.bind}
            if n.op=='panel' then widget.h=math.floor(eval(n.height)) else widget.value=eval(n.value) end
            state.widgets[#state.widgets+1]=widget
          end
        elseif n.op=='on' or n.op=='function' then if phase=='init' then state.handlers[n.name]=n.body end
        elseif n.op=='every' then
          if phase=='init' then
            local interval=tonumber(eval(n.value)); assert(interval and interval>=0.1 and interval<=86400,'Timer interval must be 0.1..86400 seconds')
            state.timers[#state.timers+1]={interval=interval,body=n.body}
          end
        elseif phase~='render' then
          if n.op=='let' then
            if phase=='init' then state.vars[n.name]=eval(n.value) end
          elseif n.op=='set' then state.vars[n.name]=eval(n.value)
          elseif n.op=='app' then state.title=tostring(eval(n.value))
          elseif n.op=='notify' then api.notify(tostring(eval(n.value)))
          elseif n.op=='call' then assert(state.handlers[n.name],'Unknown function: '..n.name); run(state.handlers[n.name],phase)
          elseif n.op=='load' then local value,why=peanut.read(tostring(eval(n.value))); assert(value~=nil,why); state.vars[n.name]=value
          elseif n.op=='save' then assert(peanut.write(tostring(eval(n.value)),state.vars[n.name]))
          elseif n.op=='quit' then state.quit=true end
        end
      end)
      if not ok then fail(n.line,tostring(err)) end
    end
  end
  function state.initialize() state.budget=10000; run(ast,'init') end
  function state.layout() state.budget=10000; state.widgets={}; run(ast,'render'); return state.widgets end
  function state.dispatch(name) state.budget=10000; if state.handlers[name] then run(state.handlers[name],'event') end end
  function state.tick(timer) state.budget=10000; run(timer.body,'event') end
  return state
end
return P
]]},
  ["system/pixels.lua"]={sha256="1378a7f70bcd169de1256a2d629d782c90ae49b52f42746fda07546bfc3ab560",data=[[
-- Portable 2x3 subpixels per terminal cell. No CraftOS-PC graphics extensions.
local M = {}
local hex = "0123456789abcdef"
function M.new(w, h, fill)
  local b = { w = w, h = h, data = {} }
  for y = 1, h do b.data[y] = {}; for x = 1, w do b.data[y][x] = fill or colors.black end end
  function b.set(x, y, c)
    x, y = math.floor(x), math.floor(y)
    if x >= 1 and x <= w and y >= 1 and y <= h then b.data[y][x] = c end
  end
  function b.line(x1, y1, x2, y2, c)
    local dx, dy = math.abs(x2-x1), -math.abs(y2-y1)
    local sx, sy = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
    local err = dx + dy
    while true do
      b.set(x1, y1, c)
      if x1 == x2 and y1 == y2 then break end
      local e = 2 * err
      if e >= dy then err = err + dy; x1 = x1 + sx end
      if e <= dx then err = err + dx; y1 = y1 + sy end
    end
  end
  function b.rect(x, y, rw, rh, c)
    for yy = y, y + rh - 1 do for xx = x, x + rw - 1 do b.set(xx, yy, c) end end
  end
  return b
end
local function digit(c)
  local n = 0
  while c > 1 do c = c / 2; n = n + 1 end
  return hex:sub(n+1, n+1)
end
function M.cell(p)
  local count, order = {}, {}
  for _, c in ipairs(p) do
    if not count[c] then count[c] = 0; order[#order+1] = c end
    count[c] = count[c] + 1
  end
  table.sort(order, function(a, b) return count[a] > count[b] or (count[a] == count[b] and a < b) end)
  local bg, fg = order[1], order[2] or order[1]
  -- The sixth pixel is always background; invert the mask when necessary.
  if p[6] == fg then bg, fg = fg, bg end
  local bits = 0
  for i = 1, 5 do if p[i] == fg and fg ~= bg then bits = bits + 2^(i-1) end end
  return string.char(128 + bits), digit(fg), digit(bg)
end
function M.draw(b, target, ox, oy, maxW, maxH)
  target, ox, oy = target or term, ox or 1, oy or 1
  local tw, th = target.getSize()
  local cw = math.min(math.ceil(b.w/2), maxW or tw, tw-ox+1)
  local ch = math.min(math.ceil(b.h/3), maxH or th, th-oy+1)
  local function get(x,y) return b.data[y] and b.data[y][x] or colors.black end
  for cy = 1, ch do
    local text, fg, bg = {}, {}, {}
    for cx = 1, cw do
      local x,y = (cx-1)*2+1, (cy-1)*3+1
      text[cx],fg[cx],bg[cx] = M.cell({get(x,y),get(x+1,y),get(x,y+1),get(x+1,y+1),get(x,y+2),get(x+1,y+2)})
    end
    target.setCursorPos(ox, oy+cy-1)
    target.blit(table.concat(text),table.concat(fg),table.concat(bg))
  end
end
return M
]]},
  ["system/session.lua"]={sha256="38cfcd40a9b14c26a30c88fa67f27ff46eed892c86281704a090de03b2969560",data=[[
-- A normal CraftOS program environment routed through the encrypted filesystem.
-- This is compatibility plumbing, not a security sandbox for untrusted Lua.
local M={}
local hostLoad=load
function M.environment(vfs,parent)
  local env={fs=vfs}
  setmetatable(env,{__index=parent})
  env._G=env
  env.load=function(chunk,name,mode,target) return hostLoad(chunk,name,mode or "t",target or env) end
  env.loadstring=function(chunk,name) return env.load(chunk,name) end
  env.loadfile=function(path,mode,target)
    if type(mode)=="table" then target,mode=mode,nil end
    local h,err=vfs.open(path,"r"); if not h then return nil,err end
    local code=h.readAll(); h.close()
    return env.load(code,"@/"..path,mode or "t",target or env)
  end
  env.dofile=function(path) return assert(env.loadfile(path))() end
  env.os={}; for k,v in pairs(parent.os) do env.os[k]=v end
  env.os.run=function(target,path,...)
    setmetatable(target,{__index=env})
    target._G=env
    local fn,err=env.loadfile(path,"t",target)
    if not fn then printError(err); return false end
    local ok,result=pcall(fn,...)
    if not ok then printError(result) end
    return ok
  end
  env.os.loadAPI=function(path)
    local target={}; setmetatable(target,{__index=env})
    local fn=env.loadfile(path,"t",target)
    if not fn then return false end
    local ok=pcall(fn)
    if ok then env[vfs.getName(path):gsub("%.lua$","")]=target end
    return ok
  end
  env.os.unloadAPI=function(name) env[name]=nil end
  -- These ROM APIs close over fs: reload them so they use the encrypted drive.
  for _,name in ipairs({"io","settings","paintutils","help"}) do
    local apiEnv=setmetatable({},{__index=env})
    local chunk=env.loadfile("/rom/apis/"..name..".lua","t",apiEnv)
    if chunk then chunk(); env[name]=apiEnv end
  end
  for _,name in ipairs(parent.settings.getNames()) do
    local value=parent.settings.get(name)
    if value~=nil then env.settings.set(name,value) end
  end
  env.settings.load("/.settings")
  local make=env.dofile("/rom/modules/main/cc/require.lua").make
  env.require,env.package=make(env,"/")
  return env
end
return M
]]},
  ["system/storage.lua"]={sha256="7a414b34dac0c19bbe4e24db3e3fd87b9fc6243aa1f4ea2ff3fcd36b9e619c55",data=[[
-- File writes keep the previous contents until the replacement is ready.
local M = {}
function M.read(path)
  local h, err = fs.open(path, "rb")
  if not h then return nil, err or ("Cannot read " .. path) end
  local ok, value = pcall(h.readAll)
  h.close()
  if not ok then return nil, value end
  return value or ""
end
function M.write(path, value)
  if fs.exists(path) and fs.isDir(path) then return nil,"Path is a directory: " .. path end
  if fs.isReadOnly(path) then return nil, "Read-only path: " .. path end
  local temp, backup = path .. ".sacabam-new", path .. ".sacabam-old"
  if fs.exists(temp) or fs.exists(backup) then
    return nil, "Recovery files exist beside " .. path .. "; inspect them first."
  end
  local moved = false
  local ok, err = pcall(function()
    fs.makeDir(fs.getDir(path))
    local h, why = fs.open(temp, "wb")
    assert(h, why or "Cannot create temporary file")
    local wrote, failure = pcall(h.write, value)
    h.close()
    assert(wrote, failure)
    assert(M.read(temp) == value, "Write verification failed")
    if fs.exists(path) then fs.move(path, backup); moved = true end
    fs.move(temp, path)
    if moved then fs.delete(backup) end
  end)
  if not ok then
    if moved and not fs.exists(path) and fs.exists(backup) then pcall(fs.move, backup, path) end
    if fs.exists(temp) then pcall(fs.delete, temp) end
    return nil, tostring(err)
  end
  return true
end
function M.load(path, fallback)
  local raw = M.read(path)
  if not raw then return fallback end
  local ok, result = pcall(textutils.unserialize, raw)
  if ok and type(result) == "table" then return result end
  return fallback
end
function M.save(path, value) return M.write(path, textutils.serialize(value)) end
function M.unique(dir, name)
  local path, n = fs.combine(dir, name), 1
  while fs.exists(path) do n = n + 1; path = fs.combine(dir, name .. "-" .. n) end
  return path
end
function M.within(path, root)
  path, root = fs.combine("/", path), fs.combine("/", root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end
function M.name(name)
  return type(name) == "string" and name ~= "" and name ~= "." and name ~= ".."
    and not name:find("[/\\%c]")
end
return M
]]},
  ["system/ui.lua"]={sha256="0d87760d2c5297cb0bca92fa11ef4d24fdb3ebebd4507fd50d8e266d79c1e00f",data=[[
local M = {}
function M.text(x, y, value, fg, bg, width)
  local w, h = term.getSize()
  if y < 1 or y > h or x > w then return end
  value = tostring(value or "")
  if x < 1 then value = value:sub(2-x); x = 1 end
  local n = math.max(0, math.min(width or #value, w-x+1))
  value = value:sub(1,n)
  if width then value = value .. string.rep(" ", n-#value) end
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.setCursorPos(x,y); term.write(value)
end
function M.fill(x,y,w,h,bg)
  for row=y,y+h-1 do M.text(x,row,"",nil,bg,w) end
end
function M.clear(t)
  term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorBlink(false)
end
function M.bar(y, text, t)
  M.text(1,y,text,t.onAccent,t.accent,(term.getSize()))
end
function M.wrap(value,width)
  local out = {}; width = math.max(1,width)
  for line in (tostring(value) .. "\n"):gmatch("(.-)\n") do
    if line == "" then out[#out+1] = "" end
    while #line > 0 do
      local cut = math.min(#line,width)
      if #line > width then
        local last = line:sub(1,width):match("^.*() ")
        if last and last > width/2 then cut = last end
      end
      out[#out+1] = line:sub(1,cut)
      line = line:sub(cut+1)
    end
  end
  return out
end
function M.prompt(api, label, initial)
  local value = initial or ""
  while true do
    local t, w, h = api.theme(), term.getSize()
    M.fill(1, math.max(1,h-2),w,3,t.panel)
    M.text(2,h-2,label,t.text,t.panel,w-2)
    M.text(2,h-1,"> " .. value:sub(-math.max(1,w-5)),t.text,t.bg,w-2)
    M.text(2,h,"Enter: accept   Esc: cancel",t.muted,t.panel,w-2)
    local e,a = os.pullEventRaw()
    if e == "char" or e == "paste" then value = value .. a:gsub("[%c]", ""):sub(1,512-#value)
    elseif e == "key" then
      if a == keys.enter then return value
      elseif a == keys.escape then return nil
      elseif a == keys.backspace then value = value:sub(1,-2) end
    elseif e == "sacabam_close" or e == "terminate" then return nil end
  end
end
function M.confirm(api, label)
  return (M.prompt(api, label .. " (type YES)") or ""):upper() == "YES"
end
function M.message(api, value)
  api.notify(tostring(value))
end
return M
]]},
  ["system/vault.lua"]={sha256="6168a0ed3478565fccfe5c9b7d047e51520d4155209ff85e013df47162efa17e",data=[[
-- Only encrypted envelopes are ever written to the physical filesystem.
local V={ iterations=100000, limit=196608 }
local physical=fs
function V.new(crypto,storage,path)
  local self={path=path,open=false,files=nil,key=nil,salt=nil,iterations=nil,serial=0}
  local function keyFor(label) return crypto.hmac(self.key,"CCSacabam v1 "..label) end
  local function header(raw)
    assert(type(raw)=="string" and #raw>=88 and raw:sub(1,4)=="SCV1","Not a CCSacabam vault")
    local iterations=crypto.number(raw,37)
    assert(iterations>=10000 and iterations<=2000000,"Unsupported key derivation parameters")
    return raw:sub(5,36),iterations,raw:sub(41,52),raw:sub(53,-33),raw:sub(-32)
  end
  function self.exists() return physical.exists(path) end
  function self.recoverPending()
    -- A power interruption can leave the old or new encrypted envelope beside
    -- the main file. Restore the last committed copy, and retain other copies.
    local old,new=path..".sacabam-old",path..".sacabam-new"
    if not physical.exists(path) then
      if physical.exists(old) then physical.move(old,path)
      elseif physical.exists(new) then physical.move(new,path) end
    end
    for _,candidate in ipairs({old,new}) do
      if physical.exists(candidate) then
        local n=1; local archive
        repeat archive=path..".recovery-"..n; n=n+1 until not physical.exists(archive)
        physical.move(candidate,archive)
      end
    end
  end
  function self.unlock(password,progress)
    local raw,err=storage.read(path); if not raw then return nil,err end
    local ok,salt,iterations,nonce,cipher,tag=pcall(header,raw)
    if not ok then return nil,tostring(salt) end
    local master=crypto.pbkdf2(password,salt,iterations,progress)
    local macKey=crypto.hmac(master,"CCSacabam v1 authentication")
    if not crypto.equal(crypto.hmac(macKey,raw:sub(1,-33)),tag) then
      return nil,"Wrong password or damaged vault."
    end
    local plain=crypto.chacha20(crypto.hmac(master,"CCSacabam v1 encryption"),nonce,cipher)
    local decoded=storage and textutils.unserialize(plain)
    if type(decoded)~="table" or decoded[""]~=true then return nil,"Invalid vault filesystem" end
    for name,value in pairs(decoded) do
      if type(name)~="string" or physical.combine("",name)~=name or (type(value)~="string" and value~=true) then
        return nil,"Invalid vault entry"
      end
    end
    self.key,self.salt,self.iterations,self.files,self.open=master,salt,iterations,decoded,true
    return true
  end
  function self.persist()
    assert(self.open,"Personal drive is locked")
    local plain=textutils.serialize(self.files)
    if #plain>V.limit then return nil,"Personal drive full (192 KiB serialized limit)." end
    self.serial=self.serial+1
    -- CC has no OS CSPRNG. A keyed nonce includes the entire content digest,
    -- time and a counter, so different contents remain distinct after rollback.
    local timing=tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock()..":"..self.serial
    local nonce=crypto.hmac(keyFor("nonce"),crypto.sha256(plain)..timing):sub(1,12)
    local cipher=crypto.chacha20(keyFor("encryption"),nonce,plain)
    local body="SCV1"..self.salt..crypto.be(self.iterations)..nonce..cipher
    return storage.write(path,body..crypto.hmac(keyFor("authentication"),body))
  end
  function self.create(password,entropy,progress)
    if self.exists() then return nil,"A vault already exists. Unlock it instead." end
    assert(type(password)=="string" and #password>=12,"Use a passphrase of at least 12 characters")
    self.salt=crypto.sha256("CCSacabam salt:"..tostring(entropy)..":"..tostring(os.getComputerID())..":"..tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock())
    self.iterations=V.iterations
    self.key=crypto.pbkdf2(password,self.salt,self.iterations,progress)
    self.files={[""]=true,Documents=true,Pictures=true,Programs=true,[".Trash"]=true,[".system"]=true}
    self.open=true
    local ok,err=self.persist()
    if not ok then self.lock(); return nil,err end
    return true
  end
  function self.changePassword(password,entropy,progress)
    assert(self.open,"Drive is locked")
    if #password<12 then return nil,"Use at least 12 characters." end
    local oldKey,oldSalt,oldIterations=self.key,self.salt,self.iterations
    local newSalt=crypto.sha256(self.salt..tostring(entropy)..tostring(os.clock())..keyFor("password change"))
    local newKey=crypto.pbkdf2(password,newSalt,V.iterations,progress)
    self.salt,self.iterations,self.key=newSalt,V.iterations,newKey
    local ok,err=self.persist()
    if not ok then self.key,self.salt,self.iterations=oldKey,oldSalt,oldIterations end
    return ok,err
  end
  function self.lock()
    if self.files then for k in pairs(self.files) do self.files[k]=nil end end
    self.files,self.key,self.salt,self.iterations,self.open=nil,nil,nil,nil,false
  end
  function self.filesystem(mount)
    mount=physical.combine("",mount)
    local systemRoot=physical.getDir(mount)
    local out={}
    for k,v in pairs(physical) do out[k]=v end
    local function resolve(path)
      path=physical.combine("",path)
      if path==mount then return "" end
      if path:sub(1,#mount+1)==mount.."/" then return path:sub(#mount+2) end
      if path=="rom" or path:sub(1,4)=="rom/" or path=="host" or path:sub(1,5)=="host/"
        or path==systemRoot or path:sub(1,#systemRoot+1)==systemRoot.."/" then return nil end
      return path
    end
    local function hostPath(path)
      path=physical.combine("",path)
      if path=="rom/modules/main/peanut.lua" then return physical.combine(systemRoot,"system/peanut.lua") end
      if path=="rom/modules/main/ganymede.lua" then return physical.combine(systemRoot,"system/ganymede.lua") end
      if path=="rom/modules/main/europa.lua" then return physical.combine(systemRoot,"system/europa.lua") end
      if path=="host" then return "" elseif path:sub(1,5)=="host/" then return path:sub(6) end
      return path
    end
    local function check() assert(self.open,"Personal drive is locked") end
    local function mutate(fn)
      check()
      local old={}; for k,v in pairs(self.files) do old[k]=v end
      local ok,err=pcall(fn)
      if ok then ok,err=self.persist() end
      if not ok then self.files=old; error(err,3) end
    end
    local function subtree(path,key) return path==key or path:sub(1,#key+1)==key.."/" end
    function out.exists(path)
      local key=resolve(path)
      if key then check(); return self.files[key]~=nil end
      return physical.exists(hostPath(path))
    end
    function out.isDir(path)
      local key=resolve(path)
      if key then check(); return self.files[key]==true end
      return physical.isDir(hostPath(path))
    end
    function out.isReadOnly(path) return resolve(path)==nil end
    function out.getDrive(path) if resolve(path) then return "encrypted" else return physical.getDrive(hostPath(path)) end end
    function out.isDriveRoot(path) return resolve(path)=="" or (resolve(path)==nil and physical.isDriveRoot and physical.isDriveRoot(path)) or false end
    function out.list(path)
      local key=resolve(path)
      if key then
        check(); assert(self.files[key]==true,"Not a directory")
        local prefix=key=="" and "" or key.."/"
        local names={}
        for p in pairs(self.files) do
          if p:sub(1,#prefix)==prefix then
            local name=p:sub(#prefix+1)
            if name~="" and not name:find("/",1,true) then names[#names+1]=name end
          end
        end
        if key=="" then
          for _,n in ipairs({"rom",systemRoot,"host"}) do
            if not self.files[n] then names[#names+1]=n end
          end
        end
        table.sort(names); return names
      end
      local names=physical.list(hostPath(path))
      if physical.combine("",path)=="rom/modules/main" then
        names[#names+1]="peanut.lua"; names[#names+1]="ganymede.lua"; names[#names+1]="europa.lua"; table.sort(names)
      end
      if physical.combine("",path)==physical.getDir(mount) then
        local found=false; for _,n in ipairs(names) do if n==physical.getName(mount) then found=true end end
        if not found then names[#names+1]=physical.getName(mount); table.sort(names) end
      end
      return names
    end
    function out.getSize(path)
      local key=resolve(path)
      if key then check(); assert(self.files[key]~=nil,"No such file"); return self.files[key]==true and 0 or #self.files[key] end
      return physical.getSize(hostPath(path))
    end
    function out.getFreeSpace(path)
      if resolve(path) then check(); return math.max(0,V.limit-#textutils.serialize(self.files)) end
      return physical.getFreeSpace(hostPath(path))
    end
    function out.getCapacity(path) if resolve(path) then return V.limit else return physical.getCapacity and physical.getCapacity(hostPath(path)) end end
    function out.attributes(path)
      if resolve(path) then
        if not out.exists(path) then return nil end
        return {size=out.getSize(path),isDir=out.isDir(path),isReadOnly=false,created=0,modified=0,modification=0}
      end
      return physical.attributes and physical.attributes(hostPath(path))
    end
    local function parents(key)
      local dir=physical.getDir(key)
      if dir~="" then parents(dir) end
      if self.files[dir]~=nil and self.files[dir]~=true then error("Parent is a file") end
      self.files[dir]=true
    end
    function out.makeDir(path)
      local key=assert(resolve(path),"Writes belong on the encrypted personal drive")
      if self.files[key]==true then return end
      mutate(function() assert(self.files[key]==nil,"File already exists"); parents(key); self.files[key]=true end)
    end
    function out.delete(path)
      local key=assert(resolve(path),"Cannot delete outside the personal drive")
      assert(key~="","Cannot delete the personal drive")
      mutate(function() for p in pairs(self.files) do if subtree(p,key) then self.files[p]=nil end end end)
    end
    function out.move(from,to)
      local a=assert(resolve(from),"Cannot move outside the personal drive")
      local b=assert(resolve(to),"Cannot export decrypted data")
      assert(a~="" and b~="" and not subtree(b,a),"Cannot move a folder into itself")
      mutate(function()
        assert(self.files[a]~=nil,"Source does not exist"); assert(self.files[b]==nil,"Destination exists")
        parents(b)
        local changes={}
        for p,v in pairs(self.files) do if subtree(p,a) then changes[b..p:sub(#a+1)]=v end end
        for p in pairs(self.files) do if subtree(p,a) then self.files[p]=nil end end
        for p,v in pairs(changes) do self.files[p]=v end
      end)
    end
    function out.copy(from,to)
      local b=assert(resolve(to),"Cannot export decrypted data")
      local a=resolve(from)
      if a then assert(a~="" and not subtree(b,a),"Cannot copy a folder into itself") end
      assert(out.exists(from) and not out.exists(to),"Source missing or destination exists")
      local changes={}
      local function copy(src,key)
        if out.isDir(src) then
          changes[key]=true
          for _,n in ipairs(out.list(src)) do copy(physical.combine(src,n),physical.combine(key,n)) end
        else local h=assert(out.open(src,"rb")); changes[key]=h.readAll(); h.close() end
      end
      copy(from,b)
      mutate(function() parents(b); for p,v in pairs(changes) do self.files[p]=v end end)
    end
    function out.open(path,mode)
      mode=mode or "r"
      local key=resolve(path)
      if not key then
        if mode~="r" and mode~="rb" then return nil,"Read-only system/host path. Save on the personal drive." end
        return physical.open(hostPath(path),mode)
      end
      check()
      if not ({r=true,rb=true,w=true,wb=true,a=true,ab=true,["r+"]=true,["r+b"]=true,["w+"]=true,["w+b"]=true})[mode] then error("Unsupported file mode",2) end
      local update=mode:find("+",1,true)~=nil
      local writable=mode:sub(1,1)~="r" or update
      local readable=mode:sub(1,1)=="r" or update
      local binary=mode:sub(-1)=="b"
      if self.files[key]==true then return nil,"Cannot open a directory" end
      if mode:sub(1,1)=="r" and self.files[key]==nil then return nil,"No such file" end
      local data=mode:sub(1,1)=="w" and "" or self.files[key] or ""
      local pos=mode:sub(1,1)=="a" and #data or 0
      local closed,dirty=false,writable and mode:sub(1,1)=="w"
      local h={}
      local function alive() check(); assert(not closed,"File is closed") end
      function h.flush()
        alive()
        if writable and dirty then
          mutate(function() parents(key); self.files[key]=data end)
          dirty=false
        end
      end
      function h.close() alive(); h.flush(); closed=true; data="" end
      if writable then
        function h.write(value)
          alive(); value=type(value)=="number" and binary and string.char(value%256) or tostring(value)
          assert(pos+#value<=V.limit,"File too large")
          if pos>#data then data=data..string.rep("\0",pos-#data) end
          data=data:sub(1,pos)..value..data:sub(pos+#value+1); pos=pos+#value; dirty=true
        end
        function h.writeLine(value) h.write(tostring(value).."\n") end
      end
      if readable then
        function h.read(n)
          alive(); if pos>=#data then return nil end
          if n==nil and binary then pos=pos+1; return data:byte(pos) end
          n=n or 1; assert(n>=0,"Negative read")
          local s=data:sub(pos+1,pos+n); pos=pos+#s; return s
        end
        function h.readAll() alive(); local s=data:sub(pos+1); pos=#data; return s end
        function h.readLine(trailing)
          alive(); if pos>=#data then return nil end
          local endpos=data:find("\n",pos+1,true)
          local line=data:sub(pos+1,endpos and (trailing and endpos or endpos-1) or #data)
          pos=endpos or #data
          if not trailing then line=line:gsub("\r$","") end
          return line
        end
      end
      function h.seek(whence,offset)
        alive(); whence=whence or "cur"; offset=offset or 0
        local bases={set=0,cur=pos,["end"]=#data}; assert(bases[whence],"Invalid seek")
        if bases[whence]+offset<0 then return nil,"Negative seek" end
        pos=bases[whence]+offset; return pos
      end
      return h
    end
    function out.complete(part,location,includeFiles,includeDirs)
      local base=physical.combine(location or "",physical.getDir(part))
      local tail=physical.getName(part); if part:sub(-1)=="/" then base=physical.combine(location or "",part); tail="" end
      local result={}
      if out.isDir(base) then for _,name in ipairs(out.list(base)) do
        if name:sub(1,#tail)==tail then
          local isdir=out.isDir(physical.combine(base,name)); local suffix=name:sub(#tail+1)
          if isdir then
            result[#result+1]=suffix.."/"
            if includeDirs~=false and suffix~="" then result[#result+1]=suffix end
          elseif includeFiles~=false and suffix~="" then result[#result+1]=suffix end
        end
      end end
      table.sort(result); return result
    end
    function out.find(pattern)
      local result={}
      local function walk(base,parts,index)
        if index>#parts then if out.exists(base) then result[#result+1]=base end; return end
        if not out.isDir(base) then return end
        local pat="^"..parts[index]:gsub("([%^%$%(%)%%%.%[%]%+%-])","%%%1"):gsub("%*",".*"):gsub("%?",".").."$"
        for _,name in ipairs(out.list(base)) do if name:match(pat) then walk(physical.combine(base,name),parts,index+1) end end
      end
      local parts={}; for p in physical.combine("",pattern):gmatch("[^/]+") do parts[#parts+1]=p end
      walk("",parts,1); table.sort(result); return result
    end
    return out
  end
  return self
end
return V
]]},
  ["uninstall.lua"]={sha256="0b46240b3e35fc94921f127c489f6b43b21b9532a72e8fc19af4034f7ccd257e",data=[[
-- Detach autostart without deleting the encrypted drive or installation.
local args={...}; local root=fs.getDir(shell.getRunningProgram())
local function readFile(path) local h=assert(fs.open(path,'r')); local data=h.readAll(); h.close(); return data end
local info=textutils.unserialize(readFile(fs.combine(root,'config/install.tbl'))) or {}
local loader='/startup.lua'
if fs.exists(loader) and (fs.isDir(loader) or not readFile(loader):find('CCSacabam managed startup',1,true)) then
  error('Startup was changed after installation. Restore it manually from the backup; no files changed.',0)
end
for path,backup in pairs(info.startupRestore or {}) do
  assert(fs.exists(backup),'Missing startup backup: '..backup)
  assert(path=='/startup.lua' or not fs.exists(path),'Startup destination already exists: '..path)
end
if args[1]~='--yes' then
  print('Disable CCSacabam autostart and restore previous startup?')
  print('The OS and encrypted drive will be kept. Type REMOVE to continue.')
  if read()~='REMOVE' then return end
end
local saved
if fs.exists(loader) then saved=readFile(loader); fs.delete(loader) end
local restored={}
local ok,err=pcall(function()
  for path,backup in pairs(info.startupRestore or {}) do fs.copy(backup,path); restored[#restored+1]=path end
end)
if not ok then
  for _,path in ipairs(restored) do fs.delete(path) end
  if saved then local h=assert(fs.open(loader,'w')); h.write(saved); h.close() end
  error('Could not restore startup: '..tostring(err),0)
end
print('Autostart disabled. The encrypted drive and CCSacabam files are preserved.')
print('Run '..fs.combine(root,'boot.lua')..' to open CCSacabam manually.')
]]},
}}
local installer=(function()
-- Shared installer engine, embedded verbatim in the standalone distribution.
local I={target='/ccsacabam',stage='/ccsacabam-install-stage'}
local function readFile(path)
  local h,err=fs.open(path,'r'); assert(h,err); local data=h.readAll(); h.close(); return data
end
local function writeFile(path,data)
  fs.makeDir(fs.getDir(path)); local h,err=fs.open(path,'w'); assert(h,err)
  local ok,why=pcall(h.write,data); h.close(); assert(ok,why)
  assert(readFile(path)==data,'Write verification failed: '..path)
end
local function size(path)
  if not fs.exists(path) then return 0 end
  if not fs.isDir(path) then return fs.getSize(path) end
  local n=0; for _,name in ipairs(fs.list(path)) do n=n+size(fs.combine(path,name)) end; return n
end
function I.validate(package)
  assert(type(package)=='table' and type(package.files)=='table','Invalid package')
  local cryptoFile=assert(package.files['system/crypto.lua'],'Missing crypto module')
  local crypto=assert(load(cryptoFile.data,'@crypto','t',_ENV))()
  local total=0
  for path,file in pairs(package.files) do
    assert(type(path)=='string' and path~='' and fs.combine('',path)==path and path:sub(1,1)~='/' and not path:find('%.%.'),'Invalid package path')
    assert(type(file.data)=='string' and crypto.hex(crypto.sha256(file.data))==file.sha256,'Package checksum mismatch: '..path)
    if path:match('%.lua$') then assert(load(file.data,'@'..path,'t',_ENV)) end
    total=total+#file.data
  end
  for _,name in ipairs({'boot.lua','system/kernel.lua','system/vault.lua','system/session.lua','apps/terminal.lua','uninstall.lua','chatplus.lua'}) do
    assert(package.files[name],'Incomplete package: '..name)
  end
  return total
end
function I.install(package,options)
  options=options or {}; local total=I.validate(package)
  local target,stage=I.target,I.stage
  assert(not fs.isReadOnly('/'),'Root filesystem is read-only')
  assert(not fs.exists(stage),'An interrupted install exists at '..stage..'. Inspect it before trying again.')
  local exists=fs.exists(target)
  assert(not exists or (fs.isDir(target) and fs.exists(target..'/.ccsacabam')),'Existing /ccsacabam is not an owned installation; choose a different source folder.')
  local oldInfo=exists and fs.exists(target..'/config/install.tbl') and textutils.unserialize(readFile(target..'/config/install.tbl')) or {}
  local free=fs.getFreeSpace('/')
  assert(type(free)~='number' or free>=total+size(target)+8192,'Not enough space for a staged install and backup')
  local n=1; local backup
  repeat backup='/ccsacabam-backups/install-'..n; n=n+1 until not fs.exists(backup)
  local startupRestore=oldInfo and oldInfo.startupRestore or {}
  local movedStartup={}; local movedOld,movedNew,wroteStartup=false,false,false
  local loader='-- CCSacabam managed startup\nif not shell.run("/ccsacabam/boot.lua") then print("CCSacabam failed; CraftOS remains available.") end\n'
  local ok,err=pcall(function()
    fs.makeDir(backup)
    if exists then fs.copy(target,stage) else fs.makeDir(stage) end
    for _,dir in ipairs({'system','apps','examples','sites'}) do
      if fs.exists(stage..'/'..dir) then fs.delete(stage..'/'..dir) end
    end
    for path,file in pairs(package.files) do
      local dest=fs.combine(stage,path)
      if fs.exists(dest) then fs.delete(dest) end
      writeFile(dest,file.data)
    end
    writeFile(stage..'/.ccsacabam',package.version or '1.0.0')
    local mode=options.mode or (term.isColor() and 'color' or 'basic')
    if not term.isColor() then mode='basic' end
    assert(mode=='basic' or mode=='color' or mode=='render','Unknown display mode')
    writeFile(stage..'/config/display.tbl',textutils.serialize({mode=mode,welcome=true}))
    for _,path in ipairs({'/startup.lua','/startup'}) do
      if fs.exists(path) and not startupRestore[path] and not (path=='/startup.lua' and not fs.isDir(path) and readFile(path):find('CCSacabam managed startup',1,true)) then
        startupRestore[path]=backup..'/'..fs.getName(path)
      end
    end
    writeFile(stage..'/config/install.tbl',textutils.serialize({version=package.version,backup=backup,startupRestore=startupRestore}))
    if exists then fs.move(target,backup..'/previous'); movedOld=true end
    fs.move(stage,target); movedNew=true
    for _,path in ipairs({'/startup.lua','/startup'}) do
      if fs.exists(path) then
        local dest=backup..'/'..fs.getName(path); fs.move(path,dest); movedStartup[#movedStartup+1]={from=path,to=dest}
      end
    end
    -- Mark before writing so a partially written loader is also rolled back.
    wroteStartup=true; writeFile('/startup.lua',loader)
  end)
  if not ok then
    local rollbackErrors={}
    local function undo(fn) local good,why=pcall(fn); if not good then rollbackErrors[#rollbackErrors+1]=tostring(why) end end
    if wroteStartup and fs.exists('/startup.lua') then undo(function() fs.delete('/startup.lua') end) end
    for i=#movedStartup,1,-1 do local item=movedStartup[i]; undo(function() fs.move(item.to,item.from) end) end
    if movedNew and fs.exists(target) then undo(function() fs.delete(target) end) end
    if movedOld then undo(function() fs.move(backup..'/previous',target) end) end
    if fs.exists(stage) then undo(function() fs.delete(stage) end) end
    if #rollbackErrors>0 then error(tostring(err)..'\nRollback needs attention: '..table.concat(rollbackErrors,'; ')..'\nBackups: '..backup,0) end
    error(tostring(err)..'\nPrevious installation and startup restored.',0)
  end
  return {target=target,backup=backup,bytes=total}
end
function I.run(package,args)
  assert(bit32 and window and term.blit,'CCSacabam needs CC: Tweaked or a compatible modern ComputerCraft runtime.')
  local w,h=term.getSize(); assert(w>=20 and h>=10,'Display must be at least 20x10.')
  local mode=term.isColor() and 'color' or 'basic'
  if args and args[1]=='--yes' then mode=args[2] or mode
  else
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
    print('CCSacabam installer\n')
    print('Installs to /ccsacabam. Existing files are preserved.')
    print('Existing startup programs are backed up.')
    print('Create your encrypted drive and passphrase at first boot.\n')
    if term.isColor() then
      print('Display mode:')
      print('1 Basic: monochrome, keyboard controls')
      print('2 Color: mouse and keyboard (default)')
      print('3 Render: color + portable subpixel graphics')
      write('Choose 1, 2, or 3: '); local choice=read()
      mode=choice=='1' and 'basic' or choice=='3' and 'render' or 'color'
    else print('Basic computer detected: monochrome mode.') end
    write('\nPress Enter to install, or type cancel: ')
    if read()~='' then print('Cancelled.'); return false end
  end
  print('Checking package and staging files...')
  local ok,result=pcall(I.install,package,{mode=mode})
  if not ok then printError(result); return false end
  print('CCSacabam installed. Backup: '..result.backup)
  print('Run /ccsacabam/boot.lua or reboot to sign in.')
  return true
end
return I

end)()
return installer.run(package,{...})
