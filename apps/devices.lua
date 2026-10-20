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
