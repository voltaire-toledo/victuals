#!/usr/bin/env bash

# Target-neutral definition adapter. This file deliberately owns only catalog
# discovery and validation; package managers, ordering, privilege, conditions,
# configuration, and completion checks remain in the Ubuntu workflow.

set -Eeuo pipefail

VICTUALS_CATALOG_DIR="${VICTUALS_CATALOG_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../victuals/definitions" && pwd)}"

victuals_catalog_file() {
  local catalog="$1"
  case "$catalog" in
    applications|policies|presets) printf '%s/%s.json' "$VICTUALS_CATALOG_DIR" "$catalog" ;;
    *) printf 'Unknown Victuals catalog: %s\n' "$catalog" >&2; return 2 ;;
  esac
}

victuals_catalog_require_tools() {
  command -v python3 >/dev/null 2>&1 \
    || { printf 'Victuals catalog validation requires python3\n' >&2; return 127; }
}

victuals_catalog_validate() {
  victuals_catalog_require_tools
  VICTUALS_CATALOG_DIR="$VICTUALS_CATALOG_DIR" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["VICTUALS_CATALOG_DIR"])
manifest = json.loads((root / "manifest.json").read_text())
if manifest.get("kind") != "manifest":
    raise SystemExit("manifest.json must have kind=manifest")

ids = set()
for name in ("applications", "policies", "presets"):
    data = json.loads((root / f"{name}.json").read_text())
    if data.get("kind") != "catalog":
        raise SystemExit(f"{name}.json must have kind=catalog")
    for item in data.get("items", []):
        item_id = item.get("id")
        if not item_id or item_id in ids:
            raise SystemExit(f"duplicate or missing definition id: {item_id!r}")
        ids.add(item_id)
        for dependency in item.get("dependencies", []):
            # Dependencies may refer to a definition in another catalog.
            if not isinstance(dependency, str) or not dependency:
                raise SystemExit(f"invalid dependency in {item_id}")
print(f"Victuals definitions validated: {len(ids)} records")
PY
}

victuals_catalog_count() {
  victuals_catalog_require_tools
  VICTUALS_CATALOG_FILE="$(victuals_catalog_file "$1")" python3 - <<'PY'
import json, os
from pathlib import Path
data = json.loads(Path(os.environ["VICTUALS_CATALOG_FILE"]).read_text())
print(len(data.get("items", [])))
PY
}

victuals_catalog_label() {
  victuals_catalog_require_tools
  VICTUALS_CATALOG_FILE="$(victuals_catalog_file "$1")" VICTUALS_CATALOG_ID="$2" python3 - <<'PY'
import json, os
from pathlib import Path
data = json.loads(Path(os.environ["VICTUALS_CATALOG_FILE"]).read_text())
wanted = os.environ["VICTUALS_CATALOG_ID"]
for item in data.get("items", []):
    if item.get("id") == wanted:
        print(f"{item['name']}: {item['description']}")
        break
else:
    raise SystemExit(f"definition not found: {wanted}")
PY
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    validate)
      victuals_catalog_validate
      ;;
    *)
      # This adapter is normally sourced by the Ubuntu workflow. Keep direct
      # invocation intentionally narrow so it cannot mutate the host.
      printf 'Usage: %s validate\n' "$(basename -- "$0")" >&2
      exit 2
      ;;
  esac
fi
