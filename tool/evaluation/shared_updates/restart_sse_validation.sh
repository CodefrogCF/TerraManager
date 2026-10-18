#!/usr/bin/env bash
# Rebuild/recreate ONLY the disposable lab after the SSE disconnect correction.
set -eu
umask 077
tm186_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$tm186_project_dir"
export TM186_HOST="${TM186_HOST:?Set TM186_HOST to the Pi LAN host or IP}"
export TM186_BIND_IP="${TM186_BIND_IP:-$TM186_HOST}"
export TM186_PUBLIC_ORIGIN="https://$TM186_HOST:8443"
export TM186_CERT_DIR="${TM186_CERT_DIR:-$PWD/deploy/certs}"
export TM186_ANIMALS=100
export TM186_HISTORY=20
: "${TM186_PREVIOUS_RUN:?Set TM186_PREVIOUS_RUN to the stopped comparison resource directory}"

# Stop only the sampler whose command line matches this exact output file.
python3 - "$TM186_PREVIOUS_RUN" <<'PY'
from pathlib import Path
import os, signal, sys
folder = Path(sys.argv[1]).resolve()
folder.relative_to((Path.home() / 'tm186-private').resolve())
pid = int((folder / 'collector.pid').read_text().strip())
assert pid > 1, 'Unexpected sampler PID'
try:
    arguments = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
except FileNotFoundError:
    print('Previous sampler already finished.')
else:
    expected = str(folder / 'pi-resources.jsonl').encode()
    script_matches = any(arg.endswith(b'/sample_resources.py') for arg in arguments)
    output_matches = any(arg == b'--output' and index + 1 < len(arguments)
                         and arguments[index + 1] == expected
                         for index, arg in enumerate(arguments))
    assert script_matches and output_matches, 'PID does not match this sampler; nothing stopped.'
    os.kill(pid, signal.SIGTERM)
    print('Previous sampler stopped:', pid)
PY
if command -v vcgencmd >/dev/null 2>&1; then
  vcgencmd get_throttled > "$TM186_PREVIOUS_RUN/throttling-after.txt"
fi

docker compose -p tm186-evaluation -f tool/evaluation/shared_updates/compose.yaml build lab
docker compose -p tm186-evaluation -f tool/evaluation/shared_updates/compose.yaml \
  up -d --no-deps --no-build --force-recreate lab

tm186_ready=false
for tm186_attempt in $(seq 1 90); do
  if docker exec tm186-evaluation-lab-1 sh -eu -c \
    'set -- /tmp/tm186-*/credentials.json; test "$#" -eq 1 && test -s "$1"' \
    >/dev/null 2>&1; then
    tm186_ready=true
    break
  fi
  sleep 1
done
if [ "$tm186_ready" != true ]; then
  echo 'New disposable lab did not create its credentials file.' >&2
  docker compose -p tm186-evaluation -f tool/evaluation/shared_updates/compose.yaml logs --tail 20 lab
  exit 1
fi
install -d -m 700 "$HOME/tm186-private"
tm186_credentials_tmp="$(mktemp "$HOME/tm186-private/.credentials.XXXXXX")"
trap 'rm -f -- "$tm186_credentials_tmp"' EXIT
docker exec tm186-evaluation-lab-1 sh -eu -c \
  'set -- /tmp/tm186-*/credentials.json; test "$#" -eq 1; test -s "$1"; cat -- "$1"' \
  > "$tm186_credentials_tmp"
test -s "$tm186_credentials_tmp"
chmod 600 "$tm186_credentials_tmp"
mv -f -- "$tm186_credentials_tmp" "$HOME/tm186-private/credentials.json"
printf '%s\n' 'New private credentials exported: ~/tm186-private/credentials.json'

docker compose -p tm186-evaluation -f tool/evaluation/shared_updates/compose.yaml \
  up -d --no-deps --no-build --force-recreate gateway
bash tool/evaluation/shared_updates/start_sse_validation.sh
