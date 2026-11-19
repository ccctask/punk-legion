"""Export both Windows release fixtures outside the source tree and operate their actual UI."""

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time


ROOT = Path(__file__).resolve().parents[1]
PROBE = Path(__file__).with_name("runtime_endpoints_probe.gd").resolve()


class ProfileStub(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        self.server.requests.append(self.path)
        body = b'{"error":"invalid_credentials"}'
        self.send_response(401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def checked(command, env=None, timeout=120):
    run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8", errors="replace", env=env, timeout=timeout)
    if run.returncode or any(x in run.stdout for x in ["SCRIPT ERROR:", "ERROR:", "ENDPOINTS_FAIL"]):
        problems = [x for x in run.stdout.splitlines() if "ERROR" in x or "FAIL" in x]
        raise RuntimeError("\n".join(problems + [run.stdout[-600:]]))
    return run.stdout


def wait_for(file, token, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if file.exists() and token in file.read_text(encoding="utf-8", errors="replace"):
            return
        time.sleep(.1)
    raise AssertionError((file, token))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--room-port", type=int, default=24681)
    parser.add_argument("--profile-port", type=int, default=24682)
    args = parser.parse_args()
    editor = str(args.godot.resolve())
    engine = editor.replace("_console.exe", ".exe")
    output = ROOT / "build/runtime-verification"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp, ThreadingHTTPServer(("127.0.0.1", args.profile_port), ProfileStub) as http:
        stage = Path(tmp) / "game"
        shutil.copytree(ROOT / "game", stage, ignore=shutil.ignore_patterns(".godot", "export_credentials.cfg", "runtime_endpoints.cfg"))
        shutil.copy2(PROBE, stage / "qa_probe.gd")
        settings = stage / "project.godot"
        settings.write_text(settings.read_text(encoding="utf-8").replace("[autoload]", '[autoload]\nQAEndpoints="*res://qa_probe.gd"'), encoding="utf-8")
        checked([editor, "--headless", "--path", stage, "--import"])
        overrides = {**os.environ, "ROOM_HOST": "127.0.0.1", "SOLO_HOST": "127.0.0.1", "PARTY_HOST": "127.0.0.1",
                     "ROOM_PORT": "24871", "SOLO_PORT": "24872", "PARTY_PORT": "24873", "PROFILE_URL": "http://127.0.0.1:1",
                     "EXPECT_SOLO": str(args.room_port + 2), "EXPECT_PARTY": str(args.room_port + 3)}
        evidence = Path(tmp) / "debug-evidence.log"
        checked([editor, "--headless", "--path", stage], {**overrides, "QA_ENDPOINTS_MODE": "debug", "QA_ENDPOINTS_EVIDENCE": str(evidence)}, timeout=20)
        assert evidence.read_text(encoding="utf-8").strip() == "ENDPOINTS_OK debug"
        print("PASS debug separate room/solo/party, explicit room port and IPv6")
        http.requests = []
        threading.Thread(target=http.serve_forever, daemon=True).start()
        config = stage / "runtime_endpoints.cfg"
        room_log = Path(tmp) / "room.log"
        server = subprocess.Popen([engine, "--headless", "--path", stage, "--log-file", room_log,
                                   "res://net/server.tscn", "--", "--server"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  env={**os.environ, "ROOM_PORT": str(args.room_port)})
        try:
            wait_for(room_log, "ROOM_READY")
            for mode in ["configured", "missing"]:
                if mode == "configured":
                    sections = [f'[profile]\nurl="http://127.0.0.1:{args.profile_port}"']
                    for service, port in [("room", args.room_port), ("solo", args.room_port + 2), ("party", args.room_port + 3)]:
                        sections.append(f'[{service}]\nhost="127.0.0.1"\nport={port}')
                    config.write_text("\n\n".join(sections) + "\n", encoding="utf-8")
                else:
                    config.write_text('[solo]\nhost="127.0.0.1"\nport=65536\n[party]\nhost="bad host"\nport=24684\n', encoding="utf-8")
                folder = output / mode
                folder.mkdir(exist_ok=True)
                binary = folder / "PunkLegion.exe"
                checked([editor, "--headless", "--path", stage, "--export-release", "Windows Release QA", binary])
                client_log = folder / "client.log"
                client_log.unlink(missing_ok=True)
                run = subprocess.run([binary, "--headless"],
                                     env={**overrides, "QA_ENDPOINTS_MODE": mode, "QA_ENDPOINTS_EVIDENCE": str(client_log)},
                                     timeout=25, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                log = client_log.read_text(encoding="utf-8", errors="replace")
                assert run.returncode == 0 and f"ENDPOINTS_OK {mode}" in log, log
                assert http.requests == ["/v1/sessions"], http.requests
                assert room_log.read_text(encoding="utf-8").count("ROOM_JOIN") == 1
                print(f"PASS {mode} {binary.stat().st_size} bytes SHA256 {hashlib.sha256(binary.read_bytes()).hexdigest()}", flush=True)
            print(f"PASS actual release UDP {args.room_port}, HTTP {args.profile_port}, missing UI and zero extra requests")
        finally:
            server.terminate()
            server.wait(timeout=10)
            http.shutdown()


if __name__ == "__main__":
    main()
