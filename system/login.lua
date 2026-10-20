local L={}
function L.password(label,subtitle)
  local value,entropy="",{}
  local function draw()
    local w,h=term.getSize()
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
    term.setCursorPos(2,2); term.write("CCSacabam")
    term.setCursorPos(2,4); term.write(label:sub(1,w-2))
    local y=6
    for _,line in ipairs(subtitle or {}) do term.setCursorPos(2,y); term.write(line:sub(1,w-2)); y=y+1 end
    local py=math.min(h-3,y+1)
    term.setCursorPos(2,py); term.write("> "..string.rep("*",math.min(#value,w-5)))
    term.setCursorBlink(true)
    term.setCursorPos(2,h-1); term.write(("Enter: unlock / F5: leave"):sub(1,w-2))
    term.setCursorPos(math.min(w,4+#value),py)
  end
  draw()
  while true do
    local e,a=os.pullEventRaw()
    entropy[#entropy+1]=tostring(os.epoch and os.epoch("utc") or os.clock())..":"..os.clock()
    if e=="char" or e=="paste" then value=value..a:gsub("[%c]",""):sub(1,256-#value)
    elseif e=="key" and a==keys.backspace then value=value:sub(1,-2)
    elseif e=="key" and a==keys.enter then term.setCursorBlink(false); return value,table.concat(entropy,";")
    elseif e=="terminate" or (e=="key" and a==keys.f5) then term.setCursorBlink(false); return nil end
    draw()
  end
end
function L.progress(n,total)
  if n%1024==0 then
    local _,h=term.getSize(); term.setCursorPos(2,h-2); term.clearLine()
    term.write("Deriving key... "..math.floor(n/total*100).."%")
  end
  os.queueEvent("ccsacabam_crypto_yield")
  os.pullEvent("ccsacabam_crypto_yield")
end
function L.unlock(vault,options)
  local encrypted=options and options.encrypt==true
  local message
  while true do
    if not vault.exists() then
      local password,entropy=L.password("Create your personal drive",{
        "Use a passphrase of 12+ characters.",
        encrypted and "Encryption ON: saved files are protected." or "Encryption OFF: login only; files are readable.",
        message or "There is no password reset. Keep it safe."})
      if not password then return false end
      if #password<12 then message="Passphrase must have at least 12 characters."
      else
        local again=L.password("Confirm your passphrase",{"Enter the same passphrase again."})
        if not again then return false end
        if password~=again then message="Passphrases did not match."
        else
          local ok,err=vault.create(password,entropy,L.progress,encrypted)
          password,again=nil,nil
          if ok then return true end
          message=err
        end
      end
    else
      local password=L.password("Unlock your personal drive",{message or (vault.isEncrypted() and "Your files are encrypted while locked." or "Encryption OFF. Files are readable outside the OS.")})
      if not password then return false end
      local ok,err=vault.unlock(password,L.progress)
      password=nil
      if ok then return true end
      message=err
      sleep(1)
    end
  end
end
return L
