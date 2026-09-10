# Dell Precision 5550 Ubuntu 26.04 GPU, Power, and Recovery Research

## Scope and bottom line

Researched 2026-09-04 using first-party documentation from Dell, NVIDIA,
Canonical/Ubuntu, GNOME, System76, and the Timeshift project. No scripts,
drivers, initramfs files, tasks, or host state were changed.

The safest target architecture is:

1. Keep Ubuntu Desktop/GNOME on the Intel iGPU for display ownership.
2. Keep the Quadro T2000 available as a per-application CUDA/AI device.
3. Use NVIDIA PRIME render offload or an equivalent hybrid mode; do not use
   `prime-select intel` as the normal AI-workstation mode.
4. Install and select the NVIDIA package supplied by Ubuntu’s repositories,
   rather than installing NVIDIA’s `.run` installer. Driver 595 already lists
   the T2000; current NVIDIA 610.57.04 also lists it. Moving to 610 is not, by
   itself, proof of lower idle power or a fix for GNOME choosing the dGPU.
5. Treat `system76-power` as an experiment requiring package-conflict and
   hardware validation, not as a drop-in Ubuntu 26.04 replacement. It directly
   conflicts with `power-profiles-daemon` and `nvidia-prime` in its Debian
   metadata.
6. A Timeshift snapshot is useful only if stored on a separate device or
   partition. If the machine cannot reach GRUB/recovery and there is no other
   bootable recovery environment, Timeshift cannot be started from the erased
   or unbootable installation.

## Hardware and display topology

