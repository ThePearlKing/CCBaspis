-- Runs inside actual CraftOS-PC, using an isolated data directory.
local results={}; local physical=fs; local rawTerm=term.current(); local failures=0
local function persist()
  local h=assert(physical.open('/test-results.json','w')); h.write(textutils.serializeJSON({complete=false,tests=results,failures=failures})); h.close()
end
local function test(name,fn)
  term.redirect(rawTerm)
  -- Each case is a separate emulator interaction; do not accumulate the
  -- watchdog budget across synchronous synthetic keyboard/mouse sequences.
  os.queueEvent('ccsacabam_test_tick'); os.pullEvent('ccsacabam_test_tick')
  local ok,err=pcall(fn)
  if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
  persist()
end
local function readFile(path) local h=assert(physical.open(path,'r')); local s=h.readAll(); h.close(); return s end
local function writeFile(path,data) physical.makeDir(physical.getDir(path)); local h=assert(physical.open(path,'w')); h.write(data); h.close() end
local function module(name) return assert(loadfile('/src/'..name..'.lua'))() end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function rejects(fn) local ok=pcall(fn); assert(not ok,'Expected an error') end
local function scan(dir)
  for _,name in ipairs(physical.list(dir)) do
    local path=physical.combine(dir,name)
    if physical.isDir(path) and name~='dist' and name:sub(1,1)~='.' then scan(path)
    elseif name:match('%.lua$') then test('Lua syntax: '..path,function() assert(loadfile(path)) end) end
  end
