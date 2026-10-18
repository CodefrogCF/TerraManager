#!/usr/bin/env bash
set -euo pipefail
umask 077
tm230_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$tm230_root"
tm230_run="$HOME/tm230-private/run-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$tm230_run"
python3 tool/evaluation/shared_updates/sample_resources.py \
  --container tm230-acceptance-lab-1 --container tm230-acceptance-gateway-1 \
  --process-stats --interface "${TM230_INTERFACE:-wlan0}" \
  --seconds 12 --interval 5 --output "$tm230_run/preflight.jsonl"
python3 - "$tm230_run/preflight.jsonl" <<'PY'
import json, sys
from pathlib import Path
rows = [json.loads(s) for s in Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()]
assert rows[0]['metadata']['clock_ticks_per_second'] > 0
samples = [r for r in rows if 'utc' in r]
assert len(samples) >= 2
for r in samples:
    assert len(r.get('processes', [])) == 2
    for p in r['processes']:
        assert p.get('rss_kib', 0) > 0 and p.get('cpu_user_ticks') is not None
for p in samples[-1]['processes']:
    print('OK:', p['container'], 'RSS KiB=' + str(p['rss_kib']))
PY
nohup python3 tool/evaluation/shared_updates/sample_resources.py \
  --container tm230-acceptance-lab-1 --container tm230-acceptance-gateway-1 \
  --process-stats --interface "${TM230_INTERFACE:-wlan0}" \
  --seconds "${TM230_CAPTURE_SECONDS:-10800}" --interval 5 \
  --output "$tm230_run/pi-resources.jsonl" > "$tm230_run/collector.log" 2>&1 &
tm230_pid=$!
printf '%s\n' "$tm230_pid" > "$tm230_run/collector.pid"
sleep 3
kill -0 "$tm230_pid"
printf 'Messung laeuft\nMessordner: %s\nCollector PID: %s\n' "$tm230_run" "$tm230_pid"
