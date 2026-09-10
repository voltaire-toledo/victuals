# Hydrator design

This directory records the design for the cross-platform system hydrator and
its definition data. It is separate from the installer implementation. These
files are design records, not an API contract or a task tracker.

## Current direction

The project began as dotfiles. It now also provisions machines whose software
and execution environments may span local operating systems, cloud services,
AI tools, and virtualized guests.

The current boundary is:

```text
Static definitions → TUI selections → existing OS-specific hydrator code
```

JSON describes applications, suites, policies, targets, and images. The
hydrator owns ordering, package-manager behavior, secrets, privileged actions,
configuration, and validation.

## Documents

- [Core directive and guardrails](core-directive.md)
- [Schema options under consideration](schema-options.md)
- [Design ideas borrowed from other systems](borrowed-designs.md)
- [Hydrator inception](inception.md)

## Naming options under consideration

The schema will continue to use the current technical names. Two user-facing
vocabularies are being considered as an explanatory layer: military supply
logistics and restaurant kitchen operations. Neither vocabulary changes the
underlying object model.

| Current object | Military supply vocabulary | Restaurant vocabulary |
| --- | --- | --- |
| Hydrator | Quartermaster or provisioner | Kitchen manager or expediter |
| Catalog | Supply depot | Menu and inventory |
| Application | Supply item or ration | Ingredient, dish, or orderable item |
| Suite | Loadout | Meal combination or tasting flight |
| Preset | Mission profile | Set menu or prix fixe menu |
| Policy | Standing order | House procedure |
| Plan | Operations plan | Prep and service sequence |
| Target | Deployment target | Customer order or table |
| Report | After-action report | Post-service report |

These are analogies, not replacements for the technical terms. The military
vocabulary emphasizes logistics and distribution. The restaurant vocabulary
emphasizes selection, preparation, sequencing, and service.

## Preset, policy, and plan

These concepts must remain distinct. They are not interchangeable names for a
collection of settings or actions.

### Preset

A preset is a fixed, named configuration choice. It is selected as a whole and
does not support exceptions, substitutions, or conditional deviation.

It is similar to a shirt size or a restaurant set menu: the user chooses the
defined option, and the hydrator applies its contents as defined. If the user
needs a different result, they choose another preset or a separately defined
variant.

Examples:

- `ubuntu-new-laptop-standard`
- `ubuntu-new-laptop-minimal`
- a fixed accessibility loadout

A preset may reference applications, suites, policies, and plans, but it does
not become a general-purpose override mechanism.

### Policy

A policy is a monitored guideline or rule. It describes what may, must, or must
not be true and provides a basis for auditing, blocking, warning, or enforcing
behavior.

Policies are closer to linters and validators than to action sequences. A
policy can be evaluated before, during, or after hydration.

Examples:

- Snap packages must not be installed.
- A power profile must exist and be enabled on supported hardware.
- A service must be enabled only when its application is selected.
- Secrets must not appear in catalog definitions.

A policy may cause an action, prevent an action, or report a violation, but the
policy itself is not the action sequence.

### Plan

A plan is a predetermined orchestration of actions. It can define sequence,
precedence, conditions, prerequisites, and alternative paths.

Plans answer “what happens, and in what order?” Policies answer “what is
allowed, required, or valid?” Presets answer “which fixed package of choices
does the user want?”

Examples:

- Install package-manager prerequisites, then refresh repositories, then
  install selected applications.
- If NVIDIA hardware is detected, install the supported driver path; otherwise
  skip that path.
- Configure the host before creating a VM, then pass guest initialization to
  cloud-init.

Plans belong to hydrator behavior and orchestration. Catalog data may select a
named plan or provide its inputs, but JSON definitions must not become a
general-purpose programming language.

| Concept | Core question | May contain exceptions or branches? |
| --- | --- | --- |
| Preset | “Which fixed configuration do I want?” | No |
| Policy | “What must, may, or must not be true?” | It may define enforcement outcomes |
| Plan | “What actions happen, and in what order?” | Yes |

## Current modeling decisions

- Every object requires `description`.
- Every object may have an optional `comment`.
- Applications are defined once and referenced by stable `id` values.
- `dependsOn` is the only stored dependency direction.
- `requiredBy` is derived and is not persisted.
- `recommendation` replaces `requiredness`.
- `batch` describes installation timing, not recommendation.
- Host policies such as power management and Snap handling are not apps.
- Nix may become an optional execution backend for portable packages and
  dotfiles; it is not a prerequisite for the hydrator.