end
scan('/src')
local C=module('system/crypto'); local S=module('system/storage'); local Login=module('system/login')
test('SHA256 empty and abc',function()
  eq(C.hex(C.sha256('')),'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
  eq(C.hex(C.sha256('abc')),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
end)
test('HMAC RFC4231',function() eq(C.hex(C.hmac(string.rep('\11',20),'Hi There')),'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7') end)
test('PBKDF2 SHA256 4096 rounds',function() eq(C.hex(C.pbkdf2('password','salt',4096,Login.progress)),'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a') end)
test('ChaCha20 RFC8439 block',function()
  local key=''; for i=0,31 do key=key..string.char(i) end
  eq(C.hex(C.chachaBlock(key,C.unhex('000000090000004a00000000'),1)),'10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e')
  local msg=string.rep('independent oracle check\0',21)
  writeFile('/crypto-oracle.json',textutils.serializeJSON({key=C.hex(key),nonce='000000090000004a00000000',plain=C.hex(msg),cipher=C.hex(C.chacha20(key,C.unhex('000000090000004a00000000'),msg)),sha=C.hex(C.sha256(msg)),hmac=C.hex(C.hmac(key,msg))}))
end)
local package={version='1.0.0',files={}}
for path,hash in pairs(module('manifest').files) do package.files[path]={sha256=hash,data=readFile('/src/'..path):gsub('\r\n','\n'):gsub('\r','\n')} end
local I=module('tools/installer')
writeFile('/keep.txt','KEEP EXISTING FILE'); writeFile('/startup.lua','print("old startup")'); writeFile('/startup/old.lua','print("directory startup")')
test('Installer preserves files and startup backups',function()
  local info=I.install(package,{mode='render'})
  eq(readFile('/keep.txt'),'KEEP EXISTING FILE')
  eq(readFile(info.backup..'/startup.lua'),'print("old startup")')
  assert(physical.exists(info.backup..'/startup/old.lua')); assert(physical.exists('/ccsacabam/boot.lua'))
end)
test('Installer rejects corrupt payload',function()
  local old=package.files['boot.lua'].data; package.files['boot.lua'].data=old..'-- corruption'
  rejects(function() I.install(package) end); package.files['boot.lua'].data=old
  assert(readFile('/startup.lua'):find('CCSacabam managed startup',1,true))
end)
local before=readFile('/ccsacabam/boot.lua')
test('Installer rolls back a failed startup swap',function()
  local move=physical.move
  physical.move=function(a,b) if a=='/startup.lua' then error('injected disk error') end return move(a,b) end
  local ok=pcall(I.install,package,{mode='basic'}); physical.move=move
  assert(not ok); eq(readFile('/ccsacabam/boot.lua'),before); assert(physical.exists('/startup.lua')); assert(not physical.exists(I.stage))
end)
local vaultModule=module('system/vault'); vaultModule.iterations=10000
local vault=vaultModule.new(C,S,'/ccsacabam/vault/data.scv')
physical.makeDir('/ccsacabam/vault')
local password='correct horse battery staple'
test('Create encrypted vault',function() assert(vault.create(password,'test fixture',Login.progress)) end)
local vfs=vault.filesystem('/ccsacabam/home')
local secret='PRIVATE-SENTINEL-custard-97351'
test('Normal root and relative paths write only ciphertext',function()
  local h=assert(vfs.open('/secret-file.txt','w')); h.write(secret); h.close()
  h=assert(vfs.open('.chatplus/client.cfg','w')); h.write(secret); h.close()
  assert(not physical.exists('/secret-file.txt')); assert(not physical.exists('/.chatplus'))
  assert(not readFile(vault.path):find(secret,1,true)); assert(not readFile(vault.path):find('secret-file.txt',1,true))
  local r=assert(vfs.open('/ccsacabam/home/secret-file.txt','r')); eq(r.readAll(),secret); r.close()
end)
test('Filesystem handles, binary seek, rename, copy, find',function()
  vfs.makeDir('/Documents/testing')
  local h=assert(vfs.open('/Documents/testing/a.bin','wb')); h.write(0); h.write('ABC'); h.close()
  local r=assert(vfs.open('/Documents/testing/a.bin','rb')); eq(r.read(),0); eq(r.seek('set',2),2); eq(r.read(2),'BC'); r.close()
  vfs.copy('/Documents/testing/a.bin','/Documents/testing/b.bin'); vfs.move('/Documents/testing/b.bin','/Documents/testing/c.bin')
  local update=assert(vfs.open('/Documents/testing/a.bin','r+b')); update.seek('set',1); update.write('Z'); update.seek('set',0); eq(update.readAll(),'\0ZBC'); update.close()
  local empty=assert(vfs.open('/Documents/empty-append.txt','a')); empty.close(); assert(vfs.exists('/Documents/empty-append.txt')); eq(vfs.getSize('/Documents/empty-append.txt'),0)
  eq(#vfs.find('/Documents/testing/*.bin'),2); vfs.delete('/Documents/testing/c.bin')
  rejects(function() vfs.move('/Documents','/Documents/child') end)
end)
test('Vault authentication rejects wrong passwords and tampering',function()
  vault.lock(); assert(not vault.unlock('not the correct passphrase',Login.progress))
  local raw=readFile(vault.path)
  writeFile(vault.path,raw:sub(1,70)..string.char(bit32.bxor(raw:byte(71),1))..raw:sub(72))
  assert(not vault.unlock(password,Login.progress)); writeFile(vault.path,raw)
  assert(vault.unlock(password,Login.progress))
  local h=assert(vfs.open('/secret-file.txt','r')); eq(h.readAll(),secret); h.close()
end)
test('Locked handles cannot read',function()
  local h=assert(vfs.open('/secret-file.txt','r')); vault.lock(); rejects(h.readAll); assert(vault.unlock(password,Login.progress))
end)
test('Persistence failure keeps previous data',function()
  local oldWrite=S.write; S.write=function() return nil,'injected full disk' end
  local h=assert(vfs.open('/secret-file.txt','w')); h.write('replacement'); rejects(h.close); S.write=oldWrite
  local r=assert(vfs.open('/secret-file.txt','r')); eq(r.readAll(),secret); r.close()
end)
test('Interrupted encrypted writes recover without plaintext',function()
  local raw=readFile(vault.path)
  physical.move(vault.path,vault.path..'.sacabam-old')
  writeFile(vault.path..'.sacabam-new',raw)
  vault.recoverPending(); eq(readFile(vault.path),raw)
  assert(physical.exists(vault.path..'.recovery-1'))
  physical.delete(vault.path..'.recovery-1')
end)
test('Safe writer refuses to overwrite a directory',function()
  local ok=S.write('/ccsacabam','bad'); assert(not ok); assert(physical.isDir('/ccsacabam'))
end)
test('Encryption OFF removes login and keys; enabling creates a password',function()
  assert(vault.setEncryption(false)); assert(not vault.isEncrypted())
  local raw=readFile(vault.path); eq(raw:sub(1,4),'SCP2'); assert(raw:find(secret,1,true))
  assert(vault.key==nil and vault.salt==nil)
  vault.lock(); assert(vault.unlock()); assert(not vault.isEncrypted())
  assert(not vault.setEncryption(true)); assert(not vault.isEncrypted())
  assert(vault.setEncryption(true,password,'test fixture',Login.progress)); assert(vault.isEncrypted())
  assert(not readFile(vault.path):find(secret,1,true))
  local h=assert(vfs.open('/secret-file.txt','r')); eq(h.readAll(),secret); h.close()
end)
test('Failed encryption conversion preserves the previous mode and disk image',function()
  local raw=readFile(vault.path); local writer=S.write
  S.write=function() return nil,'disk full' end
  local ok=vault.setEncryption(false); S.write=writer
  assert(not ok); assert(vault.isEncrypted()); eq(readFile(vault.path),raw)
end)
test('Legacy plaintext drives open without a password and migrate on save',function()
  local body='SCP1'..vault.salt..C.be(vault.iterations)..string.rep('\0',12)..textutils.serialize(vault.files)
  writeFile(vault.path,body..C.hmac(C.hmac(vault.key,'CCSacabam v1 authentication'),body))
  vault.lock(); assert(Login.unlock(vault,{encrypt=true})); assert(not vault.isEncrypted())
  eq(vault.files['secret-file.txt'],secret); assert(vault.persist())
  eq(readFile(vault.path):sub(1,4),'SCP2')
  local raw=readFile(vault.path); vault.lock()
  writeFile(vault.path,raw:sub(1,-2)..string.char(bit32.bxor(raw:byte(-1),1)))
  assert(not vault.unlock()); writeFile(vault.path,raw); assert(vault.unlock())
  local writer=S.write; S.write=function() return nil,'disk full' end
  local ok=vault.setEncryption(true,password,'failure fixture',Login.progress); S.write=writer
  assert(not ok and not vault.isEncrypted() and vault.key==nil); eq(readFile(vault.path),raw)
  assert(vault.setEncryption(true,password,'restored fixture',Login.progress))
end)
test('Password change invalidates the old password and preserves files',function()
  assert(vault.changePassword('a different long passphrase','test',Login.progress)); vault.lock()
  assert(not vault.unlock(password,Login.progress)); assert(vault.unlock('a different long passphrase',Login.progress))
  assert(vault.changePassword(password,'restore test fixture',Login.progress))
end)
test('Cleanup failure after a save keeps the committed image authoritative',function()
  writeFile('/cleanup-test','old'); local deletion=physical.delete
  physical.delete=function(path) if path=='/cleanup-test.sacabam-old' then error('injected cleanup failure') end return deletion(path) end
  local ok,err=S.write('/cleanup-test','new'); physical.delete=deletion
  assert(ok,err); eq(readFile('/cleanup-test'),'new'); eq(readFile('/cleanup-test.sacabam-old'),'old')
end)
local env
local oldShell=shell
local Config=module('system/config')
local function loadSession(name) return assert(env.loadfile('/ccsacabam/'..name..'.lua'))() end
test('Standard Lua environment with io, settings and require',function()
  env=module('system/session').environment(vfs,_ENV)
  local ioFile=assert(env.io.open('/Documents/io.txt','w')); ioFile:write(secret); ioFile:close()
  env.settings.set('private-test',secret); assert(env.settings.save('/settings-test'))
  assert(not physical.exists('/Documents/io.txt')); assert(not physical.exists('/settings-test'))
  eq(env.require('peanut').decode('{a=42,}').a,42)
  assert(type(env.require('ganymede').form)=='function')
  local options=env.fs.complete('','/',{include_files=false,include_dirs=false,include_hidden=false})
  for _,value in ipairs(options) do assert(value:sub(-1)=='/' and (value=='../' or value:sub(1,1)~='.'),'Unexpected completion: '..value) end
  local root=env.fs.complete('/Doc','/Pictures'); assert(root[1]=='uments/' or root[2]=='uments/')
end)
local Peanut=module('system/peanut')
test('Peanut round trips data, null, escapes and empty arrays',function()
  local data=Peanut.decode('# comment\n{ title="Hello", values=[1,false,null,], escaped="a\\nb", empty=[], }')
  local round=Peanut.decode(Peanut.encode(data,true)); eq(round.title,'Hello'); eq(round.values[2],false); eq(round.values[3],Peanut.null)
  eq(round.escaped,'a\nb'); eq(Peanut.encode(round.empty),'[]')
  eq(Peanut.decode('"\\uD83D\\uDE00"'),'\240\159\152\128')
end)
test('Peanut rejects malformed, duplicate and executable input',function()
  for _,bad in ipairs({'{x=1,x=2}','[1,,2]','{x=os.shutdown()}','01','true trailing','"\\q"','"\\uD800"'}) do rejects(function() Peanut.decode(bad) end) end
  local cyc={}; cyc.self=cyc; rejects(function() Peanut.encode(cyc) end)
end)
local P=module('system/pistachio')
local Syntax=module('system/syntax')
test('Code lexer handles four languages, multiline comments/strings and embedded scripts',function()
  local samples={lua={'local n = 42 -- comment','--[=[ long','comment ]=] return "ok"','local s = [[long','string]]'},
    peanut={'{name = "value", enabled = true, n = 42} // note'},
    pistachio={'button go 2 3 12 "Go" # comment'},
    cashew={'<!-- comment','end --> <input name="test" />','<script type="pistachio">','let n = 42','</script>'}}
  for lang,lines in pairs(samples) do
    local doc=Syntax.document(lines,lang)
    for i,line in ipairs(lines) do eq(#doc.styles[i],#line) end
  end
  local doc=Syntax.document(samples.lua,'lua')
  eq(doc.styles[1]:sub(1,5),'kkkkk'); eq(doc.styles[3]:sub(1,11),string.rep('c',11))
  assert(doc.styles[3]:find('kkkkkk',1,true)); eq(doc.styles[5]:sub(1,8),string.rep('s',8))
  eq(Syntax.document(samples.cashew,'cashew').styles[4]:sub(1,3),'kkk')
  eq(Syntax.language('HELLO.PIST'),'pistachio'); eq(Syntax.language('config.peanut'),'peanut')
end)
test('Code completion knows APIs, variables and tags and skips strings/comments',function()
  local function offers(lang,source,choice)
    local lines={source}; local result=Syntax.complete(lines,lang,#source+1,1,Syntax.document(lines,lang))
    for _,word in ipairs(result) do if word==choice then return end end
    error('Missing '..choice..' for '..source)
  end
  offers('lua','term.setCur','term.setCursorPos'); offers('peanut','{"ok": tru','true')
  offers('pistachio','but','button'); offers('pistachio','fra','frame'); offers('pistachio','arr','array')
  offers('cashew','<bu','button'); offers('cashew','<a hr','href')
  local lines={'local customCount = 1','custom'}
  local result=Syntax.complete(lines,'lua',7,2,Syntax.document(lines,'lua')); eq(result[1],'customCount')
  for _,source in ipairs({'-- prin','"prin','--[[prin'}) do
    eq(#Syntax.complete({source},'lua',#source+1,1,Syntax.document({source},'lua')),0)
  end
end)
local Seal=module('system/seal'); Seal.iterations=10000
test('Pistachio seal/unseal authenticate, reject tampering and work without drive encryption',function()
  assert(vault.setEncryption(false))
  local api={caps={color=true},config=function() return {mode='color'} end,cryptoProgress=Login.progress,
    load=function(name) if name=='system/seal' then return Seal elseif name=='system/crypto' then return C end error(name) end}
  local runtime=P.runtime(P.parse('let envelope = seal("private message", "separate long password")\nlet plain = unseal(envelope, "separate long password")'),api,Peanut)
  runtime.initialize(); eq(runtime.vars.plain,'private message')
  assert(not runtime.vars.envelope:find('private message',1,true))
  local box=Seal.new(C,Login.progress)
  rejects(function() box.unseal(runtime.vars.envelope,'another long password') end)
  local message=runtime.vars.envelope
  local last=message:sub(-1)=='0' and '1' or '0'
  rejects(function() box.unseal(message:sub(1,-2)..last,'separate long password') end)
  eq(box.unseal(box.seal('',password),password),'')
  writeFile('/seal-oracle.json',textutils.serializeJSON({envelope=message,password='separate long password',plain='private message'}))
  assert(vault.setEncryption(true,password,'test fixture',Login.progress))
end)
local fake={caps={color=true},config=function() return {mode='render'} end,notify=function() end}
test('Pistachio expressions, handlers, conditionals and loops',function()
  local ast=P.parse('app "test"\nlet n = 0\nbutton add 2 2 12 "Add"\non add\nrepeat 3\nset n = n + 1\nend\nif advanced and n >= 3\nset n = n * 2\nend\nend')
  local state=P.runtime(ast,fake,Peanut); state.initialize(); state.dispatch('add'); eq(state.vars.n,6); eq(#state.layout(),1)
  eq(state.eval(P.expression('false and missing')),false)
end)
test('Pistachio rejects unknown statements and limits recursive handlers',function()
  rejects(function() P.parse('lua os.shutdown()') end)
  local state=P.runtime(P.parse('on loop\ncall loop\nend'),fake,Peanut); state.initialize(); rejects(function() state.dispatch('loop') end)
  local huge=P.runtime(P.parse('let data = "x"\non grow\nrepeat 1000\nset data = data .. data\nend\nend'),fake,Peanut)
  huge.initialize(); rejects(function() huge.dispatch('grow') end); assert(#huge.vars.data<=131072)
end)
local Cashew=module('system/cashew'); local Europa=module('system/europa')
test('Cashew parses HTML-like pages and Pistachio handlers',function()
  local doc=Cashew.parse(readFile('/ccsacabam/sites/welcome/index.cashew'))
  eq(doc.title,'Your first site'); local ast=P.parse(table.concat(doc.scripts,'\n')); assert(Cashew.safeScript(ast))
  local state=P.runtime(ast,fake,Peanut); state.initialize(); state.vars.name='Tester'; state.dispatch('greet')
  eq(state.vars.message,'Hello, Tester!')
end)
test('Cashew rejects file access, Lua, and malformed markup',function()
  rejects(function() Cashew.safeScript(P.parse('save password "/leak"')) end)
  rejects(function() Cashew.parse('<cashew><p>x</cashew>') end)
  rejects(function() Cashew.parse('<script type="lua">print(1)</script>') end)
  rejects(function() Cashew.safeScript(P.parse('let x = seal("message", "password")')) end)
  rejects(function() Cashew.safeScript(P.parse('if true\nlet x = len(unseal("data", "password"))\nend')) end)
end)
test('Europa domains, numeric addresses, links and traversal protection',function()
  eq(Europa.address('workshop.cc').url,'europa://workshop.cc/index.cashew')
  eq(Europa.address('europa://42/about.cashew').id,42)
  eq(Europa.relative('about.cashew','europa://workshop.cc/site/index.cashew'),'europa://workshop.cc/site/about.cashew')
  eq(Europa.relative('about.cashew','file:///Sites/welcome/index.cashew'),'file:///Sites/welcome/about.cashew')
  eq(Europa.relative('../welcome/index.cashew','file:///Sites/welcome/about.cashew'),'file:///Sites/welcome/index.cashew')
  eq(Europa.relative('/Sites/welcome/index.cashew','file:///Documents/other.cashew'),'file:///Sites/welcome/index.cashew')
  for _,path in ipairs({'/../vault/data.scv','/%2e%2e/data.txt','/%252e%252e/data.txt','/.settings','/x/../../etc.txt'}) do rejects(function() Europa.path(path) end) end
  eq(Europa.serve('/ccsacabam/sites/welcome','/').status,200)
  eq(Europa.serve('/ccsacabam/sites/welcome','/missing.cashew').status,404)
  eq(Europa.serve('/ccsacabam','/boot.lua').status,403)
end)
for _,name in ipairs(physical.list('/ccsacabam/examples')) do
  local dst='/ccsacabam/home/Programs/'..name
  if not vfs.exists(dst) then vfs.copy('/ccsacabam/examples/'..name,dst) end
end
vfs.copy('/ccsacabam/chatplus.lua','/ccsacabam/home/Programs/chatplus.lua')
vfs.copy('/ccsacabam/sites/welcome','/Sites/welcome')
local cache={}
local function cached(name) if not cache[name] then cache[name]=loadSession(name) end; return cache[name] end
local w,h=rawTerm.getSize(); local target=window.create(rawTerm,1,1,w,h,false)
local caps=Config.capabilities(target)
local ctx={root='/ccsacabam',load=cached,configModule=Config,config=Config.normalize({mode='render',welcome=false},caps),caps=caps,target=target,shell=oldShell,password=Login.password,
  isEncrypted=vault.isEncrypted,setEncryption=function(enabled,pw,entropy) return vault.setEncryption(enabled,pw,entropy,Login.progress) end,cryptoProgress=Login.progress}
local kernel=cached('system/kernel').new(ctx)
env.ccsacabam={launch=kernel.launch,forShell=kernel.forShell}
local function assertRunning(id)
  local p=assert(kernel.get(id),'Task missing'); assert(p.state=='running',p.error); return p
end
local function key(k) kernel.step({'key',k,false}); kernel.step({'key_up',k}) end
local function text(value) for c in value:gmatch('.') do kernel.step({'char',c}) end end
local function ctrl(k) kernel.step({'key',keys.leftCtrl}); key(k); kernel.step({'key_up',keys.leftCtrl}) end
local function dump(name)
  local lines={}
  for y=1,kernel.height do local a,b,c=kernel.frame.getLine(y); lines[y]={text=a,fg=b,bg=c} end
  writeFile('/snapshot-'..name..'.json',textutils.serializeJSON({width=kernel.width,height=kernel.height,lines=lines}))
end
test('Boot every bundled application in a real window',function()
  for _,app in ipairs(cached('system/kernel').catalog) do
    local id=kernel.launch(app.id); assertRunning(id); kernel.render(); kernel.remove(id)
  end
end)
test('Editor saves encrypted content and supports undo',function()
  local id=kernel.launch('editor','/Documents/editor-secret.txt'); assertRunning(id)
  text(secret); kernel.step({'key',keys.leftCtrl}); key(keys.s); kernel.step({'key_up',keys.leftCtrl})
  eq(cached('system/storage').read('/Documents/editor-secret.txt'),secret)
  text('Z'); kernel.step({'key',keys.leftCtrl}); key(keys.z); key(keys.s); kernel.step({'key_up',keys.leftCtrl})
  eq(cached('system/storage').read('/Documents/editor-secret.txt'),secret)
  kernel.requestClose(kernel.get(id)); assert(not kernel.get(id))
end)
test('Code Editor completes and highlights Lua, Peanut, Pistachio and Cashew in real windows',function()
  local cases={
    {'lua','local message = "hello"\n','pri','(message)','local message = "hello"\nprint(message)'},
    {'peanut','{ enabled = ','tru',', count = 42 }','{ enabled = true, count = 42 }'},
    {'pist','','but',' add 2 3 12 "Go"','button add 2 3 12 "Go"'},
    {'cashew','<','bu',' id="go">Go</button>','<button id="go">Go</button>'},
  }
  for _,sample in ipairs(cases) do
    local path='/Programs/code-editor-test.'..sample[1]
    local id=kernel.launch('code',path); local p=assertRunning(id)
    kernel.step({'paste',sample[2]}); text(sample[3]); key(keys.tab); kernel.step({'paste',sample[4]}); ctrl(keys.s)
    eq(cached('system/storage').read(path),sample[5]); assertRunning(id)
    local _,fg,bg=p.win.getLine(2)
    local gutter=(p.w-2)>24 and 5 or 0
    local marked=(caps.color and fg or bg):sub(gutter+1,gutter+math.min(#sample[5],p.w-2-gutter))
    assert(marked:find('[^'..marked:sub(1,1)..']'),'Syntax highlighting is missing for '..sample[1])
    kernel.notice=nil; kernel.render(); dump('code-'..sample[1]); kernel.remove(id)
  end
end)
test('Code Editor member completion, undo/redo and manual language selection',function()
  local id=kernel.launch('code','/Programs/completion.lua'); local p=assertRunning(id)
  text('term.setCur'); key(keys.down); key(keys.tab); ctrl(keys.z); ctrl(keys.y); ctrl(keys.s)
  eq(cached('system/storage').read('/Programs/completion.lua'),'term.setCursorPos')
  ctrl(keys.l); local _,h=p.win.getSize(); assert(p.win.getLine(h):find('peanut',1,true))
  ctrl(keys.l); assert(p.win.getLine(h):find('pistachio',1,true))
  ctrl(keys.space); key(keys.f5); assertRunning(id); kernel.remove(id)
end)
test('Settings encryption toggle requires explicit confirmation',function()
  local id=kernel.launch('settings'); assertRunning(id)
  text('7'); key(keys.enter); assert(vault.isEncrypted())
  text('7'); key(keys.f5); assert(vault.isEncrypted())
  text('7'); text('YES'); key(keys.enter); assertRunning(id); assert(not vault.isEncrypted())
  text('7'); text('YES'); key(keys.enter); text(password); key(keys.enter); text(password); key(keys.enter)
  while kernel.get(id).filter=='ccsacabam_crypto_yield' do kernel.step({os.pullEventRaw()}); assertRunning(id) end
  assert(vault.isEncrypted())
  kernel.remove(id)
end)
test('Customisation saves desktop, frame and button colours and resets the current profile',function()
  local id=kernel.launch('settings'); local p=assertRunning(id); local profile=Config.profile(ctx.config)
  local old=Config.theme(ctx.config).desktop
  key(keys.right); assert(p.win.getLine(2):find('Customisation',1,true))
  local selected=1
  local function change(field,color)
    local target
    for i,item in ipairs(Config.colorFields) do if item[1]==field then target=i end end
    while selected<target do key(keys.down); selected=selected+1 end
    while selected>target do key(keys.up); selected=selected-1 end
    key(keys.enter)
    for i=1,15 do key(keys.left) end
    local n=0; while 2^n~=color do n=n+1 end
    for i=1,n do key(keys.right) end
    key(keys.enter); assertRunning(id)
  end
  change('desktop',colors.yellow)
  eq(kernel.theme().desktop,colors.yellow)
  eq(cached('system/storage').load('/.system/settings.tbl').customColors[profile].desktop,colors.yellow)
  kernel.notice=nil; kernel.minimize(p); kernel.render()
  local _,_,bg=kernel.frame.getLine(2); eq(bg:sub(1,1),colors.toBlit(colors.yellow))
  kernel.focusTask(id)
  change('frame',colors.purple); change('close',colors.orange)
  kernel.render(); local _,_,title=kernel.frame.getLine(p.y)
  eq(title:sub(p.x+p.w-3,p.x+p.w-3),colors.toBlit(colors.orange))
  kernel.remove(id); id=kernel.launch('settings'); p=assertRunning(id); key(keys.tab)
  eq(kernel.theme().frame,colors.purple); eq(kernel.theme().close,colors.orange)
  key(keys.enter); key(keys.right); key(keys.f5); eq(kernel.theme().desktop,colors.yellow)
  kernel.render(); dump('customisation')
  text('r'); key(keys.enter); eq(kernel.theme().desktop,colors.yellow)
  text('r'); text('YES'); key(keys.enter); eq(kernel.theme().desktop,old)
  assert(next(ctx.config.customColors[profile])==nil); kernel.remove(id)
end)
test('Custom colours validate palette values, keep presets separate and roll back failed saves',function()
  local c=Config.normalize({mode='color',theme='dark',customColors={
    dark={desktop=colors.green,text=3,bogus=colors.blue},light={desktop=colors.pink},basic={desktop=colors.gray}}},
    {color=true,blit=true})
  eq(Config.theme(c).desktop,colors.green); assert(c.customColors.dark.text==nil and c.customColors.dark.bogus==nil)
  c.theme='light'; eq(Config.theme(c).desktop,colors.pink)
  c.mode='basic'; eq(Config.theme(c).desktop,colors.gray)
  local before=kernel.theme().desktop; local save=kernel.storage.save
  local id=kernel.launch('settings'); key(keys.right); key(keys.enter)
  for i=1,15 do key(keys.left) end
  kernel.storage.save=function() return nil,'Injected settings write failure' end
  key(keys.enter); kernel.storage.save=save
  assertRunning(id); eq(kernel.theme().desktop,before); key(keys.f5); kernel.remove(id)
end)
test('Wallpaper patterns persist from Settings and refresh the desktop cache',function()
  local old=ctx.config.wallpaperPattern
  local id=kernel.launch('settings'); key(keys.right); text('w'); key(keys.right); key(keys.enter)
  assert(ctx.config.wallpaperPattern~=old and ctx.config.wallpaper)
  eq(cached('system/storage').load('/.system/settings.tbl').wallpaperPattern,ctx.config.wallpaperPattern)
  kernel.remove(id); kernel.render(); local before=kernel.wallpaper
  id=kernel.launch('settings'); key(keys.right); text('w'); key(keys.right); key(keys.enter); kernel.remove(id)
  kernel.render(); assert(kernel.wallpaper~=before,'Wallpaper cache was not refreshed')
  dump('wallpaper')
  ctx.config.wallpaperPattern=old; assert(kernel.saveConfig())
end)
test('Skip typing YES defaults OFF, persists, and enables Enter/click confirmation',function()
  eq(Config.normalize({},caps).skipTypedConfirmation,false)
  local settings=kernel.launch('settings'); text('8'); assert(ctx.config.skipTypedConfirmation)
  assert(cached('system/storage').load('/.system/settings.tbl').skipTypedConfirmation)
  kernel.remove(settings)
  local id=kernel.launch('editor'); local p=assertRunning(id); text('unsaved')
  key(keys.f4); key(keys.f5); assertRunning(id)
  key(keys.f4); key(keys.enter); assert(not kernel.get(id))
  id=kernel.launch('editor'); p=assertRunning(id); text('unsaved again')
  key(keys.f4)
  kernel.step({'mouse_click',1,p.x+math.floor((p.w-2)/2)+1,p.y+p.h-3}); assertRunning(id)
  key(keys.f4); kernel.step({'mouse_click',1,p.x+1,p.y+p.h-3}); assert(not kernel.get(id))
  settings=kernel.launch('settings'); text('8'); assert(not ctx.config.skipTypedConfirmation); kernel.remove(settings)
  id=kernel.launch('editor'); text('still requires YES'); key(keys.f4); key(keys.enter); assertRunning(id)
  key(keys.f4); text('YES'); key(keys.enter); assert(not kernel.get(id))
end)
test('Sealed-note visual program masks passwords and saves only ciphertext on a plain drive',function()
  local seal=cached('system/seal'); local iterations=seal.iterations; seal.iterations=10000
  assert(vault.setEncryption(false))
  local id=kernel.launch('pistachio','/Programs/sealed-note.pist'); local p=assertRunning(id)
  local message='GUI-SEALED-NOTE-7123'; local passphrase='visual test passphrase'
  text(message); key(keys.tab); text(passphrase)
  for y=1,p.h-2 do assert(not p.win.getLine(y):find(passphrase,1,true),'Password field was not masked') end
  local function finishCrypto()
    while p.filter=='ccsacabam_crypto_yield' do kernel.step({os.pullEventRaw()}); assertRunning(id) end
  end
  key(keys.tab); key(keys.enter); finishCrypto()
  local envelope=cached('system/peanut').read('/Documents/sealed-note.peanut')
  assert(type(envelope)=='string' and envelope:sub(1,11)=='pistachio1:')
  local raw=readFile(vault.path)
  assert(raw:sub(1,4)=='SCP2' and not raw:find(message,1,true) and not raw:find(passphrase,1,true))
  kernel.step({'key',keys.leftShift}); key(keys.tab); kernel.step({'key_up',keys.leftShift})
  text(passphrase); key(keys.tab); key(keys.tab); key(keys.enter); finishCrypto()
  assert(p.win.getLine(3):find(message,1,true),'Decrypted note was not shown')
  assert(not readFile(vault.path):find(message,1,true))
  kernel.remove(id); assert(vault.setEncryption(true,password,'test fixture',Login.progress)); seal.iterations=iterations
end)
test('Two terminals have isolated shell working directories',function()
  local storage=cached('system/storage')
  assert(storage.write('/Programs/lookup-check.lua',[[
local name=...
local f=assert(fs.open('/Documents/'..name..'.txt','w')); f.write(shell.dir()); f.close()
]]))
  local first=kernel.launch('terminal'); assertRunning(first)
  text('cd /Documents'); key(keys.enter)
  local second=kernel.launch('terminal'); assertRunning(second)
  text('cd /Pictures'); key(keys.enter)
  text('lookup-check second'); key(keys.enter)
  kernel.focusTask(first); text('lookup-check first'); key(keys.enter)
  eq(storage.read('/Documents/first.txt'),'Documents'); eq(storage.read('/Documents/second.txt'),'Pictures')
  text('edit /Documents/normal-edit.txt'); key(keys.enter); assertRunning(first)
  kernel.remove(first); kernel.remove(second)
end)
test('Shared paths normalize dots, parents, absolute paths and spaces',function()
  local paths=cached('system/paths')
  for _,case in ipairs({{'.','/Sites/welcome'},{'..','/Sites'},{'./a/../b','/Sites/welcome/b'},
    {'../../../../','/'},{'/Pictures/../Documents','/Documents'},{'./a b','/Sites/welcome/a b'},
    {'\\Pictures\\..\\Documents','/Documents'}}) do
    eq(paths.resolve(case[1],'/Sites/welcome'),case[2])
  end
end)
test('Existing installs refresh stock launchers while retaining custom programs',function()
  local storage=cached('system/storage'); local programs=cached('system/programs')
  local old=[[local path = ...
if not path then print('Usage: pistachio <file.pist>'); return end
assert(ccsacabam,'Run this command inside CCSacabam').launch('pistachio',shell.resolve(path))
]]
  assert(storage.write('/Programs/pistachio.lua',old))
  local europa=assert(storage.read('/Programs/europa.lua'))
  assert(storage.write('/Programs/europa.lua',europa..'-- my custom launcher\n'))
  vfs.delete('/Programs/pmatrix.lua'); vfs.delete('/Programs/pmatrix.pist')
  programs.update('/ccsacabam',storage,C)
  eq(storage.read('/Programs/pistachio.lua'),storage.read('/ccsacabam/examples/pistachio.lua'))
  eq(storage.read('/Programs/europa.lua'),europa..'-- my custom launcher\n')
  local matrix=storage.read('/ccsacabam/examples/pmatrix.pist')
  eq(storage.read('/Programs/pmatrix.lua'),storage.read('/ccsacabam/examples/pmatrix.lua'))
  eq(storage.read('/Programs/pmatrix.pist'),matrix)
  assert(storage.write('/Programs/pmatrix.pist',matrix..'\n# user edits\n'))
  local raw=readFile(vault.path); programs.update('/ccsacabam',storage,C); eq(readFile(vault.path),raw)
  eq(storage.read('/Programs/pmatrix.pist'),matrix..'\n# user edits\n')
  assert(storage.write('/Programs/pmatrix.pist',matrix))
  assert(storage.write('/Programs/europa.lua',europa))
end)
test('pmatrix command launches its Pistachio source from another directory and returns cleanly',function()
  local terminal=kernel.launch('terminal'); assertRunning(terminal)
  text('cd /Documents'); key(keys.enter); text('pmatrix --help'); key(keys.enter)
  eq(kernel.focus,terminal); assertRunning(terminal)
  text('pmatrix'); key(keys.enter)
  local id=kernel.focus; assert(id~=terminal); local p=assertRunning(id)
  eq(p.app,'pistachio'); eq(p.title,'pmatrix'); key(keys.h)
  local _,height=p.win.getSize(); assert(p.win.getLine(height):find('Pistachio',1,true))
  key(keys.h); kernel.notice=nil; kernel.render(); dump('pmatrix')
  key(keys.q); assert(not kernel.get(id)); assertRunning(terminal)
  eq(kernel.focus,terminal); kernel.remove(terminal)
end)
test('Shell commands and Lua executables resolve relative and quoted paths',function()
  local storage=cached('system/storage')
  assert(storage.write('/Documents/paths/source.lua',[[
local arg=...
local f=assert(fs.open(shell.resolve('./ran.txt'),'w')); f.write(arg); f.close()
]]))
  assert(storage.write('/Programs/path-commands.lua',[[
assert(shell.run('cd /Documents/paths'))
assert(shell.run('mkdir "./child folder"'))
assert(shell.run('copy ./source.lua "./child folder/local.lua"'))
assert(shell.run('cd "./child folder"'))
assert(shell.run('./local.lua "quoted argument"'))
assert(shell.run('move ./ran.txt ../moved.txt'))
assert(shell.run('copy ../moved.txt ./copy.txt'))
assert(shell.run('delete ./copy.txt'))
assert(not fs.exists(shell.resolve('./copy.txt')))
assert(shell.run('ls ..'))
assert(shell.run('cd ..'))
assert(shell.run('cd .'))
assert(shell.run('./source.lua current'))
assert(shell.run('cd "./child folder"'))
assert(shell.run('../source.lua parent'))
assert(shell.run('shell ../source.lua nested'))
assert(ccsacabam.dir()=='/Documents/paths/child folder')
assert(ccsacabam.resolve('../source.lua')=='/Documents/paths/source.lua')
local h=assert(fs.open('/Documents/paths/command-complete','w')); h.write(shell.dir()); h.close()
]]))
  local id=kernel.launch('terminal'); text('path-commands'); key(keys.enter); assertRunning(id)
  eq(storage.read('/Documents/paths/moved.txt'),'quoted argument')
  eq(storage.read('/Documents/paths/ran.txt'),'current')
  eq(storage.read('/Documents/paths/child folder/ran.txt'),'nested')
  eq(storage.read('/Documents/paths/command-complete'),'Documents/paths/child folder')
  kernel.remove(id)
end)
local function command(value) kernel.step({'paste',value}); key(keys.enter) end
local function pickerName(value,mode)
  if mode=='folder' then
    ctrl(keys.l); kernel.step({'paste',value}); key(keys.enter); ctrl(keys.enter); return
  end
  if mode=='open' then key(keys.tab) end
  ctrl(keys.a)
  kernel.step({'paste',value}); key(keys.enter)
end
test('All app launches inherit the calling terminal directory and freeze it per window',function()
  local storage=cached('system/storage')
  assert(storage.write('/Programs/open-window.lua',[[local app,path=...; ccsacabam.launch(app,path)]]))
  assert(storage.write('/Documents/paths/note.txt','original'))
  local terminal=kernel.launch('terminal'); command('cd /Documents/paths')
  command('open-window editor ./note.txt'); local editor=assertRunning(kernel.focus)
  eq(editor.paths.dir(),'/Documents/paths'); text('changed '); ctrl(keys.s)
  eq(storage.read('/Documents/paths/note.txt'),'changed original')
  kernel.focusTask(terminal); command('cd /Pictures')
  local other=kernel.launch('terminal'); command('cd /Sites'); kernel.remove(other)
  kernel.focusTask(editor.id); text('again '); ctrl(keys.s)
  eq(storage.read('/Documents/paths/note.txt'),'changed again original')
  eq(editor.paths.dir(),'/Documents/paths'); kernel.remove(editor.id)
  kernel.focusTask(terminal); command('cd /Documents/paths'); command('open-window code ./source.lua')
  local code=assertRunning(kernel.focus); eq(code.app,'code'); eq(code.paths.dir(),'/Documents/paths'); kernel.remove(code.id)
  kernel.focusTask(terminal); command('open-window files "./child folder"')
  local files=assertRunning(kernel.focus); eq(files.app,'files'); eq(files.paths.dir(),'/Documents/paths/child folder')
  assert(files.win.getLine(1):find('/Documents/paths',1,true))
  kernel.remove(files.id); kernel.focusTask(terminal)
  command('open-window terminal "./child folder/local.lua"')
  local child=assertRunning(kernel.focus); eq(child.app,'terminal'); eq(child.paths.dir(),'/Documents/paths')
  kernel.remove(child.id); kernel.remove(terminal)
end)
test('File dialogs and Files navigation resolve paths against their own directory',function()
  local storage=cached('system/storage')
  local id=kernel.launchAt('/Documents/paths','editor'); text('relative save'); ctrl(keys.s)
  pickerName('./child folder/../dialog.txt','save')
  eq(storage.read('/Documents/paths/dialog.txt'),'relative save')
  ctrl(keys.o); pickerName('./dialog.txt','open'); text('loaded '); ctrl(keys.s)
  eq(storage.read('/Documents/paths/dialog.txt'),'loaded relative save'); kernel.remove(id)
  id=kernel.launchAt('/Documents/paths','sketch'); text('s')
  pickerName('./child folder/../drawing.sketch','save')
  assert(storage.read('/Documents/paths/drawing.sketch')); kernel.remove(id)
  id=kernel.launchAt('/Documents/paths','sketch','./drawing.sketch'); assertRunning(id); kernel.remove(id)
  id=kernel.launchAt('/Documents/paths','files','.'); local files=assertRunning(id)
  -- G opens the location prompt; entering a parent must use the displayed folder.
  text('g'); pickerName('./child folder','folder'); eq(files.paths.dir(),'/Documents/paths/child folder')
  text('g'); pickerName('..','folder'); eq(files.paths.dir(),'/Documents/paths')
  kernel.remove(id)
end)
test('File pickers browse encrypted files, cancel cleanly and preserve overwrite confirmation',function()
  local storage=cached('system/storage')
  assert(storage.write('/Documents/picker/a.txt','alpha')); assert(storage.write('/Documents/picker/b.txt','beta'))
  local id=kernel.launchAt('/Documents/picker','editor','./a.txt'); local p=assertRunning(id)
  ctrl(keys.o); key(keys.f5); assertRunning(id); eq(storage.read('/Documents/picker/a.txt'),'alpha')
  ctrl(keys.o); text('b'); key(keys.enter); text('new '); ctrl(keys.s)
  eq(storage.read('/Documents/picker/b.txt'),'new beta')
  local function saveAs()
    kernel.step({'key',keys.leftShift}); ctrl(keys.s); kernel.step({'key_up',keys.leftShift})
    pickerName('./a.txt','save')
  end
  saveAs(); key(keys.enter); eq(storage.read('/Documents/picker/a.txt'),'alpha')
  saveAs(); text('YES'); key(keys.enter); eq(storage.read('/Documents/picker/a.txt'),'new beta')
  assert(not physical.exists('/Documents/picker/a.txt'))
  ctrl(keys.o); key(keys.f4); assert(not kernel.get(id),'Closing a picker did not close its clean parent window')
  id=kernel.launch('editor'); text('unsaved'); ctrl(keys.s); key(keys.f4); key(keys.f5); assertRunning(id)
  key(keys.f4); text('YES'); key(keys.enter); assert(not kernel.get(id))
end)
test('Callisto chooses local pages through a file browser',function()
  local id=kernel.launchAt('/Sites/welcome','browser'); local p=assertRunning(id)
  ctrl(keys.o); text('index'); key(keys.enter); eq(p.title,'Callisto - Your first site')
  ctrl(keys.o); key(keys.f5); eq(p.title,'Callisto - Your first site')
  ctrl(keys.o); key(keys.f4); assert(not kernel.get(id))
end)
test('Pistachio programs and Peanut load/save share the inherited working directory',function()
  local storage=cached('system/storage')
  assert(storage.write('/Documents/paths/relative.pist',[[app "Relative paths"
load value "./input.peanut"
save value "./child folder/../output.peanut"
label value 1 1 15 value
]]))
  assert(storage.write('/Documents/paths/input.peanut','42'))
  local terminal=kernel.launch('terminal'); command('cd /Documents/paths')
  for _,value in ipairs({'pistachio ./relative.pist','pistachio "./child folder/../relative.pist"'}) do
    command(value); local app=assertRunning(kernel.focus); eq(app.app,'pistachio')
    eq(storage.read('/Documents/paths/output.peanut'),'42'); kernel.remove(app.id); kernel.focusTask(terminal)
  end
  kernel.remove(terminal)
end)
test('Europa launchers, Jupiter folder edits and Callisto local pages share shell paths',function()
  local terminal=kernel.launch('terminal'); command('cd /Sites/welcome')
  for _,path in ipairs({'.','../welcome','./../welcome','/Sites/welcome'}) do
    command('europa host eater.com '..path); local app=assertRunning(kernel.focus); eq(app.app,'server')
    assert(app.win.getLine(5):find('Folder: /Sites/welcome',1,true))
    assert(app.win.getLine(10):find('Home: index.cashew',1,true))
    text('r'); pickerName('../welcome','folder')
    assert(app.win.getLine(5):find('Folder: /Sites/welcome',1,true))
    kernel.remove(app.id); kernel.focusTask(terminal)
  end
  for _,path in ipairs({'./index.cashew','../welcome/index.cashew','.','file://./index.cashew'}) do
    command('europa open '..path); local app=assertRunning(kernel.focus); eq(app.app,'browser')
    eq(app.title,'Callisto - Your first site')
    key(keys.tab); key(keys.tab); key(keys.enter); eq(app.title,'Callisto - About Europa')
    key(keys.enter); eq(app.title,'Callisto - Your first site')
    kernel.remove(app.id); kernel.focusTask(terminal)
  end
  kernel.remove(terminal)
end)
test('Unmodified Lua programs use fs, io, require and settings',function()
  local storage=cached('system/storage')
  assert(storage.write('/Programs/library.lua','return {value=73}'))
  assert(storage.write('/Programs/normal program.lua',[[
local library=require('library')
local peanut=require('peanut')
assert(library.value==73)
local f=assert(fs.open('normal-relative.dat','w')); f.write('normal Lua program'); f.close()
local g=assert(io.open('/normal-io.dat','w')); g:write('normal io'); g:close()
settings.set('normal.program',73); assert(settings.save('/normal-settings'))
assert(peanut.write('/normal.peanut',{value=library.value}))
]]))
  local id=kernel.launch('terminal','/Programs/normal program.lua'); assertRunning(id)
  eq(storage.read('/normal-relative.dat'),'normal Lua program'); eq(storage.read('/normal-io.dat'),'normal io')
  assert(not physical.exists('/normal-relative.dat')); assert(not physical.exists('/normal-io.dat'))
  eq(cached('system/peanut').read('/normal.peanut').value,73); kernel.remove(id)
end)
test('Files double-click runs a root-relative Lua path with spaces',function()
  local storage=cached('system/storage')
  assert(storage.write('/Programs/launch-test/normal program.lua',[[
local f=assert(fs.open('/Documents/launched-from-files.txt','w')); f.write('ran normally'); f.close()
print('Lua program ran normally')
]]))
  local id=kernel.launch('files','/ccsacabam/home/Programs/launch-test'); local p=assertRunning(id)
  kernel.step({'mouse_click',1,p.x+3,p.y+3}); kernel.step({'mouse_click',1,p.x+3,p.y+3})
  eq(storage.read('/Documents/launched-from-files.txt'),'ran normally')
  local program=assertRunning(kernel.focus); eq(program.app,'terminal')
  for y=1,program.h-2 do assert(not program.win.getLine(y):find('No such program',1,true)) end
  kernel.remove(program.id); kernel.focusTask(id); text('e')
  local editor=assertRunning(kernel.focus); eq(editor.app,'code'); kernel.remove(editor.id); kernel.remove(id)
end)
test('Background programs receive timers without receiving another window keyboard input',function()
  local storage=cached('system/storage')
  assert(storage.write('/Programs/background.lua',[[
local timer=os.startTimer(10)
local f=fs.open('/timer-id','w'); f.write(tostring(timer)); f.close()
while true do
  local e,id=os.pullEvent()
  if e=='char' then local h=fs.open('/unexpected-key','w'); h.write(id); h.close() end
  if e=='timer' and id==timer then local h=fs.open('/timer-fired','w'); h.write('yes'); h.close(); return end
end
]]))
  local bg=kernel.launch('terminal','/Programs/background.lua'); local fg=kernel.launch('terminal')
  text('hello'); assert(not vfs.exists('/unexpected-key'))
  kernel.step({'timer',tonumber(storage.read('/timer-id'))}); eq(storage.read('/timer-fired'),'yes')
  kernel.remove(bg); kernel.remove(fg)
end)
test('Callisto renders Cashew and activates a Pistachio button',function()
  local id=kernel.launch('browser','file:///Sites/welcome/index.cashew'); local app=assertRunning(id)
  key(keys.tab); key(keys.enter)
  local found=false
  for attempt=1,30 do
    for y=1,app.h-2 do if app.win.getLine(y):find('Hello, traveller!',1,true) then found=true end end
    key(keys.down)
  end
  assert(found,'Greeting button did not render its result'); kernel.remove(id)
end)
test('Pistachio keyboard and window manager controls',function()
  local id=kernel.launch('pistachio'); local p=assertRunning(id)
  key(keys.enter); key(keys.tab); key(keys.enter); assertRunning(id)
  key(keys.f6); key(keys.f7); key(keys.right); key(keys.down); key(keys.enter)
  assert(p.x>=1 and p.y>=2); key(keys.f8); key(keys.left); key(keys.up); key(keys.enter); assert(p.w>=8 and p.h>=4)
  key(keys.f3); assert(p.minimized); key(keys.f2); assert(not p.minimized)
  kernel.render(); dump(caps.color and 'render' or 'basic'); kernel.remove(id)
end)
test('Window mouse coordinates, dragging and resizing',function()
  kernel.notice=nil
  local id=kernel.launch('editor'); local p=assertRunning(id)
  if p.maximized then kernel.maximize(p) end
  kernel.render()
  local grip,_,gripBG=kernel.frame.getLine(p.y+p.h-1)
  eq(grip:sub(p.x+p.w-3,p.x+p.w-1),caps.color and '  /' or '../')
  if caps.color then assert(gripBG:sub(p.x+p.w-1,p.x+p.w-1)~=colors.toBlit(kernel.theme().frame)) end
  local x,y=p.x,p.y
  kernel.step({'mouse_click',1,x+2,y}); kernel.step({'mouse_drag',1,x+3,y+1}); kernel.step({'mouse_up',1,x+3,y+1})
  assert(p.x>=x); kernel.step({'mouse_click',1,p.x+p.w-2,p.y+p.h-1})
  kernel.step({'mouse_drag',1,p.x+p.w-4,p.y+p.h-2}); kernel.step({'mouse_up',1,1,1}); assertRunning(id)
  dump('resize-corner')
  kernel.remove(id)
end)
test('Desktop shortcut menus remove only shortcuts and persist the choice',function()
  kernel.notice=nil; kernel.render()
  for y=1,kernel.height do
    local line=kernel.frame.getLine(y)
    assert(not line:find('Your computer',1,true) and not line:find('F1 Apps',1,true))
  end
  local hit=kernel.desktopHits[1]; eq(hit.id,'files')
  for _,item in ipairs(kernel.desktopHits) do assert(item.id~='code' and item.id~='chatplus','App was pinned automatically') end
  kernel.step({'mouse_click',2,hit.x,hit.y}); assert(kernel.context and #kernel.tasks==0)
  key(keys.down); key(keys.enter); assert(ctx.config.hiddenShortcuts.files)
  assert(cached('system/storage').load('/.system/settings.tbl').hiddenShortcuts.files)
  for _,item in ipairs(kernel.desktopHits) do assert(item.id~='files') end
  key(keys.f1); text('Files'); key(keys.enter)
  local p=kernel.get(kernel.focus); eq(p.app,'files'); kernel.remove(p.id); kernel.render()
  kernel.step({'mouse_click',2,kernel.width,kernel.height-1}); assert(kernel.context)
  key(keys.down); key(keys.down); key(keys.enter); assert(not ctx.config.hiddenShortcuts.files)
  eq(kernel.desktopHits[1].id,'files'); dump('desktop')
  key(keys.f1); text('Code Editor'); key(keys.enter)
  local code=assertRunning(kernel.focus); eq(code.app,'code'); kernel.remove(code.id)
end)
test('Window buttons have distinct colors; right click preserves app coordinates',function()
  local id=kernel.launch('terminal'); local p=assertRunning(id); kernel.render()
  local _,_,bg=kernel.frame.getLine(p.y); local left=p.x+p.w-10
  if caps.color then
    eq(bg:sub(left,left+8),string.rep(colors.toBlit(colors.yellow),3)..string.rep(colors.toBlit(colors.lime),3)..string.rep(colors.toBlit(colors.red),3))
    assert(kernel.theme().frame~=kernel.theme().desktop and kernel.theme().frame~=kernel.theme().accent)
  else
    local row=kernel.frame.getLine(p.y+1); eq(row:sub(p.x,p.x),'|')
  end
  local event
  p.co=coroutine.create(function() event={os.pullEventRaw('mouse_click')}; os.pullEventRaw() end); p.filter=nil; kernel.resume(p,{})
  kernel.step({'mouse_click',2,p.x+3,p.y+2}); eq(event[2],2); eq(event[3],3); eq(event[4],2); assert(not kernel.context)
  kernel.step({'mouse_click',2,left+7,p.y}); assert(kernel.context); assertRunning(id)
  key(keys.enter); assert(p.minimized); kernel.focusTask(id)
  kernel.step({'mouse_click',1,p.x+p.w-9,p.y}); assert(p.minimized); kernel.focusTask(id)
  local maximized=p.maximized
  kernel.step({'mouse_click',1,p.x+p.w-6,p.y}); eq(p.maximized,not maximized)
  kernel.remove(id)
end)
test('Desktop works at pocket and minimum display sizes',function()
  for _,size in ipairs({{26,20},{20,10},{51,19}}) do
    target.reposition(1,1,size[1],size[2]); kernel.step({'term_resize'})
    local id=kernel.launch('files'); assertRunning(id); kernel.render(); kernel.remove(id)
  end
end)
test('Application crash is contained and logged in encrypted drive',function()
  local id=kernel.launch('editor'); local p=assertRunning(id)
  p.co=coroutine.create(function() error(secret) end); kernel.resume(p,{}); eq(p.state,'crashed')
  assert(cached('system/storage').read('/.system/system.log'):find(secret,1,true))
  assert(not physical.exists('/.system/system.log')); kernel.remove(id)
end)
test('Same apps render in basic mode and color mode',function()
  for _,mode in ipairs({'basic','color','render'}) do
    ctx.config=Config.normalize({mode=mode},caps)
    local id=kernel.launch('pistachio'); assertRunning(id); kernel.notice=nil; kernel.render(); dump(mode); kernel.remove(id)
  end
end)
test('Upgrade preserves encrypted vault byte for byte',function()
  vault.lock(); local beforeVault=readFile(vault.path)
  I.install(package,{mode='color'}); eq(readFile(vault.path),beforeVault)
end)
test('Real boot login, lock, wrong password and logout',function()
  local observed=window.create(rawTerm,1,1,w,h,false)
  term.redirect(observed)
  local finished=false; local bootOK
  local function contains(text)
    for y=1,h do if observed.getLine(y):find(text,1,true) then return true end end
    return false
  end
  local function untilText(text)
    local start=os.clock()
    while not contains(text) do assert(os.clock()-start<30,'Timed out waiting for '..text); sleep(.05) end
  end
  local function enter(value)
    os.queueEvent('paste',value); os.queueEvent('key',keys.enter,false); os.queueEvent('key_up',keys.enter)
  end
  parallel.waitForAll(function() bootOK=shell.run('/ccsacabam/boot.lua'); finished=true end,function()
    untilText('Unlock your personal'); enter(password); untilText(' Apps    ')
    os.queueEvent('key',keys.f9,false); sleep(.1); enter(''); untilText('Unlock your personal')
    enter('wrong passphrase'); untilText('Wrong password'); enter(password); untilText(' Apps    ')
    os.queueEvent('key',keys.f10,false); sleep(.1); enter('')
  end)
  term.redirect(rawTerm); assert(finished and bootOK)
  assert(not physical.exists('/secret-file.txt')); assert(not readFile(vault.path):find(secret,1,true))
end)
test('Uninstaller restores original startup without deleting vault',function()
  assert(shell.run('/ccsacabam/uninstall.lua','--yes'))
  eq(readFile('/startup.lua'),'print("old startup")'); assert(physical.exists('/startup/old.lua')); assert(physical.exists(vault.path))
end)
local final={complete=true,tests=results,failures=failures,host=_HOST,color=caps.color,screen={w,h}}
local hnd=assert(physical.open('/test-results.json','w')); hnd.write(textutils.serializeJSON(final)); hnd.close()
os.shutdown()
