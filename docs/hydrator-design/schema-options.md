# Schema options under consideration

This is a design comparison. No schema in this directory is final.

## Shared object rules

All objects require a stable `id`, `name` where user-facing, and `description`.
All objects may have `comment`. Schema documents use `$schema`; definition
bundles use `schemaVersion` and a published `bundleVersion` when a coherent
set must be pinned.

Applications currently need these concepts:

```json
{
  "id": "voxtype",
  "name": "Voxtype",
  "description": "Local dictation application.",
  "comment": "Optional maintenance note.",
  "category": ["Accessibility"],
  "recommendation": "recommended",
  "batch": "Optional",
  "version": "latest",
  "installMethod": "github-release-deb-via-apt",
  "firstRunSetup": true,
  "dependencySource": "package",
  "dependsOn": []
}
```

`requiredBy` is intentionally absent. It can be derived from `dependsOn` when
the hydrator needs reverse lookup.

## Option A: one monolithic schema

```text
linux-sbom.json
├── applications[]
├── suites[]
├── hostPolicies[]
├── targets[]
├── vmImages[]
└── workflows[]
```

Advantages:

- One file to fetch and validate.
- Easy to understand initially.

Risks:

- Quickly becomes a universal schema for unrelated concerns.
- Couples portable catalog data to target-specific provisioning.
- Encourages generic resource and dependency abstractions.

## Option B: normalized catalog plus presets

```text
catalog
├── applications[]
├── suites[]
├── hostPolicies[]
└── vmImages[]

presets
├── ubuntu-new-laptop
├── ubuntu-qemu-host
├── proxmox-existing-lxc
└── proxmox-new-lxc
```

Presets contain IDs and fixed user-facing choices. They do not contain shell
commands, ordering, expressions, state transitions, exceptions, or ad hoc
overrides. A materially different choice should be another named preset.

Presets, policies, and plans have different responsibilities:

- A preset is a fixed selection with no deviations.
- A policy is an auditable rule that can warn, block, or enforce.
- A plan is the orchestration of actions, including order, conditions, and
  alternative paths.

Policies and plans may be selected by a preset, but they are not synonyms for
the preset itself.

This is the current preferred direction. It keeps reusable data separate from
hydrator behavior without adding a module language.

## Option C: lifecycle directories

```text
definitions/
├── manifest.json
├── catalog.json
├── presets.json
└── schemas/
```

If the catalog becomes too large, it can split into a few logical files:

```text
definitions/
├── manifest.json
├── applications.json
├── suites.json
├── policies.json
└── images.json
```

This is preferred over one file per installation action. Directory structure
should organize data; it must not imply an execution sequence.

## Lifecycle and target separation

The same catalog entry may be available through different target adapters:

```text
application definition
        ↓
target adapter
  ├── Ubuntu/APT/systemd
  ├── Nix/Home Manager
  ├── macOS/nix-darwin
  ├── Windows/WinGet
  └── Proxmox/LXC
```

The catalog describes the application. The adapter owns installation,
configuration, privilege, service management, and validation.
