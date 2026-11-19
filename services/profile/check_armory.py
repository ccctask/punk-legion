"""Fresh account armory contract. Only southern land, spare parts and clock are fixture inputs."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import secrets
import tempfile
from unittest.mock import patch

import factory
import inventory
import platforms
import private_base
import server


def run():
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "armory.sqlite"
        server.initialize(path)
        room_key = secrets.token_hex(32)
        user = server.login(path, {"name": "armory_qa", "password": secrets.token_hex(12)}, True)
        auth = "Bearer " + user["token"]
        owner, robot = user["account"]["id"], user["robots"][0]["id"]

        def post(route, fields):
            return server.handle(path, "POST", "/v1/" + route, fields, auth)

        def start():
            return post("expedition/start", dict(key=secrets.token_hex(8), robots=[robot], location="old_armory"))["expedition"]["active"]

        def internal(action, fields):
            return server.handle(path, "POST", "/internal/expedition/" + action, fields, "Bearer " + room_key, room_key)

        def reject(code, fn, *args):
            try:
                fn(*args)
            except inventory.Fault as error:
                assert error.code == code, error.code
            else:
                raise AssertionError(code)

        def result(mission, outcome, nodes):
            return internal("settle", dict(id=mission["id"], outcome=outcome, seconds=29, nodes=nodes, reports={robot: []}))["receipt"]

        reject("requires_south_land", start)
        with server.transaction(path) as db:
            layout = factory.layout_for(db, owner)
            private_base.save_layout(db, owner, dict(layout, factory_south=True))
            while db.execute("SELECT COUNT(*) FROM (" + inventory.FREE_PARTS + ")", (owner,)).fetchone()[0] < inventory.PART_CAP:
                db.execute("INSERT INTO parts VALUES(?,?,'eye')", (secrets.token_hex(16), owner))

        mission = start()
        assert mission["location"] == internal("open", dict(id=mission["id"], secret=mission["secret"]))["deployment"]["location"] == "old_armory"
        reject("invalid_armory_result", result, mission, "win", [])
        assert not result(mission, "retreat", ["armory_cache"])["first_clear"]
        mission = start()
        first = result(mission, "win", ["armory_cache"])
        assert first["first_clear"] and first["pending_part"] and first["part"] is None and first["changes"] == {"components": 1}
        assert result(mission, "win", ["armory_cache"]) == first
        reject("result_conflict", result, mission, "retreat", [])
        claim_route = "expedition/claim-armory"
        claim = {"key": "claim_armory_one"}
        reject("parts_full", post, claim_route, claim)
        with server.transaction(path) as db:
            free_item = db.execute(inventory.FREE_PARTS + " LIMIT 1", (owner,)).fetchone()["id"]
            db.execute("DELETE FROM parts WHERE id=?", (free_item,))
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(lambda _: post(claim_route, claim), range(2)))
        assert responses[0]["receipt"] == responses[1]["receipt"]
        state = responses[0]["expedition"]
        assert state["wins"] == 0 and not state["pending_drill"] and not state["quick_salvage"]["unlocked"]
        assert state["old_armory"]["last"] == first and not state["old_armory"]["pending_part"]
        item = responses[0]["receipt"]["part"]["id"]
        reject("nothing_to_claim", post, claim_route, {"key": "new_claim_armory"})
        fit = server.handle(path, "GET", "/v1/workshop", {}, auth)["workshop"]["robots"][0]["slots"]
        slots = {k: v["definition"] for k, v in fit.items()}
        slots["weapon"] = "chimney_arm"
        design = post("workshop/design", dict(key="armory_design", version=1, slots=slots, name="Chimney"))["receipt"]["design"]
        reject("blueprint_locked", post, "workshop/build", dict(key="armory_build", design=design, name="copy"))
        assert not platforms.function("chimney_arm")
        preview = post("workshop/apply-preview", dict(design=design, robot=robot))["plan"]
        assert preview["can_apply"]
        installed = post("workshop/apply", dict(key="armory_apply", design=design, robot=robot, fingerprint=preview["fingerprint"]))["receipt"]
        assert installed["installed"]["weapon"] == item
        mission = start()
        deployed = internal("open", dict(id=mission["id"], secret=mission["secret"]))["deployment"]
        assert deployed["inventory"][item] == "chimney_arm" and deployed["points"] == 3
        repeat = result(mission, "win", ["armory_cache"])
        assert not repeat["first_clear"] and not repeat["daily_award"] and repeat["part"] is None
        with patch.object(factory, "day", return_value="2099-11-10"):
            mission = start()
        tomorrow = result(mission, "win", ["armory_cache"])
        assert tomorrow["daily_award"] and tomorrow["changes"] == {"components": 1} and tomorrow["reward_day"] == "2099-11-10"
        with server.transaction(path) as db:
            assert db.execute("SELECT COUNT(*) FROM parts WHERE definition='chimney_arm'").fetchone()[0] == 1
        basic = post("workshop/design", dict(key="basic_design", version=1, slots=dict(slots, weapon="cannon"), name="Basic"))["receipt"]["design"]
        post("workshop/build", dict(key="basic_build", design=basic, name="Spare"))
        route = "robots/" + robot + "/recovery"
        def recycle_quote():
            return server.handle(path, "GET", "/v1/" + route, {}, auth)["recovery"]
        assert recycle_quote()["recycle_reason"] == "parts_full"
        with server.transaction(path) as db:
            free_item = db.execute(inventory.FREE_PARTS + " LIMIT 1", (owner,)).fetchone()["id"]
            db.execute("DELETE FROM parts WHERE id=?", (free_item,))
        view = recycle_quote()
        assert view["can_recycle"] and view["recovered_part"]["id"] == item
        recycle = dict(key="retire_armory", confirmed=True, quote=view["quote"])
        retired = post(route + "/recycle", recycle)["receipt"]
        assert post(route + "/recycle", recycle)["receipt"] == retired and retired["changes"] == {"structure": 1}
        bag = server.handle(path, "GET", "/v1/workshop", {}, auth)["workshop"]["available"]
        assert [x["id"] for x in bag if x["definition"] == "chimney_arm"] == [item]
        second = server.login(path, {"name": "armory_next", "password": secrets.token_hex(12)}, True)
        auth = "Bearer " + second["token"]
        owner, robot = second["account"]["id"], second["robots"][0]["id"]
        with server.transaction(path) as db:
            layout = factory.layout_for(db, owner)
            private_base.save_layout(db, owner, dict(layout, factory_south=True))
            inventory.apply_stock(db, owner, {"components": inventory.STOCK["components"][1]})
        mission = start()
        direct = result(mission, "win", ["armory_cache"])
        assert direct["first_clear"] and direct["part"]["definition"] == "chimney_arm" and not direct["pending_part"]
        assert direct["changes"] == {"components": 0} and direct["daily_award"]
        mission = start()
        assert not result(mission, "win", ["armory_cache"])["daily_award"]
        print("PASS fresh armory access, authority identity, retreat, missing cache, immediate first drop, win replay, capacity, concurrent claim, isolation, physical design apply, fabrication rejection, opening-day and stock caps")


if __name__ == "__main__":
    run()
