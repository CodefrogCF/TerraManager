#!/usr/bin/env bash
# Prepare only the isolated 8443 evaluation gateway and resource capture.
(
  set -eu
  umask 077
  tm186_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
  cd "$tm186_project_dir"
  export TM186_HOST="${TM186_HOST:?Set TM186_HOST to the Pi LAN host or IP}"
  export TM186_BIND_IP="${TM186_BIND_IP:-$TM186_HOST}"
  export TM186_PUBLIC_ORIGIN="https://$TM186_HOST:8443"
  export TM186_CERT_DIR="${TM186_CERT_DIR:-$PWD/deploy/certs}"
  export TM186_INTERFACE="${TM186_INTERFACE:-wlan0}"
  export TM186_ANIMALS=100
  export TM186_HISTORY=20

  docker compose -f tool/evaluation/shared_updates/compose.yaml config --quiet
  docker compose -f tool/evaluation/shared_updates/compose.yaml \
    up -d --no-deps --no-build gateway

  tm186_run_dir="$HOME/tm186-private/sse-$(date -u +%Y%m%dT%H%M%SZ)"
  install -d -m 700 "$tm186_run_dir"
  docker image inspect --format '{{json .RepoTags}} {{.Id}} {{.Architecture}}' \
    terramanager-update-evaluation:local caddy:2.11.4-alpine \
    > "$tm186_run_dir/image-identities.txt"
  git rev-parse HEAD > "$tm186_run_dir/source-head.txt"
  sha256sum tool/evaluation/shared_updates/sample_resources.py \
    tool/evaluation/shared_updates/browser_benchmark.cjs \
    tool/evaluation/shared_updates/web/client.js \
    > "$tm186_run_dir/source-sha256.txt"
  if command -v vcgencmd >/dev/null 2>&1; then
    vcgencmd get_throttled > "$tm186_run_dir/throttling-before.txt"
  fi

  python3 tool/evaluation/shared_updates/sample_resources.py \
    --container tm186-evaluation-lab-1 \
    --container tm186-evaluation-gateway-1 \
    --interface "$TM186_INTERFACE" --process-stats --seconds 12 --interval 5 \
    --output "$tm186_run_dir/preflight.jsonl"

  python3 - "$tm186_run_dir/preflight.jsonl" <<'PY'
import json, sys
from pathlib import Path
rows = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
assert rows[0]["metadata"].get("clock_ticks_per_second", 0) > 0, "CPU clock tick rate unavailable"
samples = [row for row in rows if "utc" in row]
assert len(samples) >= 2, "Too few resource samples"
for row in samples:
    assert "docker_stats_error" not in row, "Docker stats failed"
    processes = row.get("processes", [])
    assert len(processes) == 2, "Expected both processes"
    for process in processes:
        assert process.get("memory_available") and process.get("rss_kib", 0) > 0, "Process RSS unavailable"
        assert process.get("cpu_user_ticks") is not None, "Process CPU unavailable"
for process in samples[-1]["processes"]:
    print("OK:", process["container"], "RSS KiB=" + str(process["rss_kib"]))
PY

  nohup python3 tool/evaluation/shared_updates/sample_resources.py \
    --container tm186-evaluation-lab-1 \
    --container tm186-evaluation-gateway-1 \
    --interface "$TM186_INTERFACE" --process-stats --seconds 2700 --interval 5 \
    --output "$tm186_run_dir/pi-resources.jsonl" \
    > "$tm186_run_dir/collector.log" 2>&1 &
  tm186_collector_pid=$!
  printf '%s\n' "$tm186_collector_pid" > "$tm186_run_dir/collector.pid"
  sleep 3
  if ! kill -0 "$tm186_collector_pid" 2>/dev/null; then
    cat "$tm186_run_dir/collector.log"
    exit 1
  fi
  printf 'Messung laeuft\nMessordner: %s\nCollector PID: %s\n' \
    "$tm186_run_dir" "$tm186_collector_pid"
)
