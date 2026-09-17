# Task-backed prompt catalog and selection manifest

## Status

Accepted design direction for the Victuals CLI/TUI. This supersedes the use of
a separate checked-in JSON catalog for interactive Task-backed provisioning.

## Decision

The Taskfile is the single authoritative source for prompt metadata. The
Victuals CLI invokes a read-only Task target to obtain Task's fully resolved
catalog; it does not independently parse Taskfile YAML, require `yq`, or keep a
parallel catalog file.

The CLI owns a separate, versioned YAML **selection manifest** for importing
and exporting a user's answers. The manifest is user state, not catalog data.

```text
Taskfile map → read-only Task exporter → Victuals CLI/TUI → selection manifest
                                      ↘ validated answers → Task executor
```

This is a deep module seam: callers learn one exporter target and one manifest
format, while Task retains include, variable, and template resolution and the
CLI retains rendering, navigation, validation, and persistence.

## Catalog location and shape

Taskfiles must not add arbitrary root keys: Task's schema rejects them. Store
the catalog in a reserved literal map variable in the relevant included
Taskfile, for example `tasks/LinuxDev.yml`:

```yaml
version: '3'

vars:
  VICTUALS_PROMPT_CATALOG:
    map:
      schema: victuals.catalog/v1
      id: linuxdev
      revision: 1
      prompts:
        - id: battery-policy
          title: Battery policy
          description: Choose the normal battery and performance behavior.
          kind: single
          plan_field: BATTERY_POLICY
          controls: [skip, main-menu]
          default: balanced
          options:
            - id: balanced
              label: Balanced
              description: Balance battery life and workstation responsiveness.
              value: balanced
            - id: performance
              label: Performance
              description: Prefer performance when connected to external power.
              value: performance
```

The source order of `prompts` is the presentation order. Every prompt requires
an immutable `id`, title, description, `kind`, and `plan_field`. Every option
requires an immutable `id`, label, description, and persisted `value`.

The catalog also defines:

- selection constraints (`min`, `max`, or an equivalent single/multi kind);
- an optional default expressed as an option ID or IDs;
- applicability conditions based only on previously discovered facts;
- the executor mapping or an explicit `plan_only: true` designation;
- allowed non-persisted controls and the prompt-specific meaning of Skip.

Reserved control IDs are `skip`, `back`, `main-menu`, and `cancel`. They are UI
events, never options and never plan values. `back` is omitted from the first
reachable prompt. The UI may bind these events to single keys, but keyboard
bindings are renderer policy, not catalog values.

## Read-only exporter interface

Task's `--list --json` reports task metadata; it does not export arbitrary map
variables. Each Task-backed catalog therefore exposes one silent exporter:

```yaml
tasks:
  prompt-catalog:
    desc: Export the resolved Victuals prompt catalog
    silent: true
    env:
      VICTUALS_CATALOG_JSON: '{{.VICTUALS_PROMPT_CATALOG | toJson}}'
    cmds:
      - 'printf "%s\\n" "$VICTUALS_CATALOG_JSON"'
```

When `tasks/LinuxDev.yml` is included as `linuxdev`, the CLI invokes:

```text
task linuxdev:prompt-catalog
```

The exporter writes exactly one JSON object to standard output, diagnostics to
standard error, and exits non-zero on failure. JSON is a transport encoding of
the Taskfile map—not a checked-in schema or alternate catalog. A YAML transport
is permissible later, but changing the transport requires a new exporter
interface version.

## Selection manifest and CLI arguments

The external `victuals` executable provides these user-facing workflows:

```text
victuals plan --export selections.yml
victuals apply --import selections.yml
```

`plan` may be interactive; `--export` writes its normalized answers. `apply
--import` is non-interactive after validation. The exact command names may
evolve, but `--import <file>` and `--export <file>` remain the stable behavior.

The file is YAML so users can inspect, version, edit, and review it:

```yaml
schema: victuals.selections/v1
catalog:
  id: linuxdev
  revision: 1
answers:
  battery-policy: balanced
  browsers:
    - firefox
    - chromium
```

The manifest contains only catalog identity and stable answer IDs. It must not
repeat labels, descriptions, choices, commands, control events, or renderer
state. Values are normalized in catalog prompt order when exported.

Before executing, import must validate:

1. the manifest schema, catalog ID, and catalog revision;
2. every prompt and option ID against the resolved catalog;
3. single/multi selection cardinality, defaults, and required prompts;
4. applicability conditions and dependency rules;
5. that each persisted answer has an executor mapping or is explicitly
   plan-only.

Validation failure reports each offending manifest path and performs no host
mutation. After success, the CLI passes the validated manifest path to the
existing Task application target (for example through `HYDRATE_SELECTIONS_FILE`).

## Non-goals

- Task does not gain native `--import` or `--export` flags; those belong to the
  Victuals CLI.
- The CLI does not independently parse Taskfile YAML or require `yq` on the
  target.
- The manifest is not a second catalog and cannot introduce new option IDs.
- This specification does not choose the renderer. A future UI may use fzf,
  tview, Bubble Tea, or Huh if it preserves the control-event contract.

## Migration rule

Existing JSON definition files are reference and migration material only for
this Task-backed interactive path. Prompt metadata is migrated into the
Taskfile map before a corresponding JSON record is removed or ignored. There
must be exactly one authoritative prompt catalog at any time.
