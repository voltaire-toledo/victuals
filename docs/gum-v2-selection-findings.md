# Gum selection findings

Verified 2026-09-08 against the repository's installed binary and Charmbracelet's
upstream documentation/source.

## Installed version

The workstation currently resolves `/usr/bin/gum` to `gum version v2.0.0
(4d089f9)`. APT reports the same version as installed and as the candidate from
`https://repo.charm.sh/apt`.

The public upstream GitHub release page currently documents the v0.17.0
release series, so the local v2.0.0 package should be treated as the runtime
authority for this repository. Its command help was checked directly with
`gum choose --help`.

Sources: [Gum releases](https://github.com/charmbracelet/gum/releases),
[Gum repository](https://github.com/charmbracelet/gum).

## Relevant `gum choose` capabilities

The installed command supports `--header`, `--show-help`/`--no-show-help`,
`--limit`/`--no-limit`, selected and unselected prefixes, ANSI stripping,
padding, and independent foreground/background styles for the cursor, header,
items, and selected items.

It does not expose a flag or environment variable for replacing the built-in
help text, adding custom key bindings, or changing the action associated with a
key such as Backspace or Ctrl+R. Upstream's own discussion of custom choose
shortcuts remains an unresolved feature request.

Source: the installed `gum choose --help`; upstream [custom shortcut
discussion](https://github.com/charmbracelet/gum/discussions/847).

## Behavior relevant to Hydrator

`gum choose --no-limit` returns selected rows, not the row currently under the
cursor. Therefore an unselected `← Back` row cannot be activated with Enter
alone. It must first be toggled, currently with `x`, and then submitted with
Enter. Esc exits with status 1 and Ctrl+C interrupts with status 130; the
Hydrator wrapper can use those statuses for back and cancel behavior.

The current Hydrator should therefore keep the explicit `← Back` row plus the
Esc back path, and must not claim that Enter alone activates an unselected
multi-select Back row unless the selector is replaced with a custom Bubble Tea
component or a future Gum release adds action/key binding support.

## Practical styling conclusion

The built-in help line can be styled only through Gum's available widget style
flags. Its text cannot be extended in place. A custom footer can be rendered
only by hiding the native help line and drawing a separate component; placing
text below a live `gum choose` process is not supported by the shell API.
