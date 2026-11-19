"""Freeze and sign a Windows-hosted Android private beta. Secrets stay in the user's local DPAPI store."""
import argparse
from contextlib import contextmanager
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
PACKAGE="dev.punklegion.beta"
ALIAS="punklegion-private-beta"
SERVICES=("room","solo","party","camp","treasure")


def endpoint_host(value):
    if not isinstance(value,str):
        raise argparse.ArgumentTypeError("Endpoint host must be a canonical IPv4 unicast address")
    try:
        host=ipaddress.IPv4Address(value)
    except ipaddress.AddressValueError as error:
        raise argparse.ArgumentTypeError("Endpoint host must be a canonical IPv4 unicast address") from error
    if host.is_unspecified or host.is_multicast or host.is_reserved or host.is_loopback or host.packed[0]==0:
        raise argparse.ArgumentTypeError("Endpoint host must be a canonical IPv4 unicast address")
    return str(host)


def private_network(snapshot):
    settings={}
    for line in (snapshot/"deploy/private-beta.env").read_text(encoding="utf-8-sig").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key,value=line.split("=",1)
        if key in settings:
            raise ValueError("Duplicate private beta setting: "+key)
        settings[key]=value
    ports={name:int(settings[name.upper()+"_HOST_PORT"]) for name in ("profile",*SERVICES)}
    if any(port<1 or port>65535 for port in ports.values()) or len(set(ports.values()))!=len(ports):
        raise ValueError("Private beta port configuration is invalid")
    return ports.pop("profile"),ports,int(settings["BETA_PROTOCOL_MIN"])


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source,"sha256").hexdigest()


def freeze(folder):
    folder=folder.resolve()
    if folder.exists():
        raise ValueError("Choose a new immutable snapshot directory")
    folder.parent.mkdir(exist_ok=True,parents=True)
    with tempfile.TemporaryDirectory(dir=folder.parent) as temp:
        staging=Path(temp)/"project"
        staging.mkdir()
        for name in ("game","services","deploy"):
            shutil.copytree(ROOT/name,staging/name,ignore=shutil.ignore_patterns(".godot","__pycache__","*.apk","*.aab","runtime_endpoints.cfg","export_credentials.cfg"))
        shutil.copytree(ROOT/"tools/operations",staging/"tools/operations",ignore=shutil.ignore_patterns("__pycache__"))
        for name in ("compose.yaml","Dockerfile",".dockerignore"):
            shutil.copy2(ROOT/name,staging/name)
        manifest={str(f.relative_to(staging)).replace("\\","/"):sha(f) for f in sorted(staging.rglob("*")) if f.is_file()}
        (staging/"source-manifest.json").write_text(json.dumps(manifest,sort_keys=True,indent=2),encoding="utf8")
        staging.rename(folder)
    print("BETA_SNAPSHOT",folder,"files",len(manifest),"manifest",sha(folder/"source-manifest.json"))


def sdk(setting,envkey):
    value=os.environ.get(envkey)
    if value:
        return Path(value)
    text=(Path(os.environ["APPDATA"])/"Godot/editor_settings-4.6.tres").read_text(encoding="utf8")
    found=re.search(r'^export/android/'+setting+r' = "([^"]+)"',text,re.MULTILINE)
    if not found:
        raise RuntimeError("Configure the Godot Android editor setting "+setting)
    return Path(found[1])


@contextmanager
def machine_lock(folder):
    import msvcrt
    folder.mkdir(parents=True,exist_ok=True)
    with (folder/"build.lock").open("a+b") as lock:
        if not lock.tell():lock.write(b"1");lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        try:
            yield
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)


