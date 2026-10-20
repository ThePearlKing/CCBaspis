local ganymede = require('ganymede')
local form = ganymede.form('Ganymede / Lua UI')
local count = 0
form.label('heading',2,3,35,'Lua programs can use native controls too.')
form.label('count',2,5,30,'Count: 0')
form.button('add',2,7,15,'Add one',function()
  count=count+1
  form.set('count','Count: '..count)
end)
form.button('quit',20,7,12,'Close',function() form.close() end)
form.run()
