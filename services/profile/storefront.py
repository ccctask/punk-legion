"""M21 test catalog, order transitions, robot paint and editable design positions."""
import os
import re
import time
import uuid

from inventory import Fault

BASE_SLOTS = 6
CATALOG = {
    "paint_mint":{"name":"薄荷珐琅","price":6,"limit":1,"purpose":"更换机壳涂色","style":"mint"},
    "extra_slot":{"name":"装配方案栏 +1","price":3,"limit":2,"purpose":"多保存一套常用方案"},
}
FREE_PAINT = "base"


def schema(db):
    db.execute("""CREATE TABLE IF NOT EXISTS shop_orders(id TEXT PRIMARY KEY,owner TEXT REFERENCES accounts(id),
        intent TEXT NOT NULL,sku TEXT NOT NULL,price INTEGER NOT NULL,state TEXT NOT NULL,created INTEGER NOT NULL,
        UNIQUE(owner,intent))""")
    db.execute("""CREATE TABLE IF NOT EXISTS shop_events(id INTEGER PRIMARY KEY,order_id TEXT REFERENCES shop_orders(id),
        state TEXT NOT NULL,at INTEGER NOT NULL,UNIQUE(order_id,state))""")
    db.execute("CREATE TABLE IF NOT EXISTS robot_paint(robot TEXT PRIMARY KEY REFERENCES robots(id),paint TEXT NOT NULL)")
    db.execute("""CREATE TABLE IF NOT EXISTS design_positions(owner TEXT REFERENCES accounts(id),name TEXT NOT NULL,
        pos INTEGER NOT NULL,PRIMARY KEY(owner,name),UNIQUE(owner,pos))""")
    for owner,name in db.execute("SELECT owner,name FROM designs GROUP BY owner,name ORDER BY min(rowid)"):
        pos=db.execute("SELECT COALESCE(MAX(pos),0)+1 FROM design_positions WHERE owner=?",(owner,)).fetchone()[0]
        db.execute("INSERT OR IGNORE INTO design_positions VALUES (?,?,?)",(owner,name,pos))


def order_count(db,owner,sku,held=False):
    states="('created','paid','delivered')" if held else "('delivered')"
    return db.execute(f"SELECT COUNT(*) FROM shop_orders WHERE owner=? AND sku=? AND state IN {states}",(owner,sku)).fetchone()[0]


def capacity(db,owner):
    return BASE_SLOTS + min(2,order_count(db,owner,"extra_slot"))


def positions(db,owner):
    return dict(db.execute("SELECT name,pos FROM design_positions WHERE owner=?",(owner,)))


def allocate(db,owner,name,replace_id=None):
    existing=positions(db,owner)
    limit=capacity(db,owner)
    if replace_id:
        row=db.execute("SELECT name FROM designs WHERE owner=? AND id=?",(owner,replace_id)).fetchone()
        if not row or existing.get(row[0],limit+1)>limit:
            raise Fault(409,"design_position_changed")
        slot=existing[row[0]]
        if row[0]!=name and existing.get(name,limit+1)<=limit:
            raise Fault(409,"design_already_active")
        db.execute("DELETE FROM design_positions WHERE owner=? AND (name=? OR name=?)",(owner,name,row[0]))
    elif existing.get(name,limit+1)<=limit:
        return
    else:
        slot=next((i for i in range(1,limit+1) if i not in existing.values()),None)
        if slot is None:
            raise Fault(409,"design_slots_full")
        db.execute("DELETE FROM design_positions WHERE owner=? AND name=?",(owner,name))
    db.execute("INSERT INTO design_positions VALUES (?,?,?)",(owner,name,slot))


def enabled():
    return os.environ.get("PUNK_TEST_PAYMENTS")=="1"


