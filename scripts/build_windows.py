"""Cross-build the same standalone dylib with Clang/LLD and an iPhoneOS SDK."""
import argparse, hashlib, json, pathlib, subprocess, sys

parser=argparse.ArgumentParser()
parser.add_argument('--llvm-bin',type=pathlib.Path,required=True)
parser.add_argument('--sdk',type=pathlib.Path,required=True)
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent
sdk=args.sdk.resolve(); llvm=args.llvm_bin.resolve()
clang=llvm/'clang.exe'; linker=llvm/'ld.lld.exe'
assert clang.is_file() and linker.is_file(), 'Clang and LLD are required'
assert (sdk/'System/Library/Frameworks/UIKit.framework/Headers/UIKit.h').is_file(), 'Invalid iPhoneOS SDK'
# Git for Windows may have checked text-based link stubs out as CRLF.
# LLVM's TAPI file-magic detector requires the original LF header.
sdk_long=pathlib.Path(chr(92)*2+'?'+chr(92)+str(sdk))
normalized=0
for stub in sdk_long.rglob('*.tbd'):
    data=stub.read_bytes()
    if bytes([13,10]) in data:
        stub.write_bytes(data.replace(bytes([13,10]),bytes([10]))); normalized+=1
print('Normalized TAPI line endings:',normalized,flush=True)
out=root/'out'; obj=out/'objects'; obj.mkdir(parents=True,exist_ok=True)
def run(command):
    result=subprocess.run([str(x) for x in command],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace')
    if result.stdout: print(result.stdout,end='')
    if result.returncode: raise SystemExit(result.returncode)
    return result.stdout
sources=['RIRuntime.m','RICommon.m','RIDownloader.m','RIMediaResolver.m','RIMedia.m','Menu.m','Tweak.m']
objects=[]
for source in sources:
    target=obj/(pathlib.Path(source).stem+'.o'); objects.append(target)
    print('Compiling',source,flush=True)
    run([clang,'-target','arm64-apple-ios16.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-O2','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-Wno-deprecated-declarations','-c',source,'-o',target])
dylib=out/'RiseInsta.dylib'
run([linker,'-flavor','darwin','-arch','arm64','-dylib','-platform_version','ios','16.0','16.5','-syslibroot',sdk,'-L',sdk/'usr/lib','-F',sdk/'System/Library/Frameworks','-install_name','@rpath/RiseInsta.dylib','-adhoc_codesign','-o',dylib,*objects,'-lobjc','-lSystem','-framework','Foundation','-framework','UIKit','-framework','Photos','-framework','UniformTypeIdentifiers','-framework','QuartzCore','-framework','CoreGraphics'])
run([sys.executable,'scripts/verify_macho.py',dylib])
run([sys.executable,'scripts/verify_signature.py',dylib])
manifest={'compiler':run([clang,'--version']),'linker':run([linker,'-flavor','darwin','--version']),'sdk':str(sdk),'deployment_target':'iOS 16.0','architecture':'arm64','signature':'LLD ad-hoc; re-sign with the host IPA','runtime_tested':False}
try:
    manifest['sdk_repository_commit']=subprocess.check_output(['git','-C',str(sdk.parent),'rev-parse','HEAD'],text=True).strip()
except (subprocess.CalledProcessError,FileNotFoundError): pass
(out/'toolchain.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(out/'SHA256SUMS').write_text(hashlib.sha256(dylib.read_bytes()).hexdigest()+'  RiseInsta.dylib\n',encoding='utf-8')
print('Built:',dylib)
