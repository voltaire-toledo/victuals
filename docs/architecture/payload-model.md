# Victuals payload model

Victuals separates presentation, orchestration, and installation instructions.
The shell or future native UI is a thin bootstrap and adapter. It does not own
the application catalog.

## Remote layout

The canonical payload root is:

```text
https://raw.githubusercontent.com/voltaire-toledo/victuals/main/
```

That URL maps directly to this repository’s root at the selected Git ref. For
example:

```text
payloads/manifest.json
→ https://raw.githubusercontent.com/voltaire-toledo/victuals/main/payloads/manifest.json

payloads/packages/firefox.json
→ https://raw.githubusercontent.com/voltaire-toledo/victuals/main/payloads/packages/firefox.json
```

The ref should be pinned for reproducible hydration. A release or profile may
override `main` with a tag or commit SHA.

## Fetch and queue lifecycle

1. Bootstrap fetches and validates `payloads/manifest.json`.
2. It fetches only the sequence and menu definition for the next stage.
3. A menu selection emits package IDs, not package bodies.
4. Each package ID is resolved through `payloads/packages/index.json` and its
   individual JSON document is fetched, checksum-checked, and schema-validated
   as it enters the queue.
5. Dependencies are package IDs. They are resolved recursively as they enter
   the queue, with cycle detection and a stable topological order.
6. The resulting queue is presented for confirmation, then adapters execute
   the platform-specific actions encoded in each package document.
7. Metric events record queue, fetch, install, validation, cancellation, and
   export outcomes without embedding telemetry policy in shell code.

The initial manifest and catalog index are metadata, not the full package
library. Package bodies remain independently cacheable and replaceable.

## Object boundaries

- `schemas/v1/package.schema.json`: one package/application/tool recipe,
  including delivery manager, platform scope, dependencies, actions, and
  validation.
- `schemas/v1/menu.schema.json`: menu labels, choices, defaults, and the
  package IDs a choice may enqueue.
- `schemas/v1/sequence.schema.json`: ordered menus and queue timing. This is
  where navigation and sequencing live, not in the UI script.
- `schemas/v1/payload.schema.json`: the small bootstrap manifest and remote
  object references.
- `schemas/v1/catalog.schema.json`: the package index used to resolve IDs and
  verify per-file digests.
- `schemas/v1/metric.schema.json`: portable result events and timing fields.

## Package actions

An action declares an executor (`apt`, `deb`, `appimage`, `flatpak`, `brew`,
`mise`, `curl`, `script`, or `task`) and its phase. Download URLs, checksums,
commands, environment, platform conditions, and Task targets belong in the
package JSON. The runtime interprets those declarations; it should not grow a
second hard-coded package catalog.

The current package files are intentionally marked `state: "draft"`. They are
the normalized inventory scaffold extracted from the existing Ubuntu SBOM and
must be reviewed and promoted to `verified` as each delivery recipe is tested.
