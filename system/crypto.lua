-- SHA-256, HMAC-SHA-256, PBKDF2 and IETF ChaCha20. Pure Lua / bit32.
-- Encrypt-then-MAC envelope; see docs/SECURITY.md for the format and limits.
local C = {}
local unpack=table.unpack or unpack
assert(bit32, "CCSacabam encryption requires bit32 (CC: Tweaked recommended)")
local bx,ba,bn,rr,rs,ls,lr = bit32.bxor,bit32.band,bit32.bnot,bit32.rrotate,bit32.rshift,bit32.lshift,bit32.lrotate
local MOD = 4294967296
local H0={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local constants={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
function C.be(n) return string.char(rs(n,24),ba(rs(n,16),255),ba(rs(n,8),255),ba(n,255)) end
function C.number(s,p)
  local a,b,c,d=s:byte(p,p+3); return ((a*256+b)*256+c)*256+d
end
local function le(n) return string.char(ba(n,255),ba(rs(n,8),255),ba(rs(n,16),255),rs(n,24)) end
local function readle(s,p)
  local a,b,c,d=s:byte(p,p+3); return ((d*256+c)*256+b)*256+a
end
local function compress(h,s,p)
  local w={}
  for i=1,16 do w[i]=C.number(s,p+(i-1)*4) end
  for i=17,64 do
    local a,b=w[i-15],w[i-2]
    w[i]=(w[i-16]+bx(rr(a,7),rr(a,18),rs(a,3))+w[i-7]+bx(rr(b,17),rr(b,19),rs(b,10)))%MOD
  end
  local a,b,c,d,e,f,g,j=unpack(h)
  for i=1,64 do
    local t1=(j+bx(rr(e,6),rr(e,11),rr(e,25))+bx(ba(e,f),ba(bn(e),g))+constants[i]+w[i])%MOD
    local t2=(bx(rr(a,2),rr(a,13),rr(a,22))+bx(ba(a,b),ba(a,c),ba(b,c)))%MOD
    j,g,f,e,d,c,b,a=g,f,e,(d+t1)%MOD,c,b,a,(t1+t2)%MOD
  end
  local v={a,b,c,d,e,f,g,j}
  for i=1,8 do h[i]=(h[i]+v[i])%MOD end
end
local function finish(s,initial,prior)
  local h={}; for i=1,8 do h[i]=initial[i] end
  local n=#s+(prior or 0)
  s=s.."\128"..string.rep("\0",(55-#s)%64)..C.be(math.floor(n/536870912))..C.be((n*8)%MOD)
  for i=1,#s,64 do compress(h,s,i) end
  local out={}; for i=1,8 do out[i]=C.be(h[i]) end
  return table.concat(out)
end
function C.sha256(s) return finish(s,H0,0) end
function C.hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
function C.unhex(s)
  assert(#s%2==0 and not s:find("[^%da-fA-F]"),"Invalid hex")
  return (s:gsub("..",function(v) return string.char(tonumber(v,16)) end))
end
function C.hmacFunction(key)
  if #key>64 then key=C.sha256(key) end
  key=key..string.rep("\0",64-#key)
  local ip,op={},{}
  for i=1,64 do ip[i]=string.char(bx(key:byte(i),0x36)); op[i]=string.char(bx(key:byte(i),0x5c)) end
  local ih,oh={},{}; for i=1,8 do ih[i]=H0[i]; oh[i]=H0[i] end
  compress(ih,table.concat(ip),1); compress(oh,table.concat(op),1)
  return function(s) return finish(finish(s,ih,64),oh,64) end
end
function C.hmac(key,s) return C.hmacFunction(key)(s) end
function C.pbkdf2(password,salt,iterations,progress)
  assert(iterations>=1 and iterations%1==0,"Invalid PBKDF2 iteration count")
  local prf=C.hmacFunction(password)
  local u=prf(salt..C.be(1)); local result={u:byte(1,32)}
  for n=2,iterations do
    u=prf(u)
    for j=1,32 do result[j]=bx(result[j],u:byte(j)) end
    if progress and n%128==0 then progress(n,iterations) end
  end
  return string.char(unpack(result))
end
local function quarter(s,a,b,c,d)
  s[a]=(s[a]+s[b])%MOD; s[d]=lr(bx(s[d],s[a]),16)
  s[c]=(s[c]+s[d])%MOD; s[b]=lr(bx(s[b],s[c]),12)
  s[a]=(s[a]+s[b])%MOD; s[d]=lr(bx(s[d],s[a]),8)
  s[c]=(s[c]+s[d])%MOD; s[b]=lr(bx(s[b],s[c]),7)
end
function C.chachaBlock(key,nonce,counter)
  assert(#key==32 and #nonce==12,"Invalid ChaCha20 key/nonce")
  local state={0x61707865,0x3320646e,0x79622d32,0x6b206574}
  for i=1,8 do state[4+i]=readle(key,(i-1)*4+1) end
  state[13]=counter
  for i=1,3 do state[13+i]=readle(nonce,(i-1)*4+1) end
  local x={}; for i=1,16 do x[i]=state[i] end
  for _=1,10 do
    quarter(x,1,5,9,13); quarter(x,2,6,10,14); quarter(x,3,7,11,15); quarter(x,4,8,12,16)
    quarter(x,1,6,11,16); quarter(x,2,7,12,13); quarter(x,3,8,9,14); quarter(x,4,5,10,15)
  end
  local out={}; for i=1,16 do out[i]=le((x[i]+state[i])%MOD) end
  return table.concat(out)
end
function C.chacha20(key,nonce,text,counter)
  local out={}; counter=counter or 1
  for pos=1,#text,64 do
    local block=C.chachaBlock(key,nonce,counter); counter=counter+1
    local part={}
    for i=1,math.min(64,#text-pos+1) do part[i]=string.char(bx(text:byte(pos+i-1),block:byte(i))) end
    out[#out+1]=table.concat(part)
  end
  return table.concat(out)
end
function C.equal(a,b)
  if #a~=#b then return false end
  local v=0; for i=1,#a do v=bit32.bor(v,bx(a:byte(i),b:byte(i))) end
  return v==0
end
return C
