return function(api)
  local ui=api.ui; local scroll=0
  local content={
    "Welcome to CCSacabam", "Your workspace, on any computer.", "",
    "WINDOWS", "F1: app launcher (type to search)","F2: cycle running apps", "F3: minimize current window", "F4: close current window",
    "F6: maximize / restore", "F7: move window with arrow keys", "F8: resize window with arrow keys", "Enter finishes; Esc cancels move/resize.",
    "F9: lock encrypted drive", "F10: exit to CraftOS", "",
    "Advanced: drag title bars to move. Drag the bottom-right corner to resize. Click _ / + / X to minimize, maximize or close.", "",
    "FILES & PROGRAMS", "Double-click or Enter opens a file. Lua and Pistachio programs run in windows. E edits the selected file. N creates a file, D a folder. C/X/V copy, cut, paste. Delete moves to encrypted Trash; T opens Trash. Enter restores a trashed item.","",
    "EDITOR", "Ctrl+S save, Ctrl+Shift+S save as.","Ctrl+O open, Ctrl+N new, Ctrl+F find.","Ctrl+Z undo, Ctrl+Y redo.","",
    "PERSONAL DRIVE", "The password decrypts your files into memory. Names, content, temporary files and Trash are encrypted on disk. Normal filesystem paths in apps use this drive. /rom and the installed OS are read-only; /host shows your existing physical files for importing.",
    "Save before locking or exiting. Unsaved app buffers are discarded. There is no password reset. Back up the vault/data.scv file while locked.","",
    "PISTACHIO SCRIPT", "Open Pistachio from the launcher for a sample visual app. Examples are in Programs. Edit a .pist file with E in Files, then open it to run. Tab selects controls; Enter activates buttons. The same program works with monochrome and color displays.","",
    "CHAT+", "Chat+ is pre-installed. Open it from the launcher or type chatplus in Terminal. It requires a modem for hosting or joining. Its network traffic follows Chat+'s own protocol; vault encryption protects local files only.","",
    "RECOVERY", "Run boot.lua --basic for a monochrome session. A failed app does not close other apps; open Tasks to inspect it. The encrypted system log is in /.system/system.log.",
    "ComputerCraft programs share a Lua machine. Only run trusted code. The vault is encryption at rest, not protection against modified OS code or a server administrator inspecting live memory."
  }
  while true do
    local t=api.theme(); local w,h=term.getSize(); local lines={}
    for _,line in ipairs(content) do for _,part in ipairs(ui.wrap(line,w-3)) do lines[#lines+1]=part end end
    scroll=math.max(0,math.min(scroll,math.max(0,#lines-h+2)))
    ui.clear(t); ui.bar(1," CCSacabam / field guide",t)
    for y=2,h-1 do ui.text(2,y,lines[scroll+y-1] or "",t.text,t.bg,w-2) end
    ui.text(1,h,"Arrows / PageUp / PageDown / wheel",t.muted,t.panel,w)
    local e,a=os.pullEventRaw()
    if e=="sacabam_close" or e=="terminate" then return
    elseif e=="mouse_scroll" then scroll=scroll+a*3
    elseif e=="key" then
      if a==keys.up then scroll=scroll-1 elseif a==keys.down then scroll=scroll+1
      elseif a==keys.pageUp then scroll=scroll-h+2 elseif a==keys.pageDown then scroll=scroll+h-2
      elseif a==keys.home then scroll=0 end
    end
  end
end
