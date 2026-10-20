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
