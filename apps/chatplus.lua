-- Chat+ uses the same standard shell as every other Lua program.
return function(api)
  api.setTitle("Chat+ / Terminal")
  api.notify("Type: chatplus host <room>  or  chatplus join <room> <name>")
  return api.load("apps/terminal")(api)
end
