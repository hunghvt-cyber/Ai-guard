#!/usr/bin/env python3
import os, socket, threading, signal

sock_path = os.environ["RELAY_SOCKET"]
dest_host = os.environ["RELAY_DEST_HOST"]
dest_port = int(os.environ.get("RELAY_DEST_PORT", "22"))

if os.path.exists(sock_path):
    os.unlink(sock_path)
os.makedirs(os.path.dirname(sock_path), mode=0o700, exist_ok=True)

srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sock_path)
os.chmod(sock_path, 0o600)
srv.listen(8)
stop = False

def close_all(*_):
    global stop
    stop = True
    try: srv.close()
    except OSError: pass
    try: os.unlink(sock_path)
    except OSError: pass

signal.signal(signal.SIGTERM, close_all)
signal.signal(signal.SIGINT, close_all)

def pipe(a, b):
    try:
        while True:
            data = a.recv(65536)
            if not data: break
            b.sendall(data)
    except OSError:
        pass
    finally:
        try: b.shutdown(socket.SHUT_WR)
        except OSError: pass

def handle(client):
    upstream = None
    try:
        upstream = socket.create_connection((dest_host, dest_port), timeout=10)
        t = threading.Thread(target=pipe, args=(client, upstream), daemon=True)
        t.start()
        pipe(upstream, client)
        t.join(timeout=2)
    finally:
        for s in (client, upstream):
            if s:
                try: s.close()
                except OSError: pass

while not stop:
    try:
        client, _ = srv.accept()
    except OSError:
        break
    threading.Thread(target=handle, args=(client,), daemon=True).start()

close_all()
