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
