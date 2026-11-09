-- CCSacabam 1.0.0: standalone offline installer
local package={version="1.0.0",files={
  ["apps/browser.lua"]={sha256="42cbb334eaf9c64483edba3c2eae57f51d477680898b717c20184431906300ef",data=[=[
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
      if address:sub(1,7)=='file://' then
        address='file://'..api.resolve(address:sub(8))
      elseif address:sub(1,1)=='/' or address:sub(1,2)=='./' or address:sub(1,3)=='../'
        or address=='.' or address=='..' or (not address:find('://',1,true)
          and (address:match('%.cashew$') or address:match('%.pist$'))) then
        address='file://'..api.resolve(address)
      end
      if address:sub(1,7)=='file://' and fs.isDir(address:sub(8)) then
        address='file://'..api.resolve('index.cashew',address:sub(8))
      end
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
    ui.text(1,2,' Back  Home  File  Address  Bookmark',t.text,t.panel,w)
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
  local function openFile()
    local path=ui.filePicker(api,{mode='open',title='Open local page',path=url:sub(1,7)=='file://' and url:sub(8) or api.dir(),
      extensions={'cashew','pist','txt','peanut'}})
    if path then navigate('file://'..path) end
  end
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
        elseif a==keys.o and (api.keyDown(keys.leftCtrl) or api.keyDown(keys.rightCtrl)) then openFile()
        elseif a==keys.l and (api.keyDown(keys.leftCtrl) or api.keyDown(keys.rightCtrl)) then promptAddress() end
      elseif e=='char' or e=='paste' then
        if selected and selected.kind=='input' and state then
          state.vars[selected.bind]=(tostring(state.vars[selected.bind])..a:gsub('[%c]','')):sub(1,1024); state.dispatch(selected.id)
        elseif e=='char' then
          if a=='g' then promptAddress() elseif a=='h' then navigate('about:home') elseif a=='b' then bookmark() elseif a=='o' then openFile()
          elseif a=='l' then
            local lines={}; for i,address in ipairs(bookmarks) do lines[#lines+1]=i..' '..address end
            api.notify(table.concat(lines,' | ')); local choice=tonumber(ui.prompt(api,'Bookmark number (1-'..#bookmarks..')'))
            if choice and bookmarks[choice] then navigate(bookmarks[choice]) end
          end
        end
      elseif e=='mouse_scroll' then scroll=scroll+a*3
      elseif e=='mouse_click' then
        if c==1 then promptAddress()
        elseif c==2 then if b<=6 then back() elseif b<=12 then navigate('about:home') elseif b<=18 then openFile() elseif b<=27 then promptAddress() else bookmark() end
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
  ["apps/code.lua"]={sha256="15aaf9b91fe79dd5e72d2e7eb718a027929430a965e00d78977317af413f6a84",data=[[
return function(api,path)
  return api.load('apps/editor')(api,path,{code=true})
end
]]},
  ["apps/customisation.lua"]={sha256="97d4ade0e1594513163a07a20766940ceb7881ff7bbf0fe44279088448d750d7",data=[=[
-- Settings tab: keep the controls readable even with a low-contrast user theme.
return function(api)
  local ui=api.ui; local config=api.load('system/config')
  local self={editing=false}; local selected,offset,color=1,0,1; local rows=1
  local pattern=1; local patternImage
  local neutral=config.theme({mode='basic'})
  local confirmApi={}; for k,v in pairs(api) do confirmApi[k]=v end
  confirmApi.theme=function() return neutral end
  local function index(value) for n=1,16 do if 2^(n-1)==value then return n end end return 1 end
  local function store(key,value)
    local c=api.config(); local profile=config.profile(c); local previous=c.customColors
    local nextColors={}; for k,v in pairs(previous or {}) do nextColors[k]=v end
    local changed={}; for k,v in pairs(nextColors[profile] or {}) do changed[k]=v end
    if key then changed[key]=value else changed={} end
    nextColors[profile]=changed; c.customColors=nextColors
    local ok,err=api.saveConfig()
    if not ok then api.config().customColors=previous; api.notify(err); return false end
    return true
  end
  local function begin()
    self.editing=true; color=index(api.theme()[config.colorFields[selected][1]])
  end
  local function apply()
    if store(config.colorFields[selected][1],2^(color-1)) then self.editing=false end
  end
  local function beginPattern()
    pattern=1
    for i,name in ipairs(config.wallpaperPatterns) do if name==api.config().wallpaperPattern then pattern=i end end
    self.editing='pattern'; patternImage=nil
  end
  local function applyPattern()
    local c=api.config(); local previous,enabled=c.wallpaperPattern,c.wallpaper
    c.wallpaperPattern=config.wallpaperPatterns[pattern]; c.wallpaper=true
    local ok,err=api.saveConfig()
    if ok then self.editing=false else api.config().wallpaperPattern=previous; api.config().wallpaper=enabled; api.notify(err) end
  end
  local function swatch(x,y,width,n,active,label)
    local value=2^(n-1)
    local r,g,b=term.getPaletteColor(value)
    local fg=(r+g+b)/3>.5 and colors.black or colors.white
    ui.text(x,y,label or ((active and '>' or ' ')..string.format('%x',n-1)..(active and '<' or ' ')),fg,value,width)
  end
  function self.draw()
    local w,h=term.getSize(); local t=api.theme()
    ui.fill(1,3,w,h-2,neutral.bg)
    if self.editing=='pattern' then
      ui.text(1,3,'Wallpaper pattern',neutral.text,neutral.bg,w)
      ui.text(1,4,'< '..config.wallpaperPatterns[pattern]..' >',neutral.onAccent,neutral.accent,w)
      if h>=8 then
        local key=pattern..':'..w..':'..h
        if not patternImage or patternImage.key~=key then
          local c={mode=api.config().mode,wallpaperPattern=config.wallpaperPatterns[pattern]}
          patternImage={key=key,image=api.load('system/wallpaper').build(c,t,w,h-7,api.load('system/pixels'))}
        end
        api.load('system/wallpaper').draw(patternImage.image,api.load('system/pixels'),1,5)
      end
      local split=math.floor(w/2)
      ui.text(1,h-1,'[Apply]',neutral.onAccent,neutral.accent,split)
      ui.text(split+1,h-1,'[Cancel]',neutral.text,neutral.bg,w-split)
      ui.text(1,h,'Arrows / Enter / F5',neutral.text,neutral.bg,w)
    elseif self.editing then
      local field=config.colorFields[selected]
      ui.text(1,3,field[2],neutral.text,neutral.bg,w)
      if h>=10 then
        local cell=math.floor(w/4)
        for n=1,16 do swatch(1+((n-1)%4)*cell,4+math.floor((n-1)/4),cell,n,n==color) end
        if h>=12 then
          local preview={}; for k,v in pairs(t) do preview[k]=v end
          preview[field[1]]=2^(color-1)
          ui.text(1,8,' Title   - + X ',preview.titleText,preview.title,w)
          ui.text(1,9,' Sample text ',preview.text,preview.bg,w)
          ui.text(1,10,' Selected item ',preview.onAccent,preview.accent,w)
        end
        ui.text(1,h-2,config.colorNames[color],neutral.text,neutral.bg,w)
      else
        swatch(1,4,w,color,true,'< '..config.colorNames[color]..' >')
        if h>=8 then ui.text(1,5,config.colorNames[color],neutral.text,neutral.bg,w) end
      end
      local split=math.floor(w/2)
      ui.text(1,h-1,'[Apply]',neutral.onAccent,neutral.accent,split)
      ui.text(split+1,h-1,'[Cancel]',neutral.text,neutral.panel,w-split)
      ui.text(1,h,'Arrows / Enter / F5',neutral.text,neutral.bg,w)
    else
      rows=math.max(1,h-5)
      if selected<=offset then offset=selected-1 elseif selected>offset+rows then offset=selected-rows end
      for row=1,rows do
        local n=offset+row; local field=config.colorFields[n]
        if field then
          ui.text(1,row+2,(n==selected and '> ' or '  ')..field[2],n==selected and neutral.onAccent or neutral.text,
            n==selected and neutral.accent or neutral.bg,w-3)
          swatch(w-2,row+2,3,index(t[field[1]]),false)
        end
      end
      ui.text(1,h-2,config.colorNames[index(t[config.colorFields[selected][1]])]..' / '..config.profile(api.config()),neutral.text,neutral.bg,w)
      ui.text(1,h-1,'[W Wallpaper: '..api.config().wallpaperPattern..']',neutral.text,neutral.bg,w)
      ui.text(1,h,'Enter edit  R reset',neutral.text,neutral.bg,w)
    end
  end
  function self.event(e,a,b,c)
    local w,h=term.getSize()
    if self.editing=='pattern' then
      local step=0
      if e=='key' then
        if a==keys.escape or a==keys.f5 then self.editing=false
        elseif a==keys.enter then applyPattern()
        elseif a==keys.left or a==keys.up then step=-1
        elseif a==keys.right or a==keys.down then step=1 end
      elseif e=='mouse_scroll' then step=a
      elseif e=='mouse_click' and a==1 then
        if c==h-1 then if b<=math.floor(w/2) then applyPattern() else self.editing=false end
        elseif c==4 then step=b<=math.floor(w/2) and -1 or 1 end
      end
      pattern=((pattern-1+step)%#config.wallpaperPatterns)+1
    elseif self.editing then
      if e=='key' then
        if a==keys.f5 or a==keys.escape then self.editing=false
        elseif a==keys.enter then apply()
        elseif a==keys.left then color=math.max(1,color-1)
        elseif a==keys.right then color=math.min(16,color+1)
        elseif a==keys.up then color=math.max(1,color-(h>=10 and 4 or 1))
        elseif a==keys.down then color=math.min(16,color+(h>=10 and 4 or 1)) end
      elseif e=='mouse_click' and a==1 then
        if c==h-1 then if b<=math.floor(w/2) then apply() else self.editing=false end
        elseif h>=10 and c>=4 and c<=7 then
          color=math.min(16,(c-4)*4+math.min(4,math.floor((b-1)/math.floor(w/4))+1))
        elseif h<10 and c==4 then color=math.max(1,math.min(16,color+(b<=math.floor(w/2) and -1 or 1))) end
      elseif e=='mouse_scroll' then color=math.max(1,math.min(16,color+a)) end
    elseif e=='key' then
      if a==keys.up then selected=math.max(1,selected-1)
      elseif a==keys.down then selected=math.min(#config.colorFields,selected+1)
      elseif a==keys.pageUp then selected=math.max(1,selected-rows)
      elseif a==keys.pageDown then selected=math.min(#config.colorFields,selected+rows)
      elseif a==keys.home then selected=1
      elseif a==keys['end'] then selected=#config.colorFields
      elseif a==keys.enter then begin() end
    elseif (e=='char' and a:lower()=='w') or (e=='mouse_click' and a==1 and c==h-1) then beginPattern()
    elseif e=='char' and a:lower()=='r' then
      if ui.confirm(confirmApi,'Reset '..config.profile(api.config())..' colours?') then store() end
    elseif e=='mouse_click' and a==1 and c>=3 and c<3+rows and config.colorFields[offset+c-2] then
      selected=offset+c-2; begin()
    elseif e=='mouse_scroll' then selected=math.max(1,math.min(#config.colorFields,selected+a)) end
  end
  return self
end
]=]},
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
  ["apps/editor.lua"]={sha256="c03cfde79e0d51cc86634cea1e258e4b7e04ebc6e4229b75854871792908381b",data=[[
return function(api,path,options)
  local ui=api.ui
  local code=options and options.code
  local syntax=code and api.load('system/syntax')
  local language=code and (syntax.language(path) or 'lua')
  local cachedText,cachedLanguage,document,popup
  local lines={""}; local x,y,top,left=1,1,1,0
  local saved=""; local undo={}; local redo={}; local query=""
  local function contents() return table.concat(lines,"\n") end
  local function dirty() return contents()~=saved end
  local function syntaxDocument()
    local raw=contents()
    if raw~=cachedText or language~=cachedLanguage then
      document=syntax.document(lines,language); cachedText,cachedLanguage=raw,language
    end
    return document
  end
  local function complete(force)
    if not code then return end
    local items,prefix=syntax.complete(lines,language,x,y,syntaxDocument())
    popup=(#items>0 and (force or #prefix>=2)) and {items=items,prefix=prefix,index=1} or nil
  end
  local function split(raw)
    lines={}; for line in (raw:gsub("\r\n","\n").."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
    if #lines==0 then lines={""} end
  end
  local function snapshot()
    undo[#undo+1]={text=contents(),x=x,y=y}; if #undo>50 then table.remove(undo,1) end; redo={}
  end
  local function discard() return not dirty() or ui.confirm(api,"Discard unsaved changes?") end
  local function open(file)
    file=api.resolve(file)
    if fs.isDir(file) then api.notify("That is a folder."); return end
    local raw=""
    if fs.exists(file) then
      if fs.getSize(file)>131072 then api.notify("Editor limit is 128 KiB."); return end
      local err; raw,err=api.storage.read(file)
      if not raw then api.notify(err); return end
    end
    path=file; split(raw); saved=contents(); x,y,top,left=1,1,1,0; undo={}; redo={}
    if code then language=syntax.language(path) or language; popup=nil end
  end
  if path then open(path) end
  local function save(as)
    local target=path
    if not target or as then
      local extension=code and ({lua='lua',peanut='peanut',pistachio='pist',cashew='cashew'})[language] or 'txt'
      target=ui.filePicker(api,{mode='save',title='Save '..(code and 'source' or 'file'),path=target or api.resolve('untitled.'..extension)})
    end
    if not target or target=="" then return false end
    target=api.resolve(target)
    if target~=path and fs.exists(target) and not ui.confirm(api,"Replace "..fs.getName(target).."?") then return false end
    local ok,err=api.storage.write(target,contents())
    if ok then
      path=target; saved=contents(); if code then language=syntax.language(path) or language end
      api.notify(api.isEncrypted() and "Saved in encrypted drive." or "Saved in personal drive.")
    else api.notify(err) end
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
  local function acceptCompletion(index)
    local choice=popup and popup.items[index or popup.index]
    if choice then local suffix=choice:sub(#popup.prefix+1); popup=nil; insert(suffix) end
  end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); local gutter=w>24 and 5 or 0
    x=math.max(1,math.min(x,#lines[y]+1))
    if y<top then top=y elseif y>=top+h-2 then top=y-h+3 end
    if x<=left then left=x-1 elseif x>left+w-gutter then left=x-w+gutter end
    ui.clear(t)
    ui.bar(1," Save  Open  Find  Undo  Redo",t)
    local tokens=code and syntaxDocument().styles
    local mono=api.config().mode=='basic'
    local light=api.config().theme=='light'
    local tokenColors={k=light and colors.purple or colors.magenta,s=light and colors.green or colors.lime,
      n=light and colors.brown or colors.orange,c=colors.gray,b=light and colors.blue or colors.cyan,o=t.muted,t=t.text}
    for row=2,h-1 do
      local index=top+row-2
      if lines[index] then
        if gutter>0 then ui.text(1,row,string.format("%4d ",index),t.muted,t.panel,gutter) end
        if code then
          local text=lines[index]:sub(left+1,left+w-gutter); local fg,bg={},{}
          for n=1,#text do
            local kind=tokens[index]:sub(left+n,left+n)
            local inverse=mono and (kind=='k' or kind=='b')
            fg[n]=colors.toBlit(inverse and colors.black or mono and t.text or tokenColors[kind] or t.text)
            bg[n]=colors.toBlit(inverse and colors.white or t.bg)
          end
          term.setCursorPos(gutter+1,row); term.blit(text,table.concat(fg),table.concat(bg))
        else
          local fg=lines[index]:match("^%s*%-%-") and t.muted or t.text
          ui.text(gutter+1,row,lines[index]:sub(left+1),fg,t.bg,w-gutter)
        end
      end
    end
    ui.text(1,h,(dirty() and "* " or "  ")..(code and language.." " or "")..y..":"..x..(popup and " Tab accept / F5 hide" or code and " C-S save C-Space hints C-L lang" or "  Ctrl+S save"),t.text,t.panel,w)
    api.setTitle((code and "Code - " or "Editor - ")..(path and fs.getName(path) or "Untitled")..(dirty() and " *" or ""))
    if popup then
      local count=math.min(5,#popup.items,h-2); local width=1
      for _,item in ipairs(popup.items) do width=math.max(width,#item+2) end
      popup.w=math.min(w,width); popup.h=count
      popup.x=math.max(1,math.min(gutter+x-left,w-popup.w+1))
      local cy=2+y-top
      popup.y=cy+count<h and cy+1 or math.max(2,cy-count)
      popup.first=math.max(1,popup.index-count+1)
      for row=1,count do
        local index=popup.first+row-1
        ui.text(popup.x,popup.y+row-1,(index==popup.index and '> ' or '  ')..popup.items[index],
          index==popup.index and t.onAccent or t.text,index==popup.index and t.accent or t.panel,popup.w)
      end
    end
    term.setTextColor(t.text)
    term.setCursorPos(gutter+x-left,2+y-top); term.setCursorBlink(true)
  end
  local function history(from,to)
    local item=table.remove(from)
    if item then to[#to+1]={text=contents(),x=x,y=y}; split(item.text); x,y=item.x,item.y end
  end
  local function action(name)
    popup=nil
    if name=="save" then save(api.keyDown(keys.leftShift) or api.keyDown(keys.rightShift))
    elseif name=="open" then
      if discard() then
        local file=ui.filePicker(api,{mode='open',title='Open '..(code and 'source' or 'file'),path=path or api.dir()})
        if file then open(file) end
      end
    elseif name=="find" then find()
    elseif name=="undo" then history(undo,redo)
    elseif name=="redo" then history(redo,undo) end
  end
  while true do
    draw()
    local e,a,b,c=os.pullEventRaw()
    local ctrl=api.keyDown(keys.leftCtrl) or api.keyDown(keys.rightCtrl)
    if e=="sacabam_close" or e=="terminate" then if discard() then return end
    elseif e=="char" and not ctrl then insert(a); complete(false)
    elseif e=="paste" then popup=nil; insert(a)
    elseif e=="key" then
      if code and ctrl and a==keys.space then complete(true)
      elseif code and ctrl and a==keys.l then
        local order={'lua','peanut','pistachio','cashew'}
        for i,value in ipairs(order) do if value==language then language=order[i%#order+1]; break end end
        popup=nil
      elseif popup and not ctrl and (a==keys.up or a==keys.down or a==keys.tab or a==keys.enter or a==keys.f5) then
        if a==keys.up then popup.index=math.max(1,popup.index-1)
        elseif a==keys.down then popup.index=math.min(#popup.items,popup.index+1)
        elseif a==keys.f5 then popup=nil else acceptCompletion() end
      elseif ctrl then
        local actions={[keys.s]="save",[keys.o]="open",[keys.f]="find",[keys.z]="undo",[keys.y]="redo"}
        if actions[a] then action(actions[a])
        elseif a==keys.n and discard() then path=nil; lines={""}; saved=""; x,y,top,left=1,1,1,0; undo={}; redo={}; popup=nil end
      elseif a==keys.left then
        popup=nil
        if x>1 then x=x-1 elseif y>1 then y=y-1; x=#lines[y]+1 end
      elseif a==keys.right then
        popup=nil
        if x<=#lines[y] then x=x+1 elseif y<#lines then y=y+1; x=1 end
      elseif a==keys.up then popup=nil; y=math.max(1,y-1)
      elseif a==keys.down then popup=nil; y=math.min(#lines,y+1)
      elseif a==keys.home then popup=nil; x=1
      elseif a==keys["end"] then popup=nil; x=#lines[y]+1
      elseif a==keys.pageUp then popup=nil; local _,h=term.getSize(); y=math.max(1,y-h+2)
      elseif a==keys.pageDown then popup=nil; local _,h=term.getSize(); y=math.min(#lines,y+h-2)
      elseif a==keys.enter then
        local indent=code and lines[y]:match('^%s*') or ''
        insert("\n"..indent)
      elseif a==keys.tab then insert("  ")
      elseif a==keys.backspace then
        if x>1 then snapshot(); lines[y]=lines[y]:sub(1,x-2)..lines[y]:sub(x); x=x-1
        elseif y>1 then snapshot(); x=#lines[y-1]+1; lines[y-1]=lines[y-1]..lines[y]; table.remove(lines,y); y=y-1 end
        complete(false)
      elseif a==keys.delete then
        popup=nil
        if x<=#lines[y] then snapshot(); lines[y]=lines[y]:sub(1,x-1)..lines[y]:sub(x+1)
        elseif y<#lines then snapshot(); lines[y]=lines[y]..lines[y+1]; table.remove(lines,y+1) end
      end
    elseif e=="mouse_click" and a==1 then
      local w,h=term.getSize(); local gutter=w>24 and 5 or 0
      if popup and b>=popup.x and b<popup.x+popup.w and c>=popup.y and c<popup.y+popup.h then
        acceptCompletion(popup.first+c-popup.y)
      elseif c==1 then
        if b<=6 then action("save") elseif b<=12 then action("open") elseif b<=18 then action("find")
        elseif b<=24 then action("undo") else action("redo") end
      elseif c<h then popup=nil; y=math.max(1,math.min(#lines,top+c-2)); x=math.max(1,math.min(#lines[y]+1,b-gutter+left)) end
    elseif e=="mouse_scroll" then
      popup=nil
      local _,h=term.getSize(); top=math.max(1,math.min(math.max(1,#lines-h+3),top+a*3))
      y=math.max(top,math.min(y,top+h-3))
    end
  end
end
]]},
  ["apps/files.lua"]={sha256="15594edaf0a158de8d82395e55d61307e0f88de4a58a7602c4a839e3ea2765c8",data=[[
return function(api,start)
  local ui=api.ui; local dir=api.resolve(start or api.dir())
  local selection,scroll=1,0; local entries={}; local clip; local showHidden=false
  local trash='/'..fs.combine(api.home,".Trash")
  local function edit(path)
    local language=api.load('system/syntax').language(path)
    api.launch(language and 'code' or 'editor',path)
  end
  local function refresh()
    if not fs.isDir(dir) then dir='/'..api.home end
    api.setDir(dir)
    entries={}
    for _,name in ipairs(fs.list(dir)) do
      if showHidden or name:sub(1,1)~="." or dir==trash then
        local path=api.resolve(name,dir); local label=name
        if dir==trash then local meta=api.storage.load(fs.combine(path,"info.tbl"),{}); label=meta.original and fs.getName(meta.original) or name end
        entries[#entries+1]={name=name,label=label,path=path,folder=fs.isDir(path)}
      end
    end
    table.sort(entries,function(a,b) if a.folder~=b.folder then return a.folder end return a.label:lower()<b.label:lower() end)
    selection=math.max(1,math.min(selection,#entries))
  end
  local function selected() return entries[selection] end
  local function navigate(path)
    path=api.resolve(path)
    if fs.isDir(path) then dir=path; selection,scroll=1,0; refresh() else api.notify("Folder not found.") end
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
    else edit(item.path) end
  end
  local function new(folder)
    local name=ui.prompt(api,folder and "New folder name" or "New file name")
    if not name then return end
    if not api.storage.name(name) then api.notify("Use a name without slashes."); return end
    local path=api.resolve(name,dir)
    if fs.exists(path) then api.notify("That name already exists."); return end
    if folder then fs.makeDir(path) else local ok,err=api.storage.write(path,""); if not ok then error(err) end; edit(path) end
    refresh()
  end
  local function action(key)
    local item=selected()
    if key=="open" then open()
    elseif key=="up" then navigate('..')
    elseif key=="home" then navigate('/'..api.home)
    elseif key=="location" then local path=ui.filePicker(api,{mode='folder',title='Go to folder',path=dir}); if path then navigate(path) end
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
      elseif not fs.isReadOnly(item.path) and item.path~='/' and item.path~='/'..api.home and not api.storage.within(item.path,trash) then
        if not ui.confirm(api,"Move "..item.label.." to Trash?") then return end
        fs.makeDir(trash)
        local slot=api.storage.unique(trash,"item-"..tostring(math.floor(os.clock()*1000)))
        fs.makeDir(slot)
        assert(api.storage.save(fs.combine(slot,"info.tbl"),{original=item.path}))
        fs.move(item.path,fs.combine(slot,"content")); refresh()
      else api.notify("Only personal files can be moved to Trash.") end
    elseif key=="showtrash" then navigate(trash)
    elseif key=="run" and item and not item.folder then api.launch("terminal",item.path)
    elseif key=="edit" and item and not item.folder then edit(item.path)
    elseif key=="hidden" then showHidden=not showHidden; refresh() end
  end
  local toolbar={{"Up","up"},{"Home","home"},{"New","new"},{"Folder","folder"},{"Copy","copy"},{"Paste","paste"},{"Trash","showtrash"}}
  local hits={}
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.text(1,1,dir,t.onAccent,t.accent,w)
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
  ["apps/games.lua"]={sha256="adbfacb5e3411bf8f016b436aae91379d1824ac58a43b12a060c7246141ca6f2",data=[[
return function(api,id)
  local catalog=api.load('system/game_catalog'); local ui=api.ui
  if id then
    for _,entry in ipairs(catalog) do if entry.id==id or entry.legacyId==id then return api.load('system/game').run(api,entry) end end
    api.notify('Unknown game: '..tostring(id)); return
  end
  local selected,offset=1,0
  while true do
    local w,h=term.getSize(); local t=api.theme(); ui.clear(t)
    ui.bar(1,' Games / '..#catalog..' installed',t)
    local rows=math.max(1,h-5)
    if selected<=offset then offset=selected-1 elseif selected>offset+rows then offset=selected-rows end
    for row=1,rows do
      local i=row+offset; local entry=catalog[i]
      if entry then
        ui.text(1,row+1,(i==selected and '> ' or '  ')..entry.name..(entry.advanced and ' [A]' or ''),
          i==selected and t.onAccent or t.text,i==selected and t.accent or t.bg,w)
      end
    end
    local entry=catalog[selected]
    local label=entry.advanced and 'ADVANCED COMPUTER ONLY' or 'BASIC + ADVANCED'
    if w>=22 then
      ui.text(1,h-3,entry.detail,t.muted,t.bg,w); ui.text(1,h-2,label,entry.advanced and t.folder or t.muted,t.bg,w)
    else
      local lines=ui.wrap(label,w)
      ui.text(1,h-3,lines[1],t.text,t.bg,w); ui.text(1,h-2,lines[2] or '',t.text,t.bg,w)
    end
    ui.text(1,h-1,'Files: /Games',t.muted,t.bg,w)
    ui.text(1,h,'Enter play  Q close',t.text,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' or (e=='key' and (a==keys.q or a==keys.escape)) then return
    elseif e=='key' then
      if a==keys.up then selected=math.max(1,selected-1)
      elseif a==keys.down then selected=math.min(#catalog,selected+1)
      elseif a==keys.home then selected=1 elseif a==keys['end'] then selected=#catalog
      elseif a==keys.enter then api.launch('games',catalog[selected].id) end
    elseif e=='mouse_scroll' then selected=math.max(1,math.min(#catalog,selected+a))
    elseif e=='mouse_click' and a==1 and c>=2 and c<=rows+1 and catalog[offset+c-1] then
      local choice=offset+c-1
      if choice==selected then api.launch('games',catalog[choice].id) else selected=choice end
    end
  end
end
]]},
  ["apps/help.lua"]={sha256="fb339a3e3a7e2c7e6bbaa69189b404e44b73298ac6626ef570e93ce5b44f9d9d",data=[[
return function(api)
  local ui=api.ui; local scroll=0
  local content={
    "CCSacabam controls", "",
    "WINDOWS", "F1: app launcher (type to search)","F2: cycle running apps", "F3: minimize current window", "F4: close current window",
    "F6: maximize / restore", "F7: move window with arrow keys", "F8: resize window with arrow keys", "Enter finishes; F5 cancels move/resize.",
    "F9: lock (when encryption is on)", "F10: exit to CraftOS", "",
    "Advanced: drag title bars to move. Drag the bottom-right corner to resize. Click - / + / X to minimize, maximize or close.", "",
    "Right-click a desktop shortcut to open or remove it. Right-click empty desktop to restore shortcuts. Programs remain in Apps.", "Settings: Skip typing YES is OFF by default. Turn it on to confirm prompts with Enter or a click.", "",
    "FILES & PROGRAMS", "Double-click or Enter opens a file. Lua and Pistachio programs run in windows. E edits the selected file. N creates a file, D a folder. C/X/V copy, cut, paste. Delete moves to Trash; T opens Trash. Enter restores a trashed item.","",
    "GAMES", "Open Games from Apps, type games in Terminal, or open a launcher in /Games. Ten games are installed. Snake, Pong, Blocks, Mines, 2048, Lights Out, Sokoban and Memory support basic computers. Breakout and Vault Runner are marked ADVANCED COMPUTER ONLY. P pauses, H shows controls, R restarts, Q closes. F6 maximises a game that needs more room. Completed-game records follow the drive encryption setting.",
    "VAULT RUNNER", "A first-person 3D maze. Collect six golden crystals, then find the green exit. W/S or Up/Down move; A/D or Left/Right turn. Z/X strafe. M opens the map. White is you, yellow is a crystal, green is the exit.","",
    "EDITOR", "Ctrl+S save, Ctrl+Shift+S save as.","Ctrl+O open, Ctrl+N new, Ctrl+F find.","Ctrl+Z undo, Ctrl+Y redo.","",
    "FILE PICKERS", "Open and Save dialogs browse folders. Arrows select; Enter or double-click opens. Backspace goes up. Tab moves between controls; F5 cancels. Ctrl+L edits the location, Ctrl+N creates a folder, Ctrl+H shows hidden files, and Ctrl+F switches the file-type filter. Name fields accept relative paths. Callisto: File or Ctrl+O opens a local page.","",
    "CUSTOMISATION", "Settings has General and Customisation tabs; use Tab, Left/Right, or click their names. Select a colour role, press Enter, choose a swatch, and Apply. F5 cancels the choice. R resets the current theme. Dark, light, and basic themes keep separate colours. Basic computers display colours as shades of gray.","",
    "PERSONAL DRIVE", "Encryption starts OFF. Fine to leave off on a private computer. On a shared server, try encryption: it is CCSacabam's main security feature for saved files. With encryption off, there is no password or login screen. Files are readable outside the OS.",
    "Enable or disable encryption in Settings. When ON, names, content, temporary files and Trash are encrypted on disk. Normal filesystem paths in apps use this drive. /rom and the installed OS are read-only; /host shows existing physical files for importing.",
    "Save before locking or exiting. Unsaved app buffers are discarded. There is no password reset. Back up vault/data.scv while signed out. Enabling encryption does not erase older plaintext copies or backups.","",
    "PISTACHIO SCRIPT", "Open Pistachio from the launcher for a sample visual app. Examples are in Programs. Edit a .pist file with E in Files, then open it to run. Tab selects controls; Enter activates buttons. The same program works with monochrome and color displays.","",
    "TITAN GAME ENGINE", "Lua programs use require('titan') for 2D games: scenes, sprites and animations, tile maps with solid and one-way tiles, gravity and collisions, entity templates, camera follow, particles, timers, tweens, key bindings, mouse and monitor touch, speakers and saving. Advanced computers get full-colour 2x3 subpixel graphics by default. Basic computers only run games that opt in with basic=true and design a one-cell-per-pixel version. Try titan-demo in Terminal, and read its source in Programs. Titan also runs in plain CraftOS: copy /rom/modules/main/titan.lua next to your game.","",
    "DATA & ENCRYPTION", "Peanut is the data format: comments, objects, arrays, strings and numbers. Lua uses require('peanut'). Ganymede provides Lua UI controls. Pistachio seal(text, password) and unseal(data, password) protect individual messages even with drive encryption off. Try Programs/sealed-note.pist.","",
    "EUROPA NETWORK", "Callisto browses sites; Jupiter hosts them. Attach a modem, open Jupiter, choose a domain and press Enter to start. Visit europa://workshop.cc/ or europa://123/ in Callisto. Sites use index.cashew and can contain Pistachio events. The sample is in /Sites/welcome. Preview file:///Sites/welcome/index.cashew without a modem. Network traffic is public, not encrypted.","",
    "CHAT+", "Chat+ is pre-installed. Open it from the launcher or type chatplus in Terminal. It requires a modem for hosting or joining. Its network traffic follows Chat+'s own protocol; drive encryption protects local files only.","",
    "RECOVERY", "Run boot.lua --basic for a monochrome session. A failed app does not close other apps; open Tasks to inspect it. The system log follows the drive encryption setting and is in /.system/system.log.",
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
  ["apps/pistachio.lua"]={sha256="7ba0333d3bd45b20105c2135b2530ee11737ce37fb945380c6d6970142b8386f",data=[[
return function(api,path)
  local ui=api.ui
  path=api.resolve(path or '/'..fs.combine(api.home,'Programs/counter.pist'))
  local source,err=api.storage.read(path); assert(source,err)
  local lang=api.load('system/pistachio'); local peanut=api.load('system/peanut')
  local state=lang.runtime(lang.parse(source),api,peanut); state.initialize()
  local timers={}
  api.onExit(function() for id in pairs(timers) do os.cancelTimer(id) end end)
  for _,timer in ipairs(state.timers) do timers[os.startTimer(timer.interval)]=timer end
  local controls={}; local focus=1
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); local layout=state.layout()
    ui.clear({bg=state.background or t.bg,text=t.text}); controls={}
    api.setTitle(state.title)
    for _,v in ipairs(layout) do
      v.w=math.max(1,math.min(v.w,w)); local text=tostring(v.value or '')
      if v.kind=='text' then ui.text(v.x,v.y,text,v.fg,v.bg)
      elseif v.kind=='column' then
        if v.x>=1 and v.x<=w then
          for i=math.max(1,2-v.y),math.min(#text,h-v.y+1) do ui.text(v.x,v.y+i-1,text:sub(i,i),v.fg,v.bg) end
        end
      elseif v.kind=='panel' then
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
    if state.status~='' then ui.text(1,h,state.status or 'Tab: next  Enter: activate  F4: close',t.muted,t.panel,w) end
  end
  local function activate(control)
    if not control then return end
    if control.kind=='checkbox' then state.vars[control.bind]=not state.vars[control.bind] end
    if control.kind~='input' and control.kind~='password' then state.dispatch(control.id) end
  end
  while not state.quit do
    draw(); local e,a,b,c=os.pullEventRaw()
    local control=controls[focus]
    if e=='sacabam_close' or e=='terminate' then break
    elseif e=='timer' and timers[a] then
      local timer=timers[a]; timers[a]=nil; state.tick(timer); timers[os.startTimer(timer.interval)]=timer
    elseif e=='term_resize' then state.dispatch('resize')
    elseif e=='key' and state.handlers.key then
      state.vars.key=keys.getName(a) or ''; state.vars.held=b==true; state.dispatch('key')
    elseif e=='key' then
      if a==keys.tab then
        local backwards=api.keyDown(keys.leftShift) or api.keyDown(keys.rightShift)
        focus=((focus-1+(backwards and -1 or 1))%math.max(1,#controls))+1
      elseif a==keys.enter then activate(control)
      elseif a==keys.space and control and control.kind~='input' and control.kind~='password' then activate(control)
      elseif a==keys.backspace and control and (control.kind=='input' or control.kind=='password') then state.vars[control.bind]=tostring(state.vars[control.bind]):sub(1,-2); state.dispatch(control.id) end
    elseif e=='char' and state.handlers.char then state.vars.char=a; state.dispatch('char')
    elseif (e=='char' or e=='paste') and control and (control.kind=='input' or control.kind=='password') then
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
  ["apps/server.lua"]={sha256="4167a9a6bd1630060a0204751775ecd2e3e21eee58dc432dfb3f440bad066e9b",data=[[
return function(api,domain,root)
  local ui=api.ui; local E=api.load('system/europa'); local server
  domain=domain or 'computer-'..os.getComputerID()..'.cc'
  root=api.resolve(root or '/Sites/welcome'); local message='Offline. Choose a domain and site folder.'
  local function chooseFolder()
    local value=ui.filePicker(api,{mode='folder',title='Publish folder',path=root})
    if value then root=api.resolve(value) end
  end
  local function hasHome()
    local path=fs.combine(root,'index.cashew')
    return fs.exists(path) and not fs.isDir(path)
  end
  local function stop() if server then server.stop(); server=nil end end
  api.onExit(stop)
  local function start()
    if server then stop(); message='Server stopped.'; return end
    server=E.start(domain,root); message='Serving europa://'..domain..'/ and computer #'..os.getComputerID()
    if not hasHome() then message='Online; save index.cashew in this folder.' end
  end
  while true do
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); ui.bar(1,' Jupiter / Europa web server',t)
    ui.text(2,3,'Domain: '..domain,t.text,t.bg,w-2)
    ui.text(2,5,'Folder: '..root,t.text,t.bg,w-2)
    ui.text(2,7,server and '[ Stop server ]' or '[ Start server ]',t.onAccent,t.accent,18)
    ui.text(2,9,'Requests: '..(server and server.requests or 0),t.text,t.bg,w-2)
    local home=hasHome()
    ui.text(2,10,home and 'Home: index.cashew / ready' or 'Home: MISSING index.cashew',home and t.muted or t.danger,t.bg,w-2)
    ui.text(2,11,server and server.lastPath and (server.lastStatus..' '..server.lastPath) or 'No requests yet.',t.muted,t.bg,w-2)
    ui.text(1,h-1,message,t.text,t.panel,w)
    ui.text(1,h,'Enter start/stop | D domain | R folder',t.muted,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then stop(); return end
    local ok,err=pcall(function()
      if e=='rednet_message' and server then server.receive(a,b,c)
      elseif e=='key' and a==keys.enter then start()
      elseif e=='char' then
        if a=='d' and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif a=='r' and not server then chooseFolder() end
      elseif e=='mouse_click' then
        if c==3 and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif c==5 and not server then chooseFolder()
        elseif c==7 then start() end
      end
    end)
    if not ok then message=tostring(err); api.notify(err) end
  end
end
]]},
  ["apps/settings.lua"]={sha256="a49f61e46ce3d02bc43728275fe3c9b591a0d331b8a0ce1b983d05587b35dc13",data=[[
return function(api)
  local ui=api.ui; local selected=1; local offset=0
  local tab='general'; local custom=api.load('apps/customisation')(api)
  local function options()
    local c=api.config()
    return {"Display: "..c.mode,"Theme: "..c.theme,"Wallpaper: "..tostring(c.wallpaper),
      "Welcome guide: "..tostring(c.welcome),api.isEncrypted() and "Lock personal drive" or "Lock: no password set",
      api.isEncrypted() and "Change passphrase" or "Password: not needed",
      "Encryption: "..(api.isEncrypted() and "ON" or "OFF"),
      "Skip typing YES: "..(c.skipTypedConfirmation and "ON" or "OFF"),
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
    elseif n==5 then
      if api.isEncrypted() then api.requestExit("lock") else api.notify("Encryption is off. No password or lock is needed.") end
    elseif n==6 then
      if not api.isEncrypted() then api.notify("Enable encryption to set a password."); return end
      local password,entropy=api.password("New passphrase",{"At least 12 characters. No password reset."})
      if password then
        local again=api.password("Confirm new passphrase")
        if again~=password then api.notify("Passphrases did not match.")
        else local ok,err=api.changePassword(password,entropy); api.notify(ok and "Passphrase changed." or err) end
      end
    elseif n==7 then
      local enabled=not api.isEncrypted()
      local prompt=enabled and "Encrypt? Old backups stay plain."
        or "Decrypt? Files become readable."
      if ui.confirm(api,prompt) then
        local password,entropy
        if enabled then
          password,entropy=api.password("Create encryption password",{"Use at least 12 characters. Keep it safe."})
          if not password then return end
          local again=api.password("Confirm encryption password")
          if again~=password then api.notify("Passwords did not match."); return end
        end
        local ok,err=api.setEncryption(enabled,password,entropy)
        api.notify(ok and (enabled and "Encryption enabled." or "Encryption disabled.") or err)
      end
    elseif n==8 then c.skipTypedConfirmation=not c.skipTypedConfirmation
    elseif n==9 then api.requestExit("exit") elseif n==10 then api.requestExit("reboot") elseif n==11 then api.requestExit("shutdown") end
    if n<=4 or n==8 then api.saveConfig() end
  end
  while true do
    local t=tab=='custom' and api.load('system/config').theme({mode='basic'}) or api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.bar(1," Settings",t)
    if w>=27 then
      ui.text(1,2,' General ',tab=='general' and t.onAccent or t.text,tab=='general' and t.accent or t.panel,10)
      ui.text(11,2,' Customisation ',tab=='custom' and t.onAccent or t.text,tab=='custom' and t.accent or t.panel,w-10)
    else ui.text(1,2,tab=='general' and '< General >' or '< Customisation >',t.onAccent,t.accent,w) end
    local items=options(); local rows=math.max(1,h-4)
    if tab=='custom' then custom.draw() else
    if selected<=offset then offset=selected-1 elseif selected>offset+rows then offset=selected-rows end
    for row=1,rows do local i=row+offset
      if items[i] then ui.text(1,row+2,(selected==i and "> " or "  ")..i.." "..items[i],selected==i and t.onAccent or t.text,selected==i and t.accent or t.bg,w) end
    end
    ui.text(1,h-1,api.isEncrypted() and "Saved files are encrypted." or "Private PC? Off is fine. Shared server? Try ON.",t.muted,t.bg,w)
    ui.text(1,h,"Tab: tabs | Enter / number",t.text,t.panel,w)
    end
    local e,a,b,c=os.pullEventRaw()
    if e=="sacabam_close" or e=="terminate" then return
    elseif not custom.editing and e=='key' and (a==keys.tab or a==keys.left or a==keys.right) then
      tab=a==keys.left and 'general' or a==keys.right and 'custom' or tab=='general' and 'custom' or 'general'
    elseif not custom.editing and e=='mouse_click' and a==1 and c==2 then
      if w>=27 then tab=b<=10 and 'general' or 'custom' else tab=tab=='general' and 'custom' or 'general' end
    elseif tab=='custom' then custom.event(e,a,b,c)
    elseif e=="key" then
      if a==keys.up then selected=math.max(1,selected-1) elseif a==keys.down then selected=math.min(#items,selected+1)
      elseif a==keys.enter then choose(selected) end
    elseif e=="char" and tonumber(a) and tonumber(a)>=1 and tonumber(a)<=#items then selected=tonumber(a); choose(selected)
    elseif e=="mouse_click" and a==1 and c>2 and c<=rows+2 and items[offset+c-2] then selected=offset+c-2; choose(selected)
    elseif e=="mouse_scroll" then selected=math.max(1,math.min(#items,selected+a)) end
  end
end
]]},
  ["apps/sketch.lua"]={sha256="4f6462f78cb8d9c4db0fe0354a37064fc7bf1816efad00ce54b8d1d563029110",data=[=[
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
    file=api.resolve(file)
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
    local file=ui.filePicker(api,{mode='save',title='Save sketch',path=path or api.resolve('untitled.sketch'),extensions={'sketch'}})
    if not file then return end
    file=api.resolve(file)
    if file~=path and fs.exists(file) and not ui.confirm(api,'Replace existing sketch?') then return end
    local ok,err=api.load('system/peanut').write(file,serialize())
    if ok then path=file; dirty=false; api.notify(api.isEncrypted() and 'Sketch saved in encrypted drive.' or 'Sketch saved in personal drive.') else api.notify(err) end
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
    elseif cmd=='o' and discard() then
      local file=ui.filePicker(api,{mode='open',title='Open sketch',path=path or api.dir(),extensions={'sketch'}})
      if file then open(file) end
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
  ["apps/terminal.lua"]={sha256="03ba59170d37c35911f6a758e375fc021bee56eee1fb5215228f96e92d58d252",data=[[
return function(api,program)
  local parent={}; for k,v in pairs(api.shell) do parent[k]=v end
  parent.dir=function() return fs.combine('',api.dir()) end
  parent.path=function() return ".:/"..fs.combine(api.home,"Programs")..":"..api.shell.path() end
  local t=api.theme(); term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorPos(1,1)
  print("CCSacabam / "..(api.isEncrypted() and "encrypted" or "personal").." terminal")
  print("Save files in /"..api.home)
  print("F1 apps | F2 switch | F4 close")
  local function shellTask()
    if program then
      local absolute=api.resolve(program)
      os.run({shell=parent,multishell=false},"/rom/programs/shell.lua",'"'..absolute..'"')
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
  ["boot.lua"]={sha256="a48ced6783e82a3c91d834531746e0239b13bf06eaba1f1cabe44b4a6364f787",data=[[
-- Entry point: login, encrypted personal drive, then the desktop session.
local args={...}
local root=fs.getDir(shell.getRunningProgram())
local original=term.current()
local originalDir=shell.dir()
local physicalEnv=_ENV
local activeVault
local function main()
  local function physicalModule(name) return assert(loadfile(fs.combine(root,name..".lua"),"t",physicalEnv))() end
  assert(window and window.create and term.blit and bit32 and fs.exists('/rom/modules/main/cc/require.lua'),"CCSacabam needs modern CC: Tweaked with blit, window, bit32 and cc.require.")
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
  local defaults=storage.load(fs.combine(root,"config/display.tbl"),{})
  while login.unlock(vault,defaults) do
    local function desktop()
      local env=session.environment(vault.filesystem(fs.combine(root,"home")),physicalEnv)
      local cache={}
      local function module(name)
        if not cache[name] then cache[name]=assert(env.loadfile(fs.combine(root,name..".lua")))() end
        return cache[name]
      end
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
      module('system/programs').update(root,module('system/storage'),module('system/crypto'))
      local ctx={root=root,load=module,config=config,configModule=configModule,caps=caps,target=original,shell=shell,
        password=login.password,isEncrypted=vault.isEncrypted,
        setEncryption=function(enabled,password,entropy) return vault.setEncryption(enabled,password,entropy,login.progress) end,
        cryptoProgress=login.progress,
        changePassword=function(password,entropy) return vault.changePassword(password,entropy,login.progress) end}
      local kernel=module("system/kernel").new(ctx)
      env.ccsacabam={launch=kernel.launch,forShell=kernel.forShell,version=configModule.version}
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
  print("The personal drive is closed.")
  print("Try: "..fs.combine(root,"boot.lua").." --basic")
  return false
end
print("CCSacabam closed. Personal drive signed out.")
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
  ["examples/games.lua"]={sha256="b9d258b0a850187b25d8be3896803c77189c68aa6c27ef1a014709cb0637a7ae",data=[[
assert(ccsacabam,'Run games inside CCSacabam').launch('games',...)
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
  ["examples/pistachio.lua"]={sha256="92e87c7f222b57e2c9d527c4f90ba7694d08f249a9f5b8f054e21a8cfc7f9912",data=[[
local path = ...
if not path then print('Usage: pistachio <file.pist>'); return end
assert(ccsacabam,'Run this command inside CCSacabam').launch('pistachio',path)
]]},
  ["examples/pmatrix.lua"]={sha256="694d88ca57291da96db3fafcca5045c0b14e0f3cebdc419b3e26026d2c814a89",data=[[
-- The animation lives in pmatrix.pist; this is just the shell entry point.
local option=...
if option then
  if option~='--help' and option~='-h' then printError('Unknown option: '..option) end
  print('pmatrix - Matrix rain in Pistachio Script')
  print('Space pause | Up/Down speed | 1-9 speed')
  print('C colour | H help | Q/Esc quit | F6 maximise')
  return
end
local source=fs.combine(fs.getDir(shell.getRunningProgram()),'pmatrix.pist')
assert(ccsacabam,'Run pmatrix inside CCSacabam').launch('pistachio','/'..source)
]]},
  ["examples/pmatrix.pist"]={sha256="8adc381bc66521482242491fdde279134da385e16306d3d1e68fb5d276e3953c",data=[[
# pmatrix: a cmatrix-inspired rain demo, implemented entirely in Pistachio.
# The .lua command only opens this file. Edit this source in Code Editor.
app "pmatrix"
let heads = array(80, 0)
let tails = array(80, 0)
let rates = array(80, 0)
let streams = array(80, "")
let palette = peanut("[\"lime\",\"cyan\",\"red\",\"magenta\",\"yellow\",\"white\"]")
let shadows = peanut("[\"green\",\"blue\",\"brown\",\"purple\",\"orange\",\"gray\"]")
let glyphs = "01:7Z*+4/9<>B2X=6@A%5&!30;8?V|1S-4C7D90+K2N:5R6T8W3Y"
let speed = 4
let tint = 1
let paused = false
let help = false

function seed
  set columns = min(80, floor((width + 1) / 2))
  repeat columns
    set heads[index] = random(-height, height)
    set tails[index] = random(6, max(7, min(24, height)))
    set rates[index] = random(1, 3)
    set start = random(1, len(glyphs) - tails[index])
    set streams[index] = slice(glyphs, start, start + tails[index] - 1)
  end
end
call seed

every 0.1
  if not paused
    repeat columns
      set heads[index] = heads[index] + speed * rates[index] / 6
      set pick = random(1, len(glyphs))
      set streams[index] = slice(streams[index], 2) .. slice(glyphs, pick, pick)
      if heads[index] - tails[index] > height
        set heads[index] = -random(1, max(2, height))
        set rates[index] = random(1, 3)
      end
    end
  end
end

on resize
  call seed
end
on key
  if key == "q" or key == "escape"
    quit
  end
  if key == "space" and not held
    set paused = not paused
  end
  if key == "up" or key == "equals" or key == "numPadAdd"
    set speed = min(9, speed + 1)
  end
  if key == "down" or key == "minus" or key == "numPadSubtract"
    set speed = max(1, speed - 1)
  end
  if key == "c" and not held
    set tint = tint % len(palette) + 1
  end
  if key == "h" and not held
    set help = not help
  end
end
on char
  if num(char) >= 1 and num(char) <= 9
    set speed = num(char)
  end
end

background "black"
status ""
frame
  set bright = color and palette[tint] or "lightGray"
  set dim = color and shadows[tint] or "gray"
  repeat columns
    set x = index * 2 - 1
    set y = floor(heads[index])
    set tail = tails[index]
    column x (y-tail+1) dim "black" slice(streams[index], 1, tail - 4)
    column x (y-3) bright "black" slice(streams[index], tail - 3, tail - 1)
    text x y "white" "black" slice(streams[index], tail, tail)
  end
  if paused
    text 1 1 "black" "white" " PAUSED | Space resumes "
  end
  if help
    text 1 (height-2) "white" "black" "Space pause  Up/Down speed"
    text 1 (height-1) "white" "black" "C colour  H help  Q quit"
    text 1 height "white" "black" "Speed {speed}/9 | Pistachio"
  end
end
]]},
  ["examples/sealed-note.pist"]={sha256="8974158b3668272dcb76e12fc7f10b52ed12175adfe7a8dfd61f73bbdceca4ca",data=[[
# Only the encrypted envelope is saved, even if drive encryption is OFF.
# Keep the passphrase yourself; it is never saved by this example.
app "Pistachio / Sealed note"
let message = ""
let passphrase = ""
let status = "Enter a note and a 12+ character passphrase."
label caption 2 2 (width-2) "Note:"
input messagebox 2 3 (width-2) message
label passwordcaption 2 4 (width-2) "Passphrase (12+ characters):"
password passwordbox 2 5 (width-2) passphrase
button encrypt 2 7 15 "Seal & save"
button decrypt 19 7 15 "Open note"
label result 2 9 (width-2) status
on encrypt
  if len(passphrase) >= 12
    set envelope = seal(message, passphrase)
    save envelope "/Documents/sealed-note.peanut"
    set message = ""
    set passphrase = ""
    set status = "Encrypted note saved. Passphrase cleared."
  else
    set status = "Use at least 12 characters."
  end
end
on decrypt
  if len(passphrase) >= 12
    load envelope "/Documents/sealed-note.peanut"
    set message = unseal(envelope, passphrase)
    set passphrase = ""
    set status = "Note decrypted into this window only."
  else
    set status = "Enter your note's passphrase first."
  end
end
]]},
  ["examples/titan-demo.lua"]={sha256="3516a1370d6bfdbc5e3b2b0f37acbdab9d877aa4396ee92915d5fc9d832e977b",data=[[
-- Moonhop: a Titan engine demo. A scrolling platformer in about 120 lines.
-- Arrows/WASD move, Space/Up jumps, R restarts, Q quits. Works on basic and
-- advanced computers, in CCSacabam windows, plain CraftOS and monitors.
local titan = require('titan')
-- basic=true: this game also ships a hand-designed basic-computer version
-- (the 'not px' glyphs below). Leave it out to make a game advanced-only.
local game = titan.new{title='Moonhop', fps=20, minCols=20, minRows=8, basic=true}
local px = game.mode == 'pixel'
local T = px and 3 or 1 -- tile size in pixels: 3x3 subpixels, or one cell

local levels = {
{ "                                                            ",
  "                                                            ",
  "                                              C C           ",
  "                    C C C                   =====           ",
  "                   =======        C                     F   ",
  "           C                   #######         E     ######",
  "         =====       E                    ##########  ######",
  "  @          #########       C          ###########   ######",
  "#######     ##########     #####    ^^  ###########  #######",
  "#######^^^^^##########^^^^^#####^^^^##################^#######",
  "############################################################",
},
{ "                                                            ",
  "                                C                           ",
  "                C             =====          C C C        F ",
  "             =======                   E   =======      ####",
  "        C                  E        ######             #####",
  "  @   =====     #####    #####                ===     ######",
  "####           #######  #######  ^^^       E        ########",
  "####^^^^^^^^^^^#######^^#######^^#####^^#########^^#########",
  "############################################################",
},
}

local legend = {
  ['#'] = {solid=true, color=colors.gray, char=not px and '#' or nil, fg=colors.lightGray},
  ['='] = {oneway=true, color=colors.brown, char=not px and '=' or nil, fg=colors.orange},
  ['^'] = {spike=true, color=px and nil or colors.black, char=not px and '^' or nil, fg=colors.red,
           sprite=px and titan.image({' e ', 'eee', 'eee'}) or nil},
  ['@'] = {spawn='player'}, ['C'] = {spawn='coin'}, ['E'] = {spawn='crawler'}, ['F'] = {spawn='flag'},
}

game.sprite('hero1', px and {' 4 ', '444', '1 1'} or {'4'})
game.sprite('hero2', px and {' 4 ', '444', ' 1 '} or {'4'})
game.animation('walk', {'hero1', 'hero2'}, 8)
game.sprite('coin', px and {' 4 ', '4 4', ' 4 '} or {'4'})
game.sprite('crawl1', px and {'eee', 'e0e', 'e e'} or {'e'})
game.sprite('crawl2', px and {'eee', 'e0e', ' e '} or {'e'})
game.animation('crawl', {'crawl1', 'crawl2'}, 5)
game.sprite('flag', px and {'5d ', '5dd', '5  '} or {'5'})

local state = {score=0, level=1, best=game.load('/.system/moonhop.tbl', {best=0}).best}

game.define('player', {sprite='hero1', gravity=40*T, maxFall=20*T, z=2, char=not px and '@' or nil,
  update=function(e, dt, g)
    local speed = 9*T
    if g.down('left') then e.vx = -speed; e.flip = true
    elseif g.down('right') then e.vx = speed; e.flip = false
    else e.vx = 0 end
    if g.pressed('jump') and e.onGround then e.vy = -14*T; g.sound('bit', 1, 18) end
    e.play(e.vx ~= 0 and 'walk' or 'hero1')
    local tx, ty = g.tiles.toTile(e.x + e.w/2, e.y + e.h - .1)
    local under = g.tiles.info(tx, ty)
    if under and under.spike then g.go('over', 'Spiked!') end
  end,
  fell=function(e, g) g.go('over', 'Fell off the moon.') end,
  touch=function(e, o, g)
    if o.is('coin') then
      o.destroy(); state.score = state.score + 10
      g.burst(o.x + 1, o.y + 1, {color=colors.yellow, count=6, speed=6*T, life=.4}); g.sound('chime', 1, 20)
    elseif o.is('crawler') then
      if e.vy > 0 and e.y + e.h - o.y < T then
        o.destroy(); e.vy = -10*T; state.score = state.score + 25
        g.burst(o.x + 1, o.y + 1, {color={colors.red, colors.orange}, count=10, speed=8*T}); g.shake(1, .2)
      else g.go('over', 'A crawler got you.') end
    elseif o.is('flag') then
      if state.level < #levels then state.level = state.level + 1; g.go('play')
      else g.go('over', 'You cleared every level!', true) end
    end
  end})
game.define('coin', {sprite='coin', char=not px and '*' or nil, fg=colors.yellow})
game.define('crawler', {sprite='crawl', gravity=40*T, vx=-3*T, z=1, char=not px and 'x' or nil, fg=colors.red,
  hitWall=function(e) e.vx = e.flip and -3*T or 3*T; e.flip = not e.flip end,
  update=function(e, dt, g)
    -- Turn round at ledges instead of walking off them.
    local ahead = e.vx > 0 and e.x + e.w + .5 or e.x - .5
    if e.onGround and not g.solidAt(ahead, e.y + e.h + .5) then e.vx = -e.vx; e.flip = not e.flip end
  end})
game.define('flag', {sprite='flag', char=not px and 'F' or nil, fg=colors.lime})

local function hud(g)
  g.write(1, 1, ' Moonhop  L' .. state.level .. '  ' .. state.score .. '  Best ' .. state.best .. string.rep(' ', g.cols),
    colors.black, colors.lightGray)
end

game.scene('play', {
  enter=function(g)
    -- Advanced: repaint blue as a deep night sky. Basic keeps plain black.
    if px and g.palette(colors.blue, 0x0c1030) then g.background = colors.blue else g.background = colors.black end
    g.map{tile=T, rows=levels[state.level], legend=legend}
    g.follow(g.first('player'))
    -- A few drifting stars, drawn behind everything.
    g.stars = {}
    for i = 1, px and 30 or 0 do g.stars[i] = {x=math.random(0, 400), y=math.random(0, 60)} end
  end,
  background=function(g)
    for _, s in ipairs(g.stars or {}) do g.screen.pixel((s.x - g.camera.x/4) % g.width, s.y % g.height, colors.gray) end
  end,
  update=function(g) if g.pressed('r') then state.score = 0; state.level = 1; g.go('play') end
    if g.pressed('q') then g.quit() end end,
  draw=hud,
})

game.scene('over', {
  enter=function(g, why, won)
    if state.score > state.best then state.best = state.score; g.save('/.system/moonhop.tbl', {best=state.best}) end
    g.message, g.won = why, won
  end,
  update=function(g)
    if g.pressed('r') or g.pressed('action') then state.score = 0; state.level = 1; g.go('play') end
    if g.pressed('q') then g.quit() end
  end,
  draw=function(g)
    hud(g)
    local mid = math.floor(g.rows/2)
    g.center(mid - 1, g.won and 'YOU WIN' or 'GAME OVER', g.won and colors.lime or colors.red)
    g.center(mid, g.message or '', colors.white)
    g.center(mid + 2, 'R / Enter: again   Q: quit', colors.lightGray)
  end,
})

game.run('play')
]]},
  ["games/README.txt"]={sha256="c6fb798b2f9bf0cc7ec6ab7e70ec7cdab9bb193fff1dfbccf025a08c7b4355ef",data=[[
CCSacabam Games

Open a .lua file to play, or run games in Terminal.
P pauses, H explains controls, R restarts, Q quits.
F6 maximises the game window.

Snake - BASIC + ADVANCED
Pong - BASIC + ADVANCED
Blocks - BASIC + ADVANCED
Mines - BASIC + ADVANCED
2048 - BASIC + ADVANCED
Lights Out - BASIC + ADVANCED
Sokoban - BASIC + ADVANCED
Memory - BASIC + ADVANCED
Breakout - ADVANCED COMPUTER ONLY
Vault Runner - ADVANCED COMPUTER ONLY

Vault Runner: collect six golden crystals in a 3D maze,
then find the green exit. W/S move, A/D turn, M map.
]]},
  ["games/blocks.lua"]={sha256="0c08343de2029c427486f1964180c9b3c86e2e21b32901c05503d1607ee0c214",data=[[
-- Blocks / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','blocks')
]]},
  ["games/breakout.lua"]={sha256="500612ae5743170459fb67efac1a533e8c3947747a1ef58eaae74534f7ff92af",data=[[
-- Breakout / ADVANCED COMPUTER ONLY
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','breakout')
]]},
  ["games/lights.lua"]={sha256="9313c1badee88f532f65014f79583511a0335392ec622617d33d402b0feb4219",data=[[
-- Lights Out / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','lights')
]]},
  ["games/memory.lua"]={sha256="1b4c7085ee07cc51888f5011297dfbefbdbf44abad7e239e8b160488a8d1a1a4",data=[[
-- Memory / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','memory')
]]},
  ["games/merge.lua"]={sha256="9bdbe414db5e1a23ed49dcba73840e9b1912398e1370f2dfaf66a8f32cb178a1",data=[[
-- 2048 / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','merge')
]]},
  ["games/mines.lua"]={sha256="f846a06eef9edfe897d47526a5ea0a6c2dbc3eb5ee99e35be34bfdb8154aba61",data=[[
-- Mines / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','mines')
]]},
  ["games/pong.lua"]={sha256="6e570efab7f4873fdd1f837bf12c281805a3b5a20329d2fb0bbd0bf9b2ad13e1",data=[[
-- Pong / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','pong')
]]},
  ["games/snake.lua"]={sha256="a0d7b8c8087cfc5a13ca52b16b82078337d2d3978b5415bc70912309e0d56b9b",data=[[
-- Snake / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','snake')
]]},
  ["games/sokoban.lua"]={sha256="cc274bd62af8ee56dae80591471c9ea40c6221cc522b39b074e65dadc219d067",data=[[
-- Sokoban / BASIC + ADVANCED
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','sokoban')
]]},
  ["games/vaultrunner.lua"]={sha256="84471b410de4c6712f7ea3cff3064f65c24fa16e156aef940e2fc460d5cccb45",data=[[
-- Vault Runner / ADVANCED COMPUTER ONLY
assert(ccsacabam,'Run this game inside CCSacabam').launch('games','vaultrunner')
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
  ["system/cashew.lua"]={sha256="e62da7ab6081e1216c45073a0d931092576a8929df693d57d8abeb3027d20722",data=[[
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
  local parts={}; local size=0
  local function walk(n)
    if n.tag=='text' then parts[#parts+1]=n.text else for _,child in ipairs(n.children or {}) do walk(child) end end
  end
  walk(node)
  return (table.concat(parts):gsub('{([%a_][%w_]*)}',function(key)
    local value=variables and variables[key]; local part=value==nil and '{'..key..'}' or tostring(value)
    size=size+#part; assert(size<=131072,'Rendered text exceeds 128 KiB'); return part
  end))
end
function C.safeScript(ast)
  local functions={str=true,num=true,len=true,min=true,max=true,abs=true,floor=true,round=true,
    peanut=true,encode=true,upper=true,lower=true,array=true,random=true,slice=true}
  local function expression(node)
    if type(node)~='table' then return end
    if node.tag=='call' then assert(functions[node.name],'Web pages cannot call '..node.name) end
    for _,value in pairs(node) do if type(value)=='table' then expression(value) end end
  end
  local safe={let=true,set=true,on=true,['function']=true,['if']=true,['repeat']=true,every=true,notify=true,call=true,quit=true,app=true,
    label=true,button=true,input=true,checkbox=true,progress=true,banner=true,panel=true}
  for _,node in ipairs(ast) do
    assert(safe[node.op],'Web pages cannot use '..node.op)
    for _,name in ipairs({'target','value','x','y','width','height','fg','bg'}) do expression(node[name]) end
    if node.body then C.safeScript(node.body) end
    if node.other then C.safeScript(node.other) end
  end
  return true
end
return C
]]},
  ["system/config.lua"]={sha256="390a93f8d69e6ca59fdd69d14cee7253f2a8232157fa9eb526ce009ade1dfd93",data=[=[
local M = {}
M.version = "1.0.0"
M.colorFields={
  {'desktop','Desktop background'},{'desktopText','Desktop labels'},
  {'wallpaperFar','Wallpaper back'},{'wallpaperNear','Wallpaper front'},
  {'bar','Desktop bars'},{'barText','Desktop bar text'},
  {'bg','Window background'},{'panel','Panels / toolbars'},{'text','Text'},
  {'muted','Secondary text'},{'accent','Selection / accents'},{'onAccent','Selected text'},
  {'border','Dividers'},{'danger','Errors'},{'folder','Folder names'},
  {'frame','Active window border'},{'frameText','Active border text'},
  {'inactiveFrame','Inactive border'},{'inactiveFrameText','Inactive border text'},
  {'title','Active title bar'},{'titleText','Active title text'},
  {'inactiveTitle','Inactive title bar'},{'inactiveTitleText','Inactive title text'},
  {'minimize','Minimise button'},{'maximize','Maximise button'},{'close','Close button'},
  {'controlText','Min/max symbols'},{'closeText','Close symbol'},
  {'resize','Active resize grip'},{'resizeInactive','Inactive resize grip'},{'resizeText','Resize symbol'},
}
M.colorNames={'White','Orange','Magenta','Light blue','Yellow','Lime','Pink','Gray','Light gray','Cyan','Purple','Blue','Brown','Green','Red','Black'}
M.wallpaperPatterns={'mountains','dots','grid','diagonal','checker','waves','stars','circuit'}
function M.profile(c) return c.mode=='basic' and 'basic' or c.theme=='light' and 'light' or 'dark' end
local function validColor(value)
  if type(value)~='number' then return false end
  for i=0,15 do if value==2^i then return true end end
  return false
end
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
  elseif mode ~= "basic" and mode ~= "color" and mode ~= "render" then mode = "render" end
  if mode == "render" and not caps.blit then mode = "color" end
  local hidden={}
  if type(c.hiddenShortcuts)=="table" then
    for id,value in pairs(c.hiddenShortcuts) do if type(id)=="string" and value==true then hidden[id]=true end end
  end
  local custom={}
  for _,profile in ipairs({'dark','light','basic'}) do
    custom[profile]={}
    local source=type(c.customColors)=='table' and c.customColors[profile]
    if type(source)=='table' then
      for _,field in ipairs(M.colorFields) do if validColor(source[field[1]]) then custom[profile][field[1]]=source[field[1]] end end
    end
  end
  local pattern=mode=='basic' and 'dots' or 'mountains'
  for _,name in ipairs(M.wallpaperPatterns) do if c.wallpaperPattern==name then pattern=name end end
  return { mode = mode, theme = c.theme == "light" and "light" or "dark",
    wallpaper = c.wallpaper ~= false, wallpaperPattern=pattern, clock24 = c.clock24 ~= false,
    welcome = c.welcome ~= false, version = M.version, hiddenShortcuts=hidden,
    skipTypedConfirmation = c.skipTypedConfirmation == true,customColors=custom }
end
local function defaults(config)
  if config.mode == "basic" then
    return { bg = colors.black, panel = colors.black, text = colors.white,
      muted = colors.white, accent = colors.white, onAccent = colors.black,
      border = colors.white, desktop = colors.black, danger = colors.white,
      frame=colors.black,frameText=colors.white,inactiveFrame=colors.black,inactiveFrameText=colors.white }
  end
  if config.theme == "light" then
    return { bg = colors.white, panel = colors.lightGray, text = colors.black,
      muted = colors.gray, accent = colors.blue, onAccent = colors.white,
      border = colors.gray, desktop = colors.cyan, danger = colors.red,
      frame=colors.gray,frameText=colors.white,inactiveFrame=colors.lightGray,inactiveFrameText=colors.black }
  end
  return { bg = colors.black, panel = colors.gray, text = colors.white,
    muted = colors.lightGray, accent = colors.cyan, onAccent = colors.black,
    border = colors.gray, desktop = colors.blue, danger = colors.red,
    frame=colors.lightGray,frameText=colors.black,inactiveFrame=colors.gray,inactiveFrameText=colors.white }
end
function M.theme(config)
  local t=defaults(config); local mono=config.mode=='basic'
  t.desktopText=t.text; t.wallpaperFar=mono and t.muted or colors.cyan; t.wallpaperNear=mono and colors.gray or colors.black
  t.bar=mono and t.bg or t.accent; t.barText=mono and t.text or t.onAccent
  t.folder=mono and t.text or colors.yellow
  t.title=mono and t.accent or t.frame; t.titleText=mono and t.onAccent or t.frameText
  t.inactiveTitle,t.inactiveTitleText=t.inactiveFrame,t.inactiveFrameText
  t.minimize=mono and t.title or colors.yellow; t.maximize=mono and t.title or colors.lime; t.close=mono and t.title or colors.red
  t.controlText=mono and t.titleText or colors.black; t.closeText=mono and t.titleText or colors.white
  t.resize=mono and t.bg or colors.gray; t.resizeInactive=mono and t.bg or colors.black; t.resizeText=colors.white
  local custom=config.customColors and config.customColors[M.profile(config)] or {}
  for _,field in ipairs(M.colorFields) do if validColor(custom[field[1]]) then t[field[1]]=custom[field[1]] end end
  return t
end
return M
]=]},
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
  ["system/europa.lua"]={sha256="dbba63b79d6be2626ceaa2e14aed61c4dfb081e650284845b0efaeddc60fed7b",data=[[
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
  if parsed.localFile then
    local path=link:sub(1,1)=='/' and fs.combine('',link) or fs.combine(fs.getDir(parsed.localFile),link)
    return 'file:///'..path
  end
  return 'europa://'..parsed.host..(link:sub(1,1)=='/' and link or '/'..fs.combine(fs.getDir(parsed.path),link))
end
function E.serve(root,path)
  local ok,normalized=pcall(E.path,path)
  if not ok then return {status=400,body='Invalid page path.',mime='text/plain'} end
  local file=fs.combine(root,normalized:sub(2))
  if not fs.exists(file) or fs.isDir(file) then
    return {status=404,body='Page not found: '..normalized..'\nThe host has no file at this path in its published folder.',mime='text/plain'}
  end
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
    host.lastPath=packet.path:gsub('[%c]','?'); host.lastStatus=reply.status
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
  ["system/filepicker.lua"]={sha256="4007dc82096eece72f03b3fb02635367761883b81a6ff1b206fdbd336c16b0bc",data=[[
-- Shared, window-sized file/folder selection. All paths use the personal fs.
local M={}
function M.choose(api,options)
  local o=options or {}; local ui=api.ui; local mode=o.mode or 'open'
  assert(mode=='open' or mode=='save' or mode=='folder','Invalid picker mode')
  local dir=api.resolve(o.path or api.dir()); local name=''
  if not fs.isDir(dir) then name=fs.getName(dir); dir='/'..fs.getDir(dir) end
  while not fs.isDir(dir) and dir~='/' do dir=api.resolve('..',dir) end
  if mode=='folder' then name='.' end
  local entries,selected,scroll={},1,0
  local hidden=false; local filtered=o.extensions~=nil; local message
  local focus=mode=='save' and 'name' or 'list'; local held={}; local hits={}; local order={}
  local field={value=name,cursor=#name,all=mode=='save'}
  local location={value=dir,cursor=#dir,all=false}; local creating,priorName
  local lastClick,lastTime; local search,lastSearch='',0
  local function down(key) return held[key] or (api.keyDown and api.keyDown(key)) end
  local function ctrl() return down(keys.leftCtrl) or down(keys.rightCtrl) end
  local function shift() return down(keys.leftShift) or down(keys.rightShift) end
  local function setField(value,all)
    field.value,field.cursor,field.all=value,#value,all or false
  end
  local function allowed(value)
    if not filtered then return true end
    for _,extension in ipairs(o.extensions) do
      extension=extension:gsub('^%.',''):lower()
      if value:lower():sub(-#extension-1)=='.'..extension then return true end
    end
    return false
  end
  local function refresh(preselect)
    local list={}
    for _,value in ipairs(fs.list(dir)) do
      local path=api.resolve(value,dir); local folder=fs.isDir(path)
      if (hidden or value:sub(1,1)~='.') and (folder or (mode~='folder' and allowed(value))) then
        list[#list+1]={name=value,path=path,folder=folder}
      end
    end
    table.sort(list,function(a,b)
      if a.folder~=b.folder then return a.folder end
      return a.name:lower()==b.name:lower() and a.name<b.name or a.name:lower()<b.name:lower()
    end)
    if mode=='folder' then table.insert(list,1,{name='This folder',path=dir,folder=true,current=true}) end
    entries,selected,scroll=list,1,0
    if preselect then for i,item in ipairs(list) do if item.name==preselect then selected=i; break end end end
    location.value,location.cursor,location.all=dir,#dir,false
    lastClick=nil
    search,lastSearch='',0
  end
  local function navigate(path)
    local target=api.resolve(path,dir)
    assert(fs.isDir(target),'Folder not found')
    local previous=dir; dir=target
    local ok,err=pcall(refresh)
    if not ok then dir=previous; error(err,0) end
    if mode=='folder' then setField('.') elseif mode=='open' then setField('') end
    focus='list'; message=nil
  end
  local function select(index)
    selected=math.max(1,math.min(index,#entries)); local item=entries[selected]
    if item and not creating then
      if mode=='folder' then setField(item.current and '.' or item.name)
      elseif mode=='open' or not item.folder then setField(item.name) end
    end
    lastClick=nil
  end
  local function accept()
    if creating then
      assert(api.storage.name(field.value),'Use a folder name without slashes')
      local path=api.resolve(field.value,dir)
      assert(not fs.exists(path),'That name already exists')
      assert(not fs.isReadOnly(dir),'This folder is read-only')
      fs.makeDir(path); creating=false; setField(priorName); navigate(path); return
    end
    local value=field.value
    if value=='' and entries[selected] then value=entries[selected].name end
    assert(value~='','Choose a '..(mode=='folder' and 'folder' or 'file'))
    local path=api.resolve(value,dir)
    if mode=='folder' then assert(fs.isDir(path),'Folder not found'); return path end
    if fs.isDir(path) then navigate(path); return end
    if mode=='open' then assert(fs.exists(path),'File not found')
    else
      local parent='/'..fs.getDir(path)
      assert(fs.isDir(parent),'Choose an existing folder')
      assert(not fs.isReadOnly(path),'This folder is read-only')
    end
    return path
  end
  local function activateItem()
    local item=entries[selected]; if not item then return end
    if item.current then return item.path end
    if item.folder then navigate(item.path)
    else setField(item.name); return accept() end
  end
  local function action(id)
    message=nil
    if id=='up' then navigate('..')
    elseif id=='home' then navigate('/'..api.home)
    elseif id=='hidden' then hidden=not hidden; refresh()
    elseif id=='filter' then filtered=not filtered; refresh()
    elseif id=='new' then
      assert(not fs.isReadOnly(dir),'This folder is read-only')
      if not creating then priorName=field.value end
      creating=true; setField('',true); focus='name'
    elseif id=='accept' then return accept()
    elseif id=='list' then return activateItem()
    elseif id=='cancel' then return false
    elseif id=='path' then navigate(location.value)
    elseif id=='name' then return accept() end
  end
  local function report(err)
    message=tostring(err):gsub('^.-:%d+: ','')
    if api.notify then api.notify(message) end
  end
  local ok,err=pcall(refresh,name); if not ok then report(err) end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); hits={}; order={}
    local roomy=h>=10; local help=h>=8
    local buttonsY=help and h-1 or h; local nameY=buttonsY-1
    local statusY=roomy and nameY-1 or nil
    local bottom=(statusY or nameY)-1; local rows=math.max(1,bottom-3)
    local title=o.title or (mode=='save' and 'Save file' or mode=='folder' and 'Choose folder' or 'Open file')
    ui.bar(1,' '..(not roomy and message or title),t)
    local function hit(id,x,y,width) hits[#hits+1]={id=id,x=x,y=y,w=width}; order[#order+1]=id end
    local function button(id,label,x,y,width)
      hit(id,x,y,width)
      ui.text(x,y,label,focus==id and t.onAccent or t.text,focus==id and t.accent or t.panel,width)
    end
    local function input(id,data,label,y,register)
      local x=#label+1; local width=math.max(1,w-#label)
      local offset=math.max(0,data.cursor-width+1)
      if focus~=id then offset=math.max(0,#data.value-width) end
      ui.text(1,y,label,t.muted,t.panel,#label)
      ui.text(x,y,data.value:sub(offset+1),focus==id and data.all and t.onAccent or t.text,
        focus==id and data.all and t.accent or t.bg,width)
      if register~=false then hit(id,x,y,width) end
      if focus==id then
        term.setCursorPos(math.min(w,x+data.cursor-offset),y); term.setCursorBlink(true)
      end
      return {x=x,offset=offset}
    end
    input('path',location,'> ',2)
    local x=1
    for _,control in ipairs({{'up','[Up]'},{'home','[Home]'},{'new','[New]'},{'hidden',hidden and '[*]' or '[.]'}}) do
      button(control[1],control[2],x,3,#control[2]); x=x+#control[2]
    end
    if o.extensions and x+4<=w then button('filter',filtered and '[Type]' or '[All]',x,3,math.min(6,w-x+1)) end
    order[#order+1]='list'
    if selected<=scroll then scroll=selected-1 elseif selected>scroll+rows then scroll=selected-rows end
    scroll=math.max(0,math.min(scroll,math.max(0,#entries-rows)))
    for row=1,rows do
      local item=entries[scroll+row]
      if item then
        local active=selected==scroll+row
        local label=(active and '>' or ' ')..(item.current and '= ' or item.folder and '+ ' or '  ')..item.name..(item.folder and not item.current and '/' or '')
        ui.text(1,row+3,label,active and t.onAccent or (item.folder and t.folder or t.text),
          active and t.accent or t.bg,w-1)
        hits[#hits+1]={id='item',index=scroll+row,x=1,y=row+3,w=w-1}
      end
    end
    if #entries==0 then ui.text(1,4,' (empty folder)',t.muted,t.bg,w) end
    if #entries>rows then
      local grip=4+math.floor(scroll/(#entries-rows)*math.max(0,rows-1))
      for y=4,bottom do ui.text(w,y,y==grip and '#' or '|',t.border,t.bg) end
    end
    if statusY then ui.text(1,statusY,message or (#entries..' items'..(filtered and ' | filtered' or '')..(hidden and ' | hidden shown' or '')),t.muted,t.panel,w) end
    input('name',field,creating and 'New: ' or mode=='folder' and 'Folder: ' or 'Name: ',nameY)
    local split=math.floor(w/2)
    button('accept',creating and '[Create]' or mode=='save' and '[Save]' or mode=='folder' and '[Select]' or '[Open]',1,buttonsY,split)
    button('cancel','[Cancel]',split+1,buttonsY,w-split)
    if help then ui.text(1,h,'Tab focus  Enter open  F5 cancel',t.muted,t.panel,w) end
    -- Other controls move the cursor while drawing; restore the active input last.
    if focus=='path' then input('path',location,'> ',2,false)
    elseif focus=='name' then input('name',field,creating and 'New: ' or mode=='folder' and 'Folder: ' or 'Name: ',nameY,false) end
    return rows
  end
  local function edit(data,event,a)
    if event=='char' or event=='paste' then
      if ctrl() then return end
      local text=a:gsub('[%c]','')
      if data.all then data.value=''; data.cursor=0; data.all=false end
      text=text:sub(1,512-#data.value)
      data.value=data.value:sub(1,data.cursor)..text..data.value:sub(data.cursor+1); data.cursor=data.cursor+#text
    elseif event=='key' then
      if ctrl() and a==keys.a then data.all=true
      elseif a==keys.backspace or a==keys.delete then
        if data.all then data.value=''; data.cursor=0
        elseif a==keys.backspace and data.cursor>0 then
          data.value=data.value:sub(1,data.cursor-1)..data.value:sub(data.cursor+1); data.cursor=data.cursor-1
        elseif a==keys.delete then data.value=data.value:sub(1,data.cursor)..data.value:sub(data.cursor+2) end
        data.all=false
      elseif a==keys.left then data.cursor=math.max(0,data.cursor-1); data.all=false
      elseif a==keys.right then data.cursor=math.min(#data.value,data.cursor+1); data.all=false
      elseif a==keys.home then data.cursor=0; data.all=false
      elseif a==keys['end'] then data.cursor=#data.value; data.all=false end
    end
  end
  while true do
    local rows=draw(); local e,a,b,c=os.pullEventRaw(); local result
    if e=='sacabam_close' or e=='terminate' then term.setCursorBlink(false); return nil,'close' end
    if e=='key_up' then held[a]=nil elseif e=='key' then held[a]=true end
    local success,why=pcall(function()
      if e=='key' and (a==keys.f5 or a==keys.escape) then
        if creating then creating=false; setField(priorName); focus='list' else result=false end
      elseif e=='key' and ctrl() and a==keys.l then focus='path'; location.all=true
      elseif e=='key' and ctrl() and a==keys.h then action('hidden')
      elseif e=='key' and ctrl() and a==keys.n then action('new')
      elseif e=='key' and ctrl() and a==keys.f and o.extensions then action('filter')
      elseif e=='key' and ctrl() and a==keys.enter then result=accept()
      elseif e=='key' and a==keys.tab then
        local index=1; for i,id in ipairs(order) do if id==focus then index=i; break end end
        focus=order[(index-1+(shift() and -1 or 1))%#order+1]
      elseif e=='key' and a==keys.enter then result=action(focus)
      elseif focus=='path' or focus=='name' then
        if e=='key' or e=='char' or e=='paste' then edit(focus=='path' and location or field,e,a) end
      elseif e=='key' and focus=='list' then
        if a==keys.up then select(selected-1) elseif a==keys.down then select(selected+1)
        elseif a==keys.pageUp then select(selected-rows) elseif a==keys.pageDown then select(selected+rows)
        elseif a==keys.home then select(1) elseif a==keys['end'] then select(#entries)
        elseif a==keys.left or a==keys.backspace then navigate('..')
        elseif a==keys.right then local item=entries[selected]; if item and item.folder and not item.current then navigate(item.path) end end
      elseif e=='key' and (a==keys.left or a==keys.right) then
        local group=(focus=='accept' or focus=='cancel') and {'accept','cancel'} or {'up','home','new','hidden','filter'}
        local index=1; for i,id in ipairs(group) do if id==focus then index=i end end
        local candidate=group[index+(a==keys.left and -1 or 1)]
        for _,id in ipairs(order) do if id==candidate then focus=id; break end end
      elseif e=='char' and focus=='list' and not ctrl() then
        search=(os.clock()-lastSearch<1 and search or '')..a:lower(); lastSearch=os.clock()
        for i,item in ipairs(entries) do if item.name:lower():sub(1,#search)==search then select(i); break end end
      end
      if e=='mouse_scroll' then focus='list'; select(selected+a*3)
      elseif e=='mouse_click' and a==1 then
        for _,hit in ipairs(hits) do
          if b>=hit.x and b<hit.x+hit.w and c==hit.y then
            if hit.id=='item' then
              local twice=lastClick==hit.index and os.clock()-(lastTime or 0)<.4
              select(hit.index); focus='list'; lastClick,lastTime=hit.index,os.clock()
              if twice then result=activateItem() end
            else
              focus=hit.id
              if focus=='path' then location.all=true
              elseif focus=='name' then field.all=true
              else result=action(focus) end
            end
            break
          end
        end
      elseif e=='disk' or e=='disk_eject' then refresh() end
    end)
    if not success then report(why) end
    if result~=nil then term.setCursorBlink(false); return result or nil end
  end
end
return M
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
  ["system/game.lua"]={sha256="516cbe7ee72fb30a488df49e794596b2699b608fc7fdc98513a2ad82c36a8b84",data=[[
-- Shared window lifecycle, pause/help, restart and private-drive records.
local M={}
function M.run(api,entry)
  local ui=api.ui; local w,h=term.getSize()
  if entry.advanced and not api.caps.color then
    ui.clear(api.theme())
    local lines=ui.wrap(entry.name..'\nADVANCED COMPUTER ONLY\nThis game needs the advanced display.\nQ / Enter to close.',w)
    for y,line in ipairs(lines) do if y<=h then ui.text(1,y,line,api.theme().text,api.theme().bg,w) end end
    while true do
      local e,k=os.pullEventRaw()
      if e=='sacabam_close' or e=='terminate' or (e=='key' and (k==keys.q or k==keys.escape or k==keys.enter)) then return end
    end
  end
  local factory=api.load('system/games/'..entry.id)
  local game=factory.new(); local paused,help=false,false; local timer
  local recordPath='/'..fs.combine(api.home,'.system/game-records.tbl')
  local records=api.storage.load(recordPath,{})
  if type(records)~='table' then records={} end
  local recorded=false
  local function record()
    if not game.result or recorded then return end
    recorded=true
    -- Reload so two windows finishing games cannot overwrite each other's scores.
    local current=api.storage.load(recordPath,{})
    if type(current)~='table' then current={} end
    local old=current[entry.id] or (entry.legacyId and current[entry.legacyId]); if type(old)~='table' then old={} end
    current[entry.id]={plays=(tonumber(old.plays) or 0)+1,wins=(tonumber(old.wins) or 0)+(game.result=='win' and 1 or 0),
      best=math.max(tonumber(old.best) or 0,tonumber(game.score) or 0)}
    local ok,err=api.storage.save(recordPath,current)
    if ok then records=current else api.notify('Could not save game record: '..tostring(err)) end
  end
  local function stop() if timer then os.cancelTimer(timer); timer=nil end end
  api.onExit(stop)
  local function overlay(text)
    local lines=ui.wrap(text,math.max(1,w-4)); local start=math.max(2,math.floor((h-#lines)/2))
    ui.fill(2,start-1,w-2,math.min(#lines+2,h-start),colors.black)
    for i,line in ipairs(lines) do if start+i-1<h then ui.text(3,start+i-1,line,colors.white,colors.black,w-4) end end
  end
  while true do
    w,h=term.getSize(); local enough=w>=entry.w and h>=entry.h
    local c={w=w,h=h-2,ui=ui,pixels=api.pixels,color=api.caps.color and api.config().mode~='basic'}
    c.text=function(x,y,text,fg,bg,width) ui.text(x,y+1,text,fg or colors.white,bg or colors.black,width) end
    c.cell=function(x,y,text,active)
      c.text(x,y,text,active and colors.black or colors.white,active and colors.white or colors.black)
    end
    c.drawPixels=function(canvas) api.pixels.draw(canvas,term,1,2,w,h-2) end
    ui.clear({bg=colors.black,text=colors.white}); api.setTitle(entry.name)
    if enough then game.draw(c) else
      ui.text(1,2,'Window too small',colors.white,colors.black,w)
      ui.text(1,3,'Needs '..entry.w..' x '..entry.h,colors.white,colors.black,w)
      ui.text(1,4,'F6: maximise',colors.white,colors.black,w)
    end
    local old=records[entry.id] or (entry.legacyId and records[entry.legacyId]); local best=type(old)=='table' and tonumber(old.best) or 0
    ui.text(1,1,entry.name..'  '..tostring(game.score or 0)..(w>=36 and '  Best '..tostring(best or 0) or ''),colors.white,colors.gray,w)
    ui.text(1,h,'P pause H help R new Q quit',colors.white,colors.black,w)
    if enough then
      if help then overlay(entry.help..'\nH returns. P pauses. R restarts. Q closes.')
      elseif game.result then overlay((game.result=='win' and 'You win!' or 'Game over')..'\n'..(game.message or '')..'\nR plays again. Q closes.')
      elseif paused then overlay('Paused\nP resumes.') end
    end
    record()
    if entry.timed and enough and not paused and not help and not game.result then
      if not timer then timer=os.startTimer(.1) end
    else stop() end
    local e,a,b,d=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' or (e=='key' and (a==keys.q or a==keys.escape)) then stop(); return
    elseif e=='key' then
      local name=keys.getName(a)
      if name=='h' and not b then help=not help
      elseif name=='p' and not b then paused=not paused
      elseif name=='r' and not b then stop(); game=factory.new(); recorded=false; help=false; paused=false
      elseif enough and not paused and not help and not game.result then game.key(name,b==true) end
    elseif e=='timer' and a==timer then timer=nil; if enough and not paused and not help and not game.result then game.tick(.1) end
    elseif (e=='mouse_click' or e=='mouse_drag') and enough and not paused and not help and not game.result and game.mouse then
      game.mouse(a,b,d-1,c)
    end
  end
end
return M
]]},
  ["system/game_catalog.lua"]={sha256="63b189610d997f997b12899188c3ea98dd60ae2473270429bf7a21846a2db4fa",data=[[
return {
  {id='snake',name='Snake',detail='Eat, grow, avoid your own tail.',help='Arrows / WASD steer. Eat * without hitting a wall or yourself.',w=18,h=11,timed=true},
  {id='pong',name='Pong',detail='First to seven against the computer.',help='Up/Down or W/S move your paddle. First to seven wins.',w=20,h=11,timed=true},
  {id='blocks',name='Blocks',detail='Falling blocks and disappearing lines.',help='Left/Right move. Up rotates. Down drops one row. Space hard-drops.',w=16,h=14,timed=true},
  {id='mines',name='Mines',detail='Clear the field, keep your feet.',help='Arrows move. Enter reveals. F flags. Left/right click reveal/flag. First reveal is safe.',w=18,h=11},
  {id='merge',name='2048',detail='Slide matching tiles together.',help='Arrows slide every tile. Merge equal tiles to reach 2048.',w=21,h=11},
  {id='lights',name='Lights Out',detail='One switch, five consequences.',help='Arrows move. Enter or click toggles a light and its neighbours. Turn them all off.',w=16,h=9},
  {id='sokoban',name='Sokoban',detail='Push crates onto their marks.',help='Arrows / WASD move and push. Z undoes. Put every crate on a dot. Enter starts the next level.',w=18,h=11},
  {id='memory',name='Memory',detail='Find all eight matching pairs.',help='Arrows move. Enter or click flips a card. Enter hides an unmatched pair.',w=18,h=9},
  {id='breakout',name='Breakout',detail='Bounce through a wall of bricks.',help='Left/Right or A/D move. Space launches the ball. Clear all bricks before three balls are lost.',w=22,h=12,timed=true,advanced=true},
  {id='vaultrunner',legacyId='crumb',name='Vault Runner',detail='A first-person 3D vault raid.',help='W/S or Up/Down move. Left/Right or A/D turn. Z/X strafe. M map. Collect all golden crystals, then reach the green exit.',w=22,h=12,timed=true,advanced=true},
}
]]},
  ["system/games/blocks.lua"]={sha256="40e61fc8591de2268ee1c935c7d15f5733054a47274c5141be69b5fb84c50d5a",data=[=[
local M={}
local shapes={{{0,0},{1,0},{2,0},{3,0}},{{0,0},{1,0},{0,1},{1,1}},{{0,0},{1,0},{2,0},{1,1}},
  {{1,0},{2,0},{0,1},{1,1}},{{0,0},{1,0},{1,1},{2,1}},{{0,0},{0,1},{1,1},{2,1}},{{2,0},{0,1},{1,1},{2,1}}}
local inks={colors.cyan,colors.yellow,colors.purple,colors.lime,colors.red,colors.blue,colors.orange}
function M.new(random)
  random=random or math.random
  local s={board={},score=0,lines=0,elapsed=0,next=random(1,7)}
  for y=1,12 do s.board[y]={} end
  local function fits(shape,x,y)
    for _,p in ipairs(shape) do local xx,yy=x+p[1],y+p[2]
      if xx<1 or xx>10 or yy>12 or (yy>=1 and s.board[yy][xx]) then return false end
    end
    return true
  end
  local function spawn()
    s.kind=s.next; s.next=random(1,7); s.shape={}
    for i,p in ipairs(shapes[s.kind]) do s.shape[i]={p[1],p[2]} end
    s.x,s.y=4,1
    if not fits(s.shape,s.x,s.y) then s.result='lose'; s.message=s.lines..' lines cleared' end
  end
  local function lock()
    for _,p in ipairs(s.shape) do s.board[s.y+p[2]][s.x+p[1]]=s.kind end
    local count=0; local y=12
    while y>=1 do
      local full=true; for x=1,10 do if not s.board[y][x] then full=false end end
      if full then table.remove(s.board,y); table.insert(s.board,1,{}); count=count+1 else y=y-1 end
    end
    s.lines=s.lines+count; s.score=s.score+({0,100,300,500,800})[count+1]; spawn()
  end
  function s.drop()
    if s.result then return end
    if fits(s.shape,s.x,s.y+1) then s.y=s.y+1 else lock() end
  end
  function s.key(key)
    if s.result then return end
    local dx=key=='left' and -1 or key=='right' and 1 or 0
    if dx~=0 and fits(s.shape,s.x+dx,s.y) then s.x=s.x+dx
    elseif key=='down' then s.drop()
    elseif key=='space' then while fits(s.shape,s.x,s.y+1) do s.y=s.y+1; s.score=s.score+1 end; lock()
    elseif key=='up' and s.kind~=2 then
      local rotated={}; local size=s.kind==1 and 4 or 3
      for i,p in ipairs(s.shape) do rotated[i]={size-1-p[2],p[1]} end
      for _,kick in ipairs({0,-1,1,-2,2}) do if fits(rotated,s.x+kick,s.y) then s.shape=rotated; s.x=s.x+kick; break end end
    end
  end
  function s.tick(dt)
    s.elapsed=s.elapsed+dt; local delay=math.max(.12,.7-s.lines*.025)
    if s.elapsed>=delay then s.elapsed=s.elapsed-delay; s.drop() end
  end
  function s.draw(c)
    for y=1,12 do
      c.text(1,y,'|'); c.text(12,y,'|')
      for x=1,10 do local kind=s.board[y][x]; c.text(x+1,y,kind and '#' or '.',kind and c.color and inks[kind] or kind and colors.white or colors.gray) end
    end
    for _,p in ipairs(s.shape) do if s.y+p[2]>=1 then c.text(s.x+p[1]+1,s.y+p[2],'#',c.color and inks[s.kind] or colors.white) end end
    c.text(14,1,'Next'); for _,p in ipairs(shapes[s.next]) do c.text(14+p[1],3+p[2],'#',c.color and inks[s.next] or colors.white) end
    if c.w>=20 then c.text(14,7,'Lines'); c.text(14,8,tostring(s.lines)) end
  end
  spawn(); return s
end
return M
]=]},
  ["system/games/breakout.lua"]={sha256="311802c23846ddd027f0912b906d7ae2a6c9e26ec168c1b491c095fbdbb8d38a",data=[[
local M={}
function M.new()
  local s={paddle=40,x=40,y=42,vx=12,vy=-24,ready=true,lives=3,score=0,bricks={},remaining=32}
  for row=1,4 do for col=1,8 do s.bricks[#s.bricks+1]={x=1+(col-1)*10,y=4+(row-1)*4,row=row,alive=true} end end
  function s.key(key)
    if key=='left' or key=='a' then s.paddle=math.max(7,s.paddle-5)
    elseif key=='right' or key=='d' then s.paddle=math.min(73,s.paddle+5)
    elseif key=='space' or key=='enter' then s.ready=false end
    if s.ready then s.x=s.paddle end
  end
  function s.mouse(button,x,_,c) if button==1 then s.paddle=math.max(7,math.min(73,x/c.w*80)); if s.ready then s.x=s.paddle end end end
  function s.tick(dt)
    if s.ready or s.result then return end
    local steps=math.ceil(math.max(math.abs(s.vx),math.abs(s.vy))*dt/.7)
    for _=1,steps do
      local ox,oy=s.x,s.y; s.x=s.x+s.vx*dt/steps; s.y=s.y+s.vy*dt/steps
      if s.x<1 then s.x=1; s.vx=math.abs(s.vx) elseif s.x>79 then s.x=79; s.vx=-math.abs(s.vx) end
      if s.y<1 then s.y=1; s.vy=math.abs(s.vy) end
      if s.vy>0 and oy<=44 and s.y>=44 and math.abs(s.x-s.paddle)<=8 then
        s.y=44; s.vy=-math.abs(s.vy); s.vx=(s.x-s.paddle)*3
      end
      for _,b in ipairs(s.bricks) do
        if b.alive and s.x>=b.x-1 and s.x<=b.x+8 and s.y>=b.y-1 and s.y<=b.y+3 then
          b.alive=false; s.remaining=s.remaining-1; s.score=s.score+10
          if (ox<b.x-1 or ox>b.x+8) and oy>=b.y-1 and oy<=b.y+3 then s.vx=-s.vx else s.vy=-s.vy end
          if s.remaining==0 then s.result='win'; s.message='No bricks left standing.'; return end
          break
        end
      end
      if s.y>49 then
        s.lives=s.lives-1; s.ready=true; s.x,s.y=s.paddle,42; s.vx,s.vy=12,-24
        if s.lives==0 then s.result='lose'; s.message=s.remaining..' bricks survived.' end
        return
      end
    end
  end
  function s.draw(c)
    local b=c.pixels.new(c.w*2,c.h*3,colors.black)
    local function rect(x,y,w,h,color)
      local x1,y1=math.floor(x/80*b.w)+1,math.floor(y/48*b.h)+1
      local x2,y2=math.floor((x+w)/80*b.w),math.floor((y+h)/48*b.h)
      b.rect(x1,y1,math.max(1,x2-x1+1),math.max(1,y2-y1+1),color)
    end
    for _,brick in ipairs(s.bricks) do if brick.alive then rect(brick.x,brick.y,8,3,({colors.red,colors.orange,colors.lime,colors.cyan})[brick.row]) end end
    rect(s.paddle-7,45,14,2,colors.white); rect(s.x-1,s.y-1,2,2,colors.yellow)
    c.drawPixels(b)
    c.text(1,1,'Balls '..s.lives..(s.ready and ' | Space: launch' or ''))
  end
  return s
end
return M
]]},
  ["system/games/lights.lua"]={sha256="b9ccf8633079ae771bc2d174f3cb68b66d977452084a0632efe01a68114e80a5",data=[[
local M={}
function M.new(random)
  random=random or math.random
  local s={cells={},x=3,y=3,moves=0,score=0}
  for i=1,25 do s.cells[i]=false end
  local function flip(x,y)
    for _,d in ipairs({{0,0},{-1,0},{1,0},{0,-1},{0,1}}) do
      local xx,yy=x+d[1],y+d[2]
      if xx>=1 and xx<=5 and yy>=1 and yy<=5 then local i=(yy-1)*5+xx; s.cells[i]=not s.cells[i] end
    end
  end
  for y=1,5 do for x=1,5 do if random(0,1)==1 then flip(x,y) end end end
  local any=false; for _,on in ipairs(s.cells) do any=any or on end; if not any then flip(3,3) end
  function s.key(key)
    if s.result then return end
    if key=='left' then s.x=math.max(1,s.x-1) elseif key=='right' then s.x=math.min(5,s.x+1)
    elseif key=='up' then s.y=math.max(1,s.y-1) elseif key=='down' then s.y=math.min(5,s.y+1)
    elseif key=='space' or key=='enter' then
      flip(s.x,s.y); s.moves=s.moves+1; local lit=false
      for _,on in ipairs(s.cells) do lit=lit or on end
      if not lit then s.result='win'; s.score=math.max(1,1000-s.moves); s.message=s.moves..' switches.' end
    end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-15)/2)+1; local xx=math.floor((x-ox)/3)+1
    if button==1 and xx>=1 and xx<=5 and y>=1 and y<=5 then s.x,s.y=xx,y; s.key('enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-15)/2)+1
    for y=1,5 do for x=1,5 do
      local on=s.cells[(y-1)*5+x]; local selected=x==s.x and y==s.y
      c.cell(ox+(x-1)*3,y,(selected and '[' or ' ')..(on and '*' or '.')..(selected and ']' or ' '),selected)
    end end
    c.text(ox,7,'Moves '..s.moves)
  end
  return s
end
return M
]]},
  ["system/games/memory.lua"]={sha256="3b73437a322c703d1b97fdbcdd4760c04c9dcb106920cdd48167780e21ef3dc0",data=[[
local M={}
function M.new(random)
  random=random or math.random
  local s={cards={},matched={},flipped={},cursor=1,turns=0,score=0}
  for i=1,16 do s.cards[i]=string.char(65+math.floor((i-1)/2)) end
  for i=16,2,-1 do local j=random(1,i); s.cards[i],s.cards[j]=s.cards[j],s.cards[i] end
  function s.key(key)
    if s.result then return end
    if key=='left' then s.cursor=math.max(1,s.cursor-1) elseif key=='right' then s.cursor=math.min(16,s.cursor+1)
    elseif key=='up' then s.cursor=math.max(1,s.cursor-4) elseif key=='down' then s.cursor=math.min(16,s.cursor+4)
    elseif key=='enter' or key=='space' then
      if #s.flipped==2 then s.flipped={}; return end
      if s.matched[s.cursor] or s.flipped[1]==s.cursor then return end
      s.flipped[#s.flipped+1]=s.cursor
      if #s.flipped==2 then
        s.turns=s.turns+1; local a,b=s.flipped[1],s.flipped[2]
        if s.cards[a]==s.cards[b] then
          s.matched[a],s.matched[b]=true,true; s.flipped={}; s.score=s.score+1
          if s.score==8 then s.result='win'; s.message='Eight pairs in '..s.turns..' tries.' end
        end
      end
    end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-16)/2)+1; local xx=math.floor((x-ox)/4)+1
    if button==1 and xx>=1 and xx<=4 and y>=1 and y<=4 then s.cursor=(y-1)*4+xx; s.key('enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for i=1,16 do
      local visible=s.matched[i] or s.flipped[1]==i or s.flipped[2]==i
      c.cell(ox+((i-1)%4)*4,1+math.floor((i-1)/4),'['..(visible and s.cards[i] or '?')..'] ',i==s.cursor)
    end
    c.text(ox,6,'Pairs '..s.score..'/8')
    c.text(ox,7,#s.flipped==2 and 'Enter: hide pair' or 'Tries '..s.turns)
  end
  return s
end
return M
]]},
  ["system/games/merge.lua"]={sha256="1b00cc0fef98676fbc2c204cd6e8989251829591127738400f957d57e08d8cb1",data=[=[
local M={}
function M.new(random)
  random=random or math.random
  local s={cells={},score=0}
  local function spawn()
    local empty={}; for i=1,16 do if not s.cells[i] then empty[#empty+1]=i end end
    if #empty>0 then s.cells[empty[random(1,#empty)]]=random(1,10)==10 and 4 or 2 end
  end
  local function possible()
    for y=1,4 do for x=1,4 do local i=(y-1)*4+x; local v=s.cells[i]
      if not v or (x<4 and v==s.cells[i+1]) or (y<4 and v==s.cells[i+4]) then return true end
    end end
    return false
  end
  function s.key(key)
    if s.result or not ({left=true,right=true,up=true,down=true})[key] then return end
    local changed=false
    for line=1,4 do
      local ids,values={},{}
      for n=1,4 do
        local x,y
        if key=='left' or key=='right' then x=key=='left' and n or 5-n; y=line else x=line; y=key=='up' and n or 5-n end
        ids[n]=(y-1)*4+x; if s.cells[ids[n]] then values[#values+1]=s.cells[ids[n]] end
      end
      local merged={}; local n=1
      while n<=#values do
        local v=values[n]
        if values[n+1]==v then v=v*2; s.score=s.score+v; n=n+1 end
        merged[#merged+1]=v; n=n+1
      end
      for i,id in ipairs(ids) do if s.cells[id]~=merged[i] then changed=true end; s.cells[id]=merged[i] end
    end
    if changed then spawn() end
    for _,v in pairs(s.cells) do if v>=2048 then s.result='win'; s.message='2048. Nicely crunched.' end end
    if not s.result and not possible() then s.result='lose'; s.message='No moves left.' end
  end
  function s.draw(c)
    local ox=math.floor((c.w-20)/2)+1
    for y=1,4 do for x=1,4 do
      local v=s.cells[(y-1)*4+x]; local bg=colors.black
      if c.color and v then bg=({[2]=colors.gray,[4]=colors.blue,[8]=colors.cyan,[16]=colors.purple,[32]=colors.brown,[64]=colors.red})[v] or colors.green end
      c.text(ox+(x-1)*5,1+(y-1)*2,v and string.format('%4d',v) or '   .',colors.white,bg,4)
    end end
  end
  spawn(); spawn(); return s
end
return M
]=]},
  ["system/games/mines.lua"]={sha256="0dbaf0bf6f440fb8918a5776c9e821bf67932c7f47e098b86993193e0a68852e",data=[[
local M={}
function M.new(random)
  random=random or math.random
  local s={bombs={},open={},flags={},x=1,y=1,score=0,started=false}
  local function id(x,y) return (y-1)*8+x end
  local function neighbours(x,y,fn)
    for yy=math.max(1,y-1),math.min(8,y+1) do for xx=math.max(1,x-1),math.min(8,x+1) do if xx~=x or yy~=y then fn(xx,yy,id(xx,yy)) end end end
  end
  function s.count(x,y) local count=0; neighbours(x,y,function(_,_,i) if s.bombs[i] then count=count+1 end end); return count end
  function s.reveal(x,y)
    if s.result or s.flags[id(x,y)] or s.open[id(x,y)] then return end
    if not s.started then
      local cells={}; for yy=1,8 do for xx=1,8 do if math.abs(xx-x)>1 or math.abs(yy-y)>1 then cells[#cells+1]=id(xx,yy) end end end
      for _=1,10 do s.bombs[table.remove(cells,random(1,#cells))]=true end; s.started=true
    end
    if s.bombs[id(x,y)] then s.result='lose'; s.message='That one was a mine.'; return end
    local todo={{x,y}}
    while #todo>0 do
      local p=table.remove(todo); local i=id(p[1],p[2])
      if not s.open[i] and not s.flags[i] then
        s.open[i]=true; s.score=s.score+1
        if s.count(p[1],p[2])==0 then neighbours(p[1],p[2],function(xx,yy,j) if not s.open[j] then todo[#todo+1]={xx,yy} end end) end
      end
    end
    if s.score==54 then s.result='win'; s.message='Every safe square cleared.' end
  end
  function s.key(key,held)
    if key=='left' then s.x=math.max(1,s.x-1) elseif key=='right' then s.x=math.min(8,s.x+1)
    elseif key=='up' then s.y=math.max(1,s.y-1) elseif key=='down' then s.y=math.min(8,s.y+1)
    elseif key=='enter' or key=='space' then s.reveal(s.x,s.y)
    elseif key=='f' and not held and not s.open[id(s.x,s.y)] then local i=id(s.x,s.y); s.flags[i]=not s.flags[i] end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-16)/2)+1; local xx=math.floor((x-ox)/2)+1
    if xx>=1 and xx<=8 and y>=1 and y<=8 then s.x,s.y=xx,y; s.key(button==2 and 'f' or 'enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1; local flags=0
    for y=1,8 do for x=1,8 do
      local i=id(x,y); local mark=s.flags[i] and 'F' or '#'
      if s.flags[i] then flags=flags+1 end
      if s.open[i] then local n=s.count(x,y); mark=n==0 and '.' or tostring(n) end
      if s.result=='lose' and s.bombs[i] then mark='*' end
      c.cell(ox+(x-1)*2,y,mark..' ',x==s.x and y==s.y)
    end end
    c.text(ox,9,'Flags '..flags..'/10')
  end
  return s
end
return M
]]},
  ["system/games/pong.lua"]={sha256="2b819ab5a5d85d1b8f0e419d23d25511a72e9c429cd231b4ca9163e53a8ef2df",data=[[
local M={}
function M.new(random)
  random=random or math.random
  local s={player=4,computer=4,x=9,y=4,vx=6,vy=3,left=0,right=0,score=0}
  local function serve(direction) s.x,s.y=9,4; s.vx=6*direction; s.vy=random(0,1)==0 and -3 or 3 end
  function s.key(key)
    if key=='up' or key=='w' then s.player=math.max(2,s.player-1)
    elseif key=='down' or key=='s' then s.player=math.min(7,s.player+1) end
  end
  function s.tick(dt)
    if s.result then return end
    s.computer=math.max(2,math.min(7,s.computer+math.max(-2.7*dt,math.min(2.7*dt,s.y-s.computer))))
    local old=s.x; s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt
    if s.y<1 then s.y=2-s.y; s.vy=math.abs(s.vy) elseif s.y>8 then s.y=16-s.y; s.vy=-math.abs(s.vy) end
    if old>=2 and s.x<=2 and math.abs(s.y-s.player)<=1.6 then
      s.x=2; s.vx=math.min(12,math.abs(s.vx)+.3); s.vy=(s.y-s.player)*4
    elseif old<=17 and s.x>=17 and math.abs(s.y-s.computer)<=1.6 then
      s.x=17; s.vx=-math.min(12,math.abs(s.vx)+.3); s.vy=(s.y-s.computer)*4
    end
    if s.x<0 then s.right=s.right+1; serve(1)
    elseif s.x>19 then s.left=s.left+1; s.score=s.left; serve(-1) end
    if s.left==7 or s.right==7 then s.result=s.left==7 and 'win' or 'lose'; s.message=s.left..' : '..s.right end
  end
  function s.draw(c)
    local ox=math.floor((c.w-18)/2)
    for y=1,8 do c.text(ox+9,y,':',colors.gray) end
    for dy=-1,1 do c.text(ox+1,s.player+dy,'|'); c.text(ox+18,math.floor(s.computer+.5)+dy,'|') end
    c.text(ox+math.max(1,math.min(18,math.floor(s.x+.5))),math.max(1,math.min(8,math.floor(s.y+.5))),'O',c.color and colors.yellow or colors.white)
    c.text(ox+5,9,s.left..'   :   '..s.right)
  end
  return s
end
return M
]]},
  ["system/games/snake.lua"]={sha256="6ade6557553a639f4a594936c048e6ca4a44c1608de47b7c02744be7a051a02e",data=[[
local M={}
function M.new(random)
  random=random or math.random
  local s={body={{x=8,y=4},{x=7,y=4},{x=6,y=4}},dx=1,dy=0,nextX=1,nextY=0,score=0,elapsed=0}
  local function fruit()
    local free={}
    for y=1,8 do for x=1,16 do
      local occupied=false; for _,p in ipairs(s.body) do if p.x==x and p.y==y then occupied=true end end
      if not occupied then free[#free+1]={x=x,y=y} end
    end end
    if #free==0 then s.result='win'; s.message='The entire board is snake.' else s.food=free[random(1,#free)] end
  end
  fruit()
  function s.key(key)
    local d=({up={0,-1},w={0,-1},down={0,1},s={0,1},left={-1,0},a={-1,0},right={1,0},d={1,0}})[key]
    if d and not (d[1]==-s.dx and d[2]==-s.dy) then s.nextX,s.nextY=d[1],d[2] end
  end
  function s.tick(dt)
    if s.result then return end
    s.elapsed=s.elapsed+dt; local delay=math.max(.09,.22-s.score*.002)
    if s.elapsed<delay then return end; s.elapsed=s.elapsed-delay
    s.dx,s.dy=s.nextX,s.nextY
    local head={x=s.body[1].x+s.dx,y=s.body[1].y+s.dy}
    local grows=head.x==s.food.x and head.y==s.food.y
    local hit=head.x<1 or head.x>16 or head.y<1 or head.y>8
    for i=1,#s.body-(grows and 0 or 1) do local p=s.body[i]; if p.x==head.x and p.y==head.y then hit=true end end
    if hit then s.result='lose'; s.message='Tail: '..#s.body..' cells'; return end
    table.insert(s.body,1,head)
    if grows then s.score=s.score+10; fruit() else table.remove(s.body) end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for y=1,8 do c.text(ox,y,string.rep('.',16),colors.gray) end
    c.text(ox+s.food.x-1,s.food.y,'*',c.color and colors.red or colors.white)
    for i,p in ipairs(s.body) do c.text(ox+p.x-1,p.y,i==1 and '@' or 'o',c.color and colors.lime or colors.white) end
  end
  return s
end
return M
]]},
  ["system/games/sokoban.lua"]={sha256="d51950b498140cef2753057d9b8f10cb6ac4a833daf054587c66a8a7e2877e58",data=[[
local M={}
M.levels={
  {'########','#      #','# .$@  #','#      #','########'},
  {'########','# . .  #','# $ $  #','#   @  #','#      #','########'},
  {'########','#  .   #','#  $   #','# . $  #','#  @   #','#      #','########'},
  {'########','# . .  #','# $ $  #','#      #','#  $ . #','# @    #','########'},
}
function M.new()
  local s={level=1,score=0,moves=0,history={}}
  local function id(x,y) return y*16+x end
  local function copy(t) local out={}; for k,v in pairs(t) do out[k]=v end; return out end
  function s.load(level)
    s.level=level; s.map=M.levels[level]; s.crates={}; s.goals={}; s.walls={}; s.history={}; s.cleared=false
    for y,row in ipairs(s.map) do for x=1,#row do
      local ch=row:sub(x,x); local i=id(x,y)
      if ch=='#' then s.walls[i]=true elseif ch=='$' then s.crates[i]=true elseif ch=='.' then s.goals[i]=true elseif ch=='@' then s.x,s.y=x,y end
    end end
  end
  function s.key(key)
    if s.result then return end
    if s.cleared then if key=='enter' then s.load(s.level+1) end; return end
    if key=='z' and #s.history>0 then local prev=table.remove(s.history); s.x,s.y,s.crates,s.moves=prev.x,prev.y,prev.crates,prev.moves; return end
    local d=({up={0,-1},w={0,-1},down={0,1},s={0,1},left={-1,0},a={-1,0},right={1,0},d={1,0}})[key]
    if not d then return end
    local x,y=s.x+d[1],s.y+d[2]; local target=id(x,y); local beyond=id(x+d[1],y+d[2])
    if s.walls[target] or (s.crates[target] and (s.walls[beyond] or s.crates[beyond])) then return end
    s.history[#s.history+1]={x=s.x,y=s.y,crates=copy(s.crates),moves=s.moves}; if #s.history>200 then table.remove(s.history,1) end
    if s.crates[target] then s.crates[target]=nil; s.crates[beyond]=true end
    s.x,s.y=x,y; s.moves=s.moves+1
    local complete=true; for i in pairs(s.goals) do if not s.crates[i] then complete=false end end
    if complete then
      s.score=s.level*100; s.cleared=true
      if s.level==#M.levels then s.result='win'; s.message='All four warehouses cleared.' end
    end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for y,row in ipairs(s.map) do for x=1,#row do
      local i=id(x,y); local glyph=s.walls[i] and '##' or s.crates[i] and (s.goals[i] and '**' or '[]') or s.goals[i] and '..' or '  '
      if s.x==x and s.y==y then glyph='@ ' end
      c.text(ox+(x-1)*2,y,glyph,c.color and (s.goals[i] and colors.lime or s.crates[i] and colors.yellow or colors.white) or colors.white)
    end end
    c.text(ox,8,'Level '..s.level..'/4')
    c.text(ox,9,s.cleared and 'Enter: next level' or 'Z undo / '..s.moves..' moves')
  end
  s.load(1); return s
end
return M
]]},
  ["system/games/vaultrunner.lua"]={sha256="2186ee0da701b6fd86a0d385b058afddacabe4add4530bc79c9f6c386110dd6f",data=[=[
-- Vault Runner: perspective raycasting, depth-tested sprites and a carved maze.
local M={}
function M.new(random)
  random=random or math.random
  local s={map={},x=2.5,y=2.5,angle=0,crystals={},collected=0,score=0,time=0,showMap=false,size=15}
  for y=1,15 do s.map[y]={}; for x=1,15 do s.map[y][x]=1 end end
  local stack={{2,2}}; s.map[2][2]=0
  while #stack>0 do
    local p=stack[#stack]; local options={}
    for _,d in ipairs({{2,0},{0,2},{-2,0},{0,-2}}) do
      local x,y=p[1]+d[1],p[2]+d[2]
      if x>=2 and x<=14 and y>=2 and y<=14 and s.map[y][x]==1 then options[#options+1]={x,y} end
    end
    if #options==0 then table.remove(stack)
    else local n=options[random(1,#options)]; s.map[(p[2]+n[2])/2][(p[1]+n[1])/2]=0; s.map[n[2]][n[1]]=0; stack[#stack+1]=n end
  end
  s.angle=s.map[2][3]==0 and 0 or math.pi/2
  -- Breadth-first order gives reachable, well-spaced treasures and a distant exit.
  local queue={{2,2}}; local visited={['2:2']=true}; local cursor=1
  while cursor<=#queue do
    local p=queue[cursor]; cursor=cursor+1
    for _,d in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
      local x,y=p[1]+d[1],p[2]+d[2]; local id=x..':'..y
      if s.map[y] and s.map[y][x]==0 and not visited[id] then visited[id]=true; queue[#queue+1]={x,y} end
    end
  end
  local last=queue[#queue]; s.exit={x=last[1]+.5,y=last[2]+.5,exit=true}
  for i=1,6 do local p=queue[math.floor(i*(#queue-2)/7)+2]; s.crystals[i]={x=p[1]+.5,y=p[2]+.5} end
  function s.solid(x,y) return not s.map[math.floor(y)] or s.map[math.floor(y)][math.floor(x)]~=0 end
  local function walkable(x,y)
    for _,dx in ipairs({-.18,.18}) do for _,dy in ipairs({-.18,.18}) do if s.solid(x+dx,y+dy) then return false end end end
    return true
  end
  function s.collect()
    for _,crystal in ipairs(s.crystals) do
      if not crystal.taken and (crystal.x-s.x)^2+(crystal.y-s.y)^2<.23 then crystal.taken=true; s.collected=s.collected+1; s.score=s.score+100 end
    end
    if s.collected==6 and (s.exit.x-s.x)^2+(s.exit.y-s.y)^2<.23 then
      s.result='win'; s.score=s.score+math.max(0,1000-math.floor(s.time)); s.message='Six crystals. One clean getaway.'
    end
  end
  function s.move(dx,dy)
    if s.result then return end
    if walkable(s.x+dx,s.y) then s.x=s.x+dx end
    if walkable(s.x,s.y+dy) then s.y=s.y+dy end
    s.collect()
  end
  function s.key(key,held)
    if s.result then return end
    if key=='left' or key=='a' then s.angle=(s.angle-.17)%(math.pi*2)
    elseif key=='right' or key=='d' then s.angle=(s.angle+.17)%(math.pi*2)
    elseif key=='up' or key=='w' then s.move(math.cos(s.angle)*.3,math.sin(s.angle)*.3)
    elseif key=='down' or key=='s' then s.move(-math.cos(s.angle)*.3,-math.sin(s.angle)*.3)
    elseif key=='z' then s.move(math.sin(s.angle)*.3,-math.cos(s.angle)*.3)
    elseif key=='x' then s.move(-math.sin(s.angle)*.3,math.cos(s.angle)*.3)
    elseif key=='m' and not held then s.showMap=not s.showMap end
  end
  function s.tick(dt) if not s.result then s.time=s.time+dt end end
  function s.ray(dx,dy)
    local mx,my=math.floor(s.x),math.floor(s.y)
    local deltaX,deltaY=dx==0 and math.huge or math.abs(1/dx),dy==0 and math.huge or math.abs(1/dy)
    local stepX,stepY=dx<0 and -1 or 1,dy<0 and -1 or 1
    local sideX=(dx<0 and s.x-mx or mx+1-s.x)*deltaX
    local sideY=(dy<0 and s.y-my or my+1-s.y)*deltaY
    local side,dist
    for _=1,64 do
      if sideX<sideY then mx=mx+stepX; dist=sideX; sideX=sideX+deltaX; side=0
      else my=my+stepY; dist=sideY; sideY=sideY+deltaY; side=1 end
      if not s.map[my] or s.map[my][mx]~=0 then
        local hit=side==0 and s.y+dist*dy or s.x+dist*dx
        return math.max(.05,dist),side,hit%1
      end
    end
    return 64,0,0
  end
  function s.draw(c)
    local pw,ph=c.w*2,c.h*3; local b=c.pixels.new(pw,ph,colors.black)
    if s.showMap then
      local scale=math.max(1,math.floor(math.min(pw/15,(ph-3)/15))); local ox=math.floor((pw-15*scale)/2)
      for y=1,15 do for x=1,15 do b.rect(ox+(x-1)*scale+1,(y-1)*scale+1,scale,scale,s.map[y][x]==1 and colors.gray or colors.black) end end
      local function dot(p,color) b.rect(ox+(math.floor(p.x)-1)*scale+1,(math.floor(p.y)-1)*scale+1,scale,scale,color) end
      for _,crystal in ipairs(s.crystals) do if not crystal.taken then dot(crystal,colors.yellow) end end
      dot(s.exit,colors.lime); dot(s,colors.white)
    else
      local dirX,dirY=math.cos(s.angle),math.sin(s.angle); local planeX,planeY=-dirY*.66,dirX*.66
      local depth={}
      for x=1,pw do
        local camera=(x-.5)*2/pw-1
        local dist,side,u=s.ray(dirX+planeX*camera,dirY+planeY*camera); depth[x]=dist
        local height=ph/dist; local top=ph/2-height/2
        for y=1,ph do
          local ink
          if y<top then ink=y<ph*.28 and colors.blue or colors.black
          elseif y>top+height then ink=(y%3==0) and colors.gray or colors.black
          else
            local mortar=math.floor(u*12)%6==0 or math.floor((y-top)/height*12)%4==0
            ink=mortar and colors.black or dist>6 and colors.gray or side==1 and colors.brown or colors.orange
          end
          b.set(x,y,ink)
        end
      end
      local sprites={s.exit}; for _,crystal in ipairs(s.crystals) do if not crystal.taken then sprites[#sprites+1]=crystal end end
      table.sort(sprites,function(a,d) return (a.x-s.x)^2+(a.y-s.y)^2>(d.x-s.x)^2+(d.y-s.y)^2 end)
      local inverse=1/(planeX*dirY-dirX*planeY)
      for _,sprite in ipairs(sprites) do
        local rx,ry=sprite.x-s.x,sprite.y-s.y
        local tx=inverse*(dirY*rx-dirX*ry); local ty=inverse*(-planeY*rx+planeX*ry)
        if ty>.1 then
          local size=math.min(ph,ph/ty*.3); local sx=pw/2*(1+tx/ty); local sy=ph/2+ph/ty*.15
          for x=math.max(1,math.floor(sx-size)),math.min(pw,math.ceil(sx+size)) do
            if ty<depth[x] then for y=math.max(1,math.floor(sy-size)),math.min(ph,math.ceil(sy+size)) do
              if math.abs(x-sx)+math.abs(y-sy)<=size then
                b.set(x,y,sprite.exit and (s.collected==6 and colors.lime or colors.green) or colors.yellow)
              end
            end end
          end
        end
      end
    end
    c.drawPixels(b); c.text(1,c.h,'Crystals '..s.collected..'/6  '..(s.collected==6 and 'Find green exit' or 'M map'))
  end
  return s
end
return M
]=]},
  ["system/ganymede.lua"]={sha256="1534835d0157cf9f7ec973c92ad51028691b82594195fa4bdcf212969a415017",data=[[
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
  elseif v.kind=='input' then text=text:sub(-math.max(1,v.w))
  elseif v.kind=='password' then text=string.rep('*',math.min(#text,math.max(1,v.w))) end
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
  function form.password(id,x,y,width,text,fn) return add('password',id,x,y,width,text or '',fn) end
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
        if item.kind~='input' and item.kind~='password' and item.callback then item.callback(form,item) end
      end
      if e=='terminate' or e=='sacabam_close' then return
      elseif e=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shift=false
      elseif e=='key' then
        if a==keys.leftShift or a==keys.rightShift then shift=true
        elseif a==keys.tab then form.focus=((form.focus-1+(shift and -1 or 1))%math.max(1,#controls))+1
        elseif a==keys.enter or (a==keys.space and v and v.kind~='input' and v.kind~='password') then click(v)
        elseif a==keys.backspace and v and (v.kind=='input' or v.kind=='password') then v.value=tostring(v.value):sub(1,-2); if v.callback then v.callback(form,v) end end
      elseif (e=='char' or e=='paste') and v and (v.kind=='input' or v.kind=='password') then
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
  ["system/kernel.lua"]={sha256="a1e610b09f2e8c0c9513e13fd5c31fcd88de70b082f8011c1f390ba22358e5a3",data=[=[
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
  {id="games", name="Games", detail="Arcade games, puzzles and Vault Runner 3D", icon="sketch"},
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
    if ctx.config.wallpaper then
      local wallpaper=ctx.load('system/wallpaper')
      if not self.wallpaper then
        self.wallpaper=wallpaper.build(ctx.config,t,self.width,self.height-2,Pixels)
      end
      wallpaper.draw(self.wallpaper,Pixels,1,2)
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
]=]},
  ["system/login.lua"]={sha256="00650632d0e8c0c19b8647e4d9d13321d84c7fef9e1fc47be6bd6ce9795641c6",data=[[
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
    term.setCursorPos(2,h-1); term.write(("Enter: unlock / F5: leave"):sub(1,w-2))
    term.setCursorPos(math.min(w,4+#value),py)
  end
  draw()
  while true do
    local e,a=os.pullEventRaw()
    entropy[#entropy+1]=tostring(os.epoch and os.epoch("utc") or os.clock())..":"..os.clock()
    if e=="char" or e=="paste" then value=value..a:gsub("[%c]",""):sub(1,256-#value)
    elseif e=="key" and a==keys.backspace then value=value:sub(1,-2)
    elseif e=="key" and a==keys.enter then term.setCursorBlink(false); return value,table.concat(entropy,";")
    elseif e=="terminate" or (e=="key" and a==keys.f5) then term.setCursorBlink(false); return nil end
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
function L.unlock(vault,options)
  local encrypted=options and options.encrypt==true
  if (vault.exists() and not vault.isEncrypted()) or (not vault.exists() and not encrypted) then
    local ok,err
    if vault.exists() then ok,err=vault.unlock()
    else ok,err=vault.create(nil,nil,nil,false) end
    assert(ok,err); return true
  end
  local message
  while true do
    if not vault.exists() then
      local password,entropy=L.password("Create your personal drive",{
        "Use a passphrase of 12+ characters.",
        "Encryption ON: saved files are protected.",
        message or "There is no password reset. Keep it safe."})
      if not password then return false end
      if #password<12 then message="Passphrase must have at least 12 characters."
      else
        local again=L.password("Confirm your passphrase",{"Enter the same passphrase again."})
        if not again then return false end
        if password~=again then message="Passphrases did not match."
        else
          local ok,err=vault.create(password,entropy,L.progress,encrypted)
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
  ["system/paths.lua"]={sha256="1e4842930e9ff1f07e1631f31739675d428072a09d0b5af497c88e99ff12bebd",data=[[
-- Working directories belong to a window or shell, never to the shared fs API.
local M={}
function M.resolve(path,base)
  assert(type(path)=='string','Path must be a string')
  path=path:gsub('\\','/')
  local parts={}
  local function append(value)
    for part in value:gmatch('[^/]+') do
      if part=='..' then table.remove(parts)
      elseif part~='.' then parts[#parts+1]=part end
    end
  end
  if path:sub(1,1)~='/' then append((base or '/'):gsub('\\','/')) end
  append(path)
  return '/'..table.concat(parts,'/')
end
function M.context(directory)
  local cwd=M.resolve(directory or '/')
  local context={}
  function context.dir() return cwd end
  function context.resolve(path,base) return M.resolve(path,base or cwd) end
  function context.setDir(path)
    local resolved=context.resolve(path)
    assert(fs.isDir(resolved),'Not a directory: '..resolved)
    cwd=resolved
  end
  return context
end
return M
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
  ["system/pistachio.lua"]={sha256="3754742410e69dd13ab8e9283502ae8f2df22dbce647d7191b2e3b11baf308f2",data=[[
-- Pistachio Script: parsed application language, never evaluated as Lua.
local P={version='1.1'}
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
        if op=='if' or op=='repeat' or op=='on' or op=='every' or op=='function' or op=='frame' then
          if op=='on' or op=='function' then
            if not rest:match('^[%a_][%w_]*$') then fail(line,'Expected handler name') end
            node.name=rest
          elseif op=='frame' then assert(rest=='','frame takes no arguments')
          else node.value=expr(rest) end
          local stop; node.body,stop=block(depth+1)
          if stop=='else' and op=='if' then node.other,stop=block(depth+1) end
          if stop~='end' then fail(line,'Missing end for '..op) end
        elseif op=='set' then
          -- Find the assignment outside subscripts/strings (which may contain ==).
          local depth,quoted,escaped,split=0,false,false
          for i=1,#rest do
            local c=rest:sub(i,i)
            if quoted then
              if escaped then escaped=false elseif c=='\\' then escaped=true elseif c=='"' then quoted=false end
            elseif c=='"' then quoted=true
            elseif c=='[' or c=='(' then depth=depth+1
            elseif c==']' or c==')' then depth=depth-1
            elseif c=='=' and depth==0 then split=i; break end
          end
          if not split then fail(line,'Use set name[index] = expression or set name = expression') end
          node.target=expr(rest:sub(1,split-1)); node.value=expr(rest:sub(split+1))
          local root=node.target
          while root.tag=='index' do root=root.object end
          if root.tag~='variable' then fail(line,'Assignment needs a variable or its field/index') end
        elseif op=='let' then
          node.name,rest=rest:match('^([%a_][%w_]*)%s*=%s*(.+)$')
          if not node.name then fail(line,'Use '..op..' name = expression') end
          node.value=expr(rest)
        elseif op=='label' or op=='button' or op=='input' or op=='password' or op=='checkbox' or op=='progress' or op=='banner' then
          local id,x,y,w,text=rest:match('^([%a_][%w_]*)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$')
          if not id then fail(line,'Use '..op..' id x y width expression') end
          node.name,node.x,node.y,node.width,node.value=id,expr(x),expr(y),expr(w),expr(text)
          if op=='input' or op=='password' or op=='checkbox' then
            if not text:match('^[%a_][%w_]*$') then fail(line,op..' needs a variable name') end
            node.bind=text
          end
        elseif op=='text' or op=='column' then
          local x,y,fg,bg,value=rest:match('^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$')
          if not x then fail(line,'Use '..op..' x y foreground background expression') end
          node.x,node.y,node.fg,node.bg,node.value=expr(x),expr(y),expr(fg),expr(bg),expr(value)
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
        elseif op=='app' or op=='notify' or op=='background' or op=='status' then node.value=expr(rest)
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
  local function bounded(value)
    assert(type(value)~='string' or #value<=131072,'String exceeds 128 KiB')
    return value
  end
  local builtins={str=tostring,num=function(v) return tonumber(v) or 0 end,len=function(v) return #v end,
    min=math.min,max=math.max,abs=math.abs,floor=math.floor,round=function(n) return math.floor(n+0.5) end,
    peanut=peanut.decode,encode=peanut.encode,upper=string.upper,lower=string.lower,slice=string.sub}
  local function integer(n,low,high)
    assert(type(n)=='number' and n==math.floor(n) and n>=low and n<=high,'Integer out of range')
    return n
  end
  builtins.random=function(low,high) return math.random(integer(low,-1000000000,1000000000),integer(high,low,1000000000)) end
  builtins.array=function(count,value)
    integer(count,0,4096); assert(type(value)~='table','Array fill must be a scalar')
    state.budget=state.budget-count; assert(state.budget>=0,'Instruction limit reached')
    local out=peanut.array(); for i=1,count do out[i]=value==nil and 0 or value end; return out
  end
  local function displayColor(value)
    if type(value)=='string' then value=colors[value] end
    for i=0,15 do if value==2^i then return value end end
    error('Expected a ComputerCraft color name or value',0)
  end
  local box
  local function crypto()
    assert(api.load,'Encryption functions are available only to native programs')
    if not box then box=api.load('system/seal').new(api.load('system/crypto'),api.cryptoProgress) end
    return box
  end
  builtins.seal=function(text,passphrase) return crypto().seal(text,passphrase) end
  builtins.unseal=function(data,passphrase) return crypto().unseal(data,passphrase) end
  local eval
  eval=function(n)
    state.budget=state.budget-1; assert(state.budget>=0,'Expression limit reached')
    if n.tag=='literal' then
      if type(n.value)=='string' then
        local size=0
        return bounded((n.value:gsub('{([%a_][%w_]*)}',function(k)
          local v=state.vars[k]; local part=v==nil and '{'..k..'}' or tostring(v)
          size=size+#part; assert(size<=131072,'String exceeds 128 KiB'); return part
        end)))
      end
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
      local args={}; for i,v in ipairs(n.args) do args[i]=eval(v) end; return bounded(fn((table.unpack or unpack)(args)))
    elseif n.tag=='binary' then
      local a=eval(n.left)
      if n.op=='and' then return a and eval(n.right) elseif n.op=='or' then return a or eval(n.right) end
      local b=eval(n.right); local op=n.op
      if op=='+' then return a+b elseif op=='-' then return a-b elseif op=='*' then return a*b
      elseif op=='/' then assert(b~=0,'Division by zero'); return a/b elseif op=='%' then assert(b~=0,'Division by zero'); return a%b
      elseif op=='..' then a,b=tostring(a),tostring(b); assert(#a+#b<=131072,'String exceeds 128 KiB'); return a..b
      elseif op=='==' then return a==b elseif op=='!=' then return a~=b
      elseif op=='<' then return a<b elseif op=='>' then return a>b elseif op=='<=' then return a<=b elseif op=='>=' then return a>=b end
    end
  end
  state.eval=eval
  local visual={label=true,button=true,input=true,password=true,checkbox=true,progress=true,banner=true,panel=true,text=true,column=true}
  local sizes=setmetatable({},{__mode='k'})
  local function assign(target,value)
    if target.tag=='variable' then state.vars[target.name]=value; return end
    local object,key=eval(target.object),eval(target.key)
    assert(type(object)=='table' and object~=peanut.null,'Assignment needs an array or object')
    if type(key)=='number' then integer(key,1,4096)
    else assert(type(key)=='string' and #key<=256,'Invalid field name') end
    if not sizes[object] then local count=0; for _ in pairs(object) do count=count+1 end; sizes[object]=count end
    local count=sizes[object]+(object[key]==nil and 0 or -1)+(value==nil and 0 or 1)
    assert(count<=4096,'Object exceeds 4096 entries'); sizes[object]=count; object[key]=value
  end
  local run
  run=function(nodes,phase)
    for _,n in ipairs(nodes) do
      state.budget=state.budget-1; if state.budget<0 then fail(n.line,'Instruction limit reached') end
      local ok,err=pcall(function()
        if n.op=='frame' then if phase=='render' then run(n.body,'frame') end
        elseif n.op=='if' then run(eval(n.value) and n.body or n.other or {},phase)
        elseif n.op=='repeat' then
          local count=math.floor(tonumber(eval(n.value)) or -1); assert(count>=0 and count<=1000,'repeat range is 0..1000')
          local previous=state.vars.index
          for i=1,count do state.vars.index=i; run(n.body,phase) end
          state.vars.index=previous
        elseif visual[n.op] then
          if phase=='render' or phase=='frame' then
            local widget={kind=n.op,id=n.name,x=integer(math.floor(eval(n.x)),-1000000,1000000),y=integer(math.floor(eval(n.y)),-1000000,1000000),w=n.width and math.floor(eval(n.width)) or 1,bind=n.bind}
            if n.op=='panel' then widget.h=math.floor(eval(n.height)) else widget.value=eval(n.value) end
            if n.fg then widget.fg=displayColor(eval(n.fg)); widget.bg=displayColor(eval(n.bg)) end
            state.widgets[#state.widgets+1]=widget
          end
        elseif n.op=='background' or n.op=='status' then
          if phase=='render' or phase=='frame' then
            local value=eval(n.value); state[n.op]=n.op=='background' and displayColor(value) or tostring(value)
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
          elseif n.op=='set' then assign(n.target,eval(n.value))
          elseif n.op=='app' then state.title=tostring(eval(n.value))
          elseif n.op=='notify' then api.notify(tostring(eval(n.value)))
          elseif n.op=='call' then assert(state.handlers[n.name],'Unknown function: '..n.name); run(state.handlers[n.name],phase)
          elseif n.op=='load' then local value,why=peanut.read(api.resolve(tostring(eval(n.value)))); assert(value~=nil,why); state.vars[n.name]=value
          elseif n.op=='save' then assert(peanut.write(api.resolve(tostring(eval(n.value))),state.vars[n.name]))
          elseif n.op=='quit' then state.quit=true end
        end
      end)
      if not ok then fail(n.line,tostring(err)) end
    end
  end
  function state.initialize() state.budget=10000; run(ast,'init') end
  function state.layout() state.budget=10000; state.widgets={}; state.background=nil; state.status=nil; run(ast,'render'); return state.widgets end
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
  ["system/programs.lua"]={sha256="308c9dbf68836567d1e060562c74d095444eef2f8b3f926962840c29fe6e4703",data=[[
-- Add/refresh shipped commands after an upgrade without replacing user edits.
local M={}
local bundled={'pistachio.lua','europa.lua','pmatrix.lua','pmatrix.pist','games.lua','titan-demo.lua'}
local legacy={
  ['pistachio.lua']='70badd04b0c3bdb0e7568a6afaf5e984e1fd06723ddc3e10947877940eef97f8',
  ['europa.lua']='26e0c24b08490d6cfe4cafd29179052fdc70d584b2d7cd26c8fd543dc069d815',
}
function M.update(root,storage,crypto)
  local record=fs.combine(root,'home/.system/bundled-commands.tbl')
  local previous=storage.load(record,{})
  local nextHashes={}; local changed=false
  local files={}
  for _,name in ipairs(bundled) do files[#files+1]={name,'examples/'..name,'Programs/'..name} end
  local games=fs.combine(root,'games')
  if fs.isDir(games) then
    for _,name in ipairs(fs.list(games)) do
      if not fs.isDir(fs.combine(games,name)) then files[#files+1]={'Games/'..name,'games/'..name,'Games/'..name} end
    end
  end
  for _,entry in ipairs(files) do
    local name=entry[1]
    local oldHash=legacy[name]
    local source=assert(storage.read(fs.combine(root,entry[2])))
    local hash=crypto.hex(crypto.sha256(source))
    local destination=fs.combine(root,'home/'..entry[3])
    local current=storage.read(destination)
    local currentHash=current and crypto.hex(crypto.sha256(current))
    if not fs.exists(destination) or (currentHash and (currentHash==oldHash or currentHash==previous[name])) then
      if current~=source then assert(storage.write(destination,source)) end
    end
    nextHashes[name]=hash
    if previous[name]~=hash then changed=true end
  end
  -- Retire the old stock launcher only after its replacement was installed.
  -- Edited launchers keep working through the catalog's legacy ID alias.
  local retired=fs.combine(root,'home/Games/crumb.lua')
  local old=storage.read(retired)
  if fs.exists(fs.combine(root,'home/Games/vaultrunner.lua')) and old
    and crypto.hex(crypto.sha256(old))=='6a28f78a4b32bb05d1902885559c5085f565fc39ca43106315ee4496c394b7ad' then
    fs.delete(retired)
  end
  if changed then assert(storage.save(record,nextHashes)) end
end
return M
]]},
  ["system/seal.lua"]={sha256="7e7268aa2d3609cd92827b7d50a9e5a991c378df0977fd35f29d92e05250eef5",data=[[
-- Password-encrypted messages for native Pistachio programs. No drive key access.
local S={iterations=100000,maxPlain=32768}
function S.new(C,progress)
  local serial=0; local box={}
  local function password(value)
    assert(type(value)=='string' and #value>=12 and #value<=256,'Use a passphrase of 12..256 characters')
  end
  local function key(master,label) return C.hmac(master,'Pistachio seal v1 '..label) end
  function box.seal(text,passphrase)
    assert(type(text)=='string' and #text<=S.maxPlain,'seal needs text of at most 32 KiB')
    password(passphrase); serial=serial+1
    local timing=tostring(os.epoch and os.epoch('utc') or os.time())..':'..os.clock()..':'..os.getComputerID()..':'..serial
    local salt=C.sha256('Pistachio salt:'..timing)
    local master=C.pbkdf2(passphrase,salt,S.iterations,progress)
    local nonce=C.hmac(key(master,'nonce'),C.sha256(text)..timing):sub(1,12)
    local body='PCS1'..salt..C.be(S.iterations)..nonce..C.chacha20(key(master,'encryption'),nonce,text)
    return 'pistachio1:'..C.hex(body..C.hmac(key(master,'authentication'),body))
  end
  function box.unseal(envelope,passphrase)
    password(passphrase)
    assert(type(envelope)=='string' and envelope:sub(1,11)=='pistachio1:' and #envelope<=11+(S.maxPlain+84)*2,'Invalid sealed message')
    local raw=C.unhex(envelope:sub(12))
    assert(#raw>=84 and raw:sub(1,4)=='PCS1','Invalid sealed message')
    local iterations=C.number(raw,37)
    assert(iterations>=10000 and iterations<=2000000,'Unsupported key derivation parameters')
    local master=C.pbkdf2(passphrase,raw:sub(5,36),iterations,progress)
    assert(C.equal(C.hmac(key(master,'authentication'),raw:sub(1,-33)),raw:sub(-32)),'Wrong password or damaged sealed message')
    return C.chacha20(key(master,'encryption'),raw:sub(41,52),raw:sub(53,-33))
  end
  return box
end
return S
]]},
  ["system/session.lua"]={sha256="10dedd07bae75e976e3b764091b64b1e16060d456913ed2efcf65857c6687c8a",data=[[
-- A normal CraftOS program environment routed through the encrypted filesystem.
-- This is compatibility plumbing, not a security sandbox for untrusted Lua.
local M={}
local hostLoad=load
function M.environment(vfs,parent)
  local env={fs=vfs}
  setmetatable(env,{__index=parent})
  env._G=env
  env.load=function(chunk,name,mode,target)
    -- CraftOS creates a fresh environment with its own shell for each program.
    -- Bind launches there, while the caller's actual working directory exists.
    if target and rawget(target,'shell') and not rawget(target,'ccsacabam')
      and env.ccsacabam and env.ccsacabam.forShell then
      target.ccsacabam=env.ccsacabam.forShell(target.shell)
    end
    return hostLoad(chunk,name,mode or "t",target or env)
  end
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
  for _,name in ipairs({"fs","io","settings","paintutils","help"}) do
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
  ["system/storage.lua"]={sha256="f02a3773774699dd7563b8f5bd9bd2ca2d4af1620edd4fcd65d4bc3e7ce7510b",data=[[
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
    -- The replacement is committed now. Cleanup failure must not tell callers
    -- to roll back their encryption keys while the new image is already live.
    if moved then pcall(fs.delete,backup) end
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
  ["system/syntax.lua"]={sha256="cf688499fe6eb2ebf8577c40d128a49a59c180c12d1bbd3f695bc4be3574096e",data=[[
-- Editor lexing/completion only. Buffer contents are never executed.
local S={}
local function words(text)
  local out={}; for word in text:gmatch('%S+') do out[word]=true end; return out
end
local keywords={
  lua=words('and break do else elseif end false for function goto if in local nil not or repeat return then true until while'),
  peanut=words('true false null'),
  pistachio=words('app let set if else end repeat on every function call quit notify load save label banner button input password checkbox progress panel frame background status text column and or not true false null'),
  cashew=words('cashew html head body main div title h1 h2 p pre a button input label br hr script'),
}
local builtins={
  lua=words('assert error ipairs next pairs pcall print printError read require select tonumber tostring type unpack write xpcall'),
  peanut={},
  pistachio=words('advanced color render width height index key held char str num len min max abs floor round upper lower peanut encode seal unseal array random slice'),
  cashew=words('title href id name value type'),
}
local modules=words('fs term os math string table textutils shell colors colours keys http rednet peripheral paintutils window turtle pocket vector settings parallel bit32')
local libraries={peanut='decode parse encode stringify read write array null',ganymede='form',europa='address relative path serve',titan='new run image loadImage clamp lerp sign dist overlap ease version'}
function S.language(path)
  local ext=tostring(path or ''):lower():match('%.([%w]+)$')
  return ({lua='lua',peanut='peanut',json='peanut',pist='pistachio',pistachio='pistachio',cashew='cashew'})[ext]
end
function S.line(line,language,previous)
  local state={}; for k,v in pairs(previous or {}) do state[k]=v end
  local out={}; local i=1
  local function mark(last,kind)
    last=math.min(last,#line)
    for n=i,last do out[n]=kind end; i=last+1
  end
  while i<=#line do
    local c=line:sub(i,i); local rest=line:sub(i); local lang=state.script and 'pistachio' or language
    if state.block then
      local a,b=line:find(state.block,i,true)
      mark(b or #line,state.blockKind); if a then state.block,state.blockKind=nil,nil end
    elseif state.quote then
      local j=i
      while j<=#line do
        local ch=line:sub(j,j)
        if ch=='\\' and lang~='cashew' then j=j+2
        elseif ch==state.quote then j=j+1; state.quote=nil; break else j=j+1 end
      end
      mark(j-1,'s')
    elseif language=='cashew' and rest:sub(1,9)=='</script>' then
      state.script=nil; state.tag=true; state.closing=true; state.tagName=true; mark(i+1,'o')
    elseif language=='cashew' and not state.script and rest:sub(1,4)=='<!--' then
      state.block='-->'; state.blockKind='c'; mark(i+3,'c')
    elseif language=='cashew' and not state.script and c=='<' then
      state.tag=true; state.closing=rest:sub(1,2)=='</'; state.tagName=true
      mark(i+(state.closing and 1 or 0),'o')
    elseif language=='cashew' and state.tag then
      if c=='>' then
        state.tag=nil; if state.nextScript then state.script=true end
        state.nextScript=nil; mark(i,'o')
      elseif c=='"' or c=="'" then state.quote=c; mark(i,'s')
      elseif c:match('[%a_]') then
        local word=rest:match('^[%w_-]+')
        if state.tagName then
          state.nextScript=word:lower()=='script' and not state.closing; state.tagName=nil
          mark(i+#word-1,'k')
        else mark(i+#word-1,'b') end
      else mark(i,c:match('%s') and 't' or 'o') end
    elseif language=='cashew' and not state.script then
      local entity=rest:match('^&[%w#]+;'); local variable=rest:match('^{[%w_]+}')
      if entity or variable then mark(i+#(entity or variable)-1,'b') else mark(i,'t') end
    elseif lang=='lua' and rest:sub(1,2)=='--' then
      local equal=rest:match('^%-%-%[(=*)%[')
      if equal then state.block=']'..equal..']'; state.blockKind='c'; mark(i+#equal+3,'c')
      else mark(#line,'c') end
    elseif (lang=='pistachio' or lang=='peanut') and (c=='#' or (lang=='peanut' and rest:sub(1,2)=='//')) then mark(#line,'c')
    elseif lang=='lua' and rest:match('^%[=*%[') then
      local equal=rest:match('^%[(=*)%['); state.block=']'..equal..']'; state.blockKind='s'; mark(i+#equal+1,'s')
    elseif c=='"' or (lang=='lua' and c=="'") then state.quote=c; mark(i,'s')
    elseif c:match('%d') or (c=='.' and rest:sub(2,2):match('%d')) then
      local number=rest:match('^0[xX][%x]+') or rest:match('^%d*%.?%d+[eE][+-]?%d+') or rest:match('^%d*%.?%d+')
      mark(i+#number-1,'n')
    elseif c:match('[%a_]') then
      local word=rest:match('^[%a_][%w_]*')
      local kind=keywords[lang][word] and 'k' or builtins[lang][word] and 'b' or 't'
      if lang=='lua' and (modules[word] or libraries[word]) then kind='b' end
      if lang=='peanut' and line:sub(i+#word):match('^%s*[:=]') then kind='b' end
      mark(i+#word-1,kind)
    else mark(i,c:match('[%s]') and 't' or 'o') end
  end
  return table.concat(out),state
end
function S.document(lines,language)
  local result={styles={},before={}}; local state={}
  for i,line in ipairs(lines) do
    result.before[i]=state; result.styles[i],state=S.line(line,language,state)
  end
  return result
end
function S.complete(lines,language,x,y,document)
  local before=lines[y]:sub(1,x-1)
  local _,state=S.line(before,language,document.before[y])
  if state.quote or state.block then return {},'' end
  local styles=document.styles[y]
  if styles:sub(x-1,x-1)=='c' then return {},'' end
  local prefix=before:match('([%a_][%w_%.]*)$') or ''
  local active=state.script and 'pistachio' or language
  if language=='cashew' and not state.script and not state.tag then return {},'' end
  local pool={}
  if active=='lua' then
    local module=prefix:match('^([%a_][%w_]*)%.')
    if module then
      if modules[module] then
        local value=_ENV[module]
        if type(value)=='table' then
          for key in pairs(value) do if type(key)=='string' and key:match('^[%a_][%w_]*$') then pool[module..'.'..key]=true end end
        end
      elseif libraries[module] then for key in libraries[module]:gmatch('%S+') do pool[module..'.'..key]=true end end
    else
      for key in pairs(modules) do pool[key]=true end
      for key in pairs(libraries) do pool[key]=true end
    end
  end
  for key in pairs(keywords[active]) do pool[key]=true end
  for key in pairs(builtins[active]) do pool[key]=true end
  if active~='cashew' then
    for row,line in ipairs(lines) do
      local pos=1
      while true do
        local a,b,word=line:find('([%a_][%w_]*)',pos); if not a then break end
        local kind=document.styles[row]:sub(a,a)
        if kind~='c' and kind~='s' then pool[word]=true end
        pos=b+1
      end
    end
  end
  local out={}
  for word in pairs(pool) do if word~=prefix and word:sub(1,#prefix)==prefix then out[#out+1]=word end end
  table.sort(out); while #out>32 do table.remove(out) end
  return out,prefix
end
return S
]]},
  ["system/titan.lua"]={sha256="564fa1848aae7c897027d76478e7f8866567801453780da2c072b594e90fe9e0",data=[=[
-- Titan: a 2D game engine for ComputerCraft.
-- Standalone: works inside CCSacabam windows, in plain CraftOS (copy this file
-- next to your program or into /rom-less module paths), and on monitors.
-- Saturn's biggest moon. It got the heavy lifting.
local T={version='1.0'}
local floor,ceil,max,min,abs,sqrt=math.floor,math.ceil,math.max,math.min,math.abs,math.sqrt
local unpack=table.unpack or unpack
local DIGITS='0123456789abcdef'
local HEX,FROMHEX={},{}
for i=0,15 do local c=DIGITS:sub(i+1,i+1); HEX[2^i]=c; FROMHEX[c]=2^i end
local CHAR={}; for bits=0,31 do CHAR[bits]=string.char(128+bits) end
local EPS=1e-6

-- Small helpers games tend to need.
function T.clamp(v,lo,hi) return v<lo and lo or v>hi and hi or v end
function T.lerp(a,b,t) return a+(b-a)*t end
function T.sign(v) return v>0 and 1 or v<0 and -1 or 0 end
function T.dist(ax,ay,bx,by) local dx,dy=bx-ax,by-ay; return sqrt(dx*dx+dy*dy) end
function T.overlap(a,b)
  return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
T.ease={
  linear=function(t) return t end,
  ['in']=function(t) return t*t end,
  out=function(t) return 1-(1-t)*(1-t) end,
  inout=function(t) return t<.5 and 2*t*t or 1-((-2*t+2)^2)/2 end,
}

-- Images. Rows are strings; each character is a palette key. Default palette
-- uses blit digits 0-f (the same as paint / .nfp files); space and . are clear.
local function parseImage(rows,palette)
  local img={w=0,h=#rows,px={}}
  for y,row in ipairs(rows) do
    img.px[y]={}; img.w=max(img.w,#row)
    for x=1,#row do
      local ch=row:sub(x,x); local c
      if palette and palette[ch]~=nil then c=palette[ch] or nil
      elseif ch~=' ' and ch~='.' then c=FROMHEX[ch:lower()] end
      img.px[y][x]=c
    end
  end
  return img
end
T.image=parseImage
function T.loadImage(path,palette)
  local h=fs.open(path,'r'); if not h then return nil,'Cannot open '..tostring(path) end
  local rows={}; local line=h.readLine()
  while line do rows[#rows+1]=line; line=h.readLine() end
  h.close(); return parseImage(rows,palette)
end
local function readLines(path)
  local h=fs.open(path,'r'); if not h then error('Cannot open '..tostring(path),3) end
  local rows={}; local line=h.readLine()
  while line do rows[#rows+1]=line; line=h.readLine() end
  h.close(); return rows
end

function T.new(def)
  def=def or {}
  local g={entities={},camera={x=0,y=0},mouse={x=0,y=0,col=0,row=0,down=false},
    time=0,frame=0,running=false,paused=false,background=def.background or colors.black}
  local target=def.target or term.current()
  g.target=target; g.side=def.side; g.fps=def.fps or 20
  if def.scale and target.setTextScale then target.setTextScale(def.scale) end
  local color=target.isColor and target.isColor()
  -- Advanced computers get full 2x3 subpixel colour graphics by default.
  -- Basic computers are opt-in: a game sets basic=true and designs its
  -- one-cell-per-pixel version itself (check g.mode=='cell').
  g.supported=color or def.basic==true
  local mode=def.mode or (color and 'pixel' or 'cell')
  g.mode=mode; g.color=color
  local sx,sy=1,1; if mode=='pixel' then sx,sy=2,3 end
  g.sx,g.sy=sx,sy
  local buf,cover={}, {}
  local held,pressed,clicked={}, {}, {}
  local binds={left={'left','a'},right={'right','d'},up={'up','w'},down={'down','s'},
    jump={'space','up','w'},action={'enter','space','e'}}
  local sprites,anims,templates,scenes={}, {}, {}, {}
  local scene,sceneName
  local timers,tweens,particles,handlers={}, {}, {}, {}
  local pending={}; local nextId=0
  local shake={time=0,amount=0}; local follow
  local map

  -- Display ---------------------------------------------------------------
  function g.resize()
    local cols,rows=target.getSize()
    g.cols,g.rows=cols,rows; g.width,g.height=cols*sx,rows*sy
    buf={}; cover={}
    g.tooSmall=(def.minCols and cols<def.minCols) or (def.minRows and rows<def.minRows) or false
    if scene and scene.resize then scene.resize(g) end
  end
  g.resize()

  -- Input -------------------------------------------------------------------
  function g.bind(action,list) binds[action]=type(list)=='table' and list or {list} end
  local function any(set,name)
    if set[name] then return true end
    local list=binds[name]; if not list then return false end
    for _,k in ipairs(list) do if set[k] then return true end end
    return false
  end
  function g.down(name) return any(held,name) end
  function g.pressed(name) return any(pressed,name) end
  function g.clicked(button) return clicked[button or 1]==true end
  local function setMouse(col,row,button,down)
    local m=g.mouse
    m.col,m.row=col,row
    m.x=(col-1)*sx+(sx-1)/2+g.camera.x; m.y=(row-1)*sy+(sy-1)/2+g.camera.y
    m.sx,m.sy=m.x-g.camera.x,m.y-g.camera.y
    if button then m.button=button end
    if down~=nil then m.down=down end
  end

  -- Assets -----------------------------------------------------------------
  function g.sprite(name,rows,palette)
    if type(rows)=='string' then sprites[name]=assert(T.loadImage(rows,palette))
    elseif rows.px then sprites[name]=rows
    else sprites[name]=parseImage(rows,palette) end
    return sprites[name]
  end
  function g.animation(name,frames,fps,loop) anims[name]={frames=frames,fps=fps or 6,loop=loop~=false}; return anims[name] end
  local function imageFor(e)
    local name=e.sprite; if not name then return end
    local a=anims[name]
    if a then
      local i=floor(((g.time-(e.animStart or 0))*a.fps))
      i=a.loop and (i%#a.frames)+1 or min(i+1,#a.frames)
      name=a.frames[i]
    end
    return type(name)=='table' and name or sprites[name]
  end

  -- Drawing (world coordinates: (0,0) is the top-left pixel of the world) --
  local ox,oy=0,0 -- current offset; camera for world drawing, 0 for screen
  local function plot(x,y,c)
    if not c then return end
    x,y=floor(x-ox),floor(y-oy)
    if x>=0 and y>=0 and x<g.width and y<g.height then buf[y*g.width+x+1]=c end
  end
  local draw={}
  function draw.pixel(x,y,c) plot(x,y,c) end
  function draw.rect(x,y,w,h,c)
    local x1,y1=max(0,floor(x-ox)),max(0,floor(y-oy))
    local x2,y2=min(g.width,floor(x-ox+w))-1,min(g.height,floor(y-oy+h))-1
    local W=g.width
    for yy=y1,y2 do local base=yy*W+1 for xx=x1,x2 do buf[base+xx]=c end end
  end
  function draw.outline(x,y,w,h,c)
    draw.rect(x,y,w,1,c); draw.rect(x,y+h-1,w,1,c); draw.rect(x,y,1,h,c); draw.rect(x+w-1,y,1,h,c)
  end
  function draw.line(x1,y1,x2,y2,c)
    x1,y1,x2,y2=floor(x1),floor(y1),floor(x2),floor(y2)
    local dx,dy=abs(x2-x1),-abs(y2-y1); local stx,sty=x1<x2 and 1 or -1,y1<y2 and 1 or -1; local err=dx+dy
    while true do
      plot(x1,y1,c); if x1==x2 and y1==y2 then return end
      local e2=2*err
      if e2>=dy then err=err+dy; x1=x1+stx end
      if e2<=dx then err=err+dx; y1=y1+sty end
    end
  end
  function draw.circle(cx,cy,r,c,filled)
    for y=-r,r do for x=-r,r do
      local d=x*x+y*y
      if d<=r*r+r and (filled~=false or d>=(r-1)*(r-1)+(r-1)) then plot(cx+x,cy+y,c) end
    end end
  end
  function draw.image(img,x,y,flip,flipY)
    if type(img)~='table' then img=sprites[img] end
    if not img then return end
    for yy=1,img.h do
      local row=img.px[flipY and img.h-yy+1 or yy]
      for xx=1,img.w do
        local c=row[flip and img.w-xx+1 or xx]
        if c then plot(x+xx-1,y+yy-1,c) end
      end
    end
  end
  -- Text sits on terminal cells. x,y are pixels; it snaps to the cell there.
  function draw.text(x,y,text,fg,bg)
    local col,row=floor((x-ox)/sx)+1,floor((y-oy)/sy)+1
    g.write(col,row,text,fg,bg)
  end
  function g.write(col,row,text,fg,bg)
    text=tostring(text)
    if row<1 or row>g.rows then return end
    for i=1,#text do
      local c=col+i-1
      if c>=1 and c<=g.cols then cover[(row-1)*g.cols+c]={text:sub(i,i),fg or colors.white,bg} end
    end
  end
  function g.center(row,text,fg,bg) text=tostring(text); g.write(floor((g.cols-#text)/2)+1,row,text,fg,bg) end
  for k,fn in pairs(draw) do g[k]=fn end
  g.screen={}
  for k,fn in pairs(draw) do
    g.screen[k]=function(...) local px,py=ox,oy; ox,oy=0,0; fn(...); ox,oy=px,py end
  end
  g.screen.write=g.write; g.screen.center=g.center

  -- Tile maps ---------------------------------------------------------------
  function g.map(spec)
    local m={tile=spec.tile or 3,legend=spec.legend or {},grid={},spawned={},edge=spec.edge}
    local rows=spec.rows
    if type(rows)=='string' then rows=readLines(rows) end
    m.cols,m.rows=0,#rows
    for _,r in ipairs(rows) do m.cols=max(m.cols,#r) end
    m.width,m.height=m.cols*m.tile,m.rows*m.tile
    for y=1,m.rows do m.grid[y]={} for x=1,m.cols do m.grid[y][x]=rows[y]:sub(x,x) end end
    function m.get(tx,ty) local r=m.grid[ty]; return r and r[tx] end
    function m.set(tx,ty,ch) if m.grid[ty] and tx>=1 and tx<=m.cols then m.grid[ty][tx]=ch end end
    function m.info(tx,ty) local ch=m.get(tx,ty); return ch and m.legend[ch] end
    function m.toTile(x,y) return floor(x/m.tile)+1,floor(y/m.tile)+1 end
    function m.fromTile(tx,ty) return (tx-1)*m.tile,(ty-1)*m.tile end
    function m.find(ch)
      local out={}
      for y=1,m.rows do for x=1,m.cols do if m.grid[y][x]==ch then out[#out+1]={x=x,y=y} end end end
      return out
    end
    map=m; g.tiles=m
    -- Legend entries can create entities: a template name or a function.
    for y=1,m.rows do for x=1,m.cols do
      local info=m.legend[m.grid[y][x]]
      if info and info.spawn then
        local px,py=m.fromTile(x,y)
        local e
        if type(info.spawn)=='function' then e=info.spawn(px,py,x,y)
        else e=g.spawn(info.spawn,{x=px,y=py}) end
        m.grid[y][x]=info.under or ' '
        if e then m.spawned[#m.spawned+1]=e end
      end
    end end
    return m
  end
  local function tileBlocks(info,dir,e,top)
    if not info then return false end
    if info.solid then return true end
    -- One-way platforms stop things falling onto them, not jumping through.
    return info.oneway and dir=='down' and e.y+e.h-EPS<=top
  end
  -- Returns the boxes blocking e at (x,y), for a move in dir.
  local function blockers(e,x,y,dir)
    local out={}
    if map and e.collide~=false then
      local t=map.tile
      local tx1,ty1=floor(x/t)+1,floor(y/t)+1
      local tx2,ty2=floor((x+e.w-EPS)/t)+1,floor((y+e.h-EPS)/t)+1
      for ty=ty1,ty2 do for tx=tx1,tx2 do
        local info
        if tx<1 or ty<1 or tx>map.cols or ty>map.rows then info=map.edge~=false and (map.legend.edge or {solid=true}) or nil
        else info=map.legend[map.grid[ty][tx]] end
        if info and ty>map.rows and not info.floor then info=nil end -- fall out of the bottom
        if tileBlocks(info,dir,e,(ty-1)*t) then out[#out+1]={x=(tx-1)*t,y=(ty-1)*t,w=t,h=t,tile=info,tx=tx,ty=ty} end
      end end
    end
    if e.collide~=false then
      for _,o in ipairs(g.entities) do
        if o~=e and o.alive and o.solid and o.x<x+e.w and x<o.x+o.w and o.y<y+e.h and y<o.y+o.h then
          if not o.oneway or (dir=='down' and e.y+e.h-EPS<=o.y) then out[#out+1]=o end
        end
      end
    end
    return out
  end
  -- True when (x,y) is inside a solid or one-way tile, or a solid entity.
  function g.solidAt(x,y)
    if map then
      local tx,ty=floor(x/map.tile)+1,floor(y/map.tile)+1
      local info=map.legend[map.get(tx,ty) or '']
      if info and (info.solid or info.oneway) then return true end
    end
    for _,o in ipairs(g.entities) do
      if o.alive and o.solid and x>=o.x and x<o.x+o.w and y>=o.y and y<o.y+o.h then return true end
    end
    return false
  end
  -- Move e by (dx,dy), stopping at solid tiles and solid entities.
  -- Returns hitX, hitY (the blocking box or false).
  function g.move(e,dx,dy)
    local step=map and map.tile*.5 or 1
    local n=max(1,ceil(max(abs(dx),abs(dy))/step))
    local hitX,hitY=false,false
    for _=1,n do
      if dx~=0 and not hitX then
        local nx=e.x+dx/n
        local list=blockers(e,nx,e.y,dx>0 and 'right' or 'left')
        if #list>0 then
          for _,b in ipairs(list) do
            if dx>0 then nx=min(nx,b.x-e.w) else nx=max(nx,b.x+b.w) end
          end
          hitX=list[1]
        end
        e.x=nx
      end
      if dy~=0 and not hitY then
        local ny=e.y+dy/n
        local list=blockers(e,e.x,ny,dy>0 and 'down' or 'up')
        if #list>0 then
          for _,b in ipairs(list) do
            if dy>0 then ny=min(ny,b.y-e.h) else ny=max(ny,b.y+b.h) end
          end
          hitY=list[1]
        end
        e.y=ny
      end
    end
    return hitX,hitY
  end

  -- Entities ----------------------------------------------------------------
  function g.define(name,template) templates[name]=template; return template end
  function g.spawn(kind,props)
    local e={}
    if type(kind)=='string' then
      local tpl=templates[kind]; if not tpl then error('Unknown entity template: '..kind,2) end
      for k,v in pairs(tpl) do e[k]=v end; e.kind=kind
    elseif type(kind)=='table' then props=kind end
    for k,v in pairs(props or {}) do e[k]=v end
    nextId=nextId+1; e.id=nextId; e.alive=true
    e.x,e.y,e.vx,e.vy=e.x or 0,e.y or 0,e.vx or 0,e.vy or 0
    local img=imageFor(e)
    e.w,e.h=e.w or (img and img.w) or sx,e.h or (img and img.h) or sy
    local tags={}
    if e.kind then tags[e.kind]=true end
    for _,t in ipairs(type(e.tags)=='table' and e.tags or {e.tags}) do tags[t]=true end
    e.tags=tags; e.animStart=g.time
    function e.is(tag) return tags[tag]==true end
    function e.tag(tag,on) tags[tag]=on~=false or nil end
    function e.destroy() e.alive=false end
    function e.play(name) if e.sprite~=name then e.sprite=name; e.animStart=g.time end end
    function e.center() return e.x+e.w/2,e.y+e.h/2 end
    pending[#pending+1]=e
    if e.init then e.init(e,g) end
    return e
  end
  local function flush()
    if #pending>0 then
      for _,e in ipairs(pending) do if e.alive then g.entities[#g.entities+1]=e end end
      pending={}
    end
    local j=1
    for i=1,#g.entities do local e=g.entities[i]
      if e.alive then g.entities[j]=e; j=j+1 elseif e.removed then e.removed(e,g) end
    end
    for i=#g.entities,j,-1 do g.entities[i]=nil end
  end
  g.flush=flush
  function g.find(tag)
    local out={}
    for _,list in ipairs({g.entities,pending}) do
      for _,e in ipairs(list) do if e.alive and (not tag or e.tags[tag]) then out[#out+1]=e end end
    end
    return out
  end
  function g.first(tag) return g.find(tag)[1] end
  function g.count(tag) return #g.find(tag) end
  function g.at(x,y,tag)
    for i=#g.entities,1,-1 do local e=g.entities[i]
      if e.alive and (not tag or e.tags[tag]) and x>=e.x and x<e.x+e.w and y>=e.y and y<e.y+e.h then return e end
    end
  end
  function g.overlapping(e,tag)
    local out={}
    for _,o in ipairs(g.entities) do
      if o~=e and o.alive and (not tag or o.tags[tag]) and T.overlap(e,o) then out[#out+1]=o end
    end
    return out
  end

  -- Time --------------------------------------------------------------------
  local function addTimer(t) timers[#timers+1]=t; function t.cancel() t.dead=true end; return t end
  function g.after(delay,fn) return addTimer({left=delay,fn=fn}) end
  function g.every(delay,fn) return addTimer({left=delay,every=delay,fn=fn}) end
  function g.tween(obj,time,goal,ease,done)
    local tw={obj=obj,time=max(time,EPS),t=0,goal=goal,from={},ease=T.ease[ease or 'out'] or ease,done=done}
    for k,v in pairs(goal) do tw.from[k]=obj[k] end
    tweens[#tweens+1]=tw; function tw.cancel() tw.dead=true end; return tw
  end
  function g.burst(x,y,opts)
    opts=opts or {}
    for _=1,opts.count or 8 do
      local a=math.random()*math.pi*2; local s=(opts.speed or 20)*(.4+math.random()*.6)
      particles[#particles+1]={x=x,y=y,vx=math.cos(a)*s,vy=math.sin(a)*s,life=opts.life or .6,
        color=type(opts.color)=='table' and opts.color[math.random(#opts.color)] or opts.color or colors.white,
        gravity=opts.gravity or 0}
    end
  end
  function g.shake(amount,time) shake.amount,shake.time=amount or 2,time or .3 end
  function g.follow(e,opts) follow=e and {e=e,lerp=(opts and opts.lerp) or 1,bounds=not opts or opts.bounds~=false} or nil end

  -- Sound: any attached speaker; silent when there is none.
  function g.sound(instrument,volume,pitch)
    if g.speaker==nil then g.speaker=peripheral and peripheral.find and peripheral.find('speaker') or false end
    if g.speaker then pcall(g.speaker.playNote,instrument or 'bit',volume or 1,pitch or 12) end
  end

  -- Saving: plain Lua tables through fs (encrypted drive inside CCSacabam).
  function g.save(path,data)
    local h,err=fs.open(path,'w'); if not h then return nil,err end
    h.write(textutils.serialize(data)); h.close(); return true
  end
  function g.load(path,default)
    local h=fs.open(path,'r'); if not h then return default end
    local data=textutils.unserialize(h.readAll()); h.close()
    if data==nil then return default end
    return data
  end

  -- Scenes ------------------------------------------------------------------
  function g.scene(name,s) scenes[name]=s; return s end
  function g.clear()
    for _,e in ipairs(g.entities) do e.alive=false end
    for _,e in ipairs(pending) do e.alive=false end
    g.entities={}; pending={}; timers={}; tweens={}; particles={}
    map=nil; g.tiles=nil; follow=nil; g.camera.x,g.camera.y=0,0
  end
  function g.go(name,...)
    local nextScene=scenes[name]; if not nextScene then error('Unknown scene: '..tostring(name),2) end
    if scene and scene.leave then scene.leave(g) end
    if not nextScene.keep then g.clear() end
    scene,sceneName=nextScene,name; g.sceneName=name
    if scene.enter then scene.enter(g,...) end
  end
  function g.on(event,fn) handlers[event]=handlers[event] or {}; table.insert(handlers[event],fn) end
  if def.update or def.draw or def.enter then
    g.scene('main',{enter=def.enter,update=def.update,draw=def.draw,background=def.backdrop,event=def.event})
  end

  -- Simulation --------------------------------------------------------------
  local function physics(e,dt)
    if e.gravity then e.vy=min(e.vy+e.gravity*dt,e.maxFall or 200) end
    if e.friction and e.onGround ~= false then
      local f=e.friction*dt
      if abs(e.vx)<=f then e.vx=0 else e.vx=e.vx-T.sign(e.vx)*f end
    end
    if e.drag then local k=max(0,1-e.drag*dt); e.vx,e.vy=e.vx*k,e.vy*k end
    if e.vx==0 and e.vy==0 then if e.gravity then e.onGround=#blockers(e,e.x,e.y+.01,'down')>0 end return end
    if map or e.collide then
      local hx,hy=g.move(e,e.vx*dt,e.vy*dt)
      e.onGround=hy and e.vy>0 or false
      if hx then if e.bounce then e.vx=-e.vx*e.bounce else e.vx=0 end; if e.hitWall then e.hitWall(e,hx,g) end end
      if hy then
        if e.bounce then e.vy=-e.vy*e.bounce else e.vy=0 end
        if e.hitFloor and e.onGround then e.hitFloor(e,hy,g) elseif e.hitCeiling and not e.onGround then e.hitCeiling(e,hy,g) end
      end
    else e.x,e.y=e.x+e.vx*dt,e.y+e.vy*dt end
    if map and e.y>map.height+(e.fallOut or 4*map.tile) and e.fell then e.fell(e,g) end
  end
  function g.step(dt)
    if g.tooSmall then pressed={}; clicked={}; return end
    g.dt=dt
    if not g.paused then
      g.time=g.time+dt; g.frame=g.frame+1
      flush()
      if scene and scene.update then scene.update(g,dt) end
      for _,e in ipairs(g.entities) do
        if e.alive then
          if e.update then e.update(e,dt,g) end
          if e.alive then physics(e,dt) end
          if e.life then e.life=e.life-dt; if e.life<=0 then e.alive=false end end
        end
      end
      for _,e in ipairs(g.entities) do
        if e.alive and e.touch then
          for _,o in ipairs(g.entities) do
            if o~=e and o.alive and e.alive and (not e.touches or o.tags[e.touches]) and T.overlap(e,o) then e.touch(e,o,g) end
          end
        end
      end
      for i=#timers,1,-1 do local t=timers[i]
        if t and not t.dead then
          t.left=t.left-dt
          if t.left<=0 then
            t.fn(g)
            if t.every and not t.dead then t.left=t.left+t.every else t.dead=true end
          end
        end
      end
      for i=#timers,1,-1 do if timers[i] and timers[i].dead then table.remove(timers,i) end end
      for i=#tweens,1,-1 do local tw=tweens[i]
        if tw and not tw.dead then
          tw.t=min(tw.time,tw.t+dt); local k=tw.ease(tw.t/tw.time)
          for key,v in pairs(tw.goal) do tw.obj[key]=tw.from[key]+(v-tw.from[key])*k end
          if tw.t>=tw.time then tw.dead=true; if tw.done then tw.done(tw.obj,g) end end
        end
        if tw and tw.dead and tweens[i]==tw then table.remove(tweens,i) end
      end
      for i=#particles,1,-1 do local p=particles[i]
        p.life=p.life-dt; p.vy=p.vy+p.gravity*dt; p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt
        if p.life<=0 then table.remove(particles,i) end
      end
      flush()
      if follow then
        local e=follow.e
        local tx,ty=e.x+e.w/2-g.width/2,e.y+e.h/2-g.height/2
        g.camera.x=g.camera.x+(tx-g.camera.x)*min(1,follow.lerp)
        g.camera.y=g.camera.y+(ty-g.camera.y)*min(1,follow.lerp)
        if follow.bounds and map then
          g.camera.x=T.clamp(g.camera.x,0,max(0,map.width-g.width))
          g.camera.y=T.clamp(g.camera.y,0,max(0,map.height-g.height))
        end
      end
      if shake.time>0 then shake.time=shake.time-dt end
    elseif scene and scene.paused then scene.paused(g,dt) end
    pressed={}; clicked={}
  end

  -- Rendering ---------------------------------------------------------------
  local function drawMap(m)
    local t=m.tile
    local tx1,ty1=max(1,floor(g.camera.x/t)+1),max(1,floor(g.camera.y/t)+1)
    local tx2,ty2=min(m.cols,floor((g.camera.x+g.width)/t)+1),min(m.rows,floor((g.camera.y+g.height)/t)+1)
    for ty=ty1,ty2 do for tx=tx1,tx2 do
      local info=m.legend[m.grid[ty][tx]]
      if info then
        local x,y=(tx-1)*t,(ty-1)*t
        if info.image or info.sprite then draw.image(info.image or info.sprite,x,y)
        elseif info.color then draw.rect(x,y,t,t,info.color) end
        if info.char then draw.text(x,y,info.char,info.fg,info.color) end
      end
    end end
  end
  local function compose()
    local W=g.width
    cover={}
    local cx,cy=floor(g.camera.x+.5),floor(g.camera.y+.5)
    if shake.time>0 then cx=cx+math.random(-shake.amount,shake.amount); cy=cy+math.random(-shake.amount,shake.amount) end
    ox,oy=0,0
    draw.rect(0,0,W,g.height,g.background)
    if scene and scene.background then scene.background(g) end
    ox,oy=cx,cy
    if map then drawMap(map) end
    local order={}
    for i,e in ipairs(g.entities) do if e.alive and e.visible~=false then order[#order+1]=e end end
    table.sort(order,function(a,b) return (a.z or 0)<(b.z or 0) or ((a.z or 0)==(b.z or 0) and a.id<b.id) end)
    for _,e in ipairs(order) do
      if e.draw then e.draw(e,g)
      else
        local x,y=floor(e.x+.5),floor(e.y+.5)
        -- In cell mode a glyph is clearer than a one-cell block of colour.
        local glyph=e.char and (g.mode=='cell' or not (e.sprite or e.color))
        local img=not glyph and imageFor(e)
        if img then draw.image(img,x,y,e.flip,e.flipY)
        elseif e.color and not glyph then draw.rect(x,y,e.w,e.h,e.color) end
        if glyph then draw.text(x,y,e.char,e.fg or e.color or colors.white,e.bg) end
      end
    end
    for _,p in ipairs(particles) do plot(p.x,p.y,p.color) end
    if scene and scene.draw then scene.draw(g) end
    ox,oy=0,0
    if g.tooSmall then
      draw.rect(0,0,W,g.height,colors.black); cover={}
      g.write(1,1,'Window too small',colors.white,colors.black)
      g.write(1,2,'Needs '..(def.minCols or g.cols)..'x'..(def.minRows or g.rows),colors.white,colors.black)
    end
  end
  -- Two most common colours become background/foreground for each cell.
  local function encode(a,b,c,d,e,f)
    if a==b and b==c and c==d and d==e and e==f then return ' ',f,f end
    local cols={a,b,c,d,e,f}; local count={}
    local first,second
    for i=1,6 do local v=cols[i]; count[v]=(count[v] or 0)+1 end
    for v,n in pairs(count) do
      if not first or n>count[first] or (n==count[first] and v<first) then second=first; first=v
      elseif not second or n>count[second] or (n==count[second] and v<second) then second=v end
    end
    local bg,fg=first,second or first
    if f==fg then bg,fg=fg,bg end
    local bits=0
    if a==fg then bits=bits+1 end; if b==fg then bits=bits+2 end; if c==fg then bits=bits+4 end
    if d==fg then bits=bits+8 end; if e==fg then bits=bits+16 end
    return CHAR[bits],fg,bg
  end
  function g.render()
    compose()
    local W,bgc=g.width,g.background
    for row=1,g.rows do
      local text,fgs,bgs={}, {}, {}
      local y=(row-1)*sy
      for col=1,g.cols do
        local ch,fg,bg
        if sx==1 then ch,fg,bg=' ',bgc,buf[y*W+col] or bgc
        else
          local i=y*W+(col-1)*2+1
          ch,fg,bg=encode(buf[i] or bgc,buf[i+1] or bgc,buf[i+W] or bgc,buf[i+W+1] or bgc,buf[i+2*W] or bgc,buf[i+2*W+1] or bgc)
        end
        local o=cover[(row-1)*g.cols+col]
        if o then ch,fg=o[1],o[2]; if o[3] then bg=o[3] end end
        text[col],fgs[col],bgs[col]=ch,HEX[fg] or '0',HEX[bg] or 'f'
      end
      target.setCursorPos(1,row)
      target.blit(table.concat(text),table.concat(fgs),table.concat(bgs))
    end
  end
  -- Read back what the screen shows, for tests and tools.
  function g.pixelAt(x,y) return buf[floor(y)*g.width+floor(x)+1] or g.background end

  -- Events and the main loop ------------------------------------------------
  function g.event(name,a,b,c,...)
    if name=='key' then
      local k=keys.getName(a); if k then held[k]=true; if not b then pressed[k]=true end end
    elseif name=='key_up' then local k=keys.getName(a); if k then held[k]=nil end
    elseif name=='mouse_click' then setMouse(b,c,a,true); clicked[a]=true
    elseif name=='mouse_drag' then setMouse(b,c,a,true)
    elseif name=='mouse_up' then setMouse(b,c,a,false)
    elseif name=='monitor_touch' and (not g.side or a==g.side) then setMouse(b,c,1,false); clicked[1]=true
    elseif name=='term_resize' or (name=='monitor_resize' and (not g.side or a==g.side)) then g.resize()
    elseif name=='terminate' or name=='sacabam_close' then g.quit() end
    if scene and scene.event then scene.event(g,name,a,b,c,...) end
    for _,fn in ipairs(handlers[name] or {}) do fn(g,a,b,c,...) end
  end
  function g.quit() g.running=false end
  -- Custom colours on advanced computers: g.palette(colors.red,0xff8040).
  -- Every changed colour is restored when the game ends.
  local savedPalette={}
  function g.palette(c,r,gr,b)
    if not (color and target.setPaletteColour) then return false end
    if not savedPalette[c] then savedPalette[c]={target.getPaletteColour(c)} end
    if gr then target.setPaletteColour(c,r,gr,b) else target.setPaletteColour(c,r) end
    return true
  end
  function g.restorePalette()
    for c,v in pairs(savedPalette) do target.setPaletteColour(c,v[1],v[2],v[3]) end
    savedPalette={}
  end
  local function advancedOnly()
    target.setBackgroundColor(colors.black); target.setTextColor(colors.white); target.clear()
    local lines={def.title or 'This game','ADVANCED COMPUTER ONLY','Needs an advanced','computer. Q / Enter','closes.'}
    for i,line in ipairs(lines) do target.setCursorPos(1,i); target.write(line) end
    while true do
      local e,k=os.pullEventRaw()
      if e=='sacabam_close' or e=='terminate' or (e=='key' and (k==keys.q or k==keys.enter or k==keys.escape)) then break end
    end
    target.clear(); target.setCursorPos(1,1)
  end
  function g.run(first,...)
    if not g.supported then return advancedOnly() end
    if first then g.go(first,...) elseif not scene and scenes.main then g.go('main') end
    g.running=true
    local frameTime=1/g.fps
    local last=os.epoch and os.epoch('utc') or os.clock()*1000
    local timer=os.startTimer(0)
    local ok,err=pcall(function()
      while g.running do
        local ev={os.pullEventRaw()}
        if ev[1]=='timer' and ev[2]==timer then
          local now=os.epoch and os.epoch('utc') or os.clock()*1000
          local dt=(now-last)/1000; last=now
          -- Fixed minimum step keeps physics steady; slow frames catch up (capped).
          g.step(max(frameTime,min(dt,.25))); if g.running then g.render() end
          timer=os.startTimer(frameTime)
        else g.event(unpack(ev)) end
      end
    end)
    os.cancelTimer(timer)
    if scene and scene.leave then pcall(scene.leave,g) end
    g.restorePalette()
    target.setBackgroundColor(colors.black); target.setTextColor(colors.white)
    target.clear(); target.setCursorPos(1,1)
    if not ok then error(err,0) end
  end
  return g
end
function T.run(def) local g=T.new(def); g.run(); return g end
return T
]=]},
  ["system/ui.lua"]={sha256="907b3d9f56c80539e8375bf8f9844dee79a37c94509f29e7a27db9ea6aec9d39",data=[[
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
    local lines=M.wrap(label,math.max(1,w-2)); local count=math.min(#lines,h-2)
    M.fill(1,h-count-1,w,count+2,t.panel)
    for i=1,count do M.text(2,h-count-2+i,lines[i],t.text,t.panel,w-2) end
    M.text(2,h-1,"> " .. value:sub(-math.max(1,w-5)),t.text,t.bg,w-2)
    M.text(2,h,"Enter: accept   F5: cancel",t.muted,t.panel,w-2)
    local e,a = os.pullEventRaw()
    if e == "char" or e == "paste" then value = value .. a:gsub("[%c]", ""):sub(1,512-#value)
    elseif e == "key" then
      if a == keys.enter then return value
      elseif a == keys.f5 then return nil
      elseif a == keys.backspace then value = value:sub(1,-2) end
    elseif e == "sacabam_close" or e == "terminate" then return nil end
  end
end
function M.confirm(api, label)
  if api.config and api.config().skipTypedConfirmation then
    local selected=1
    while true do
      local t,w,h=api.theme(),term.getSize()
      local lines=M.wrap(label,math.max(1,w-2)); local count=math.min(#lines,h-2)
      M.fill(1,h-count-1,w,count+2,t.panel)
      for i=1,count do M.text(2,h-count-2+i,lines[i],t.text,t.panel,w-2) end
      local split=math.floor(w/2)
      M.text(1,h-1,selected==1 and '> Confirm' or '  Confirm',selected==1 and t.onAccent or t.text,selected==1 and t.accent or t.panel,split)
      M.text(split+1,h-1,selected==2 and '> Cancel' or '  Cancel',selected==2 and t.onAccent or t.text,selected==2 and t.accent or t.panel,w-split)
      M.text(1,h,'Enter: select / F5: cancel',t.muted,t.panel,w)
      local e,a,b,c=os.pullEventRaw()
      if e=='key' then
        if a==keys.enter then return selected==1
        elseif a==keys.f5 then return false
        elseif a==keys.tab or a==keys.left or a==keys.right then selected=3-selected end
      elseif e=='mouse_click' and a==1 and c==h-1 then return b<=split
      elseif e=='sacabam_close' or e=='terminate' then return false end
    end
  end
  return (M.prompt(api, label .. " (type YES)") or ""):upper() == "YES"
end
function M.filePicker(api,options)
  local path,reason=api.load('system/filepicker').choose(api,options)
  if reason=='close' and api.deferClose then api.deferClose() end
  return path
end
function M.message(api, value)
  api.notify(tostring(value))
end
return M
]]},
  ["system/vault.lua"]={sha256="ac30185ff67b6061ac1bcc67cebfa3bf0d6a4136b2367c64576b2aa2480279bf",data=[[
-- Personal drive: passwordless plain storage or authenticated encryption.
local V={ iterations=100000, limit=196608 }
local physical=fs
function V.new(crypto,storage,path)
  local self={path=path,open=false,files=nil,key=nil,salt=nil,iterations=nil,serial=0,encrypted=true}
  local function keyFor(label) return crypto.hmac(self.key,"CCSacabam v1 "..label) end
  local function header(raw)
    assert(type(raw)=="string" and #raw>=88 and (raw:sub(1,4)=="SCV1" or raw:sub(1,4)=="SCP1"),"Not a CCSacabam personal drive")
    local iterations=crypto.number(raw,37)
    assert(iterations>=10000 and iterations<=2000000,"Unsupported key derivation parameters")
    return raw:sub(5,36),iterations,raw:sub(41,52),raw:sub(53,-33),raw:sub(-32),raw:sub(1,4)=="SCV1"
  end
  function self.exists() return physical.exists(path) end
  local function decode(plain)
    local decoded=textutils.unserialize(plain)
    if type(decoded)~="table" or decoded[""]~=true then return nil,"Invalid personal filesystem" end
    for name,value in pairs(decoded) do
      if type(name)~="string" or physical.combine("",name)~=name or (type(value)~="string" and value~=true) then
        return nil,"Invalid personal drive entry"
      end
    end
    return decoded
  end
  function self.isEncrypted()
    if self.open then return self.encrypted end
    local h=physical.open(path,"rb"); if not h then return false end
    local magic=h.read(4); h.close(); return magic=="SCV1"
  end
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
    if raw:sub(1,4)=="SCP2" or raw:sub(1,4)=="SCP1" then
      local plain
      if raw:sub(1,4)=="SCP2" then
        if #raw<36 or not crypto.equal(crypto.sha256(raw:sub(1,-33)),raw:sub(-32)) then return nil,"Damaged personal drive." end
        plain=raw:sub(5,-33)
      else
        -- Legacy unencrypted drives already contain readable data. Open them
        -- without the old login-only password and migrate on the next save.
        local ok,salt,iterations,nonce,body=pcall(header,raw)
        if not ok then return nil,"Invalid legacy personal drive" end
        plain=body
      end
      local decoded,why=decode(plain); if not decoded then return nil,why end
      self.files,self.open,self.encrypted=decoded,true,false
      self.key,self.salt,self.iterations=nil,nil,nil
      return true
    end
    local ok,salt,iterations,nonce,cipher,tag,encrypted=pcall(header,raw)
    if not ok then return nil,tostring(salt) end
    local master=crypto.pbkdf2(password,salt,iterations,progress)
    local macKey=crypto.hmac(master,"CCSacabam v1 authentication")
    if not crypto.equal(crypto.hmac(macKey,raw:sub(1,-33)),tag) then
      return nil,"Wrong password or damaged vault."
    end
    local plain=encrypted and crypto.chacha20(crypto.hmac(master,"CCSacabam v1 encryption"),nonce,cipher) or cipher
    local decoded,why=decode(plain); if not decoded then return nil,why end
    self.key,self.salt,self.iterations,self.files,self.open=master,salt,iterations,decoded,true
    self.encrypted=encrypted
    return true
  end
  function self.persist()
    assert(self.open,"Personal drive is locked")
    local plain=textutils.serialize(self.files)
    if #plain>V.limit then return nil,"Personal drive full (192 KiB serialized limit)." end
    if not self.encrypted then
      local body="SCP2"..plain
      return storage.write(path,body..crypto.sha256(body))
    end
    self.serial=self.serial+1
    -- CC has no OS CSPRNG. A keyed nonce includes the entire content digest,
    -- time and a counter, so different contents remain distinct after rollback.
    local timing=tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock()..":"..self.serial
    local nonce=crypto.hmac(keyFor("nonce"),crypto.sha256(plain)..timing):sub(1,12)
    local cipher=crypto.chacha20(keyFor("encryption"),nonce,plain)
    local body="SCV1"..self.salt..crypto.be(self.iterations)..nonce..cipher
    return storage.write(path,body..crypto.hmac(keyFor("authentication"),body))
  end
  function self.create(password,entropy,progress,encrypted)
    if self.exists() then return nil,"A vault already exists. Unlock it instead." end
    self.encrypted=encrypted~=false
    if self.encrypted then
      assert(type(password)=="string" and #password>=12,"Use a passphrase of at least 12 characters")
      self.salt=crypto.sha256("CCSacabam salt:"..tostring(entropy)..":"..tostring(os.getComputerID())..":"..tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock())
      self.iterations=V.iterations
      self.key=crypto.pbkdf2(password,self.salt,self.iterations,progress)
    end
    self.files={[""]=true,Documents=true,Pictures=true,Programs=true,[".Trash"]=true,[".system"]=true}
    self.open=true
    local ok,err=self.persist()
    if not ok then self.lock(); return nil,err end
    return true
  end
  function self.setEncryption(enabled,password,entropy,progress)
    assert(self.open,"Personal drive is locked")
    assert(type(enabled)=="boolean","Encryption must be on or off")
    if enabled==self.encrypted then return true end
    local previous,oldKey,oldSalt,oldIterations=self.encrypted,self.key,self.salt,self.iterations
    if enabled then
      if type(password)~="string" or #password<12 then return nil,"Choose a passphrase of at least 12 characters." end
      local salt=crypto.sha256("CCSacabam enable:"..tostring(entropy)..":"..tostring(os.epoch and os.epoch('utc') or os.time())..":"..os.clock())
      local key=crypto.pbkdf2(password,salt,V.iterations,progress)
      self.key,self.salt,self.iterations=key,salt,V.iterations
    end
    self.encrypted=enabled
    local ok,err=self.persist()
    if not ok then self.encrypted,self.key,self.salt,self.iterations=previous,oldKey,oldSalt,oldIterations
    elseif not enabled then self.key,self.salt,self.iterations=nil,nil,nil end
    return ok,err
  end
  function self.changePassword(password,entropy,progress)
    assert(self.open,"Drive is locked")
    if not self.encrypted then return nil,"No password is needed while encryption is off." end
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
      if path=="rom/modules/main/titan.lua" then return physical.combine(systemRoot,"system/titan.lua") end
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
    function out.getDrive(path) if resolve(path) then return self.encrypted and "encrypted" or "personal" else return physical.getDrive(hostPath(path)) end end
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
        names[#names+1]="peanut.lua"; names[#names+1]="ganymede.lua"; names[#names+1]="europa.lua"; names[#names+1]="titan.lua"; table.sort(names)
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
      local key=assert(resolve(path),"Writes belong on the personal drive")
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
      local closed,dirty=false,writable and (mode:sub(1,1)=="w" or self.files[key]==nil)
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
  ["system/wallpaper.lua"]={sha256="a8cabe195e209c64023b36bde3bbd043a9a0828e6ce3c788635a18f53c7a3194",data=[[
-- Cached desktop textures: cell patterns everywhere, subpixels in render mode.
local M={}
local function sample(name,x,y,w,h)
  if name=='mountains' then
    if y>h*.78+math.sin(x/10+2)*2 then return 2,'#' end
    if y>h*.56+math.sin(x/7)*2+math.sin(x/3) then return 1,':' end
  elseif name=='dots' then
    if math.floor(y)%2==0 and math.floor(x)%4==(math.floor(y/2)%2)*2 then return 1,'.' end
  elseif name=='grid' then
    local vertical=math.floor(x)%8==0; local horizontal=math.floor(y)%4==0
    if vertical or horizontal then return 1,vertical and (horizontal and '+' or '|') or '-' end
  elseif name=='diagonal' then
    if (math.floor(x)+math.floor(y)*2)%8<2 then return 1,'/' end
  elseif name=='checker' then
    if (math.floor(x/4)+math.floor(y/2))%2==0 then return 1,':' end
  elseif name=='waves' then
    local wave=(y+math.sin(x/5)*2)%6
    if wave<1 then return 1,'~' elseif wave>3 and wave<3.6 then return 2,'.' end
  elseif name=='stars' then
    local hash=(math.floor(x)*73+math.floor(y)*151+math.floor(x)*math.floor(y)*19)%127
    if hash<3 then return 1,'+' elseif hash<9 then return 2,'.' end
  elseif name=='circuit' then
    local xx,yy=math.floor(x)%12,math.floor(y)%6
    if xx==2 and yy<=3 then return 1,yy==3 and '+' or '|'
    elseif yy==3 and xx>=2 and xx<=9 then return 1,xx==9 and 'o' or '-'
    elseif xx==9 and yy==4 then return 2,'|' end
  end
  return 0,' '
end
function M.build(config,t,w,h,pixels)
  local name=config.wallpaperPattern or (config.mode=='basic' and 'dots' or 'mountains')
  if config.mode=='render' then
    local canvas=pixels.new(w*2,h*3,t.desktop)
    for y=1,canvas.h do for x=1,canvas.w do
      local level=sample(name,x/2,y/3,w,h)
      if level>0 then canvas.set(x,y,level==1 and t.wallpaperFar or t.wallpaperNear) end
    end end
    return {canvas=canvas}
  end
  local rows={}
  for y=1,h do
    local text,fg={},{}
    for x=1,w do
      local level,glyph=sample(name,x,y,w,h); text[x]=glyph
      fg[x]=colors.toBlit(level==2 and t.wallpaperNear or t.wallpaperFar)
    end
    rows[y]={table.concat(text),table.concat(fg),string.rep(colors.toBlit(t.desktop),w)}
  end
  return {rows=rows}
end
function M.draw(image,pixels,x,y)
  if image.canvas then pixels.draw(image.canvas,term,x,y)
  else for i,row in ipairs(image.rows) do term.setCursorPos(x,y+i-1); term.blit(row[1],row[2],row[3]) end end
end
return M
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
local setup=(function()
-- Full-screen setup wizard. Embedded in the offline installer; no downloads.
local S={}
function S.run(package,installer)
  local native=term.current(); local color=native.isColor()
  local oldFG,oldBG=native.getTextColor(),native.getBackgroundColor()
  local page,focus,scroll='welcome','next',0
  local options={mode=color and 'render' or 'basic',encrypt=false,initialize=true}
  local password,confirmation,entropy='','',{}
  local problem,progress,result,controls,hits,rows
  local ensure=true; local shift=false; local finished=false; local cancelled=false
  local existing=fs.exists(installer.target..'/vault/data.scv')
  if existing then
    local file=fs.open(installer.target..'/vault/data.scv','rb')
    if file then options.encrypt=file.read(4)=='SCV1'; file.close() end
  end
  local bytes,count=0,0
  for _,file in pairs(package.files) do bytes=bytes+#file.data; count=count+1 end
  local names={welcome='Welcome',display='Display',privacy='Privacy',password='Password',review='Ready to install',
    installing='Installing',done='Installation complete',error='Installation stopped'}
  local descriptions={basic='Monochrome windows and keyboard navigation.',color='Color windows with mouse and keyboard controls.',
    render='Color, subpixel graphics and custom banner fonts.'}
  local function palette()
    return color and {bg=colors.black,panel=colors.gray,text=colors.white,muted=colors.lightGray,
      accent=colors.cyan,onAccent=colors.black,button=colors.lime,onButton=colors.black,danger=colors.red}
      or {bg=colors.black,panel=colors.black,text=colors.white,muted=colors.white,
      accent=colors.white,onAccent=colors.black,button=colors.white,onButton=colors.black,danger=colors.white}
  end
  local function pages()
    local list={'welcome','display','privacy'}
    if options.encrypt and not existing then list[#list+1]='password' end
    list[#list+1]='review'; return list
  end
  local function position()
    for i,id in ipairs(pages()) do if id==page then return i end end
    return #pages()
  end
  local function change(id)
    page=id; scroll=0; problem=nil; ensure=true
    focus=id=='display' and options.mode or id=='privacy' and not existing and (options.encrypt and 'on' or 'off')
      or id=='password' and 'password' or 'next'
  end
  local function draw()
    term.redirect(native)
    local w,h=native.getSize(); local t=palette()
    native.setBackgroundColor(t.bg); native.setTextColor(t.text); native.clear(); native.setCursorBlink(false)
    local function text(x,y,value,fg,bg,width)
      if y<1 or y>h or x>w then return end
      value=tostring(value or ''); width=math.max(0,math.min(width or #value,w-x+1))
      native.setCursorPos(math.max(1,x),y); native.setTextColor(fg or t.text); native.setBackgroundColor(bg or t.bg)
      native.write(value:sub(1,width)..string.rep(' ',math.max(0,width-#value)))
    end
    text(1,1,' CCSacabam / Setup',t.onAccent,t.accent,w)
    if page~='installing' then text(w-2,1,' X ',color and colors.white or t.onAccent,t.danger,3) end
    text(2,3,names[page],t.text,t.bg,w-2)
    if w>=40 and page~='installing' and page~='done' and page~='error' then
      text(w-12,3,'Step '..position()..' of '..#pages(),t.muted,t.bg,12)
    end
    if h>=14 then text(2,4,string.rep('-',w-2),t.panel,t.bg,w-2) end
    local start=h>=14 and 6 or 4; local finish=h-4; local visible=math.max(1,finish-start+1)
    rows,controls,hits={},{},{}
    local width=math.max(1,w-4)
    local function line(value,muted)
      value=tostring(value or '')
      if value=='' then rows[#rows+1]={text=''} end
      for part in (value..'\n'):gmatch('(.-)\n') do
        while #part>0 do
          local n=math.min(#part,width)
          if #part>width then local cut=part:sub(1,width):match('^.*() '); if cut and cut>width/2 then n=cut end end
          rows[#rows+1]={text=part:sub(1,n),muted=muted}; part=part:sub(n+1)
        end
      end
    end
    local function option(id,label,selected)
      rows[#rows+1]={id=id,text=(selected and '(*) ' or '( ) ')..label,selected=selected}
      controls[#controls+1]=id
    end
    if page=='welcome' then
      line('Windows, Lua programs and a desktop made for ComputerCraft.')
      line(''); line('We will set up your display and personal drive.')
      line('Your files stay in place. Existing startup programs are backed up.',true)
    elseif page=='display' then
      line(color and 'Advanced computer detected' or 'Basic computer detected',true); line('')
      option('basic','Basic / monochrome',options.mode=='basic')
      if color then option('color','Color desktop',options.mode=='color'); option('render','Render / subpixels (default)',options.mode=='render') end
      line(''); line(descriptions[options.mode],true)
      if not color then line('This computer uses keyboard controls. All core apps are available.',true) end
    elseif page=='privacy' then
      if existing then
        line('Your personal drive is already set up.'); line('')
        line(options.encrypt and 'Encryption: ON / password protected' or 'Encryption: OFF / no password')
        line('The upgrade keeps your files and encryption setting. Change it later in Settings.',true)
      else
        option('off','Off / no password',not options.encrypt)
        option('on','On / encrypted files',options.encrypt)
        line(''); line('Fine to leave off on a private computer.')
        line('On a shared server, try encryption: it is the main security feature for saved files.',true)
        line(options.encrypt and 'You will create a password next.' or 'Boot straight into your desktop. Files remain readable outside the OS.',true)
      end
    elseif page=='password' then
      line('Protect your encrypted drive.'); line('Use 12+ characters. Keep it safe.',true); line('')
      line('Password',true); rows[#rows+1]={id='password',field=true,text=string.rep('*',math.min(#password,width-2))}; controls[#controls+1]='password'
      line('Confirm password',true); rows[#rows+1]={id='confirmation',field=true,text=string.rep('*',math.min(#confirmation,width-2))}; controls[#controls+1]='confirmation'
      line('There is no password reset.',true)
    elseif page=='review' then
      line('Display: '..options.mode)
      line('Encryption: '..(options.encrypt and 'ON' or 'OFF'))
      line(options.encrypt and 'Login: password protected' or 'Login: none / straight to desktop')
      line(''); line('Install: '..installer.target,true)
      line(count..' files / '..math.ceil(bytes/1024)..' KiB',true)
      local free=fs.getFreeSpace('/'); line('Free disk: '..(type(free)=='number' and math.floor(free/1024)..' KiB' or tostring(free)),true)
      line('Startup will be backed up. '..(existing and 'Your personal drive will be kept.' or 'Your existing files will be kept.'),true)
    elseif page=='installing' then
      line(progress.phase); line('')
      local bar=math.max(2,width-7); local n=math.floor(bar*progress.percent/100)
      line('['..string.rep('=',n)..string.rep(' ',bar-n)..'] '..progress.percent..'%')
      line(''); line(progress.detail,true); line('Please leave the computer running.',true)
    elseif page=='done' then
      line('CCSacabam is ready.'); line('')
      line(options.encrypt and 'Your drive is encrypted.' or 'No password. Straight to the desktop.')
      line('Run /ccsacabam/boot.lua or reboot.',true)
      line(''); line('Startup backup:',true); line(result.backup,true)
    elseif page=='error' then
      line('Setup could not finish.'); line(''); line(tostring(problem)); line('')
      line('Your existing drive was not intentionally erased. Review the error before retrying.',true)
    end
    if page~='installing' then
      if page~='done' then controls[#controls+1]='back' end
      controls[#controls+1]='next'
    end
    if ensure then
      for i,row in ipairs(rows) do if row.id==focus then
        if i<=scroll then scroll=i-1 elseif i>scroll+visible then scroll=i-visible end
      end end
      ensure=false
    end
    scroll=math.max(0,math.min(scroll,math.max(0,#rows-visible)))
    local cursor
    for i=1,visible do
      local row=rows[scroll+i]
      if row then
        local active=row.id==focus
        local bg=active and t.accent or row.field and t.panel or t.bg
        text(3,start+i-1,row.field and (' '..row.text) or row.text,active and t.onAccent or row.muted and t.muted or t.text,bg,width)
        if row.id then hits[#hits+1]={id=row.id,x=3,y=start+i-1,w=width} end
        if active and row.field then cursor={math.min(w-1,4+#row.text),start+i-1} end
      end
    end
    if #rows>visible then text(w,finish,scroll+visible<#rows and 'v' or '^',t.muted) end
    if problem and page~='error' then text(2,h-3,problem,t.text,t.danger,w-2) end
    if page~='installing' then
      local back=page=='welcome' and 'Exit' or page=='error' and 'Exit' or 'Back'
      local next=page=='review' and (existing and 'Upgrade' or 'Install') or page=='done' and 'Finish' or page=='error' and 'Retry' or page=='welcome' and 'Begin' or 'Next'
      local function button(id,label,x,bw,primary)
        local value=(focus==id and '>' or '[')..' '..label..' '..(focus==id and '<' or ']')
        text(x,h-2,value,primary and t.onButton or t.text,primary and t.button or t.panel,bw)
        hits[#hits+1]={id=id,x=x,y=h-2,w=bw}
      end
      if page~='done' then button('back',back,2,math.min(10,w-12),false) end
      button('next',next,w-math.min(13,w-10),math.min(12,w-10),true)
    end
    text(1,h,page=='installing' and ' Installing - please wait' or (w>=40 and ' Arrows select | Enter next | Tab | F5 exit' or 'Enter next / F5 exit'),t.muted,t.panel,w)
    if cursor then native.setCursorPos(cursor[1],cursor[2]); native.setCursorBlink(true) end
  end
  local function update(phase,done,total,detail)
    local ranges={['Checking package']={0,20},['Preparing installation']={20,5},['Installing files']={25,50},
      ['Preparing personal drive']={75,20},['Finishing installation']={95,5}}
    local range=ranges[phase] or {0,100}
    local nextProgress={phase=phase,detail=detail or '',percent=math.floor(range[1]+range[2]*(total>0 and done/total or 0))}
    local changed=not progress or progress.phase~=phase or progress.detail~=nextProgress.detail or progress.percent~=nextProgress.percent
    progress=nextProgress; if changed then draw() end
    os.queueEvent('ccsacabam_setup_tick')
    while true do local e=os.pullEventRaw(); if e=='ccsacabam_setup_tick' then break elseif e=='term_resize' then draw() end end
  end
  local function activate(id)
    if id=='basic' or id=='color' or id=='render' then options.mode=id; focus=id; ensure=true; return end
    if id=='off' or id=='on' then options.encrypt=id=='on'; focus=id; ensure=true; return end
    if id=='password' or id=='confirmation' then focus=id; ensure=true; return end
    if id=='back' then
      if page=='welcome' or page=='error' then cancelled=true; finished=true
      else change(pages()[math.max(1,position()-1)]) end
    elseif id=='next' then
      if page=='done' then finished=true; return end
      if page=='error' then change(options.encrypt and not existing and 'password' or 'review'); return end
      if page=='password' then
        if #password<12 then problem='Use at least 12 characters.'; return end
        if password~=confirmation then problem='Passwords do not match.'; return end
      end
      if page=='review' then
        page='installing'; options.password=password; options.entropy=table.concat(entropy,':'); options.progress=update
        progress={phase='Starting setup',percent=0,detail='Preparing your computer'}; draw()
        local ok,value=pcall(installer.install,package,options)
        options.password,options.entropy,options.progress=nil,nil,nil; password,confirmation,entropy='','',{}
        if ok then result=value; change('done') else change('error'); problem=tostring(value) end
      else change(pages()[position()+1]) end
    end
  end
  local ok,err=pcall(function()
    while not finished do
      draw(); local e,a,b,c=os.pullEventRaw()
      if e=='terminate' or (e=='key' and a==keys.f5) then cancelled=page~='done'; finished=true
      elseif e=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shift=false
      elseif e=='key' then
        if a==keys.leftShift or a==keys.rightShift then shift=true
        elseif a==keys.left or a==keys.right then
          focus=(a==keys.left and page~='done') and 'back' or 'next'; ensure=true
        elseif a==keys.tab or a==keys.up or a==keys.down then
          local index=1; for i,id in ipairs(controls) do if id==focus then index=i end end
          local direction=(a==keys.up or (a==keys.tab and shift)) and -1 or 1
          focus=controls[(index-1+direction)%#controls+1]; ensure=true
          if a~=keys.tab and (page=='display' or page=='privacy') and focus~='back' and focus~='next' then activate(focus) end
        elseif a==keys.enter then
          if focus=='basic' or focus=='color' or focus=='render' or focus=='off' or focus=='on' then activate(focus) end
          activate(focus=='back' and 'back' or focus=='password' and 'confirmation' or 'next')
        elseif a==keys.space and page~='password' then activate(focus)
        elseif a==keys.backspace then
          if focus=='password' then password=password:sub(1,-2)
          elseif focus=='confirmation' then confirmation=confirmation:sub(1,-2)
          elseif page~='password' then activate('back') end
        elseif a==keys.pageDown then scroll=scroll+5 elseif a==keys.pageUp then scroll=scroll-5 end
      elseif (e=='char' or e=='paste') and page=='password' and (focus=='password' or focus=='confirmation') then
        a=a:gsub('[%c]',''); entropy[#entropy+1]=tostring(os.epoch and os.epoch('utc') or os.clock())
        if focus=='password' then password=(password..a):sub(1,256) else confirmation=(confirmation..a):sub(1,256) end
        problem=nil
      elseif e=='mouse_click' and color and a==1 then
        if c==1 and b>=select(1,native.getSize())-2 then cancelled=page~='done'; finished=true
        else for _,hit in ipairs(hits) do if c==hit.y and b>=hit.x and b<hit.x+hit.w then activate(hit.id); break end end end
      elseif e=='mouse_scroll' then scroll=scroll+a*2 end
    end
  end)
  password,confirmation,options.password='','',nil
  native.setCursorBlink(false); native.setTextColor(oldFG); native.setBackgroundColor(oldBG)
  native.clear(); native.setCursorPos(1,1)
  if not ok then error(err,0) end
  if cancelled then print('Setup cancelled.'); return false end
  print('CCSacabam installed. Run /ccsacabam/boot.lua or reboot.'); return true
end
return S

end)()
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
function I.validate(package,progress)
  assert(type(package)=='table' and type(package.files)=='table','Invalid package')
  local cryptoFile=assert(package.files['system/crypto.lua'],'Missing crypto module')
  local crypto=assert(load(cryptoFile.data,'@crypto','t',_ENV))()
  local total,count,index=0,0,0
  for _ in pairs(package.files) do count=count+1 end
  for path,file in pairs(package.files) do
    assert(type(path)=='string' and path~='' and fs.combine('',path)==path and path:sub(1,1)~='/' and not path:find('%.%.'),'Invalid package path')
    assert(type(file.data)=='string' and crypto.hex(crypto.sha256(file.data))==file.sha256,'Package checksum mismatch: '..path)
    if path:match('%.lua$') then assert(load(file.data,'@'..path,'t',_ENV)) end
    total=total+#file.data
    index=index+1; if progress then progress('Checking package',index,count,path) end
  end
  for _,name in ipairs({'boot.lua','system/kernel.lua','system/vault.lua','system/session.lua','apps/terminal.lua','uninstall.lua','chatplus.lua'}) do
    assert(package.files[name],'Incomplete package: '..name)
  end
  return total
end
function I.install(package,options)
  options=options or {}
  local function report(phase,done,total,detail) if options.progress then options.progress(phase,done,total,detail) end end
  local total=I.validate(package,report)
  local target,stage=I.target,I.stage
  assert(not fs.isReadOnly('/'),'Root filesystem is read-only')
  assert(not fs.exists(stage),'An interrupted install exists at '..stage..'. Inspect it before trying again.')
  local exists=fs.exists(target)
  assert(not exists or (fs.isDir(target) and fs.exists(target..'/.ccsacabam')),'Existing /ccsacabam is not an owned installation; choose a different source folder.')
  local oldInfo=exists and fs.exists(target..'/config/install.tbl') and textutils.unserialize(readFile(target..'/config/install.tbl')) or {}
  local replaced={system=true,apps=true,examples=true,sites=true,games=true}
  for path in pairs(package.files) do if not path:find('/',1,true) then replaced[path]=true end end
  local preserved=0
  if exists then
    for _,name in ipairs(fs.list(target)) do if not replaced[name] then preserved=preserved+size(target..'/'..name) end end
  end
  local free=fs.getFreeSpace('/')
  -- Backups are renamed into place. Only the new stage needs extra space;
  -- it contains new system files plus copies of the existing personal data.
  assert(type(free)~='number' or free>=total+preserved+8192,'Not enough space for a staged install and backup')
  local n=1; local backup
  repeat backup='/ccsacabam-backups/install-'..n; n=n+1 until not fs.exists(backup)
  local startupRestore=oldInfo and oldInfo.startupRestore or {}
  local movedStartup={}; local movedOld,movedNew,wroteStartup=false,false,false
  local loader='-- CCSacabam managed startup\nif not shell.run("/ccsacabam/boot.lua") then print("CCSacabam failed; CraftOS remains available.") end\n'
  local ok,err=pcall(function()
    report('Preparing installation',0,1,'Preserving existing files')
    fs.makeDir(backup)
    fs.makeDir(stage)
    if exists then
      for _,name in ipairs(fs.list(target)) do
        if not replaced[name] then fs.copy(target..'/'..name,stage..'/'..name) end
      end
    end
    local names={}; for path in pairs(package.files) do names[#names+1]=path end; table.sort(names)
    for i,path in ipairs(names) do
      local file=package.files[path]
      local dest=fs.combine(stage,path)
      if fs.exists(dest) then fs.delete(dest) end
      writeFile(dest,file.data)
      report('Installing files',i,#names,path)
    end
    writeFile(stage..'/.ccsacabam',package.version or '1.0.0')
    local mode=options.mode or (term.isColor() and 'render' or 'basic')
    if not term.isColor() then mode='basic' end
    assert(mode=='basic' or mode=='color' or mode=='render','Unknown display mode')
    writeFile(stage..'/config/display.tbl',textutils.serialize({mode=mode,welcome=true,encrypt=options.encrypt==true}))
    if options.initialize and not fs.exists(stage..'/vault/data.scv') then
      report('Preparing personal drive',0,1,options.encrypt and 'Creating encryption keys' or 'Passwordless desktop')
      local function module(name) return assert(loadfile(stage..'/system/'..name..'.lua'))() end
      local vault=module('vault').new(module('crypto'),module('storage'),stage..'/vault/data.scv')
      local good,why=vault.create(options.password,options.entropy,function(n,total)
        report('Preparing personal drive',n,total,'Creating encryption keys')
      end,options.encrypt==true)
      assert(good,why); vault.lock()
    end
    for _,path in ipairs({'/startup.lua','/startup'}) do
      if fs.exists(path) and not startupRestore[path] and not (path=='/startup.lua' and not fs.isDir(path) and readFile(path):find('CCSacabam managed startup',1,true)) then
        startupRestore[path]=backup..'/'..fs.getName(path)
      end
    end
    writeFile(stage..'/config/install.tbl',textutils.serialize({version=package.version,backup=backup,startupRestore=startupRestore}))
    report('Finishing installation',0,1,'Backing up startup and activating CCSacabam')
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
function I.run(package,args,setup)
  assert(bit32 and window and term.blit and fs.exists('/rom/modules/main/cc/require.lua'),'CCSacabam needs modern CC: Tweaked with cc.require.')
  local w,h=term.getSize(); assert(w>=20 and h>=10,'Display must be at least 20x10.')
  local mode=term.isColor() and 'render' or 'basic'; local encrypt=false
  if args and args[1]=='--yes' then mode=args[2] or mode; encrypt=args[3]=='--encrypt'
  else return assert(setup,'Setup interface is missing').run(package,I) end
  print('Checking package and staging files...')
  local ok,result=pcall(I.install,package,{mode=mode,encrypt=encrypt})
  if not ok then printError(result); return false end
  print('CCSacabam installed. Backup: '..result.backup)
  print('Run /ccsacabam/boot.lua or reboot to sign in.')
  return true
end
return I

end)()
return installer.run(package,{...},setup)
