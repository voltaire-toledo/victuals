## VICTUALS
/ ˈvɪt·əlz / • noun

The foundational provisions, infrastructure, and life-sustaining gear required to make an empty vessel operational.

## Quickstart

Victuals is driven by declarative, remotely retrievable payloads. On a fresh
Ubuntu system, begin with the user-local Go Task bootstrap:

```bash
./install/install-task.sh
```

Then run the hydration entry point from the repository root:

```bash
task hydrate
```

The bootstrap installs and validates Go Task. The hydrator then loads the small
payload manifest, fetches the menu and sequence definitions needed for the
current stage, and fetches each package instruction only when it enters the
deployment queue. It does not download the complete package library before the
first menu.

See [`docs/architecture/payload-model.md`](docs/architecture/payload-model.md)
for the payload contract and [`docs/index.html`](docs/index.html) for the
future static documentation entry point.
