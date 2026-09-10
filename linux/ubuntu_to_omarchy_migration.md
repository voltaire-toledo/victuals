# Ubuntu (GNOME) to Omarchy 4 (Arch / Hyprland) Migration Review

Moving to **Omarchy 4 (Arch Linux with Hyprland/Quickshell)** will give you a highly customized, keyboard-centric, and exceptionally snappy environment. Here is a review of your specific requirements and how to automate the transition using Antigravity (AGY) once you install the new OS.

## 1. Filesystem (High Performance)
To get the **fastest performing filesystem possible** (sacrificing Copy-on-Write and skipping disk encryption):
* **Recommendation:** Go with **EXT4** or **XFS**. 
* **EXT4** is exceptionally stable, incredibly fast for general desktop usage, and has almost zero overhead.
* **XFS** is fantastic for high throughput, especially when dealing with large LLM models for LMStudio/Ollama. 
* *Action:* Simply format your partitions as EXT4 or XFS without LUKS during the Arch installation process.

## 2. Kanata Configurations (Safe)
Your Kanata configurations are safely tracked in your dotfiles repository at `CODE/dotfiles/os/linux/config/kanata`. The `hydrate_omarchy4.sh` script explicitly copies everything from `CODE/dotfiles/os/linux/config/` to your `~/.config/` directory.

## 3. GNOME Extensions (Replaced by Wayland Tools)
You will lose GNOME extensions (moving lockscreen, animated wallpaper, Tailscale status) since Omarchy uses Hyprland. You will replicate these using Wayland ecosystem tools (e.g., `swww` for wallpaper, Waybar/Quickshell modules for Tailscale).

---

## Antigravity (AGY) Automation Prompts

Instead of manually compiling AUR packages and editing configurations, you can use the Antigravity CLI (`agy`) once you boot into Omarchy to handle the heavy lifting. **Copy and paste these prompts into your AGY session.**

### A. Battery Life: System76 Power & EnvyControl
Your awesome battery life on Ubuntu came from your `.zshrc` `gpu-mode` script (which used the Ubuntu-specific `prime-select`) and the System76 power profile. Both of these need to be swapped to their Arch Linux equivalents (`envycontrol` and `system76-power` from the AUR).

**Paste this prompt into AGY:**
```text
I need to optimize my laptop's power management and GPU offloading for Arch Linux. 
1. Install `envycontrol` and `system76-power` from the AUR using `yay`.
2. Enable and start the `system76-power` systemd service.
3. Update my `~/.zshrc` file: find the `gpu-mode` function (which currently uses `prime-select`) and rewrite it to use `envycontrol`. Map the choices appropriately (e.g., integrated, hybrid, nvidia).
4. Verify your work: ensure the packages are installed, the service is running, and the `.zshrc` function correctly executes `envycontrol` commands.
```

### B. Three-Finger Drag Gesture
Standard `libinput` on Wayland does not support the macOS-style three-finger drag you rely on. You must replace the system's `libinput` with a patched version.

**Paste this prompt into AGY:**
```text
I need macOS-style three-finger drag to work on my Hyprland setup. 
1. Install the `libinput-three-finger-drag` package from the AUR using `yay`. (This will conflict with and replace the standard `libinput` package, which is expected).
2. Ensure that the Hyprland configuration (`~/.config/hypr/hyprland.conf` or similar) is configured to utilize natural scrolling and gestures if necessary.
3. Verify your work: confirm the patched libinput package is successfully installed and replacing the standard libinput.
```

### C. Replicating GNOME Extensions
To get back your animated wallpapers and Tailscale menu bar status in Hyprland.

**Paste this prompt into AGY:**
```text
I just migrated from GNOME and miss my extensions. I need you to set up the following for my Hyprland environment:
1. Install `swww` (for animated wallpapers) and set it to initialize on Hyprland startup.
2. Review my Wayland status bar configuration (Waybar or Quickshell in ~/.config) and add a module/applet that displays my Tailscale status. You may need to install the `tailscale` package if it isn't already installed, and ensure the service is running.
3. Verify your work: check that the `swww` daemon is added to the hyprland config exec-once, and that the status bar config has valid syntax after your modifications.
```
