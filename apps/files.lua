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
