-- Password-encrypted messages for native Pistachio programs. No drive key access.
local S={iterations=100000,maxPlain=32768}
function S.new(C,progress)
  local serial=0; local box={}
  local function password(value)
    assert(type(value)=='string' and #value>=12 and #value<=256,'Use a passphrase of 12..256 characters')
  end
  local function key(master,label) return C.hmac(master,'Pistachio seal v1 '..label) end
  function box.seal(text,passphrase)
    assert(type(text)=='string' and #text<=S.maxPlain,'seal needs text of at most 32 KiB')
    password(passphrase); serial=serial+1
    local timing=tostring(os.epoch and os.epoch('utc') or os.time())..':'..os.clock()..':'..os.getComputerID()..':'..serial
    local salt=C.sha256('Pistachio salt:'..timing)
    local master=C.pbkdf2(passphrase,salt,S.iterations,progress)
    local nonce=C.hmac(key(master,'nonce'),C.sha256(text)..timing):sub(1,12)
    local body='PCS1'..salt..C.be(S.iterations)..nonce..C.chacha20(key(master,'encryption'),nonce,text)
    return 'pistachio1:'..C.hex(body..C.hmac(key(master,'authentication'),body))
  end
  function box.unseal(envelope,passphrase)
    password(passphrase)
    assert(type(envelope)=='string' and envelope:sub(1,11)=='pistachio1:' and #envelope<=11+(S.maxPlain+84)*2,'Invalid sealed message')
    local raw=C.unhex(envelope:sub(12))
    assert(#raw>=84 and raw:sub(1,4)=='PCS1','Invalid sealed message')
    local iterations=C.number(raw,37)
    assert(iterations>=10000 and iterations<=2000000,'Unsupported key derivation parameters')
    local master=C.pbkdf2(passphrase,raw:sub(5,36),iterations,progress)
    assert(C.equal(C.hmac(key(master,'authentication'),raw:sub(1,-33)),raw:sub(-32)),'Wrong password or damaged sealed message')
    return C.chacha20(key(master,'encryption'),raw:sub(41,52),raw:sub(53,-33))
  end
  return box
end
return S
