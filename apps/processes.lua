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
