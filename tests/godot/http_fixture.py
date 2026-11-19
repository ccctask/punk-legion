"""Current-run preview responses over real ephemeral loopback HTTP; no database."""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
import re
import socket
import threading
import time

def preview(robot):
    slots=[]
    for slot,part in [('core','boiler'),('head','eye'),('weapon','cannon'),('utility',''),('armor','')]:
        slots.append(dict(slot=slot,current=part,current_id='item-'+slot if part else '',wanted=part,
            item='item-'+slot if part else '',action='keep' if part else 'empty',disposition='keep'))
    return dict(plan=dict(robot=robot,design='design-a',robot_name='Copper',design_name='Starter',revision=1,
        design_chassis='crawler',chassis='crawler',slots=slots,fingerprint='pilot-fit-current',
        bag_used=0,bag_after=0,bag_capacity=20,reason='',can_apply=True))

def refresh_reply(case, number):
    """Scheduler transport only; never a business profile or gameplay result."""
    if case not in ('ok', 'hold-a', 'hold-b', 'hold-c', 'hold-d', 'fail-once', 'unauthorized'):
        raise ValueError('Unknown refresh fixture case')
    if type(number) is not int or number < 1:
        raise ValueError('Invalid refresh request number')
    status = 401 if case == 'unauthorized' else 503 if case == 'fail-once' and number == 1 else 200
    return status, dict(revision=number, server_now=1700000000 + number, fixture='scheduler-transport-only')

class Handler(BaseHTTPRequestHandler):
    protocol_version='HTTP/1.0'
    def setup(self):
        super().setup();self.connection.settimeout(5)
    def log_message(self,*args): pass
    def do_GET(self):
        match = re.fullmatch(r'/qa/page-refresh/(ok|hold-a|hold-b|hold-c|hold-d|fail-once|unauthorized)', self.path)
        if not match:
            self.send_error(404)
            return
        case = match[1]
        with self.server.lock:
            key = 'refresh:' + case
            number = self.server.counts.get(key, 0) + 1
            self.server.counts[key] = number
        fields = dict(refresh_case=case, method='GET', path=self.path, number=number)
        self.server.log(dict(event='refresh_request_begin', **fields))
        try:
            if case.startswith('hold-'):
                release = self.server.folder / ('refresh-release-' + case)
                while not release.exists():
                    if self.server.stop_event.wait(.01):
                        self.server.log(dict(event='refresh_handler_stopped', **fields))
                        return
            status, response = refresh_reply(case, number)
            payload = json.dumps(response).encode('utf8')
            self.server.log(dict(event='refresh_response_attempt', status=status, **fields))
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(payload)
            self.wfile.flush()
            self.server.log(dict(event='refresh_response_sent', status=status, **fields))
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError) as error:
            # Only the explicit held/cancelled cases permit the client's close.
            cancel_marker = self.server.folder / ('refresh-cancel-' + case + '-' + str(number))
            if not case.startswith('hold-') or not cancel_marker.is_file():
                self.server.log(dict(event='refresh_handler_failure', error=type(error).__name__, **fields))
                raise
            self.server.log(dict(event='refresh_client_closed', error=type(error).__name__, **fields))
        except BaseException as error:
            self.server.log(dict(event='refresh_handler_failure', error=type(error).__name__, **fields))
            raise
        finally:
            self.close_connection = True
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
        assert self.path == '/v1/workshop/apply-preview'
        robot=body['robot']; assert body['design']=='design-a'
        with self.server.lock:
            number=self.server.counts.get(robot,0)+1; self.server.counts[robot]=number
        self.server.log(dict(event='request_begin',robot=robot,method='POST',path=self.path,number=number))
        delay=10 if robot.endswith('timeout') else 2 if robot.endswith('close') else 0
        if self.server.stop_event.wait(delay):
            self.server.log(dict(event='handler_stopped',robot=robot)); return
        status=500 if number==1 and not robot.endswith('close') else 200
        payload=json.dumps({'error':'fixture_unavailable'} if status==500 else preview(robot)).encode()
        self.server.log(dict(event='response_attempt',robot=robot,status=status))
        try:
            self.send_response(status);self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(payload)));self.send_header('Connection','close');self.end_headers()
            self.wfile.write(payload);self.wfile.flush()
            self.server.log(dict(event='response_sent',robot=robot,status=status))
        except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError):
            self.server.log(dict(event='client_closed',robot=robot,status=status))
        finally: self.close_connection=True

