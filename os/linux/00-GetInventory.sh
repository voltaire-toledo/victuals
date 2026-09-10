# mkdir -p ~/setup-baseline

# {
    echo "=== DATE ==="
    date

    echo "=== OS ==="
    cat /etc/os-release

    echo "=== KERNEL ==="
    uname -a

    echo "=== HARDWARE ==="
    lscpu
    free -h

    echo "=== PCI ==="
    lspci -nnk

    echo "=== BLOCK ==="
    lsblk -o NAME,SIZE,FSTYPE,FSVER,MOUNTPOINTS,MODEL

    echo "=== GPU ==="
    lspci | grep -Ei 'vga|3d|display'

    echo "=== APT SOURCES ==="
    grep -R --no-filename -h '^deb\|^Types:\|^URIs:\|^Suites:' \
        /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null

    echo "=== SNAPS ==="
    snap list 2>/dev/null || true
# } | tee ~/setup-baseline/baseline.txt


sudo lshw -short
sudo dmidecode -t system

echo 
echo "=== Getting GPU Inventory ==="
lspci -nnk | grep -A3 -Ei 'VGA|3D|Display'
