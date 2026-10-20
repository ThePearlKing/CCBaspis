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
