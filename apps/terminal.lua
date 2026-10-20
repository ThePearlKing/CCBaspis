return function(api,program)
  local parent={}; for k,v in pairs(api.shell) do parent[k]=v end
  parent.dir=function() return api.home end
  parent.path=function() return ".:/"..fs.combine(api.home,"Programs")..":"..api.shell.path() end
  local t=api.theme(); term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorPos(1,1)
  print("CCSacabam / "..(api.isEncrypted() and "encrypted" or "personal").." terminal")
  print("Save files in /"..api.home)
  print("F1 apps | F2 switch | F4 close")
  local function shellTask()
    if program then
      os.run({shell=parent,multishell=false},"/rom/programs/shell.lua",'"'..program..'"')
      print("Program finished. Press any key."); os.pullEvent("key")
    else os.run({shell=parent,multishell=false},"/rom/programs/shell.lua") end
  end
  parallel.waitForAny(shellTask,function()
    while true do
      local e=os.pullEventRaw()
      if e=="sacabam_close" or e=="terminate" then return end
    end
  end)
end
