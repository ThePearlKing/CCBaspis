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
    if ok then path=target; saved=contents(); api.notify(api.isEncrypted() and "Saved in encrypted drive." or "Saved in personal drive.") else api.notify(err) end
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
