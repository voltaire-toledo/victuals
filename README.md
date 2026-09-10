## VICTUALS
/ ˈvɪt·əlz / • noun

The foundational provisions, infrastructure, and life-sustaining gear required to make an empty vessel operational.

## Repository branches

`main` is the durable directory and documentation scaffold. The populated
hydrator, payload library, and Quartz work currently live on
`codex/feature/quartz-docs` until that feature is reviewed and merged.

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

The bootstrap installs and validates Go Task. The hydrator then loads the small
payload manifest, fetches the menu and sequence definitions needed for the
current stage, and fetches each package instruction only when it enters the
deployment queue. It does not download the complete package library before the
first menu.

Documentation is published with Quartz v5. See
[`docs/architecture/documentation-publishing.md`](docs/architecture/documentation-publishing.md)
for the publishing decision and [`quartz.config.yaml`](quartz.config.yaml) for
the enabled search, graph, backlink, and navigation features.
