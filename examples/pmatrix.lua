-- The animation lives in pmatrix.pist; this is just the shell entry point.
local option=...
if option then
  if option~='--help' and option~='-h' then printError('Unknown option: '..option) end
  print('pmatrix - Matrix rain in Pistachio Script')
  print('Space pause | Up/Down speed | 1-9 speed')
  print('C colour | H help | Q/Esc quit | F6 maximise')
  return
end
local source=fs.combine(fs.getDir(shell.getRunningProgram()),'pmatrix.pist')
assert(ccsacabam,'Run pmatrix inside CCSacabam').launch('pistachio','/'..source)
