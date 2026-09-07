#!/usr/bin/env python3
"""cline_vllm_proxy.py — fixed-port bridge from Cline to the dynamic Perplexity vLLM container.

Cline points at http://127.0.0.1:8012/v1 ONCE. This proxy forwards each connection to
the current Portable Computer vLLM host port, re-discovering it when it changes.
Stdlib only; preserves SSE streaming via raw bidirectional byte piping.

Usage:
    python3 cline_vllm_proxy.py show      # print current vLLM port, model name, Cline config
    python3 cline_vllm_proxy.py            # run the proxy on port 8012 (foreground)
    nohup python3 cline_vllm_proxy.py >/tmp/cline_vllm_proxy.log 2>&1 &   # background

Env: CLINE_PROXY_PORT (default 8012), REFRESH_SEC (default 5)
"""
import subprocess, socket, threading, select, time, sys, json, urllib.request, os

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("CLINE_PROXY_PORT", "8012"))
LABEL = "com.perplexity.computer.local-engine=vllm-docker"
REFRESH_SEC = float(os.environ.get("REFRESH_SEC", "5"))

_cache = {"port": None, "ts": 0.0}
_lock = threading.Lock()


def discover_port():
    """Host port mapped to the vLLM container's chat port (8000), or None."""
    try:
        out = subprocess.check_output(
            ["docker", "ps", "--filter", f"label={LABEL}", "--format", "{{.Ports}}"],
            text=True, timeout=3)
    except Exception:
        return None
    for line in out.splitlines():
        for token in line.split(","):
            token = token.strip()
            if token.endswith("->8000/tcp"):            # chat model, not the PII one (8001)
                host_part = token.split("->")[0]        # 0.0.0.0:43029  or  [::1]:43029
                port = host_part.rsplit(":", 1)[-1]
                if port.isdigit():
                    return int(port)
    return None


def current_port():
    now = time.time()
    with _lock:
        if _cache["port"] and (now - _cache["ts"]) < REFRESH_SEC:
            return _cache["port"]
    p = discover_port()
    if p:
        with _lock:
            _cache["port"] = p
            _cache["ts"] = now
    return p


def model_name(port):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/v1/models", timeout=3) as r:
            data = json.loads(r.read().decode())
        ids = [m.get("id") for m in data.get("data", []) if m.get("id")]
        return ids[0] if ids else None
    except Exception:
        return None


def pipe(a, b):
    """Shovel bytes one way until either socket closes (preserves SSE streaming)."""
    try:
        while True:
            r, _, _ = select.select([a], [], [], 1)
            if a in r:
                data = a.recv(65536)
                if not data:
                    break
                b.sendall(data)
    except Exception:
        pass
    finally:
        for s in (a, b):
            try: s.close()
            except Exception: pass


def handle(client):
    port = current_port()
    if not port:
        try: client.close()
        except Exception: pass
        return
    backend = None
    for _ in range(2):
        try:
            backend = socket.create_connection(("127.0.0.1", port), timeout=5)
            break
        except Exception:
            with _lock:
                _cache["port"] = None
                _cache["ts"] = 0.0
            port = current_port()
            if not port:
                break
    if not backend:
        try: client.close()
        except Exception: pass
        return
    threading.Thread(target=pipe, args=(client, backend), daemon=True).start()
    threading.Thread(target=pipe, args=(backend, client), daemon=True).start()


def serve():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((LISTEN_HOST, LISTEN_PORT))
    srv.listen(64)
    print(f"cline-vllm-proxy listening on {LISTEN_HOST}:{LISTEN_PORT} "
          f"-> dynamic vLLM (refresh every {REFRESH_SEC}s)", flush=True)
    while True:
        client, _ = srv.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "show":
        port = discover_port()
        model = model_name(port) if port else None
        print("=== Cline config (paste into Cline once) ===")
        print(f"  Provider : OpenAI Compatible")
        print(f"  Base URL : http://{LISTEN_HOST}:{LISTEN_PORT}/v1")
        print(f"  API Key  : not-needed")
        print(f"  Model    : {model or '<vLLM not running; start Portable Local Inference first>'}")
        print(f"  Direct vLLM port right now : {port or 'n/a'}")
        if port and not model:
            print("  (model still loading — retry in a few seconds)")
        sys.exit(0)
    serve()


if __name__ == "__main__":
    main()