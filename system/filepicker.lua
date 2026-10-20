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
