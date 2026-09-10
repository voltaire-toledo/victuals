# Core directive and guardrails

## Core directive

Provide a quick, simple, easy-to-manage way to provision a supported system.
Keep platform-specific behavior explicit instead of hiding it behind a common
abstraction.

## What we want

- A continuation of a dotfiles repository.
- A single guided entry point for a new laptop or server.
- A rich TUI for choosing applications, suites, host policies, dotfiles, and
  optional virtualization features.
- A small, versioned JSON catalog fetched from GitHub when needed.
- One application definition referenced by many suites.
- Required descriptions and optional maintenance comments on catalog objects.
- `dependsOn` relationships with derived reverse lookup; no duplicated inverse
  edges.
- Explicit installation batches, recommendations, versions, and first-run
  setup requirements.
- Support for Ubuntu laptop hydration, bare-metal QEMU setup, and both
  existing-container and new-container Proxmox workflows.
- Cloud-init or equivalent guest setup where a VM needs initial users,
  credentials, or packages.
- OS-specific adapters that report what they installed, skipped, or could not
  validate.
- Portable dotfile payloads that remain ordinary inspectable files and links.
- Optional Nix/Home Manager integration when it reduces work for packages or
  user configuration.
- Native package managers handling their own transitive dependencies.

## What we do not want

- A universal package manager or replacement for native administration.
- A Terraform, Bicep, or NixOS clone.
- An API server, registry service, or database-backed module system.
- A declarative infrastructure language embedded in JSON.
- A state file, reconciliation engine, or generation/rollback system without a
  demonstrated requirement.
- A universal resource graph for packages, services, files, VMs, containers,
  and hardware.
- One file per installation action or a directory that encodes execution order.
- Shell commands, conditionals, expressions, interpolation, or secrets in
  catalog JSON.
- Persisted `requiredBy` relationships.
- Reimplementation of package-manager dependency resolution.
- Hidden platform differences behind a lowest-common-denominator interface.
- Nix as a mandatory prerequisite on every supported operating system.
- A design that makes a one-application change require a framework-wide edit.

## Guardrails against accidental Terraform/Bicep/NixOS growth

- JSON is input data, not executable logic.
- A definition file is not an installation step.
- Lifecycle behavior stays in tested OS-specific code.
- Do not add a state file until a concrete workflow requires state.
- Do not persist inverse relationships such as `requiredBy`.
- Do not duplicate transitive package dependencies already handled by a
  package manager.
- Do not introduce nested modules, expressions, interpolation, or conditionals
  into the definition format.
- Prefer a named workflow in code over a generic abstraction when only one
  adapter exists.
- Keep definitions grouped by catalog kind; do not create a file for each
  installation action.

## The three-layer boundary

```text
Definitions
  What exists and what the user may choose

Hydrator
  How a target is installed, configured, and validated

Report
  What happened, what was skipped, and what needs user attention
```

The report is evidence of a run, not a state database that drives future
reconciliation.
