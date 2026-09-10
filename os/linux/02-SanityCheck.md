# After reboot, establish a known-good hardware state

Before removing Snap, installing development environments, changing shells, etc., 
make sure the laptop actually works.

Test:
- Wi-Fi
- Bluetooth
- audio
- microphone
- webcam
- suspend
- resume
- external displays
- touchpad
- keyboard function keys
- brightness controls
- battery reporting
- GPU(s)

Especially test:

```
systemctl --failed
```

and:

```
journalctl -p 3 -b
```

Don't panic if journalctl contains a couple of firmware/ACPI errors; laptops routinely
generate some. You're looking for obvious recurring failures.

I'd also check:
```
sudo dmesg --level=err,warn
```

Now you know:
| Fully updated stock Ubuntu works correctly on this laptop.

That's a valuable checkpoint.
