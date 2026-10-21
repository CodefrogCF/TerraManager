#!/usr/bin/env bash
# Switch only the disposable #230 gateway. Never run during a measured window.
set -euo pipefail
umask 077

if [ "$#" -ne 3 ] || ! [[ "$1" =~ ^(sse|polling)$ ]] ||
   ! [[ "$2" =~ ^terramanager-web:[a-zA-Z0-9_.-]+$ ]] ||
   ! [[ "$3" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  printf 'Usage: bash switch_integrated_web.sh sse|polling terramanager-web:TAG sha256:EXPECTED_ID\n' >&2
  exit 2
fi
tm230_mode="$1"
export TM230_WEB_IMAGE="$2"
tm230_expected_id="$3"
if [ -n "${TM230_CHECKOUT_ROOT:-}" ]; then
  [[ "$TM230_CHECKOUT_ROOT" = /* ]]
  tm230_root="$(cd -- "$TM230_CHECKOUT_ROOT" && pwd -P)"
else
  tm230_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
cd "$tm230_root"
test -f tool/evaluation/shared_updates/compose.integrated.yaml
test -f deploy/compose.yaml
git rev-parse --is-inside-work-tree >/dev/null
tm230_private="$HOME/tm230-private"
test -f "$tm230_private/credentials.json"

# Derive the existing lab version rather than recreating it from today's HEAD.
tm230_lab_id="$(docker inspect --format '{{.Id}}' tm230-acceptance-lab-1)"
tm230_lab_image="$(docker inspect --format '{{.Config.Image}}' "$tm230_lab_id")"
tm230_lab_started="$(docker inspect --format '{{.State.StartedAt}}' "$tm230_lab_id")"
tm230_lab_project="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$tm230_lab_id")"
test "$tm230_lab_project" = tm230-acceptance
test "$(docker inspect --format '{{.State.Running}}' "$tm230_lab_id")" = true
[[ "$tm230_lab_image" =~ ^terramanager-integrated-acceptance:([0-9a-f]{7,40})$ ]]
export TM230_VERSION="${BASH_REMATCH[1]}"
TM230_HOST="$(python3 - "$tm230_private/credentials.json" <<'PY'
import ipaddress, json, sys
from pathlib import Path
from urllib.parse import urlsplit
c = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
u = urlsplit(c['origin'])
assert c['kind'] == 'disposable-integrated-shared-care'
assert u.scheme == 'https' and u.port == 8443 and not u.username and not u.password
assert not u.query and not u.fragment and u.path in ('', '/')
address = ipaddress.ip_address(u.hostname)
assert address.version == 4 and address.is_private
print(address)
PY
)"
export TM230_HOST
export TM230_CERT_DIR="$tm230_root/deploy/certs"
test -f "$TM230_CERT_DIR/server.crt"
test -f "$TM230_CERT_DIR/server.key"
test "$(docker image inspect --format '{{.Id}}' "$TM230_WEB_IMAGE")" = "$tm230_expected_id"
test "$(docker image inspect --format '{{.Architecture}}' "$TM230_WEB_IMAGE")" = arm64
tm230_before_gateway="$(docker inspect --format '{{.Id}}' tm230-acceptance-gateway-1)"
test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$tm230_before_gateway")" = tm230-acceptance
tm230_before_image="$(docker inspect --format '{{.Image}}' "$tm230_before_gateway")"
tm230_compose=(docker compose -p tm230-acceptance -f tool/evaluation/shared_updates/compose.integrated.yaml)
"${tm230_compose[@]}" config --quiet

# End only the explicitly named resource sampler before the next mode's capture.
if [ -n "${TM230_PREVIOUS_CAPTURE_DIR:-}" ]; then
  python3 - "$TM230_PREVIOUS_CAPTURE_DIR" <<'PY'
import json, os, re, signal, sys, time
from datetime import datetime, timezone
from pathlib import Path
run = Path(sys.argv[1]).resolve(strict=True)
assert run.parent == (Path.home() / 'tm230-private').resolve()
assert re.fullmatch(r'run-\d{8}T\d{6}Z', run.name)
pid = int((run / 'collector.pid').read_text().strip())
assert pid > 1
process = Path('/proc') / str(pid)
if process.exists():
    assert process.stat().st_uid == os.getuid()
    args = (process / 'cmdline').read_bytes().split(b'\0')
    assert any(Path(os.fsdecode(arg)).name == 'sample_resources.py' for arg in args if arg)
    assert os.fsencode(str(run / 'pi-resources.jsonl')) in args
    assert b'tm230-acceptance-lab-1' in args and b'tm230-acceptance-gateway-1' in args
    os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 10
    while process.exists() and time.monotonic() < deadline:
        try:
            if (process / 'stat').read_text().split(') ', 1)[1].startswith('Z '): break
        except FileNotFoundError: break
        time.sleep(.1)
    if process.exists():
        assert (process / 'stat').read_text().split(') ', 1)[1].startswith('Z '), 'Collector did not stop; no gateway switch'
record = dict(kind='explicit-resource-capture-stop', pid=pid, utc=datetime.now(timezone.utc).isoformat())
(run / 'collector-stop.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print('Previous resource capture finished:', run)
PY
fi

# --no-deps leaves the lab, its sessions, synthetic data and fixture ID intact.
"${tm230_compose[@]}" up -d --no-deps --no-build --pull never gateway
test "$(docker inspect --format '{{.Id}}' tm230-acceptance-lab-1)" = "$tm230_lab_id"
test "$(docker inspect --format '{{.State.StartedAt}}' "$tm230_lab_id")" = "$tm230_lab_started"
test "$(docker inspect --format '{{.State.Running}}' "$tm230_lab_id")" = true
test "$(docker inspect --format '{{.Image}}' tm230-acceptance-gateway-1)" = "$tm230_expected_id"
tm230_after_gateway="$(docker inspect --format '{{.Id}}' tm230-acceptance-gateway-1)"
tm230_record="$tm230_private/web-switch-$(date -u +%Y%m%dT%H%M%SZ).json"
python3 - "$tm230_record" "$tm230_mode" "$TM230_WEB_IMAGE" "$tm230_expected_id" \
    "$tm230_before_gateway" "$tm230_after_gateway" "$tm230_before_image" \
    "$tm230_lab_id" "$tm230_lab_started" "$(git rev-parse HEAD)" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
path, mode, ref, identity, old_gateway, gateway, old_image, lab, started, head = sys.argv[1:]
record = dict(kind='integrated-gateway-switch', utc=datetime.now(timezone.utc).isoformat(),
              requestedMode=mode, webImageRef=ref, webImageId=identity,
              previousGatewayContainerId=old_gateway, gatewayContainerId=gateway,
              previousGatewayImageId=old_image, unchangedLabContainerId=lab,
              unchangedLabStartedAt=started, operatorCheckoutHead=head,
              limits=['Requested mode is a label; the browser runner verifies SSE presence/absence.',
                      'Gateway process counters restart at a gateway recreation; do not bridge identities.'])
with Path(path).open('x', encoding='utf-8') as output:
    output.write(json.dumps(record, indent=2) + '\n')
PY
"${tm230_compose[@]}" ps
printf '\nGateway switched: %s; lab identity unchanged.\nRecord: %s\n' "$tm230_mode" "$tm230_record"
