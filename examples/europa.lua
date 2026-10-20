local command,a,b=...
assert(ccsacabam,'Use this launcher inside CCSacabam')
if command=='host' then ccsacabam.launch('server',a,b)
elseif command=='open' then ccsacabam.launch('browser',a)
else print('europa host <domain> [site-folder]'); print('europa open <europa://domain/path>') end