def view(db,owner):
    catalog=[dict(v,sku=k,owned=order_count(db,owner,k),
                  remaining=v["limit"]-order_count(db,owner,k,True)) for k,v in CATALOG.items()]
    orders=[]
    for r in db.execute("SELECT id,sku,price,state,created FROM shop_orders WHERE owner=? ORDER BY rowid DESC",(owner,)):
        orders.append(dict(r,events=[dict(e) for e in db.execute("SELECT state,at FROM shop_events WHERE order_id=? ORDER BY id",(r["id"],))]))
    robots = {}
    for row in db.execute("""SELECT r.id, r.name, COALESCE(p.paint,'base') AS paint,
            COALESCE(h.definition,'crawler') AS chassis, COALESCE(n.value,'') AS hull_number, m.slot, part.definition
            FROM robots r LEFT JOIN hull_numbers n ON n.robot=r.id LEFT JOIN robot_paint p ON p.robot=r.id
            LEFT JOIN robot_condition c ON c.robot=r.id LEFT JOIN robot_chassis h ON h.robot=r.id
            LEFT JOIN mounts m ON m.robot=r.id LEFT JOIN parts part ON part.id=m.item
            WHERE r.owner=? AND COALESCE(c.state,'ready')!='retired' ORDER BY r.rowid""",(owner,)):
        if row["id"] not in robots:
            robots[row["id"]] = {key:row[key] for key in ("id","name","paint","chassis","hull_number")}
            robots[row["id"]]["parts"] = {}
        if row["slot"] is not None:
            robots[row["id"]]["parts"][row["slot"]] = row["definition"]

    return dict(catalog=catalog,orders=orders,robots=list(robots.values()),capacity=capacity(db,owner),base_slots=BASE_SLOTS,
                styles=["base"]+(["mint"] if order_count(db,owner,"paint_mint") else []),test_payment=enabled())


def transition(db,order,state):
    db.execute("UPDATE shop_orders SET state=? WHERE id=?",(state,order))
    db.execute("INSERT INTO shop_events(order_id,state,at) VALUES (?,?,?)",(order,state,int(time.time())))


def handle(db,owner,method,route,fields):
    if route=="/v1/store" and method=="GET":
        return {"store":view(db,owner)}
    if method!="POST":
        raise Fault(404,"unknown_route")
    if route=="/v1/store/equip":
        if fields.keys()!={"robot","paint"} or not all(isinstance(v,str) for v in fields.values()):
            raise Fault(400,"invalid_parameters")
        if fields["paint"] not in ("base","mint") or (fields["paint"]=="mint" and not order_count(db,owner,"paint_mint")):
            raise Fault(403,"paint_not_owned")
        if not db.execute("""SELECT 1 FROM robots r LEFT JOIN robot_condition c ON c.robot=r.id
                WHERE r.id=? AND owner=? AND COALESCE(c.state,'ready')!='retired'""",(fields["robot"],owner)).fetchone():
            raise Fault(404,"unknown_robot")
        db.execute("INSERT OR REPLACE INTO robot_paint VALUES (?,?)",(fields["robot"],fields["paint"]))
        return {"store":view(db,owner)}
    if not enabled():
        raise Fault(403,"test_payments_disabled")
    if route=="/v1/store/order":
        if (fields.keys()!={"sku","key"} or not isinstance(fields["sku"],str) or fields["sku"] not in CATALOG or
                not isinstance(fields["key"],str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}",fields["key"])):
            raise Fault(400,"invalid_parameters")
        key,sku=fields["key"],fields["sku"]
        row=db.execute("SELECT id,sku FROM shop_orders WHERE owner=? AND intent=?",(owner,key)).fetchone()
        if row:
            if row["sku"]!=sku:raise Fault(409,"key_conflict")
            oid=row["id"]
        else:
            if order_count(db,owner,sku,True)>=CATALOG[sku]["limit"]:
                raise Fault(409,"product_limit")
            oid=uuid.uuid4().hex
            db.execute("INSERT INTO shop_orders VALUES (?,?,?,?,?,'created',?)",(oid,owner,key,sku,CATALOG[sku]["price"],int(time.time())))
            transition(db,oid,"created")
    elif route=="/v1/store/simulate":
        if fields.keys()!={"order","result"} or not all(isinstance(v,str) for v in fields.values()):
            raise Fault(400,"invalid_parameters")
        oid,action=fields["order"],fields["result"]
        row=db.execute("SELECT state,sku FROM shop_orders WHERE id=? AND owner=?",(oid,owner)).fetchone()
        if not row:raise Fault(404,"unknown_order")
        state=row["state"]
        if action not in ["success","paid","retry","cancel","fail","refund"]:
            raise Fault(400,"invalid_payment_result")
        if action in ("success","paid") and state=="created":
            transition(db,oid,"paid")
            state="paid"
        if action in ("success","retry") and state=="paid":
            transition(db,oid,"delivered")
        elif action in ("cancel","fail") and state=="created":
            transition(db,oid,"cancelled" if action=="cancel" else "failed")
        elif action=="refund" and state in ("paid","delivered"):
            transition(db,oid,"refunded")
            if row["sku"]=="paint_mint" and not order_count(db,owner,"paint_mint"):
                db.execute("DELETE FROM robot_paint WHERE paint='mint' AND robot IN (SELECT id FROM robots WHERE owner=?)",(owner,))
    else:
        raise Fault(404,"unknown_route")
    return {"store":view(db,owner),"order":oid}
