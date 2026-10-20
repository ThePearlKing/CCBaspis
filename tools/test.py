#!/usr/bin/env python3
"""Run tests in disposable CraftOS-PC computers; never touch the user's save."""
from pathlib import Path
import json, os, subprocess, tempfile, time, sys
ROOT=Path(__file__).resolve().parents[1]
def run(name,color=True,width=51,height=19,vanilla=True):
    directory=Path(tempfile.mkdtemp(prefix='ccsacabam-'+name+'-'))
    (directory/'config').mkdir()
    (directory/'config/global.json').write_text(json.dumps({'checkUpdates':False,'standardsMode':True,'vanilla':vanilla,'keepOpenOnShutdown':False}))
    (directory/'config/0.json').write_text(json.dumps({'isColor':color,'computerWidth':width,'computerHeight':height}))
    report=directory/'computer/0/test-results.json'
    log=(directory/'emulator.log').open('wb')
    # The headless renderer always reports color=true. SDL's dummy video driver
    # exercises real basic/advanced terminal capabilities without a visible GUI.
    command=['craftos','--gui','-d',str(directory),'--mount-ro','/src='+str(ROOT),'--exec','shell.run("/src/tests/run.lua")']
    proc=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'SDL_AUDIODRIVER':'dummy','SDL_VIDEODRIVER':'dummy'})
    result=None; deadline=time.monotonic()+240
    try:
        while time.monotonic()<deadline:
            if report.exists():
                try:
                    candidate=json.loads(report.read_text())
                    if candidate.get('complete'):
                        result=candidate;break
                except (ValueError,OSError): pass
            if proc.poll() is not None: break
            time.sleep(.2)
    finally:
        proc.terminate()
        try: proc.wait(timeout=2)
        except subprocess.TimeoutExpired: proc.kill();proc.wait()
        log.close()
    if result is None:
        print(f'{name}: emulator did not complete; artifacts {directory}',flush=True)
        if report.exists():
            candidate=json.loads(report.read_text())
            for test in candidate.get('tests',[]):
                if not test['ok']: print(' FAIL',test['name'],test.get('error'),flush=True)
            print('Last:',candidate.get('tests',[])[-1:] or 'none',flush=True)
        return False,directory
    print(f'{name}: {len(result["tests"])-result["failures"]}/{len(result["tests"])} passed; color={result["color"]}; artifacts {directory}',flush=True)
    if result['color'] != color:
        print(' FAIL emulator capability did not match requested hardware',flush=True)
        return False,directory
    for test in result['tests']:
        if not test['ok']: print(' FAIL',test['name'],test.get('error'),flush=True)
    return result['failures']==0,directory
if __name__=='__main__':
    cases=sys.argv[1:] or ['advanced','basic']
    success=True
    for case in cases:
        ok,path=run(case,color=case!='basic',width=26 if case=='pocket' else 51,height=20 if case=='pocket' else 19)
        success=success and ok
    raise SystemExit(0 if success else 1)