def dpapi(data,protect):
    import ctypes
    from ctypes import wintypes
    class Blob(ctypes.Structure):
        _fields_=[("size",wintypes.DWORD),("ptr",ctypes.c_void_p)]
    buf=ctypes.create_string_buffer(data)
    src=Blob(len(data),ctypes.cast(buf,ctypes.c_void_p))
    dst=Blob()
    api=ctypes.WinDLL("crypt32",use_last_error=True)
    op=api.CryptProtectData if protect else api.CryptUnprotectData
    if not op(ctypes.byref(src),None,None,None,None,1,ctypes.byref(dst)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return ctypes.string_at(dst.ptr,dst.size)
    finally:
        ctypes.windll.kernel32.LocalFree(ctypes.c_void_p(dst.ptr))


def signing(folder,java):
    pfx=folder/"private-beta.p12"
    sealed=folder/"private-beta.dpapi"
    env=dict(os.environ)
    if not pfx.is_file():
        if sealed.exists():
            raise RuntimeError("Incomplete signing material; restore the matching keystore before building")
        password=secrets.token_hex(32)
        env["BETA_SIGN_SECRET"]=password
        with tempfile.TemporaryDirectory(dir=folder) as temp:
            tmp=Path(temp)
            (tmp/"password.dpapi").write_bytes(dpapi(password.encode(),True))
            subprocess.run([str(java/"bin/keytool.exe"),"-genkeypair","-storetype","PKCS12","-keystore",str(tmp/"store.p12"),
                            "-alias",ALIAS,"-keyalg","RSA","-keysize","3072","-validity","10000","-dname","CN=PunkLegion Local Private Beta",
                            "-storepass:env","BETA_SIGN_SECRET","-keypass:env","BETA_SIGN_SECRET"],env=env,check=True)
            (tmp/"store.p12").rename(pfx)
            (tmp/"password.dpapi").rename(sealed)
    else:
        if not sealed.is_file():
            raise RuntimeError("Signing password file missing; restore it from the local signing backup")
        password=dpapi(sealed.read_bytes(),False).decode()
    return pfx,password


def build(args):
    host=endpoint_host(getattr(args,"endpoint_host","10.0.2.2"))
    if os.name!="nt":
        raise RuntimeError("This private beta signing host uses Windows user DPAPI")
    snapshot=args.snapshot.resolve()
    manifest_file=snapshot/"source-manifest.json"
    source=json.loads(manifest_file.read_text(encoding="utf8"))
    present={file.relative_to(snapshot).as_posix() for file in snapshot.rglob("*") if file.is_file() and file!=manifest_file}
    if present!=set(source):
        raise ValueError("Snapshot file list differs from its manifest")
    for name,digest in source.items():
        if sha(snapshot/name)!=digest:
            raise ValueError("Snapshot changed: "+name)
    http,udp,protocol=private_network(snapshot)
    if args.protocol != protocol:
        raise ValueError(f"Frozen profile requires beta protocol {protocol}; requested {args.protocol}")
    name=f"0.1.0-beta.{args.code}"
    dest=args.output.resolve()
    dest.mkdir(parents=True,exist_ok=True)
    apk=dest/f"PunkLegion-beta-{args.code}.apk"
    report=apk.with_suffix(".json")
    vault=Path(os.environ["LOCALAPPDATA"])/"PunkLegion/signing/private-beta"
    java=sdk("java_sdk_path","JAVA_HOME")
    android=sdk("android_sdk_path","ANDROID_HOME")
    tools=max((p for p in (android/"build-tools").iterdir() if p.name.replace(".","").isdigit()),key=lambda p:tuple(map(int,p.name.split("."))))
    with machine_lock(vault):
        ledger=vault/"issued.json"
        issued=json.loads(ledger.read_text()) if ledger.exists() else {}
        if args.code<=max(map(int,issued),default=0) or apk.exists():
            raise ValueError("Already issued version or existing APK; choose a higher code")
        pfx,password=signing(vault,java)
        env=dict(os.environ,JAVA_HOME=str(java),ANDROID_HOME=str(android),GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(pfx),
                 GODOT_ANDROID_KEYSTORE_RELEASE_USER=ALIAS,GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
        with tempfile.TemporaryDirectory(prefix="punk-beta-build-") as temp:
            game=Path(temp)/"game"
            shutil.copytree(snapshot/"game",game)
            cfg=game/"project.godot"
            project=cfg.read_text(encoding="utf8").replace('run/main_scene="res://client/range.tscn"','run/main_scene="res://beta/entry.tscn"')
            project=project.replace('[application]','[application]\nconfig/version="'+name+'"',1)
            cfg.write_text(project+'\n[beta]\nprotocol='+str(args.protocol)+'\n',encoding="utf8")
            presets=game/"export_presets.cfg"
            text=presets.read_text(encoding="utf8")
            start=text.index('[preset.1]')
            end=text.index('[preset.2]',start)
            release=text[start:end].replace('name="Android Release"','name="Private Beta"\ncustom_features="private_beta"').replace('version/code=1','version/code='+str(args.code))
            release=release.replace('version/name="0.1.0"','version/name="'+name+'"').replace('package/unique_name="dev.punklegion.client"','package/unique_name="'+PACKAGE+'"').replace('package/name="PunkLegion"','package/name="朋克军团·内测"')
            presets.write_text(text[:start]+release+text[end:],encoding="utf8")
            net='[profile]\nurl="http://'+host+':'+str(http)+'"\n'
            for service,port in udp.items():
                net+='\n['+service+']\nhost="'+host+'"\nport='+str(port)+'\n'
            (game/"runtime_endpoints.cfg").write_text(net,encoding="utf8")
            out=Path(temp)/"game.apk"
            for cmd in (["--headless","--editor","--path",str(game),"--import"],["--headless","--path",str(game),"--export-release","Private Beta",str(out)]):
                run=subprocess.run([args.godot,*cmd],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding="utf8",errors="replace",timeout=600)
                if run.returncode or "SCRIPT ERROR:" in run.stdout or "Parse Error:" in run.stdout or "ERROR:" in run.stdout:
                    safe=run.stdout.replace(password,"[filtered]").splitlines()
                    errors=[line for line in safe if "error" in line.lower() or "failed" in line.lower()]
                    raise RuntimeError("\n".join((errors or safe)[-20:]))
            verify=subprocess.check_output([str(tools/"apksigner.bat"),"verify","--verbose","--print-certs",str(out)],env=env,text=True)
            pkg=subprocess.check_output([str(tools/"aapt.exe"),"dump","badging",str(out)],env=env,text=True,encoding="utf8",errors="replace")
            assert "Verified using v2 scheme (APK Signature Scheme v2): true" in verify
            assert f"package: name='{PACKAGE}' versionCode='{args.code}'" in pkg and "'arm64-v8a' 'x86_64'" in pkg
            signer=re.search(r'certificate SHA-256 digest: ([0-9a-f]+)',verify)[1]
            if issued and any(r["signer_sha256"]!=signer for r in issued.values()):
                raise RuntimeError("Signer differs from prior issued package")
            metadata={"package":PACKAGE,"code":args.code,"version":name,"protocol":args.protocol,"sha256":sha(out),
                      "signer_sha256":signer,"snapshot_sha256":sha(manifest_file),"size":out.stat().st_size,"endpoint_host":host,
                      "profile_tcp":http,"udp":udp,"abis":["arm64-v8a","x86_64"]}
            shutil.copy2(out,apk)
            report.write_text(json.dumps(metadata,indent=2),encoding="utf8")
            issued[str(args.code)]=metadata
            atomic=ledger.with_suffix(".tmp")
            atomic.write_text(json.dumps(issued,indent=2))
            atomic.replace(ledger)
            print("BETA_APK",apk,"versionCode",args.code,"sha256",metadata["sha256"],"signer",signer,flush=True)


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    sub=cli.add_subparsers(dest="action",required=True)
    snap=sub.add_parser("freeze")
    snap.add_argument("snapshot",type=Path)
    apk=sub.add_parser("build")
    apk.add_argument("--snapshot",type=Path,required=True)
    apk.add_argument("--output",type=Path,default=ROOT/"build/private-beta")
    apk.add_argument("--code",type=int,required=True)
    apk.add_argument("--protocol",type=int,choices=[1,2,3,4,5],default=5)
    apk.add_argument("--endpoint-host",type=endpoint_host,default="10.0.2.2")
    apk.add_argument("--godot",default=str(Path(os.environ.get("LOCALAPPDATA","."))/"PunkLegion/tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe"))
    args=cli.parse_args()
    freeze(args.snapshot) if args.action=="freeze" else build(args)
