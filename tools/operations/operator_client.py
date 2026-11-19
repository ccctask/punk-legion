"""One loopback request. Secret input is stdin only; no request body/header logs."""
import http.client
import json
import socket
import sys
import time


def main():
    request = json.load(sys.stdin)
    # Readiness connects do not issue an HTTP request, especially not a POST.
    deadline = time.monotonic() + 10
    while True:
        try:
            with socket.create_connection(('127.0.0.1', 24679), timeout=1):
                break
        except ConnectionRefusedError:
            if time.monotonic() >= deadline:
                print(json.dumps({'state': 'not_sent', 'reason': 'loopback readiness timeout'}))
                return 1
            time.sleep(.1)
    connection = http.client.HTTPConnection('127.0.0.1', 24679, timeout=15)
    sent = False
    try:
        # From this boundary any transport failure is conservatively unknown.
        sent = True
        connection.request(request['method'], request['route'],
                           json.dumps(request['fields']) if request['method'] == 'POST' else None,
                           {'Authorization': 'Bearer ' + request['token'], 'Content-Type': 'application/json'})
        response = connection.getresponse()
        data = response.read(1024 * 1024 + 1)
        if len(data) > 1024 * 1024:
            raise ValueError('response too large')
        print(json.dumps({'state': 'responded', 'status': response.status, 'body': json.loads(data)}))
        return 0
    except Exception as exc:
        print(json.dumps({'state': 'unknown' if sent else 'not_sent', 'reason': type(exc).__name__}))
        return 1
    finally:
        connection.close()


if __name__ == '__main__':
    sys.exit(main())
