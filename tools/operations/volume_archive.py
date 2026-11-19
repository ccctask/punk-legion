"""Container-side volume copier. Reads a quiescent database; never logs its contents or credentials."""
import hashlib
import json
import os
from pathlib import Path,PurePosixPath
import shutil
import sqlite3
import sys
import zipfile

state=Path("/state");bundle=Path("/bundle")
def digest(path):
    with path.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()
def info():
    with sqlite3.connect("file:/state/player-profiles/player.sqlite?mode=ro",uri=True) as db:
        assert db.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
        return dict(schema=db.execute("PRAGMA user_version").fetchone()[0],receipt_count=db.execute("SELECT COUNT(*) FROM receipts").fetchone()[0])
def make():
    meta={}
    for root in sorted(state.iterdir()):
        archive=bundle/(root.name+".zip")
        count=0
        with zipfile.ZipFile(archive,"x",zipfile.ZIP_DEFLATED,compresslevel=4) as z:
            for p in sorted(root.rglob("*")):
                if p.is_symlink():raise ValueError("unexpected symlink in state")
                if p.is_file():
                    z.write(p,p.relative_to(root));count+=1
        meta[root.name]=dict(sha256=digest(archive),files=count,bytes=archive.stat().st_size)
    return dict(volumes=meta,**info())
def load():
    manifest=json.loads((bundle/"manifest.json").read_text())
    if manifest["format"]!=1 or set(manifest["volumes"])!={p.name for p in state.iterdir()}:raise ValueError("invalid manifest inventory")
    for root in state.iterdir():
        if any(root.iterdir()):raise ValueError("restore requires empty target volumes")
        archive=bundle/(root.name+".zip")
        if digest(archive)!=manifest["volumes"][root.name]["sha256"]:raise ValueError("checksum mismatch "+root.name)
        with zipfile.ZipFile(archive) as z:
            if len(z.namelist())!=manifest["volumes"][root.name]["files"] or z.testzip():raise ValueError("archive integrity")
            if any(PurePosixPath(n).is_absolute() or ".." in PurePosixPath(n).parts or "\\" in n for n in z.namelist()):raise ValueError("unsafe archive path")
    created=[]
    try:
        for root in state.iterdir():
            with zipfile.ZipFile(bundle/(root.name+".zip")) as z:
                for name in z.namelist():
                    dest=root/name;dest.parent.mkdir(parents=True,exist_ok=True);created.append(dest)
                    with z.open(name) as src,dest.open("xb") as out:shutil.copyfileobj(src,out)
                    # Runtime services write as the uid/gid that owns the destination volume.
                    owner=root.stat()
                    os.chown(dest,owner.st_uid,owner.st_gid)
                    dest.chmod((z.getinfo(name).external_attr>>16)&0o777 or 0o600)
            owner=root.stat()
            for child in (p for p in root.rglob("*") if p.is_dir()):
                os.chown(child,owner.st_uid,owner.st_gid)
        restored=info()
        if any(restored[k]!=manifest[k] for k in restored):raise ValueError("database differs from manifest")
        with sqlite3.connect(state/"player-profiles/player.sqlite") as db:db.execute("UPDATE accounts SET session=NULL")
        return restored
    except Exception:
        for f in reversed(created):f.unlink(missing_ok=True)
        for root in state.iterdir():
            for child in sorted((p for p in root.rglob("*") if p.is_dir()),key=lambda p:len(p.parts),reverse=True):child.rmdir()
        raise
print(json.dumps(make() if sys.argv[1]=="capture" else load()))
