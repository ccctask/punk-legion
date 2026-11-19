"""Single-slot private defense platforms. Physical parts return through the ordinary inventory."""
import json
import re
import time

import private_base

import inventory
import workshop
from inventory import Fault


def function(definition):
    part=workshop.PARTS.get(definition)
    if not part:
        return ""
    slot_name="weapon" if definition in ("cannon","rivet_repeater") else "utility"
    slot=workshop.HULL["slots"][slot_name]
    return slot_name if (part["kind"],part["interface"])==(slot["kind"],slot["interface"]) and part["size"]<=slot["size"] else ""


def locked(db,owner,platform,stamp=None):
    stamp = int(time.time()) if stamp is None else stamp
    row=db.execute("SELECT layout FROM wild_raids WHERE owner=? AND outcome IS NULL AND starts<=?",(owner,stamp)).fetchone()
    return bool(row and any(b["id"]==platform for b in json.loads(row[0])["buildings"]))


def handle(db,owner,method,route,fields,layout):
    ident=route.rsplit("/",1)[1]
    if method=="POST":
        if fields.keys()!={"key","action","item","revision"} or type(fields["revision"])!=int or not all(isinstance(fields[k],str) for k in ("key","action","item")):
            raise Fault(400,"invalid_parameters")
        if not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",fields["key"]):
            raise Fault(400,"invalid_key")
        signature=json.dumps([route,fields],sort_keys=True)
        previous=inventory.previous(db,owner,fields["key"],signature)
        if previous:
            return {"receipt":previous}
    tower=next((b for b in layout["buildings"] if b["id"]==ident and b["kind"]=="turret"),None)
    if tower is None:
        raise Fault(404,"unknown_platform")
    if method=="GET":
        free=[dict(p) for p in db.execute(inventory.FREE_PARTS+" ORDER BY p.rowid",(owner,))]
        return {"platform":{"id":ident,"revision":layout["revision"],"legacy":"module" not in tower,
            "mounted":tower.get("module"),"locked":locked(db,owner,ident),
            "parts":[dict(p,compatible=bool(function(p["definition"]))) for p in free]}}
    if method!="POST" or fields["action"] not in ("install","detach","remove"):
        raise Fault(400,"invalid_parameters")
    if fields["revision"]!=layout["revision"]:
        raise Fault(409,"stale_layout")
    if locked(db,owner,ident):
        raise Fault(409,"platform_locked")
    current=tower.get("module")
    item=fields["item"]
    if fields["action"]=="install":
        p=db.execute(inventory.FREE_PARTS+" AND p.id=?",(owner,item)).fetchone()
        if not p:
            raise Fault(409,"item_unavailable")
        if not function(p["definition"]):
            raise Fault(409,"incompatible_part")
        if db.execute("SELECT 1 FROM relief_parts WHERE id=?",(item,)).fetchone():
            raise Fault(409,"relief_part")
        tower["module"]=dict(p)
        db.execute("INSERT OR REPLACE INTO platform_parts VALUES(?,?,?)",(ident,owner,item))
    else:
        if item or (fields["action"]=="detach" and not current):
            raise Fault(409,"nothing_to_detach")
        if current and db.execute("SELECT COUNT(*) FROM ("+inventory.FREE_PARTS+")",(owner,)).fetchone()[0]>=inventory.PART_CAP:
            raise Fault(409,"parts_full")
        db.execute("DELETE FROM platform_parts WHERE platform=? AND owner=?",(ident,owner))
        tower["module"]=None
        if fields["action"]=="remove":
            import production
            production.update(db,owner,private_base.check(layout))
            layout["buildings"].remove(tower)
            production.update(db,owner,private_base.check(layout))
    layout["revision"]+=1
    private_base.save_layout(db, owner, layout, platform=ident)
    receipt=inventory.record(db,owner,fields["key"],"platform_"+fields["action"],signature,{},
                             platform=ident,returned=current["id"] if current else None,item=item or None)
    return {"receipt":receipt}
