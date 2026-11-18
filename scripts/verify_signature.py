"""Check embedded ad-hoc CodeDirectory hashes without an Apple runtime."""
import hashlib,json,pathlib,struct,sys
p=pathlib.Path(sys.argv[1]); b=p.read_bytes()
u=lambda o:struct.unpack_from('<I',b,o)[0]
be=lambda o:struct.unpack_from('>I',b,o)[0]
pos=32; signature=None
for _ in range(u(16)):
    cmd,size=u(pos),u(pos+4)
    if cmd==0x1d: signature=(u(pos+8),u(pos+12))
    pos+=size
assert signature, 'No embedded signature'
start,length=signature
assert start+length<=len(b)
assert be(start)==0xfade0cc0, 'Expected embedded signature superblob'
checked=0
for i in range(be(start+8)):
    kind,relative=struct.unpack_from('>II',b,start+12+i*8)
    cd=start+relative
    if be(cd)!=0xfade0c02: continue
    version,flags,hashoff,identoff,special,slots,limit=struct.unpack_from('>IIIIIII',b,cd+8)
    hashsize,hashtype,platform,pageshift=struct.unpack_from('BBBB',b,cd+36)
    assert flags & 2, 'Expected ad-hoc flag'
    assert hashtype==2 and hashsize==32, 'Expected SHA256 CodeDirectory'
    assert limit==start, 'Code limit must cover file through signature start'
    pagesize=1<<pageshift
    assert slots==(limit+pagesize-1)//pagesize
    for n in range(slots):
        digest=hashlib.sha256(b[n*pagesize:min((n+1)*pagesize,limit)]).digest()
        assert b[cd+hashoff+n*hashsize:cd+hashoff+(n+1)*hashsize]==digest, 'Code page hash mismatch'
    checked+=slots
assert checked, 'No SHA256 code slots checked'
result={'file':p.name,'embedded_ad_hoc_signature':'valid SHA256 code pages','checked_pages':checked,'requires_ipa_resigning':True,'runtime_tested':False}
p.with_suffix('.signature.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
