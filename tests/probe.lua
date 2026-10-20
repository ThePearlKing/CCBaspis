local report={}
local function test(name,fn)
  local ok,err=pcall(fn); report[#report+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
local function scan(dir)
  for _,name in ipairs(fs.list(dir)) do
    local path=fs.combine(dir,name)
    if fs.isDir(path) then scan(path)
    elseif name:match('%.lua$') then test('compile '..path,function() assert(loadfile(path)) end) end
  end
end
scan('/src')
local C=assert(loadfile('/src/system/crypto.lua'))()
test('SHA256 abc',function() assert(C.hex(C.sha256('abc'))=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') end)
test('HMAC RFC4231',function() assert(C.hex(C.hmac(string.rep('\11',20),'Hi There'))=='b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7') end)
test('PBKDF2 SHA256',function() assert(C.hex(C.pbkdf2('password','salt',2))=='ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43') end)
test('ChaCha RFC8439 block',function()
  local key=''; for i=0,31 do key=key..string.char(i) end
  assert(C.hex(C.chachaBlock(key,C.unhex('000000090000004a00000000'),1))=='10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e')
end)
local Login=assert(loadfile('/src/system/login.lua'))()
local start=os.clock()
test('PBKDF2 100k performance',function() C.pbkdf2('test-passphrase-for-probe','salt',100000,Login.progress) end)
report[#report+1]={name='time',seconds=os.clock()-start}
local h=fs.open('/probe.json','w'); h.write(textutils.serializeJSON(report)); h.close()
os.shutdown()
