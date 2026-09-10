# Design ideas we are willing to borrow

Each borrowed idea must reduce implementation or maintenance cost. We do not
adopt the source system's language, state model, or execution engine by
default.

## From NixOS and Home Manager

Borrow:

- Modules as logical concerns rather than sequential steps.
- Typed options with defaults and descriptions.
- Profiles as curated compositions of existing choices.
- Separating portable user-environment configuration from host-specific work.
- Version-pinned inputs when reproducibility matters.

Reject or defer:

- A new expression language.
- Implicit option-merging priorities.
- A package store and generation model.
- Requiring Nix on every supported system.
- Treating every host action as a pure derivation.

## From Terraform and Bicep

Borrow cautiously:

- Stable identifiers.
- Explicit target context.
- Clear separation between definitions and execution.
- Strong validation before mutation.

Reject or defer:

- A universal resource graph.
- Provider-style abstraction for every OS action.
- Plan/apply/state as the default lifecycle.
- A declarative language embedded in JSON.

## From ordinary package managers

Borrow:

- Let the native package manager own transitive dependencies.
- Keep source and version information close to the application definition.
- Validate the installed command or service after installation.

Avoid:

- Reimplementing package resolution in the hydrator.
- Recording reverse dependency edges that can drift.

## From dotfiles practice

Borrow:

- Payload files remain ordinary tracked files.
- Linking is explicit and reversible.
- Shared configuration is separated from OS-specific payloads.
- A user can inspect the repository and understand what will be linked.

The hydrator should extend this practice, not hide it behind an opaque
configuration engine.
