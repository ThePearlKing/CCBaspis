-- Only encrypted envelopes are ever written to the physical filesystem.
local V={ iterations=100000, limit=196608 }
local physical=fs
function V.new(crypto,storage,path)
  local self={path=path,open=false,files=nil,key=nil,salt=nil,iterations=nil,serial=0}
  local function keyFor(label) return crypto.hmac(self.key,"CCSacabam v1 "..label) end
  local function header(raw)
    assert(type(raw)=="string" and #raw>=88 and raw:sub(1,4)=="SCV1","Not a CCSacabam vault")
    local iterations=crypto.number(raw,37)
    assert(iterations>=10000 and iterations<=2000000,"Unsupported key derivation parameters")
    return raw:sub(5,36),iterations,raw:sub(41,52),raw:sub(53,-33),raw:sub(-32)
  end
  function self.exists() return physical.exists(path) end
  function self.recoverPending()
    -- A power interruption can leave the old or new encrypted envelope beside
    -- the main file. Restore the last committed copy, and retain other copies.
    local old,new=path..".sacabam-old",path..".sacabam-new"
    if not physical.exists(path) then
      if physical.exists(old) then physical.move(old,path)
      elseif physical.exists(new) then physical.move(new,path) end
    end
    for _,candidate in ipairs({old,new}) do
      if physical.exists(candidate) then
        local n=1; local archive
        repeat archive=path..".recovery-"..n; n=n+1 until not physical.exists(archive)
        physical.move(candidate,archive)
      end
    end
  end
  function self.unlock(password,progress)
    local raw,err=storage.read(path); if not raw then return nil,err end
    local ok,salt,iterations,nonce,cipher,tag=pcall(header,raw)
    if not ok then return nil,tostring(salt) end
    local master=crypto.pbkdf2(password,salt,iterations,progress)
    local macKey=crypto.hmac(master,"CCSacabam v1 authentication")
    if not crypto.equal(crypto.hmac(macKey,raw:sub(1,-33)),tag) then
      return nil,"Wrong password or damaged vault."
    end
    local plain=crypto.chacha20(crypto.hmac(master,"CCSacabam v1 encryption"),nonce,cipher)
    local decoded=storage and textutils.unserialize(plain)
    if type(decoded)~="table" or decoded[""]~=true then return nil,"Invalid vault filesystem" end
    for name,value in pairs(decoded) do
      if type(name)~="string" or physical.combine("",name)~=name or (type(value)~="string" and value~=true) then
        return nil,"Invalid vault entry"
      end
    end
    self.key,self.salt,self.iterations,self.files,self.open=master,salt,iterations,decoded,true
    return true
  end
  function self.persist()
    assert(self.open,"Personal drive is locked")
    local plain=textutils.serialize(self.files)
    if #plain>V.limit then return nil,"Personal drive full (192 KiB serialized limit)." end
    self.serial=self.serial+1
    -- CC has no OS CSPRNG. A keyed nonce includes the entire content digest,
    -- time and a counter, so different contents remain distinct after rollback.
    local timing=tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock()..":"..self.serial
    local nonce=crypto.hmac(keyFor("nonce"),crypto.sha256(plain)..timing):sub(1,12)
    local cipher=crypto.chacha20(keyFor("encryption"),nonce,plain)
    local body="SCV1"..self.salt..crypto.be(self.iterations)..nonce..cipher
    return storage.write(path,body..crypto.hmac(keyFor("authentication"),body))
  end
  function self.create(password,entropy,progress)
    if self.exists() then return nil,"A vault already exists. Unlock it instead." end
    assert(type(password)=="string" and #password>=12,"Use a passphrase of at least 12 characters")
    self.salt=crypto.sha256("CCSacabam salt:"..tostring(entropy)..":"..tostring(os.getComputerID())..":"..tostring(os.epoch and os.epoch("utc") or os.time())..":"..os.clock())
    self.iterations=V.iterations
    self.key=crypto.pbkdf2(password,self.salt,self.iterations,progress)
    self.files={[""]=true,Documents=true,Pictures=true,Programs=true,[".Trash"]=true,[".system"]=true}
    self.open=true
    local ok,err=self.persist()
    if not ok then self.lock(); return nil,err end
    return true
  end
  function self.changePassword(password,entropy,progress)
    assert(self.open,"Drive is locked")
    if #password<12 then return nil,"Use at least 12 characters." end
    local oldKey,oldSalt,oldIterations=self.key,self.salt,self.iterations
    local newSalt=crypto.sha256(self.salt..tostring(entropy)..tostring(os.clock())..keyFor("password change"))
    local newKey=crypto.pbkdf2(password,newSalt,V.iterations,progress)
    self.salt,self.iterations,self.key=newSalt,V.iterations,newKey
    local ok,err=self.persist()
    if not ok then self.key,self.salt,self.iterations=oldKey,oldSalt,oldIterations end
    return ok,err
  end
  function self.lock()
    if self.files then for k in pairs(self.files) do self.files[k]=nil end end
    self.files,self.key,self.salt,self.iterations,self.open=nil,nil,nil,nil,false
  end
  function self.filesystem(mount)
    mount=physical.combine("",mount)
    local systemRoot=physical.getDir(mount)
    local out={}
    for k,v in pairs(physical) do out[k]=v end
    local function resolve(path)
      path=physical.combine("",path)
      if path==mount then return "" end
      if path:sub(1,#mount+1)==mount.."/" then return path:sub(#mount+2) end
      if path=="rom" or path:sub(1,4)=="rom/" or path=="host" or path:sub(1,5)=="host/"
        or path==systemRoot or path:sub(1,#systemRoot+1)==systemRoot.."/" then return nil end
      return path
    end
    local function hostPath(path)
      path=physical.combine("",path)
      if path=="rom/modules/main/peanut.lua" then return physical.combine(systemRoot,"system/peanut.lua") end
      if path=="rom/modules/main/ganymede.lua" then return physical.combine(systemRoot,"system/ganymede.lua") end
      if path=="rom/modules/main/europa.lua" then return physical.combine(systemRoot,"system/europa.lua") end
      if path=="host" then return "" elseif path:sub(1,5)=="host/" then return path:sub(6) end
      return path
    end
    local function check() assert(self.open,"Personal drive is locked") end
    local function mutate(fn)
      check()
      local old={}; for k,v in pairs(self.files) do old[k]=v end
      local ok,err=pcall(fn)
      if ok then ok,err=self.persist() end
      if not ok then self.files=old; error(err,3) end
    end
    local function subtree(path,key) return path==key or path:sub(1,#key+1)==key.."/" end
    function out.exists(path)
      local key=resolve(path)
      if key then check(); return self.files[key]~=nil end
      return physical.exists(hostPath(path))
    end
    function out.isDir(path)
      local key=resolve(path)
      if key then check(); return self.files[key]==true end
      return physical.isDir(hostPath(path))
    end
    function out.isReadOnly(path) return resolve(path)==nil end
    function out.getDrive(path) if resolve(path) then return "encrypted" else return physical.getDrive(hostPath(path)) end end
    function out.isDriveRoot(path) return resolve(path)=="" or (resolve(path)==nil and physical.isDriveRoot and physical.isDriveRoot(path)) or false end
    function out.list(path)
      local key=resolve(path)
      if key then
        check(); assert(self.files[key]==true,"Not a directory")
        local prefix=key=="" and "" or key.."/"
        local names={}
        for p in pairs(self.files) do
          if p:sub(1,#prefix)==prefix then
            local name=p:sub(#prefix+1)
            if name~="" and not name:find("/",1,true) then names[#names+1]=name end
          end
        end
        if key=="" then
          for _,n in ipairs({"rom",systemRoot,"host"}) do
            if not self.files[n] then names[#names+1]=n end
          end
        end
        table.sort(names); return names
      end
      local names=physical.list(hostPath(path))
      if physical.combine("",path)=="rom/modules/main" then
        names[#names+1]="peanut.lua"; names[#names+1]="ganymede.lua"; names[#names+1]="europa.lua"; table.sort(names)
      end
      if physical.combine("",path)==physical.getDir(mount) then
        local found=false; for _,n in ipairs(names) do if n==physical.getName(mount) then found=true end end
        if not found then names[#names+1]=physical.getName(mount); table.sort(names) end
      end
      return names
    end
    function out.getSize(path)
      local key=resolve(path)
      if key then check(); assert(self.files[key]~=nil,"No such file"); return self.files[key]==true and 0 or #self.files[key] end
      return physical.getSize(hostPath(path))
    end
    function out.getFreeSpace(path)
      if resolve(path) then check(); return math.max(0,V.limit-#textutils.serialize(self.files)) end
      return physical.getFreeSpace(hostPath(path))
    end
    function out.getCapacity(path) if resolve(path) then return V.limit else return physical.getCapacity and physical.getCapacity(hostPath(path)) end end
    function out.attributes(path)
      if resolve(path) then
        if not out.exists(path) then return nil end
        return {size=out.getSize(path),isDir=out.isDir(path),isReadOnly=false,created=0,modified=0,modification=0}
      end
      return physical.attributes and physical.attributes(hostPath(path))
    end
    local function parents(key)
      local dir=physical.getDir(key)
      if dir~="" then parents(dir) end
      if self.files[dir]~=nil and self.files[dir]~=true then error("Parent is a file") end
      self.files[dir]=true
    end
    function out.makeDir(path)
      local key=assert(resolve(path),"Writes belong on the encrypted personal drive")
      if self.files[key]==true then return end
      mutate(function() assert(self.files[key]==nil,"File already exists"); parents(key); self.files[key]=true end)
    end
    function out.delete(path)
      local key=assert(resolve(path),"Cannot delete outside the personal drive")
      assert(key~="","Cannot delete the personal drive")
      mutate(function() for p in pairs(self.files) do if subtree(p,key) then self.files[p]=nil end end end)
    end
    function out.move(from,to)
      local a=assert(resolve(from),"Cannot move outside the personal drive")
      local b=assert(resolve(to),"Cannot export decrypted data")
      assert(a~="" and b~="" and not subtree(b,a),"Cannot move a folder into itself")
      mutate(function()
        assert(self.files[a]~=nil,"Source does not exist"); assert(self.files[b]==nil,"Destination exists")
        parents(b)
        local changes={}
        for p,v in pairs(self.files) do if subtree(p,a) then changes[b..p:sub(#a+1)]=v end end
        for p in pairs(self.files) do if subtree(p,a) then self.files[p]=nil end end
        for p,v in pairs(changes) do self.files[p]=v end
      end)
    end
    function out.copy(from,to)
      local b=assert(resolve(to),"Cannot export decrypted data")
      local a=resolve(from)
      if a then assert(a~="" and not subtree(b,a),"Cannot copy a folder into itself") end
      assert(out.exists(from) and not out.exists(to),"Source missing or destination exists")
      local changes={}
      local function copy(src,key)
        if out.isDir(src) then
          changes[key]=true
          for _,n in ipairs(out.list(src)) do copy(physical.combine(src,n),physical.combine(key,n)) end
        else local h=assert(out.open(src,"rb")); changes[key]=h.readAll(); h.close() end
      end
      copy(from,b)
      mutate(function() parents(b); for p,v in pairs(changes) do self.files[p]=v end end)
    end
    function out.open(path,mode)
      mode=mode or "r"
      local key=resolve(path)
      if not key then
        if mode~="r" and mode~="rb" then return nil,"Read-only system/host path. Save on the personal drive." end
        return physical.open(hostPath(path),mode)
      end
      check()
      if not ({r=true,rb=true,w=true,wb=true,a=true,ab=true,["r+"]=true,["r+b"]=true,["w+"]=true,["w+b"]=true})[mode] then error("Unsupported file mode",2) end
      local update=mode:find("+",1,true)~=nil
      local writable=mode:sub(1,1)~="r" or update
      local readable=mode:sub(1,1)=="r" or update
      local binary=mode:sub(-1)=="b"
      if self.files[key]==true then return nil,"Cannot open a directory" end
      if mode:sub(1,1)=="r" and self.files[key]==nil then return nil,"No such file" end
      local data=mode:sub(1,1)=="w" and "" or self.files[key] or ""
      local pos=mode:sub(1,1)=="a" and #data or 0
      local closed,dirty=false,writable and mode:sub(1,1)=="w"
      local h={}
      local function alive() check(); assert(not closed,"File is closed") end
      function h.flush()
        alive()
        if writable and dirty then
          mutate(function() parents(key); self.files[key]=data end)
          dirty=false
        end
      end
      function h.close() alive(); h.flush(); closed=true; data="" end
      if writable then
        function h.write(value)
          alive(); value=type(value)=="number" and binary and string.char(value%256) or tostring(value)
          assert(pos+#value<=V.limit,"File too large")
          if pos>#data then data=data..string.rep("\0",pos-#data) end
          data=data:sub(1,pos)..value..data:sub(pos+#value+1); pos=pos+#value; dirty=true
        end
        function h.writeLine(value) h.write(tostring(value).."\n") end
      end
      if readable then
        function h.read(n)
          alive(); if pos>=#data then return nil end
          if n==nil and binary then pos=pos+1; return data:byte(pos) end
          n=n or 1; assert(n>=0,"Negative read")
          local s=data:sub(pos+1,pos+n); pos=pos+#s; return s
        end
        function h.readAll() alive(); local s=data:sub(pos+1); pos=#data; return s end
        function h.readLine(trailing)
          alive(); if pos>=#data then return nil end
          local endpos=data:find("\n",pos+1,true)
          local line=data:sub(pos+1,endpos and (trailing and endpos or endpos-1) or #data)
          pos=endpos or #data
          if not trailing then line=line:gsub("\r$","") end
          return line
        end
      end
      function h.seek(whence,offset)
        alive(); whence=whence or "cur"; offset=offset or 0
        local bases={set=0,cur=pos,["end"]=#data}; assert(bases[whence],"Invalid seek")
        if bases[whence]+offset<0 then return nil,"Negative seek" end
        pos=bases[whence]+offset; return pos
      end
      return h
    end
    function out.complete(part,location,includeFiles,includeDirs)
      local base=physical.combine(location or "",physical.getDir(part))
      local tail=physical.getName(part); if part:sub(-1)=="/" then base=physical.combine(location or "",part); tail="" end
      local result={}
      if out.isDir(base) then for _,name in ipairs(out.list(base)) do
        if name:sub(1,#tail)==tail then
          local isdir=out.isDir(physical.combine(base,name)); local suffix=name:sub(#tail+1)
          if isdir then
            result[#result+1]=suffix.."/"
            if includeDirs~=false and suffix~="" then result[#result+1]=suffix end
          elseif includeFiles~=false and suffix~="" then result[#result+1]=suffix end
        end
      end end
      table.sort(result); return result
    end
    function out.find(pattern)
      local result={}
      local function walk(base,parts,index)
        if index>#parts then if out.exists(base) then result[#result+1]=base end; return end
        if not out.isDir(base) then return end
        local pat="^"..parts[index]:gsub("([%^%$%(%)%%%.%[%]%+%-])","%%%1"):gsub("%*",".*"):gsub("%?",".").."$"
        for _,name in ipairs(out.list(base)) do if name:match(pat) then walk(physical.combine(base,name),parts,index+1) end end
      end
      local parts={}; for p in physical.combine("",pattern):gmatch("[^/]+") do parts[#parts+1]=p end
      walk("",parts,1); table.sort(result); return result
    end
    return out
  end
  return self
end
return V
