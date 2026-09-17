# Victuals documentation

This directory is the source for the Victuals documentation site. Pages remain
Markdown so they can be published with Quartz without changing the source
format. The `architecture/` and `hydrator-design/` directories hold design and
implementation notes.

The Task-backed provisioning catalog and its import/export selection-manifest
contract are recorded in
[architecture/taskfile-prompt-catalog.md](architecture/taskfile-prompt-catalog.md).

Quartz publishing configuration and the full documentation set live on the
`codex/feature/quartz-docs` branch while the `main` branch carries this
framework-neutral scaffold.
