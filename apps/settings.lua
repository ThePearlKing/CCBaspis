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