def guide_handler(guide):
    """Six fixed display-only GET replies; the existing Fixture owns all resources."""
    success=json.dumps(dict(guide=guide)).encode('utf8')
    statuses=(200,200,200,200,503,401)
    class GuideHandler(Handler):
        def do_GET(self):
            matched=self.headers.get('Authorization')=='Bearer pl-guide-display-only'
            if self.path!='/v1/onboarding' or not matched:
                self.server.log(dict(event='guide_request_rejected',method='GET',path=self.path,header_matched=matched))
                self.send_error(404 if self.path!='/v1/onboarding' else 403)
                return
            with self.server.lock:
                number=self.server.counts.get('guide',0)+1;self.server.counts['guide']=number
            fields=dict(method='GET',path=self.path,number=number,header_matched=True)
            self.server.log(dict(event='guide_request_begin',**fields))
            if number>len(statuses):
                self.server.log(dict(event='guide_unexpected_request',**fields))
                self.send_error(409)
                return
            status=statuses[number-1]
            try:
                if self.server.stop_event.wait(.35):
                    self.server.log(dict(event='guide_handler_stopped',**fields));return
                payload=success if status==200 else json.dumps(dict(error='fixture_unavailable' if status==503 else 'session_expired')).encode('utf8')
                self.server.log(dict(event='guide_response_attempt',status=status,**fields))
                self.send_response(status);self.send_header('Content-Type','application/json')
                self.send_header('Content-Length',str(len(payload)));self.send_header('Connection','close');self.end_headers()
                self.wfile.write(payload);self.wfile.flush()
                self.server.log(dict(event='guide_response_sent',status=status,**fields))
            except BaseException as exc:
                self.server.log(dict(event='guide_handler_failure',error=type(exc).__name__,**fields));raise
            finally:self.close_connection=True
        def do_POST(self):
            self.server.log(dict(event='guide_unexpected_post',method='POST',path=self.path))
            self.send_error(405)
    return GuideHandler


class Fixture(ThreadingHTTPServer):
    daemon_threads=False; block_on_close=True
    def __init__(self,folder,handler=Handler):
        self.folder=folder;self.lock=threading.RLock();self.stop_event=threading.Event();self.counts={}
        super().__init__(('127.0.0.1',0),handler)
        self.port=self.server_address[1]
        self.thread=threading.Thread(target=self.serve_forever,kwargs={'poll_interval':.05},name='pilot-http-fixture')
    def log(self,row):
        with self.lock:
            with (self.folder/'http-events.jsonl').open('a',encoding='utf8') as stream:
                stream.write(json.dumps(dict(utc=time.time(),**row))+'\n')
    def start(self): self.thread.start()
    def close(self):
        self.stop_event.set()
        # shutdown waits for serve_forever's completion event; it must not be
        # called when Thread.start failed or no serving thread ever ran.
        if self.thread.is_alive():self.shutdown()
        self.server_close()
        if self.thread.ident is not None:self.thread.join(timeout=4)
        assert not self.thread.is_alive()
        with socket.socket() as probe:
            probe.settimeout(.3)
            assert probe.connect_ex(('127.0.0.1',self.port)) != 0, 'Fixture must no longer listen'
        return dict(port=self.port,fixture_thread_alive=False,handlers_joined=True,listener_closed=True)
