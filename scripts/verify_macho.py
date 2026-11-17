"""Reject jailbreak dependencies in the standalone IPA dylib."""
import hashlib, json, pathlib, struct, sys
p=pathlib.Path(sys.argv[1]); b=p.read_bytes()
def u32(o): return struct.unpack_from('<I',b,o)[0]
assert b[:4]==bytes.fromhex('cffaedfe'), 'Expected thin Mach-O 64'
assert u32(4)==0x100000c, 'Expected ARM64'
assert u32(12)==6, 'Expected MH_DYLIB'
deps=[]; pos=32; minimum=None
for _ in range(u32(16)):
    cmd,size=struct.unpack_from('<II',b,pos)
    assert size>=8 and pos+size<=len(b), 'Invalid load command'
    if cmd in (0xc,0x80000018,0x8000001f):
        start=pos+u32(pos+8); name=b[start:b.index(b'\0',start)].decode()
        assert name.startswith(('/usr/lib/','/System/Library/Frameworks/')), 'Non-system dependency: '+name
        deps.append(name)
    if cmd==0x32:
        assert u32(pos+8)==2, 'Expected iOS device platform'
        minimum=u32(pos+12)
    elif cmd==0x25: minimum=u32(pos+8)
    pos+=size
assert deps, 'No dylib dependencies'
assert minimum is not None and minimum<=0x100000, 'Deployment target exceeds iOS 16.0'
result={'file':p.name,'sha256':hashlib.sha256(b).hexdigest(),'architecture':'arm64','minimum_ios':f'{minimum>>16}.{(minimum>>8)&255}.{minimum&255}','dependencies':deps,'runtime_tested':False}
p.with_suffix('.verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
