# Hydrator inception

This record preserves the user's language from the design discussion that
shaped the hydrator. The quotes are intentionally candid. They capture the
questions, objections, and course corrections that produced the current
design boundaries.

## Starting point

The project began with dotfiles and a practical need to move a working
environment between machines. The hydrator grew from that need rather than
from an ambition to create a general infrastructure system.

> “Don’t forget that this project started with dotfiles.”

The broader problem became clear as the target environments multiplied:

> “We are inventing this as at a time when AI, cloud, and multiplatform
> environments are wonderfully chaotic and ubiquitous.”

## The first pressure toward a schema

The initial application questionnaire established the smallest useful data
set: category, installation recommendation, batch, dependencies, version,
installation method, and first-run setup.

The design then added reusable groups without duplicating application records:

> “What if we want to define a group of apps for a suite? But to keep things
> dry the app only needs to be defined once”

That led to the catalog-and-references model: define applications once, then
let suites reference their IDs.

## The dependency correction

The design originally included both dependency directions. The user identified
the danger immediately:

> “But i strongly agree about requiredBy. Let’s remove that element going
> forward.”

The durable decision is to store `dependsOn` only. `requiredBy` is derived when
needed, preventing two copies of the same relationship from drifting apart.

## Recognizing accidental infrastructure language

As the design added modules, manifests, plans, targets, and execution layers,
the user called out the resemblance to existing infrastructure systems:

> “Holy crap. It feels like we’re reinventing terraform. But i strongly agree
> about requiredBy. Let’s remove that element going forward. But let’s continue
> designing … i don’t want to recreate the overheated design flaws of terraform
> and similar models”

The next comparison made the problem unmistakable:

> “This is terraform minus the state file. We’re building bicep!”

Those objections are design constraints, not merely tone. The hydrator must
not become a new declarative infrastructure language.

## Returning to the actual boundary

The design was pulled back to three responsibilities:

```text
Definitions → TUI selections → OS-specific hydrator code
```

The user summarized the problem with useful precision:

> “it's already fugly with just that one tiny app. it only gets more complicated
> from there.”

The resulting rule is that JSON describes choices and metadata. Existing
hydrator code performs ordering, package-manager operations, privileged
changes, secrets handling, configuration, and validation.

## Nix as a comparison, not a replacement

Nix and Home Manager supplied useful ideas for portable packages and dotfiles,
but adopting them wholesale would move the project away from its original
purpose. The practical conclusion was:

> “ok. you're right. we still need the hydrator”

Nix may become an optional backend for portable user environments. It does not
replace the hydrator's host-specific work: power policy, Snap handling,
hardware, privileged services, QEMU/libvirt, Proxmox, and interactive setup.

## Core directive

The discussion converged on this goal:

> “quick, simple, easy-to-manage way to provision systems.”

That sentence is the product's primary test. A proposed abstraction is suspect
if it makes a fresh setup slower to understand, harder to inspect, or harder to
change than the direct OS-specific implementation it replaces.

