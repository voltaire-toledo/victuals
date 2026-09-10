# Victuals definitions

This directory is the target-neutral catalog layer for the Ubuntu Victuals
workflow.
The JSON files describe selectable objects and their relationships; they do not
contain shell commands, privilege escalation, package-manager syntax, release
URLs, or host-specific validation. Those details remain in the platform
adapters under `linux/scripts/` and the tracked Linux configuration.

The bootstrap reads `manifest.json` first, then loads only the catalogs needed
for the current menu. `applications.json` supplies names, descriptions, groups,
and dependencies for selectable applications and tools. `policies.json` does
the same for system policies. `presets.json` composes stable IDs into reusable
profiles without embedding executable instructions.

Every catalog record has a stable ID, a single primary `kind`, and a descriptive
name. Package subtypes (`packageType`) and operation subtypes
(`operationType`) are deliberately separate from `kind`.
