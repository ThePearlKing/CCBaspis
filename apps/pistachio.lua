return function(api,path)
  local ui=api.ui
  path=path or fs.combine(api.home,'Programs/counter.pist')
  local source,err=api.storage.read(path); assert(source,err)
  local lang=api.load('system/pistachio'); local peanut=api.load('system/peanut')
  local state=lang.runtime(lang.parse(source),api,peanut); state.initialize()
  local timers={}
  api.onExit(function() for id in pairs(timers) do os.cancelTimer(id) end end)
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
    if control.kind~='input' and control.kind~='password' then state.dispatch(control.id) end
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
      elseif a==keys.space and control and control.kind~='input' and control.kind~='password' then activate(control)
      elseif a==keys.backspace and control and (control.kind=='input' or control.kind=='password') then state.vars[control.bind]=tostring(state.vars[control.bind]):sub(1,-2); state.dispatch(control.id) end
    elseif (e=='char' or e=='paste') and control and (control.kind=='input' or control.kind=='password') then
      state.vars[control.bind]=(tostring(state.vars[control.bind])..a:gsub('[%c]','')):sub(1,1024); state.dispatch(control.id)
    elseif e=='mouse_click' then
      for i,v in ipairs(controls) do if b>=v.x and b<v.x+v.w and c==v.y then focus=i; activate(v); break end end
    end
  end
  for id in pairs(timers) do os.cancelTimer(id) end
end
