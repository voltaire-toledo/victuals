# GNOME Shell Performance and Resource Optimization

## Scope, evidence, and bottom line

This note was researched on 2026-09-02 for the Ubuntu hydration work. It
focuses on GNOME Shell responsiveness, frame pacing, and background resource
use on Ubuntu 25.10 (GNOME 49) and Ubuntu 26.04 (GNOME 50). It deliberately
separates supported, reversible configuration from changes that make the
desktop harder to support.

**Bottom line:** update to Ubuntu 26.04, keep the extension count extremely
small, use GNOME 50's reduced-motion setting when animation is unwanted, use
the display's native resolution/appropriate refresh rate, and diagnose actual
slowdowns with Sysprof before disabling core services. These are the highest
confidence choices. The Ubuntu 26.04 release notes report improved VRR,
fractional-scaling, cursor pacing, and NVIDIA smoothness; Ubuntu 25.10's
release notes explicitly called NVIDIA Wayland performance suboptimal and said
work was underway for 26.04. [Ubuntu 25.10 release notes](https://documentation.ubuntu.com/release-notes/25.10/)
[Ubuntu 26.04 changes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/)

This is not a benchmark claim: no controlled before/after GNOME 50 benchmark
on the target hardware was found. Treat the Ubuntu release-note statements as
vendor release information and validate on the actual device.

## Recommended actions

| Priority | Action | Expected effect | Safety and reversibility | Evidence / implementation |
| --- | --- | --- | --- | --- |
| 1 | Stay fully updated, preferably on Ubuntu 26.04 for this project. | Receives GNOME 50 compositor and display-path improvements, particularly relevant to NVIDIA. | **Safe.** Normal distribution update; reboot when the update requests it. | Ubuntu documents GNOME 50 and the improvements named above. In a related Ubuntu Mutter report, Canonical developer Daniel van Vugt identifies a remaining hybrid-NVIDIA performance gap and advises against the “screen capture keeps clocks high” workaround because of its power cost. [26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/) [Launchpad report](https://bugs.launchpad.net/ubuntu/+source/mutter/+bug/2105500) |
| 2 | Run only the extensions that deliver a deliberate capability. Keep one tiling extension; do not stack tilers, docks, panel replacements, and metrics widgets. | Removes arbitrary JavaScript/CSS work from the Shell main process and sharply reduces upgrade/debug surface. | **Safe and reversible.** Disable one extension at a time with `gnome-extensions disable UUID`; restore it with `enable`. | Extensions can change window management and application launching, and load arbitrary JavaScript/CSS. GNOME maintainers explicitly recommend switching off all extensions as the first isolation test for degrading Shell rendering. [GNOME extension architecture](https://wiki.gnome.org/Projects/GnomeShell/Extensions) [maintainer troubleshooting advice](https://discourse.gnome.org/t/gnome-shell-43-2-render-performance-slowly-but-continously-degrades-how-to-debug/13966) |
| 3 | Use **Reduced Motion** in GNOME 50, or disable interface animations when the goal is the lowest animation overhead rather than visual polish. | Avoids non-essential animation work; makes perceived interaction latency more direct on lower-end GPUs. | **Safe and reversible.** Prefer the Settings UI. The scriptable fallback is `gsettings set org.gnome.desktop.interface enable-animations false`; reset with `gsettings reset org.gnome.desktop.interface enable-animations`. | Ubuntu 26.04 introduces Reduced Motion. GTK exposes a global animation setting and Libadwaita defaults to skipping animations when it is disabled; GNOME Shell exposes corresponding animation settings. [Ubuntu 26.04 notes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/) [GTK setting](https://gnome.pages.gitlab.gnome.org/gtk/gtk4/property.Settings.gtk-enable-animations.html) [Libadwaita behavior](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.2/property.Animation.follow-enable-animations-setting.html) [Shell settings](https://gnome.pages.gitlab.gnome.org/gnome-shell/st/class.Settings.html) |
| 4 | Use the panel's native resolution and select a sensible refresh rate; enable VRR only on a display/GPU path where it is exposed and working. | Correct mode selection avoids scaling blur; VRR can improve smoothness and power consumption. | **Safe and reversible** through Settings ▸ Displays. Do not force experimental Mutter flags. | GNOME says native resolution aligns output pixels to display pixels, and describes VRR as synchronizing refresh to content for smoother visuals and optimized power use. Ubuntu 26.04 also reports improved VRR and fractional scaling. [GNOME Displays help](https://teams.pages.gitlab.gnome.org/Websites/help.gnome.org/gnome-help/look-resolution.html) [Ubuntu 26.04 notes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/) |
| 5 | Remove or delay unneeded login/background applications, then remeasure. Use the GNOME Settings Apps page and Quick Settings Background Apps view to identify candidates. | Reduces post-login CPU, memory, wakeups, and I/O contention that can be mistaken for Shell slowness. | **Safe if done per application and reversible.** Do not disable system services merely because they appear in a process list. | Ubuntu 25.10 provides automatic-start controls in Settings ▸ Apps. GNOME Quick Settings exposes background applications and opens their app settings. [Ubuntu 25.10 notes](https://documentation.ubuntu.com/release-notes/25.10/) [GNOME Quick Settings](https://help.gnome.org/gnome-help/quick-settings.html) |
| 6 | Restrict desktop search to locations and providers actually used; exclude giant source trees, build outputs, VM images, and archives from Search Locations. | Reduces indexing/search scope and avoids expensive or noisy result paths. | **Safe and reversible** in Settings ▸ Search ▸ Search Locations. Trade-off: excluded locations will not be in overview/file search results. | GNOME documents per-location toggles for filesystem search and separate app-search controls. [Search locations](https://help.gnome.org/gnome-help/search-filesystem-locations.html) [app search](https://help.gnome.org/gnome-help/search-all-app.html) |
| 7 | Choose **Balanced** for daily use; select **Performance** temporarily while connected to AC power for a compile, game, or latency-sensitive workload, if hardware exposes it. | Gives the CPU/GPU platform a supported high-performance request without permanently sacrificing battery/thermals. | **Safe and reversible.** Performance may be unavailable or degraded by heat/lap detection. | GNOME defines Balanced as default and Performance as higher performance and power use. The daemon documents hardware-dependent availability and its degraded-state reporting. [GNOME power profiles](https://help.gnome.org/gnome-help/power-profile.html) [power-profiles-daemon](https://power-profiles-daemon-smallorange-d44620b7aabc963c085dca743cf75.pages.freedesktop.org/power-profiles-daemon-Platform-Profile-Drivers.html) |
| 8 | Profile an observed problem before making a permanent change. Capture 10–20 seconds of the slow interaction with Sysprof, with the GNOME Shell instrument / all processes as appropriate. | Identifies whether time is in Shell, an extension, a driver, indexing, or a background process rather than optimizing by folklore. | **Safe.** Whole-system profiling may request authorization and has temporary overhead. | GNOME Shell's debugging guide advocates Sysprof for timing metrics; a Mutter maintainer recommends a short trace and the Shell Timings view. [GNOME Shell debugging](https://wiki.gnome.org/Projects/GnomeShell/Debugging) [Sysprof guide](https://help.gnome.org/sysprof/profiling.html) [maintainer discussion](https://discourse.gnome.org/t/gnome-shell-43-2-render-performance-slowly-but-continously-degrades-how-to-debug/13966) |

## What the hydrator should do

These are reasonable defaults or explicit opt-ins for the hydration script;
they do **not** require a new desktop environment.

1. Keep its existing one-of-four tiling choice and make it an explicit
   extension budget: one tiler plus only extensions the user selected. Before
   installing an extension, record its UUID/version; validate it is compatible
   with the installed Shell; offer a simple disable command in the final
   report.
2. Make **Reduced Motion / disable animations** a user choice. It should not be
   silently imposed: some users value motion/accessibility cues, and animation
   removal changes the experience more than it changes raw throughput.
3. Add an opt-in **search scope** choice, not a global Tracker disable: allow
   the user to exclude high-churn directories through supported Search
   Locations. A developer workstation normally needs its home-source trees
   searched sometimes, so blanket indexing disablement is the wrong default.
4. Do not permanently force the performance power profile. Offer a documented
   on-demand command or leave GNOME's default Balanced mode in place.
5. Provide diagnostics, not speculative “optimizations”: report the GNOME
   version, session type, selected extensions, active power profile, display
   mode, and a Sysprof capture command. This makes a later performance task
   measurable.

## Changes to avoid

| Change | Why it is risky or unsupported | Better response |
| --- | --- | --- |
| `gnome-shell --replace`, killing `gnome-shell`, or scripting an in-place Shell restart on Wayland | Ubuntu 25.10 is Wayland-only; GNOME's debugging guide warns that `--replace` under systemd user sessions leads to a failed restart state and the “Oh no!” dialog. | Log out/in for extension and session changes; profile rather than restart the compositor. [Ubuntu 25.10 notes](https://documentation.ubuntu.com/release-notes/25.10/) [GNOME debugging warning](https://wiki.gnome.org/Projects/GnomeShell/Debugging) |
| Forcing unsupported `org.gnome.mutter experimental-features` flags | These are explicitly experimental, change across releases, and may make display behavior worse. 26.04 already improved VRR/fractional scaling without requiring a forced flag. | Use Settings ▸ Displays and only opt into a feature the installed GNOME exposes. |
| Disabling extension version validation | It defeats the compatibility safety net. A GNOME user who did this reported all extensions stopped working; a maintainer advised resetting the value and re-enabling extensions. | Install a build matching the installed Shell version, and retain version validation. [GNOME Discourse incident](https://discourse.gnome.org/t/extensions-stopped-working/15201) |
| Disabling Tracker/search daemons system-wide, deleting dconf databases, or masking GNOME services | It trades an unmeasured resource concern for broken search, portals, files, or desktop integration; it is difficult to attribute or safely reverse. | Narrow Search Locations/providers first, then profile. |
| Using a second dock/panel/overview replacement alongside a tiling extension | These all execute in the Shell process and multiply integration/upgrade risk. | Use GNOME's existing panel and selected tiler; the project’s plan to remove Ubuntu Dock is compatible with this budget. |
| Treating Snap removal as a GNOME Shell optimization | Replacing/removing Snap changes application packaging and background application behavior, but it does not itself optimize Mutter/GNOME Shell. Ubuntu 26.04 continues to improve Snap portal integration, which is a compatibility consideration rather than evidence that Snap speeds or slows Shell. | Keep the project’s no-Snap policy as a separate product decision; measure background-process impact independently. [Ubuntu 26.04 notes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/) |

## Practitioner evidence: useful but anecdotal

The strongest directly relevant practitioner guidance located was from GNOME
maintainers in a public troubleshooting thread, rather than a personal
“tweak-list” success story: disable all Shell extensions, reboot, and test;
then collect a 10–20 second Sysprof trace to inspect Shell frame timing. That
is expert operational advice, but it is still case-specific rather than a
benchmark. [GNOME Discourse thread](https://discourse.gnome.org/t/gnome-shell-43-2-render-performance-slowly-but-continously-degrades-how-to-debug/13966)

For Ubuntu 25.10/26.04 specifically, Canonical's release-note statements are
the reliable current evidence: 25.10 acknowledged suboptimal NVIDIA Wayland
desktop performance, while 26.04 reports a smoother NVIDIA desktop and related
display-path improvements. They support upgrading and validating the driver /
session path; they do not prove a particular third-party extension or command
will help every machine.

One Canonical developer report adds a concrete hybrid-graphics result: connecting
an external display through a USB-C port routed to the integrated GPU can avoid
the hybrid-NVIDIA path on hardware wired that way. This is **hardware-specific
diagnostic guidance**, not a hydrator default: BIOS primary-GPU changes, udev
rules, or disabling the iGPU can conflict directly with battery-preserving
on-demand graphics. [Ubuntu Mutter bug 2105500](https://bugs.launchpad.net/ubuntu/+source/mutter/+bug/2105500)

## Measurement checklist

Capture these before and after any selected change:

```bash
gnome-shell --version
printf 'session=%s\n' "$XDG_SESSION_TYPE"
gnome-extensions list --enabled
powerprofilesctl get 2>/dev/null || true
gsettings get org.gnome.desktop.interface enable-animations
```

Then reproduce a concrete interaction (overview opening, workspace switch,
window drag, or login) and take a short Sysprof trace. Keep the selected change
only if it improves the reported symptom without removing a needed desktop
capability. This avoids conflating boot-time work, a buggy extension, GPU
driver behavior, and GNOME Shell itself.
