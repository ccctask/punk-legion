"""Local player profiles. Run the service or manage SQLite snapshots."""
import argparse
from contextlib import closing, contextmanager
from hashlib import sha256
from hmac import compare_digest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
import uuid
import logging
import threading
import inventory
import account_access
from account_access import digest
import onboarding
import storefront
import world_calendar
import camp
import treasure
import friends
import recovery
import raids
import favorites
import plaques
import service_record
import private_base
import factory
import armory
import expedition
import party
import pump
import workshop
import profile_maintenance
from inventory import Fault

VERSION = 21
BETA_MAX_PROTOCOL = 5
TASKS = ("expedition", "guard", "aid", "repair")


@contextmanager
def transaction(path):
    with closing(sqlite3.connect(path, timeout=8)) as db:
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        with db:
            db.execute("BEGIN IMMEDIATE")
            yield db


def validate_version(db):
    if db.execute("PRAGMA user_version").fetchone()[0] not in range(1,VERSION+1):
        raise ValueError("unsupported profile database version")


def initialize(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with transaction(path) as db:
        version = db.execute("PRAGMA user_version").fetchone()[0]
        if version == VERSION:
            return
        if version or db.execute(
            "SELECT 1 FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"
        ).fetchone():
            raise ValueError("This build requires a fresh development database")
        else:
            db.execute("CREATE TABLE accounts (id TEXT PRIMARY KEY, name TEXT UNIQUE NOT NULL, salt BLOB NOT NULL, digest BLOB NOT NULL, session TEXT UNIQUE)")
            db.execute("""CREATE TABLE robots (id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES accounts(id),
                   name TEXT NOT NULL, task TEXT, assignment TEXT UNIQUE,
                   CHECK ((task IS NULL) = (assignment IS NULL)),
                   CHECK (task IS NULL OR task IN ('expedition','guard','aid','repair')))""")
        if version < 2:
            inventory.create_tables(db)
            for account in db.execute("SELECT id FROM accounts"):
                inventory.seed(db,account[0])
        if version < 3:
            workshop.create_tables(db)
        if version < 4:
            service_record.create_tables(db)
        if version < 6:
            recovery.create_tables(db)
        if version<7:
            raids.schema(db)
        if version < 8:
            raids.upgrade_clock(db)
        if version < 9:
            onboarding.schema(db)
        if version < 10:
            world_calendar.schema(db)
        if version < 11:
            camp.schema(db)
        if version < 12:
            storefront.schema(db)
        if version < 13:
            world_calendar.upgrade_repeat_entries(db)
        if version < 14:
            friends.schema(db)
        if version < 15:
            treasure.schema(db)
        if version < 16:
            db.execute("""CREATE TABLE IF NOT EXISTS platform_parts(platform TEXT PRIMARY KEY,owner TEXT NOT NULL REFERENCES accounts(id),
                item TEXT NOT NULL UNIQUE REFERENCES parts(id))""")
        if version < 17:
            db.execute("CREATE TABLE robot_orders(robot TEXT PRIMARY KEY REFERENCES robots(id), body TEXT NOT NULL)")
        if version < 18:
            party.continuity_schema(db)
        if version < 19:
            db.execute("CREATE TABLE IF NOT EXISTS robot_chassis(robot TEXT PRIMARY KEY REFERENCES robots(id),definition TEXT NOT NULL)")
            if "chassis" not in {r["name"] for r in db.execute("PRAGMA table_info(designs)")}:
                db.execute("ALTER TABLE designs ADD COLUMN chassis TEXT NOT NULL DEFAULT 'crawler'")
        if version < 20:
            favorites.schema(db)
        if version == 0:
            db.execute("""CREATE TABLE hull_numbers(robot TEXT PRIMARY KEY REFERENCES robots(id),
                        value TEXT NOT NULL CHECK(length(value)=2 AND value GLOB '[0-9][0-9]'))""")
            account_access.schema(db)
            plaques.schema(db)
            pump.schema(db)
            factory.schema(db)
            armory.schema(db)
            party.matchmaking_schema(db)
        db.execute(f"PRAGMA user_version={VERSION}")


def login(path, fields, register):
    name = fields.get("name")
    password = fields.get("password")
    if not account_access.valid_name(name):
        raise Fault(400, "invalid_account")
    if not account_access.valid_password(password):
        raise Fault(400, "invalid_password")
    name = name.lower()
    with transaction(path) as db:
        row = db.execute("SELECT * FROM accounts WHERE name=?", (name,)).fetchone()
        if register:
            if row:
                raise Fault(409, "account_exists")
            user = uuid.uuid4().hex
            salt = secrets.token_bytes(16)
            db.execute("INSERT INTO accounts VALUES (?,?,?,?,NULL)", (user, name, salt, digest(password,salt)))
            robot = uuid.uuid4().hex
            db.execute("INSERT INTO robots VALUES (?,?,?,NULL,NULL)", (robot, user, "新虎机组"))
            workshop.initial_fit(db,user,robot)
            inventory.seed(db,user)
        else:
            salt = row["salt"] if row else bytes(16)
            expected = digest(password, salt)
            if not row or not compare_digest(expected, row["digest"]):
                raise Fault(401, "invalid_credentials")
            user = row["id"]
        token = secrets.token_urlsafe(32)
        private_base.activate(db,user)
        raids.advance(db,user,active=True)
        db.execute("UPDATE accounts SET session=? WHERE id=?", (sha256(token.encode()).hexdigest(), user))
        onboarding.capture(db,user)
        return {"token": token, **profile(db, user)}


def profile(db, owner):
    account = db.execute("SELECT id,name FROM accounts WHERE id=?", (owner,)).fetchone()
    robots = db.execute("""SELECT r.id,r.name,r.task,r.assignment,COALESCE(nu.value,'') hull_number,
        EXISTS(SELECT 1 FROM named_robots n WHERE n.robot=r.id) AS named,COALESCE(c.state,'ready') state,c.due repair_due,
        CASE WHEN s.ticket IS NULL THEN NULL WHEN s.ticket GLOB 'mission_*' AND r.task='guard' THEN 'raid_guard'
        WHEN s.ticket GLOB 'mission_*' THEN 'mission' WHEN s.battle IS NULL THEN 'waiting' ELSE 'active' END AS sortie
        FROM robots r LEFT JOIN hull_numbers nu ON nu.robot=r.id LEFT JOIN robot_sorties s ON s.ticket=r.assignment LEFT JOIN robot_condition c ON c.robot=r.id
        WHERE r.owner=? ORDER BY r.rowid""", (owner,))
    fleet = [dict(row) for row in robots]
    equipment = None
    if fleet and fleet[0]["state"] != "retired":
        rid = fleet[0]["id"]
        paint = db.execute("SELECT paint FROM robot_paint WHERE robot=?", (rid,)).fetchone()
        equipment = {"owner":owner,"id":rid,"chassis":workshop.robot_chassis(db,rid),
                     "hull_number":fleet[0]["hull_number"],"paint":paint[0] if paint else storefront.FREE_PAINT,"slots":workshop.fit(db,rid)}
    return {"account":dict(account),"robots":fleet,"starter_equipment":equipment,"server_now":time.time()}


def session_owner(db, bearer):
    if not bearer.startswith("Bearer "):
        raise Fault(401, "session_expired")
    user = db.execute("SELECT id FROM accounts WHERE session=?", (sha256(bearer[7:].encode()).hexdigest(),)).fetchone()
    if not user:
        raise Fault(401, "session_expired")
    return user["id"]


def handle(path, method, route, fields, bearer, room_key="",peer_address="local"):
    if method=="POST" and route in (account_access.ISSUE,account_access.REDEEM):
        name=fields.get("name")
        # Charge before expensive password work. Rejected attempts remain counted
        # independently of the atomic credential transaction that follows.
        with transaction(path) as db:
            identity=session_owner(db,bearer) if route==account_access.ISSUE else (name.lower() if account_access.valid_name(name) else "")
            account_access.reserve_attempt(db,route,identity,peer_address)
        with transaction(path) as db:
            if route==account_access.ISSUE:
                return account_access.issue(db,session_owner(db,bearer),fields)
            return account_access.redeem(db,name,fields)
    if method=="POST" and route in ("/internal/treasure/poll","/internal/treasure/command","/internal/treasure/frames"):
        if not room_key or not compare_digest(bearer.encode(),("Bearer "+room_key).encode()):
            raise Fault(401,"room_auth_required")
        with transaction(path) as db:
            if route.endswith("/frames"):
                return treasure.frames(db,fields)
            return treasure.internal(db,route.rsplit("/",1)[1],fields)
    if method=="GET" and route=="/v1/beta/compat":
        return {"capabilities":["base_first_naming","starter_equipment_snapshot"],"protocol_min":int(os.environ.get("BETA_PROTOCOL_MIN","1")),"protocol_max":BETA_MAX_PROTOCOL,"server_now":int(time.time())}
    radar_route = route.startswith("/v1/base/radar/")
    if radar_route and method != "GET":
        raise Fault(405,"method_not_allowed")
    if method=="GET" and (route.startswith("/v1/base/edits/") or route=="/v1/camp/defense-alerts" or radar_route):
        # Foreground status reads use one committed snapshot, without global cleanup or write locks.
        with closing(sqlite3.connect(Path(path).resolve().as_uri()+"?mode=ro", uri=True, timeout=8)) as db:
            db.row_factory = sqlite3.Row
            db.execute("BEGIN")
            owner=session_owner(db,bearer)
            if radar_route:
                return raids.radar(db,owner,route.removeprefix("/v1/base/radar/"))
            if route=="/v1/camp/defense-alerts":
                return camp.defense_alerts(db,owner)
            return private_base.edit_status(db,owner,route.removeprefix("/v1/base/edits/"))
    # Lease cleanup commits independently of a later rejected action (including a late result).
    with transaction(path) as db:
        profile_maintenance.advance_request_state(db)
    if method == "POST" and route in ("/v1/accounts", "/v1/sessions"):
        return login(path, fields, route.endswith("accounts"))
    with transaction(path) as db:
        if method == "POST" and route in ("/internal/results","/internal/deploy","/internal/expedition/open","/internal/expedition/settle","/internal/party/open","/internal/party/settle","/internal/camp/open","/internal/camp/settle"):
            if not room_key or not compare_digest(bearer.encode(), ("Bearer "+room_key).encode()):
                raise Fault(401, "room_auth_required")
            if route.startswith("/internal/party/"):
                return party.internal(db,route,fields)
            if route.startswith("/internal/camp/"):
                return camp.internal(db,route,fields)
            if route.startswith("/internal/expedition/"):
                return expedition.internal(db,route,fields)
            if route == "/internal/deploy":
                return service_record.deploy(db,fields)
            return {"receipt": service_record.settle(db,fields)}
        owner = session_owner(db,bearer)
        # Freeze an arrival statement before a returning player can mutate a balance.
        onboarding.capture(db,owner)
        reply = authorized(db,owner,method,route,fields)
        onboarding.capture(db,owner)
        return reply


def authorized(db,owner,method,route,fields):
    if route=="/v1/treasure" or route.startswith("/v1/treasure/"):
        return treasure.handle(db,owner,method,route,fields)
    if route=="/v1/friends" or route.startswith("/v1/friends/"):
        return friends.handle(db,owner,method,route,fields)
    if route=="/v1/store" or route.startswith("/v1/store/"):
        return storefront.handle(db,owner,method,route,fields)
    if route=="/v1/camp" or route.startswith("/v1/camp/"):
        return camp.handle(db,owner,method,route,fields)
    if route == "/v1/onboarding" and method=="GET":
        return {"guide":onboarding.guide(db,owner)}
    if route == "/v1/world" or route.startswith("/v1/world/"):
        result=world_calendar.handle(db,owner,method,route,fields)
        if "world" in result:
            result["world"]["treasure"]=treasure.event()
            result["world"]["pump_ruin"]=pump.quote(db,owner)
        return result
    raids.advance(db,owner,active=True)
    if route.startswith("/v1/base/raids"):
        return raids.handle(db,owner,method,route,fields)
    if route == "/v1/recovery" and method == "GET":
        recovery.complete_due(db,owner)
        return {"recovery":recovery.bay_view(db,owner)}
    match = re.fullmatch(r"/v1/robots/([0-9a-f]{32})/recovery(?:/(repair|recycle|relief))?",route)
    if match:
        ident,action = match.groups()
        recovery.complete_due(db,owner)
        if method == "GET" and not action:
            return {"recovery":recovery.snapshot(db,owner,ident),"profile":profile(db,owner)}
        if method == "POST" and action:
            receipt = recovery.operate(db,owner,ident,action,fields)
            return {"recovery":recovery.snapshot(db,owner,ident),"receipt":receipt,"profile":profile(db,owner)}
        raise Fault(404,"unknown_route")
    if route == "/v1/factory" or route.startswith("/v1/factory/"):
        return party.handle(db,owner,method,route.replace("/v1/factory","/v1/party",1),fields,activity_kind=factory.ACTIVITY)
    if route == "/v1/pump" or route.startswith("/v1/pump/"):
        return party.handle(db,owner,method,route.replace("/v1/pump","/v1/party",1),fields,activity_kind="pump_ruin")
    if route == "/v1/party" or route.startswith("/v1/party/"):
        return party.handle(db,owner,method,route,fields)
    if route == "/v1/expedition" or route.startswith("/v1/expedition/"):
        return expedition.handle(db,owner,method,route,fields)
    if method=="POST" and route=="/v1/workshop/favorite":
        body=dict(fields)
        robot=body.pop("robot",None)
        favorites.update(db,owner,robot,body)
        return {"workshop":workshop.view(db,owner)}
    if method == "GET" and route.startswith("/v1/robots/") and "/history" in route:
        return service_record.history(db,owner,route)
    if route == "/v1/base" or route.startswith("/v1/base/"):
        return private_base.handle(db, owner, method, route, fields)
    if route == "/v1/workshop/deployment" and method == "POST":
        if fields.keys() != {"robots"}:
            raise Fault(400,"invalid_parameters")
        return {"deployment":workshop.deployment_for(workshop.owned_robots(db,owner),fields["robots"])}
    if route=="/v1/workshop/apply-preview" and method=="POST":
        if fields.keys()!={"robot","design"}:
            raise Fault(400,"invalid_parameters")
        return {"plan":workshop.apply_plan(db,owner,fields["design"],fields["robot"])}
    if route=="/v1/workshop/claim-pump-arm" and method=="POST":
        receipt=pump.claim_arm(db,owner,fields)
        return {"workshop":workshop.view(db,owner),"receipt":receipt}
    if route == "/v1/workshop" and method == "GET":
        return {"workshop":workshop.view(db,owner)}
    if route in ("/v1/workshop/design","/v1/workshop/build","/v1/workshop/refit","/v1/workshop/remove","/v1/workshop/apply","/v1/workshop/orders","/v1/workshop/chassis","/v1/workshop/hull-number") and method == "POST":
        receipt = workshop.operate(db,owner,route.rsplit("/",1)[1],fields)
        if route in ("/v1/workshop/design", "/v1/workshop/build"):
            receipt = {**receipt, "confirmation_key": fields["key"]}
        return {"workshop":workshop.view(db,owner),"receipt":receipt}
    if route == "/v1/profile" and method == "GET":
        return profile(db, owner)
    if route == "/v1/inventory" and method == "GET":
        return {"inventory":inventory.view(db,owner)}
    if route in ("/v1/inventory/craft", "/v1/inventory/admit") and method == "POST":
        receipt = inventory.operate(db,owner,route.rsplit("/",1)[1],fields)
        if route.endswith("/admit") and "robot" in fields:
            service_record.attach(db,owner,receipt["ticket"],fields["robot"])
        return {"receipt":receipt, "inventory":inventory.view(db,owner)}
    match = re.fullmatch(r"/v1/robots/([0-9a-f]{32})/(rename|assign|finish)", route)
    if not match or method != "POST":
        raise Fault(404, "unknown_route")
    ident, action = match.groups()
    robot = db.execute("SELECT * FROM robots WHERE id=? AND owner=?", (ident,owner)).fetchone()
    if not robot:
        raise Fault(404, "unknown_robot")
    if action == "rename":
        name = fields.get("name")
        if not isinstance(name,str) or not 1 <= len(name.strip()) <= 24 or not name.isprintable():
            raise Fault(400, "invalid_robot_name")
        if fields.get("first_name_only") is True:
            named=db.execute("SELECT 1 FROM named_robots WHERE robot=?",(ident,)).fetchone()
            if (named or robot["name"]!="新虎机组") and robot["name"]!=name.strip():
                raise Fault(409,"already_named")
        db.execute("INSERT OR IGNORE INTO named_robots VALUES (?)",(ident,))
        db.execute("UPDATE robots SET name=? WHERE id=?", (name.strip(),ident))
    elif action == "assign":
        if recovery.condition(db,ident)["state"] != "ready":
            raise Fault(409,"unit_unavailable")
        task = fields.get("task")
        if task not in TASKS:
            raise Fault(400, "invalid_task")
        if len(workshop.fit(db,ident)) != len(workshop.BASE):
            raise Fault(409,"incomplete_fit")
        if robot["assignment"]:
            raise Fault(409, "robot_busy")
        db.execute("UPDATE robots SET task=?, assignment=? WHERE id=?", (task,uuid.uuid4().hex,ident))
    else:
        if recovery.condition(db,ident)["state"] == "repairing":
            raise Fault(409,"repair_in_progress")
        if str(robot["assignment"]).startswith("trq:"):
            raise Fault(409,"treasure_group_managed")
        if str(robot["assignment"]).startswith(("campg_","aidg_")):
            raise Fault(409,"camp_guard_managed")
        if fields.get("outcome") == "cancelled" and service_record.cancel(db,owner,ident,fields.get("assignment")):
            return profile(db,owner)
        if robot["assignment"] and db.execute("SELECT 1 FROM robot_sorties WHERE ticket=? AND result_digest IS NULL",(robot["assignment"],)).fetchone():
            raise Fault(409,"active_sortie")
        if fields.get("outcome") not in ("completed","cancelled"):
            raise Fault(400, "invalid_outcome")
        if not robot["assignment"] or fields.get("assignment") != robot["assignment"]:
            raise Fault(409, "assignment_changed")
        db.execute("UPDATE robots SET task=NULL, assignment=NULL WHERE id=?", (ident,))
    return profile(db,owner)


class ProfileHTTPServer(ThreadingHTTPServer):
    # A room tick and multiple player commands can open connections together.
    request_queue_size=64


@contextmanager
def raid_scheduler(path, interval=2.0):
    """Advance existing schedules even when the only connected client is observing."""
    stop = threading.Event()
    def run():
        uri = Path(path).resolve().as_uri()+"?mode=ro"
        while not stop.wait(interval):
            try:
                with closing(sqlite3.connect(uri,uri=True,timeout=2)) as db:
                    due = raids.scheduled_owners(db,int(time.time()))
                for owner in due:
                    if stop.is_set():
                        return
                    with transaction(path) as db:
                        raids.advance(db,owner)
            except Exception:
                logging.exception("Scheduled private raid processing failed")
    worker = threading.Thread(target=run,name="private-raid-clock")
    worker.start()
    try:
        yield
    finally:
        stop.set()
        worker.join()


class Handler(BaseHTTPRequestHandler):
    base_idle_seconds = 6

    def log_message(self, *_args):
        pass

    def handle_one_request(self):
        if not self.close_connection:
            # Limit only the wait for the next request to start. Its body and
            # response retain the original socket timeout.
            previous_timeout = self.connection.gettimeout()
            try:
                self.connection.settimeout(self.base_idle_seconds)
                if not self.rfile.peek(1):
                    self.close_connection = True
                    return
            except OSError:
                self.close_connection = True
                return
            finally:
                self.connection.settimeout(previous_timeout)
        super().handle_one_request()

    def keep_connection(self, status, body_size):
        if status != 200 or self.request_version != "HTTP/1.1" or "Transfer-Encoding" in self.headers:
            return False
        if any(token.strip().lower() == "close"
               for header in self.headers.get_all("Connection", []) for token in header.split(",")):
            return False
        lengths = self.headers.get_all("Content-Length", [])
        if self.command == "GET" and self.path in ("/v1/base", "/v1/base/raids", "/v1/workshop", "/v1/party", "/v1/pump", "/v1/factory"):
            return lengths in ([], ["0"])
        return (self.command == "POST" and self.path in ("/v1/sessions", "/v1/workshop/refit", "/v1/workshop/design", "/v1/workshop/build")
                and body_size > 0 and lengths == [str(body_size)])

    def respond(self):
        body = b""
        try:
            protocol=self.headers.get("X-Punk-Beta-Protocol")
            protected = self.path.startswith("/v1/") and self.path!="/v1/beta/compat"
            if protocol is None and protected and os.environ.get("BETA_REQUIRE_PROTOCOL")=="1":
                raise Fault(426,"beta_update_required")
            if protocol is not None and (not re.fullmatch(r"[0-9]{1,3}",protocol) or not int(os.environ.get("BETA_PROTOCOL_MIN","1"))<=int(protocol)<=BETA_MAX_PROTOCOL):
                raise Fault(426,"beta_update_required")
            length = int(self.headers.get("Content-Length","0"))
            limit = 131072 if self.path in ("/internal/results","/internal/expedition/settle","/internal/party/settle","/internal/camp/settle") else 8192
            if not 0 <= length <= limit:
                raise Fault(413, "body_too_large")
            body = self.rfile.read(length) if length else b""
            fields = json.loads(body) if length else {}
            if not isinstance(fields,dict):
                raise Fault(400,"invalid_json")
            arguments=(self.server.path,self.command,self.path,fields,self.headers.get("Authorization",""),self.server.room_key)
            if self.path in (account_access.ISSUE,account_access.REDEEM):
                result=handle(*arguments,peer_address=self.client_address[0])
            else:
                result=handle(*arguments)
            status = 200
        except (UnicodeError, ValueError):
            status, result = 400, {"error":"invalid_json"}
        except Fault as exc:
            status, result = exc.status, {"error":exc.code}
        except sqlite3.Error:
            status, result = 503, {"error":"storage_unavailable"}
        data = json.dumps(result, ensure_ascii=False).encode()
        keep = self.keep_connection(status, len(body))
        # Advertise 1.1 only for the selected response. Parse subsequent
        # requests with the same stdlib defaults as a fresh connection.
        previous_protocol = self.protocol_version
        if keep:
            self.protocol_version = "HTTP/1.1"
        self.send_response(status)
        self.protocol_version = previous_protocol
        self.send_header("Connection", "keep-alive" if keep else "close")
        self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Content-Length",str(len(data)))
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = respond


def snapshot(source, dest, restore=False):
    if not Path(source).is_file():
        raise ValueError("missing source database")
    with closing(sqlite3.connect(Path(source).resolve().as_uri()+"?mode=ro", uri=True)) as src:
        validate_version(src)
        with open(dest, "xb"):
            pass
        try:
            with closing(sqlite3.connect(dest)) as output:
                src.backup(output)
                if output.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                    raise ValueError("corrupt snapshot")
                if restore:
                    with output:
                        output.execute("UPDATE accounts SET session=NULL")
        except BaseException:
            Path(dest).unlink(missing_ok=True)
            raise


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("action", choices=["serve","backup","restore"])
    cli.add_argument("--db", default="/data/player.sqlite")
    cli.add_argument("--file")
    cli.add_argument("--bind", default="127.0.0.1")
    cli.add_argument("--port", type=int, default=24670)
    cli.add_argument("--room-key-file", default=os.environ.get("ROOM_KEY_FILE"))
    args = cli.parse_args()
    if args.action != "serve":
        if not args.file:
            cli.error("--file required")
        if args.action == "backup":
            snapshot(args.db,args.file)
        else:
            snapshot(args.file,args.db,restore=True)
        return
    initialize(args.db)
    with transaction(args.db) as db:
        private_base.activate_existing(db)
    with ProfileHTTPServer((args.bind,args.port),Handler) as server:
        server.path = args.db
        server.room_key = ""
        if args.room_key_file:
            key_path = Path(args.room_key_file)
            key_path.parent.mkdir(parents=True,exist_ok=True)
            if not key_path.exists():
                with key_path.open("x",encoding="ascii") as key_file:
                    key_file.write(secrets.token_hex(32))
            server.room_key = key_path.read_text(encoding="ascii").strip()
            if not re.fullmatch(r"[a-f0-9]{64}",server.room_key):
                raise ValueError("invalid room key file")
        print(f"PROFILE_READY port={server.server_port} schema={VERSION}",flush=True)
        with raid_scheduler(args.db):
            server.serve_forever()


if __name__ == "__main__":
    main()
