# Payload layout

`manifest.json` is intentionally small. It is the only catalog document the
bootstrap needs initially. It points to menu and sequence definitions and to
individual package instruction documents.

The UI fetches a menu or sequence when that stage begins. When a selection adds
an item to the deployment queue, the item’s package JSON is fetched and
validated then. Package instructions may chain other package IDs through
`dependencies`; those dependencies are fetched as they enter the queue.

Nothing in the bootstrap downloads the complete `packages/` directory merely to
render the first menu.