Dell documents the Precision 5550 configuration with an NVIDIA Quadro T2000,
4 GB GDDR6, and Intel UHD Graphics 630 using shared system memory. Dell lists
Type-C as the integrated-graphics external-display connection and does not list
external-display support for the discrete T2000 in that table. The exact port
path still needs to be verified on the individual unit and dock.
[Dell Precision 5550 video specifications](https://www.dell.com/support/manuals/en-us/precision-15-5550-laptop/precision_5550_setupspecs/video?guid=guid-cbd94b5c-58ed-4c48-b870-4b6fe4d98ca8)

Ubuntu 26.04 documents that Ubuntu Desktop now runs only on Wayland because
GNOME Shell can no longer run as an X.org session. X11 applications remain
usable through XWayland, but the normal Ubuntu GNOME session cannot be switched
back to an Ubuntu-on-Xorg session through the login screen. Other desktop
environments may still provide X11 sessions.
[Ubuntu 26.04 summary: Wayland session](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/)

This means the requirement should be expressed as “Mutter/GNOME Shell is
display compositor on Intel, while selected clients render on NVIDIA,” not as
an X11 `prime-select` configuration.

## NVIDIA 595, 610, Turing, and nouveau

The NVIDIA 595.45.04 supported-products list includes `Quadro T2000` PCI ID
`1FB8`, including Dell-related Max-Q subsystem variants. The NVIDIA 610.57.04
supported-products list contains the same T2000 entries. Therefore, both
branches support this GPU at the product-list level.
[NVIDIA 595.45.04 supported products](https://download.nvidia.com/XFree86/Linux-x86_64/595.45.04/README/supportedchips.html)
[NVIDIA 610.57.04 supported products](https://download.nvidia.com/XFree86/Linux-x86_64/610.57.04/README/supportedchips.html)

NVIDIA’s open kernel-module project says its open modules can be used on any
Turing-or-later GPU, and the T2000 is Turing. That supports considering the
Ubuntu `nvidia-open` package where Ubuntu marks it appropriate, but it does
not establish that every feature, kernel, suspend path, or laptop firmware
combination is equally reliable.
[NVIDIA open GPU kernel modules: compatible GPUs](https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus)

Ubuntu’s NVIDIA documentation explicitly says that a loaded `nouveau` module
can conflict with the proprietary NVIDIA driver and cause `nvidia-smi` to find
no devices. Ubuntu’s documented remedy is to blocklist `nouveau`, rebuild the
initramfs, and reboot. This verifies the incompatibility claim for the
proprietary-driver path; it does not mean that blindly editing modprobe files
is safe on this machine.
[Ubuntu NVIDIA driver installation and nouveau troubleshooting](https://ubuntu.com/server/docs/nvidia-drivers-installation/)

The NVIDIA driver README also warns that hybrid/Optimus notebook designs vary
by manufacturer and may not work if the integrated GPU cannot be disabled in
hardware. That warning is directly relevant to the 5550: test the internal
panel, suspend/resume, and each required external-display path before adopting
any graphics-mode change.
[NVIDIA 610.57.04 product-list design warning](https://download.nvidia.com/XFree86/Linux-x86_64/610.57.04/README/supportedchips.html)

### What driver 610 does and does not prove

The evidence supports: “610 supports the T2000.” It does not support:

- “610 is required to disable nouveau.” The proprietary-driver installation
  path, not the particular 595-versus-610 number, requires that conflicting
  kernel module not be loaded.
- “610 will reduce idle power.” Idle draw depends on DRM ownership, runtime
  power management, display routing, clocks, persistence, and client activity.
- “610 will make GNOME use Intel.” GNOME compositor ownership is a graphics
  configuration/session issue, not simply a CUDA-driver-version issue.

Ubuntu’s own driver policy recommends using Ubuntu-packaged NVIDIA drivers and
notes that user-space/kernel-module version mismatches require an immediate
reboot after driver updates. This is another reason not to mix `.run` files,
Ubuntu packages, and partial package branches during the first retry.
[Canonical NVIDIA driver update policy](https://documentation.ubuntu.com/project/SRU/reference/exception-NVidia-Updates/)

## PRIME offload and Intel GNOME ownership

NVIDIA defines PRIME render offload as a sink/source arrangement: one GPU
drives the screen while selected applications render on the other GPU. NVIDIA’s
documented offload variables are:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia application
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only application
```

The extra GLX variable is needed for GLX applications; Vulkan applications
need the offload variable and may use the NVIDIA-only layer when device
selection must be unambiguous.
[NVIDIA PRIME Render Offload](https://download.nvidia.com/XFree86/Linux-x86_64/455.45.01/README/primerenderoffload.html)

System76’s first-party documentation describes its **Hybrid** mode in the same
terms: the iGPU is the primary renderer and selected applications can use the
dGPU. It also says Turing and newer cards fully implement the relevant runtime
power-management functionality. Its **Compute** mode is even closer to the
stated goal: the iGPU is used for rendering and the dGPU is made available as a
compute node. However, system76-power’s graphics switching implementation
changes modprobe configuration and runs `update-initramfs` (or `dracut`), and
requires a reboot. That is exactly the high-risk operation that caused the
previous failure, so it must not be hidden inside a generic hydrator.
[System76 power graphics modes](https://github.com/pop-os/system76-power#switchable-graphics)
[System76 graphics implementation](https://github.com/pop-os/system76-power/blob/master/src/graphics.rs)

Recommended validation after a clean, known-good setup is observational:

```bash
echo "$XDG_SESSION_TYPE"
gnome-shell --version
glxinfo -B                         # display/compositor-side result
nvidia-smi                         # driver and active-client result
ps -ef | grep '[g]nome-shell'
```

Then launch one deliberately offloaded test process and verify its PID appears
in `nvidia-smi`, while GNOME remains the display session. Do not infer
ownership from `nvidia-smi` showing a small idle wattage alone.

## System76 power versus Ubuntu 26.04

The relevant System76 component is `system76-power`, not TLP. Its official
README documents Balanced, Performance, Battery, Integrated, NVIDIA, Hybrid,
and Compute modes. Its Debian control file declares conflicts with
`nvidia-prime` and `power-profiles-daemon`, while providing those package
names. That means installing it is a replacement of Ubuntu’s power/graphics
control stack, not an additive optimization.
[System76 power README](https://github.com/pop-os/system76-power)
[System76 Debian package metadata](https://github.com/pop-os/system76-power/blob/master/debian/control)

I found no first-party System76 statement claiming support for Ubuntu 26.04
specifically, nor a System76 compatibility matrix for non-System76 Dell
hardware. The project’s own issue tracker contains reports of graphics
switching not being supported on non-System76 laptops, including a 2025 HP
case, and its source contains vendor/model-specific logic. That is not proof
that the Dell will fail, but it is enough to require a reversible lab test and
to reject unconditional installation in the retry script.
[System76 non-System76 graphics report](https://github.com/pop-os/pop/issues/3686)

Ubuntu 26.04 already exposes GNOME power profiles and reports improved GNOME
50/NVIDIA smoothness. The first experiment should therefore preserve
`power-profiles-daemon`, measure idle power and temperature, and compare only
one controlled change at a time. Do not run TLP, `system76-power`, and
`power-profiles-daemon` together; the services are designed to conflict.
[Ubuntu 26.04 GNOME/NVIDIA changes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/)

## Timeshift CLI and recovery limits

Timeshift’s official documentation says RSYNC mode works on all systems,
protects system files/settings, excludes user data by default, and is best
stored on an external non-system partition. It also says an unbootable system
is restored by booting an Ubuntu Live CD/USB and running Timeshift against the
installed system. A same-disk snapshot is not protection against disk
erasure.
[Timeshift README: modes, scope, restore, and EFI](https://github.com/linuxmint/timeshift#timeshift)

For the installed system, first inspect devices and snapshots:

```bash
sudo timeshift --list-devices
sudo timeshift --list
```

After selecting a separate target device in Timeshift, the project’s CLI
syntax supports an explicit RSYNC snapshot:

```bash
sudo timeshift --create --rsync \
  --snapshot-device /dev/disk/by-uuid/<SNAPSHOT_DEVICE_UUID> \
  --comments "Known-good before GPU and power changes" \
  --tags O
sudo timeshift --list
```

Replace the UUID only after verifying it with `lsblk --fs`; do not guess a
device path. The project’s documented CLI also supports restoring a named
snapshot with an explicit target and optional GRUB device:

```bash
sudo timeshift --restore \
  --snapshot 'YYYY-MM-DD_HH-MM-SS' \
  --target-device /dev/disk/by-uuid/<ROOT_DEVICE_UUID> \
  --grub-device /dev/<BOOT_DISK>
```

Run `sudo timeshift --help` on the installed version before using restore, and
review every device in its confirmation screen. Restoring is a system-wide
operation, not a single-file undo; preserve user data separately. The exact
CLI option forms are recorded in the project’s official repository discussion
of its CLI help.
[Timeshift CLI help and examples](https://github.com/linuxmint/timeshift/issues/84)

If GRUB and a kernel still start, Ubuntu recovery mode is the only practical
media-free route to a root shell. From there, the root filesystem is initially
read-only and can be remounted read/write; an external snapshot device can be
mounted if the necessary hardware and drivers are available. This can allow
Timeshift CLI restoration without a USB live system.

If the system cannot reach GRUB, cannot load a kernel, or the root filesystem
cannot be mounted, there is no Windows-style magic safe mode and no way for an
installed Timeshift binary to run. Timeshift’s own documented recovery path is
external Live media. With the stated no-USB constraint, the remaining options
are a bootable second disk/network recovery environment, a working alternate
GRUB/kernel path, or temporarily obtaining compatible recovery media.
[Timeshift unbootable-system guidance](https://github.com/linuxmint/timeshift#system-restore)

## Ubuntu recovery / “safe mode”

Ubuntu’s recovery mode is the closest analogue to Windows Safe Mode. Reboot,
open GRUB, choose **Advanced options for Ubuntu**, select the matching
**(recovery mode)** kernel, then choose **Drop to root shell prompt**.
[Canonical recovery-mode instructions](https://ubuntu.com/docs/authd/stable-docs/howto/enter-recovery-mode/)

This mode is useful for inspecting logs, undoing a bad configuration, or
running Timeshift when the installed root filesystem and package are still
usable. It is not independent backup media: a broken GRUB, kernel, root
filesystem, or initramfs can prevent recovery mode itself from starting.

## Operational recommendation for the next iteration

Before any GPU/power script exists, establish a recovery rehearsal:

1. Put the Timeshift RSYNC snapshot on a separate disk/partition and create it
   from the CLI.
2. Confirm `sudo timeshift --list` sees it after an unmount/remount.
3. Record the root, `/boot`, `/boot/efi`, and snapshot device identities.
4. Test entering GRUB recovery mode without changing anything.
5. Keep Ubuntu’s power-profile stack intact for the baseline.
6. Install the Ubuntu-recommended NVIDIA package and verify that nouveau is
   not the loaded driver before testing offload.
7. Measure GNOME ownership, NVIDIA idle state, temperature, and an actual AI
   workload separately.
8. Only then consider a user-invoked, opt-in System76-power experiment, with a
   `--skip-power-policy` path and a preflight/abort path. That implementation
   is outside this research note and was intentionally not performed here.

## Source record

All links in this note point to first-party sources or the owning project’s
official source repository. Practitioner reports, forum posts, and generic
Linux tweak guides were excluded from the evidence base.

