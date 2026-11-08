#!/usr/bin/env bash
# Development loop: copies ../src into the running container and recompiles the Copilot package.
# Usage: ./iris/dev-load.sh [container]
set -euo pipefail
export MSYS_NO_PATHCONV=1
CONTAINER="${1:-copilot-iris}"
HERE="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
docker exec -u root "$CONTAINER" rm -rf /tmp/src
docker cp "$HERE/../src" "$CONTAINER:/tmp/src"
docker exec -u root "$CONTAINER" chown -R irisowner /tmp/src
docker exec -i "$CONTAINER" iris session IRIS -U COPILOT <<'EOF' | grep -vE '^(COPILOT>|\s*$)'
do $system.OBJ.LoadDir("/tmp/src","ck-d",.err,1)
write "ERRORS: ",+$get(err),!
set i="" for { set i=$order(err(i)) quit:i=""  write $get(err(i)),! }
halt
EOF
