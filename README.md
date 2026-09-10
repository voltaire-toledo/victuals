## VICTUALS
/ ˈvɪt·əlz / • noun

The foundational provisions, infrastructure, and life-sustaining gear required to make an empty vessel operational.

## Repository branches

`main` contains the Victuals directory scaffold, Ubuntu workflow, target-neutral
definitions, and documentation. Platform adapters remain under `linux/`.

## Quickstart

The implementation quickstart begins on the feature branch, where the bootstrap
and task definitions are present:

```bash
git switch codex/feature/quartz-docs
./install/install-task.sh
task hydrate
```

See the READMEs in each top-level directory for the intended contents and
ownership of the scaffold.

The bootstrap installs and validates Go Task. The Victuals workflow validates
the small definition manifest, loads catalog metadata before each stage, and
keeps package-manager behavior and privileged actions in the Linux adapters.

Documentation is published with Quartz v5. See
[`docs/architecture/documentation-publishing.md`](docs/architecture/documentation-publishing.md)
for the publishing decision and [`quartz.config.yaml`](quartz.config.yaml) for
the enabled search, graph, backlink, and navigation features.
