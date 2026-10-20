local peanut = require('peanut')
local path = '/Documents/example.peanut'
local value = {name='CCSacabam', enabled=true, count=42, tags=peanut.array({'lua','pistachio'}), optional=peanut.null}
assert(peanut.write(path,value))
local restored = assert(peanut.read(path))
print('Saved and read encrypted Peanut data:')
print(peanut.encode(restored,true))
