# Ubuntu 26.04 hydration test VM

This documents the disposable Ubuntu 26.04 VM used to test the Linux
hydration scripts without touching the live development system.

## Safety model

- The VM uses its own 50 GiB qcow2 disk under `/home/human/VMs`.
- The repository is shared into the guest read-only through virtiofs.
- Do not run the hydrator against the host checkout or host operating system.
- VM snapshots do not snapshot the shared repository. They only protect the VM
  disk and guest state.

## Host prerequisites

Install QEMU/libvirt. `qemu-kvm` is a virtual package on Ubuntu 26.04, so use
the concrete x86 package:

```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients virtinst virt-manager ovmf virtiofsd
```

Install the SPICE console client if it is not already present:

```bash
sudo apt install -y virt-viewer
```

Confirm hardware acceleration and add the current user to the VM groups:

```bash
test -e /dev/kvm && echo 'KVM available'
sudo usermod -aG libvirt,kvm "$USER"
```

Log out and back in (or reboot) so the new groups apply. Verify the session
connection:

```bash
groups
virsh -c qemu:///session list --all
```

The VM was created with the per-user libvirt connection because the system
libvirt daemon cannot reliably traverse `/home/human` for this share.

## Download and verify Ubuntu

```bash
mkdir -p /home/human/VMs/ubuntu-26.04-test
cd /home/human/VMs/ubuntu-26.04-test
wget https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso
echo '487f87faaf547ea30e0aba4d5b53346292571256b25333a978db1692bcee9dd2  ubuntu-26.04-desktop-amd64.iso' | sha256sum -c -
```

The checksum above is the verified checksum for the ISO used in this test.

## Create the VM

```bash
virt-install \
  --connect qemu:///session \
  --name ubuntu-26-04-hydration-test \
  --memory 8192 \
  --vcpus 4 \
  --cpu host-model \
  --disk path=/home/human/VMs/ubuntu-26.04-test/ubuntu-26-04-hydration-test.qcow2,size=50,format=qcow2 \
  --cdrom /home/human/VMs/ubuntu-26.04-test/ubuntu-26.04-desktop-amd64.iso \
  --os-variant generic \
  --boot uefi \
  --network user \
  --graphics spice,listen=127.0.0.1
```

Open the graphical installer with either command:

```bash
virt-manager --connect qemu:///session
remote-viewer spice://127.0.0.1:5900
```

In virt-manager, double-click `ubuntu-26-04-hydration-test` to open its SPICE
console. `remote-viewer` is provided by the `virt-viewer` package.

In the installer, create the local account:

```text
Username: human
Password: UbuntuTest!2026
```

After installation, reboot the guest and eject the installer ISO. Find the
CD-ROM target first; it was `sda` in this VM:

```bash
virsh -c qemu:///session domblklist ubuntu-26-04-hydration-test
virsh -c qemu:///session change-media ubuntu-26-04-hydration-test sda --eject --config
```

## Initial guest baseline and snapshot

Use the VM console to run the normal guest update:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

Shut down cleanly from the guest, then create the first known-good snapshot:

```bash
virsh -c qemu:///session shutdown ubuntu-26-04-hydration-test
virsh -c qemu:///session domstate ubuntu-26-04-hydration-test
virsh -c qemu:///session snapshot-create-as \
  ubuntu-26-04-hydration-test clean-install \
  'Ubuntu 26.04 installed and fully upgraded'
virsh -c qemu:///session snapshot-list ubuntu-26-04-hydration-test
virsh -c qemu:///session start ubuntu-26-04-hydration-test
```

Useful additional checkpoints:

```bash
virsh -c qemu:///session snapshot-create-as ubuntu-26-04-hydration-test pre-hydration 'Before hydration test'
virsh -c qemu:///session snapshot-create-as ubuntu-26-04-hydration-test pre-snap-removal 'Before Snap removal test'
virsh -c qemu:///session snapshot-create-as ubuntu-26-04-hydration-test post-test 'After hydration test'
```

Restore a guest snapshot only while the VM is stopped:

```bash
virsh -c qemu:///session shutdown ubuntu-26-04-hydration-test
virsh -c qemu:///session snapshot-revert ubuntu-26-04-hydration-test \
  --snapshotname pre-hydration
virsh -c qemu:///session start ubuntu-26-04-hydration-test
```

## Share the private repository with virtiofs

`virtiofsd` is the host-side daemon. QEMU connects it to the guest using a
virtio filesystem device; the guest mounts the device by its tag. The host
directory remains in place and is not copied into the VM.

The host-side configuration requires shared memfd memory. Use `virsh edit` and
ensure the domain contains this block near the memory settings:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

Then add this filesystem under `<devices>`:

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/home/human/CODE/dotfiles'/>
  <target dir='dotfiles'/>
  <readonly/>
</filesystem>
```

Restart the VM after changing the XML:

```bash
virsh -c qemu:///session shutdown ubuntu-26-04-hydration-test
# Wait until `domstate` reports `shut off`.
virsh -c qemu:///session start ubuntu-26-04-hydration-test
```

Inside the Ubuntu guest, mount the share:

```bash
sudo mkdir -p /mnt/dotfiles
sudo mount -t virtiofs -o ro dotfiles /mnt/dotfiles
ls /mnt/dotfiles
```

The repository is then available at `/mnt/dotfiles`. The `-o ro` mount and
`<readonly/>` host declaration provide two layers of protection.

Ubuntu 26.04 loads the `virtiofs` kernel support automatically when the
device is present, so `modprobe` is normally unnecessary. If the mount fails,
try `sudo modprobe virtiofs` before collecting diagnostics.

If mounting fails, collect diagnostics inside the guest:

```bash
uname -r
lsmod | grep virtiofs
ls /sys/fs/virtiofs
dmesg | tail -30
```

## Access and control

The graphical console is SPICE on `127.0.0.1:5900`:

```bash
remote-viewer spice://127.0.0.1:5900
```

The VM has a serial device, but the standard Ubuntu desktop installation does
not provide a usable serial login by default. SSH and the QEMU guest agent are
not installed by default, so host `virsh console` and guest command execution
are recovery options only after explicitly setting them up in the guest.

Inspect the VM without opening the console:

```bash
virsh -c qemu:///session domstate ubuntu-26-04-hydration-test
virsh -c qemu:///session domblklist ubuntu-26-04-hydration-test
virsh -c qemu:///session snapshot-list ubuntu-26-04-hydration-test
virsh -c qemu:///session screenshot ubuntu-26-04-hydration-test /tmp/ubuntu-vm.png
```

## Testing from the mounted checkout

From the guest:

```bash
cd /mnt/dotfiles
git status --short
```

Run only the intended test mode first. The live host must not be used for this
test. Capture an auditable transcript with `script` in a guest-writable path:

```bash
mkdir -p "$HOME/vm-test-artifacts"
script --flush --return --command \
  'bash /mnt/dotfiles/os/linux/scripts/ubu.sh' \
  "$HOME/vm-test-artifacts/hydrate-transcript.log"
```

Review the transcript afterward:

```bash
less "$HOME/vm-test-artifacts/hydrate-transcript.log"
```

The repository share is intentionally read-only; generated reports and
transcripts must be copied out of the guest or stored under the guest home.

## Cleanup

Stop the VM when finished:

```bash
virsh -c qemu:///session shutdown ubuntu-26-04-hydration-test
```

The VM can be started again with:

```bash
virsh -c qemu:///session start ubuntu-26-04-hydration-test
```
