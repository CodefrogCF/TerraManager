#!/usr/bin/env bash
# Builds and starts ONLY the disposable Issue #230 fixture on port 8443.
set -euo pipefail
umask 077
tm230_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$tm230_root"
export TM230_VERSION="$(git rev-parse --short HEAD)"
export TM230_HOST="${TM230_HOST:-192.168.1.117}"
export TM230_CERT_DIR="$tm230_root/deploy/certs"
if [ -z "${TM230_WEB_IMAGE:-}" ]; then
  tm230_web_container="$(docker compose --env-file deploy/.env -f deploy/compose.yaml ps -q web)"
  test -n "$tm230_web_container" || { printf 'Production web image could not be identified.\n'; exit 1; }
  TM230_WEB_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$tm230_web_container")"
fi
export TM230_WEB_IMAGE
case "$TM230_WEB_IMAGE" in
  terramanager-web:*) ;;
  *) printf 'Expected an explicitly identified local TerraManager web image.\n'; exit 1 ;;
esac
tm230_compose=(docker compose -p tm230-acceptance -f tool/evaluation/shared_updates/compose.integrated.yaml)
"${tm230_compose[@]}" config --quiet
docker image inspect "$TM230_WEB_IMAGE" >/dev/null
test -f "$TM230_CERT_DIR/server.crt"
test -f "$TM230_CERT_DIR/server.key"
"${tm230_compose[@]}" build lab
# Release 8443 only after the new image has built successfully. These are the
# old disposable evaluation services; the production project on 443 is untouched.
TM186_HOST="$TM230_HOST" TM186_BIND_IP="$TM230_HOST" \
  TM186_PUBLIC_ORIGIN="https://$TM230_HOST:8443" TM186_CERT_DIR="$TM230_CERT_DIR" \
  TM186_ANIMALS=100 TM186_HISTORY=20 \
  docker compose -p tm186-evaluation -f tool/evaluation/shared_updates/compose.yaml stop gateway lab
"${tm230_compose[@]}" up -d --no-build
tm230_private="$HOME/tm230-private"
install -d -m 700 "$tm230_private"
# Scratch paths change at each container creation. Never use a logged old path.
tm230_ready=0
for tm230_attempt in $(seq 1 120); do
  if "${tm230_compose[@]}" exec -T lab sh -eu -c 'cat /tmp/tm186-*/credentials.json' \
      > "$tm230_private/credentials.pending.json" 2>/dev/null; then
    tm230_ready=1
    break
  fi
  sleep 1
done
test "$tm230_ready" = 1 || { printf 'Fixture not ready; inspect compose logs.\n'; exit 1; }
python3 - "$tm230_private/credentials.pending.json" <<'PY'
import json, sys
from pathlib import Path
c = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
assert c['kind'] == 'disposable-integrated-shared-care'
assert len(c['clients']) == 3 and len(c['fixtureId']) >= 24
PY
mv -- "$tm230_private/credentials.pending.json" "$tm230_private/credentials.json"
chmod 600 "$tm230_private/credentials.json"
git rev-parse HEAD > "$tm230_private/source-head.txt"
sha256sum tool/evaluation/shared_updates/lab_server.dart \
  tool/evaluation/shared_updates/compose.integrated.yaml \
  tool/evaluation/shared_updates/sample_resources.py \
  tool/evaluation/shared_updates/integrated_benchmark.cjs > "$tm230_private/source-sha256.txt"
docker image inspect --format '{{json .RepoTags}} {{.Id}} {{.Architecture}}' \
  "terramanager-integrated-acceptance:$TM230_VERSION" "$TM230_WEB_IMAGE" \
  > "$tm230_private/image-identities.txt"
"${tm230_compose[@]}" ps
printf '\nTeststack bereit: https://%s:8443\nPrivate Zugangsdaten: %s/credentials.json\n' \
  "$TM230_HOST" "$tm230_private"
printf 'Die Zugangsdaten nicht hier oder bei GitHub einfuegen.\n'
