#!/usr/bin/env python3
"""Run tests in disposable CraftOS-PC computers; never touch the user's save."""
from pathlib import Path
import hashlib, hmac, json, os, shutil, struct, subprocess, tempfile, time, sys
ROOT=Path(__file__).resolve().parents[1]
def run(name,color=True,width=51,height=19,vanilla=True):
    directory=Path(tempfile.mkdtemp(prefix='ccsacabam-'+name+'-'))
    (directory/'config').mkdir()
    network=name in ('network','network-zero')
    host_id=0 if name=='network-zero' else 1
    client_id=1-host_id
    (directory/'config/global.json').write_text(json.dumps({'checkUpdates':False,'standardsMode':True,'vanilla':vanilla and not network,'keepOpenOnShutdown':False}))
    (directory/'config/0.json').write_text(json.dumps({'isColor':color,'computerWidth':width,'computerHeight':height}))
    report=directory/f'computer/{client_id if network else 0}/test-results.json'
    log=(directory/'emulator.log').open('wb')
    # The headless renderer always reports color=true. SDL's dummy video driver
    # exercises real basic/advanced terminal capabilities without a visible GUI.
    if network:
        for computer_id in (0,1):
            computer=directory/f'computer/{computer_id}'; computer.mkdir(parents=True)
            script_name='network-host.lua' if computer_id==host_id else 'network.lua'
            shutil.copy(ROOT/'tests'/script_name,computer/'startup.lua')
            for folder in ('system','apps','sites','examples'):
                shutil.copytree(ROOT/folder,computer/'ccsacabam'/folder)
            shutil.copy(ROOT/'chatplus.lua',computer/'ccsacabam/chatplus.lua')
    script='network.lua' if network else 'fresh.lua' if name.startswith('fresh') else 'setup.lua' if name.startswith('setup') else 'picker.lua' if name.startswith('picker') else 'run.lua'
    command=['craftos','--gui','-d',str(directory),'--mount-ro','/src='+str(ROOT),'--exec',f'shell.run("/src/tests/{script}", "{name}")']
    if network:
        # Each computer has its own host/client startup, including host ID 0.
        command=command[:-2]
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
    success=result['failures']==0
    if success and not network and not name.startswith(('setup','picker')):
        try:
            if name.startswith('fresh'): fresh_oracle(directory/'computer/0')
            else: oracle(directory/'computer/0')
            print(f'{name}: independent crypto and plaintext-storage checks passed',flush=True)
        except Exception as error:
            print(f'{name}: independent check FAILED: {error}',flush=True); success=False
    return success,directory

def fresh_oracle(computer):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms
    raw=(computer/'ccsacabam/vault/data.scv').read_bytes()
    password=json.loads((computer/'fresh-oracle.json').read_text())['password'].encode()
    assert raw[:4]==b'SCV1' and int.from_bytes(raw[36:40],'big')==100000
    master=hashlib.pbkdf2_hmac('sha256',password,raw[4:36],100000)
    key=lambda label: hmac.new(master,b'CCSacabam v1 '+label,'sha256').digest()
    assert hmac.compare_digest(hmac.new(key(b'authentication'),raw[:-32],'sha256').digest(),raw[-32:])
    plain=Cipher(algorithms.ChaCha20(key(b'encryption'),struct.pack('<I',1)+raw[40:52]),mode=None).decryptor().update(raw[52:-32])
    assert b'Programs/sealed-note.pist' in plain and b'Sites/welcome/index.cashew' in plain

def oracle(computer):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms
    def decrypt(key,nonce,cipher):
        return Cipher(algorithms.ChaCha20(key,struct.pack('<I',1)+nonce),mode=None).decryptor().update(cipher)
    sample=json.loads((computer/'crypto-oracle.json').read_text())
    key,nonce,plain,cipher=(bytes.fromhex(sample[k]) for k in ('key','nonce','plain','cipher'))
    assert decrypt(key,nonce,cipher)==plain,'ChaCha20 oracle mismatch'
    assert hashlib.sha256(plain).hexdigest()==sample['sha'],'SHA-256 oracle mismatch'
    assert hmac.new(key,plain,'sha256').hexdigest()==sample['hmac'],'HMAC oracle mismatch'
    for path,password,prefix,expected in [
        (computer/'ccsacabam/vault/data.scv',b'correct horse battery staple',b'CCSacabam v1 ',b'PRIVATE-SENTINEL-custard-97351'),
        (computer/'seal-oracle.json',b'separate long password',b'Pistachio seal v1 ',b'private message'),
    ]:
        if path.suffix=='.json':
            raw=bytes.fromhex(json.loads(path.read_text())['envelope'][11:])
        else: raw=path.read_bytes()
        master=hashlib.pbkdf2_hmac('sha256',password,raw[4:36],int.from_bytes(raw[36:40],'big'))
        authentication=hmac.new(master,prefix+b'authentication','sha256').digest()
        assert hmac.compare_digest(hmac.new(authentication,raw[:-32],'sha256').digest(),raw[-32:]),'Envelope MAC mismatch'
        encryption=hmac.new(master,prefix+b'encryption','sha256').digest()
        assert expected in decrypt(encryption,raw[40:52],raw[52:-32]),'Envelope decryption mismatch'
    secret=b'PRIVATE-SENTINEL-custard-97351'
    for path in computer.rglob('*'):
        if path.is_file():
            assert secret not in path.read_bytes(),f'Plaintext leaked to {path.relative_to(computer)}'
        assert 'secret-file' not in path.name,f'Private filename leaked: {path}'
if __name__=='__main__':
    cases=sys.argv[1:] or ['advanced','basic']
    success=True
    for case in cases:
        small=case.startswith('setup') or case.startswith('picker-small')
        ok,path=run(case,color=case!='basic' and not case.endswith('-basic'),width=20 if small else 26 if case=='pocket' else 51,height=10 if small else 20 if case=='pocket' else 19)
        success=success and ok
    raise SystemExit(0 if success else 1)
