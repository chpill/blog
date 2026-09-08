---
title: Test bootable usb drive with Qemu
author: Etienne Spillemaeker
published: 2026-09-08
---

Before trying out a live USB on a physical computer, try it out on a virtual one to make sure it works!

* Grab a Qemu
```shell
nix shell nixpkgs#qemu
```

* Check that the `iso` itself works
```shell
qemu-system-x86_64 -cdrom latest-nixos-minimal-x86_64-linux.iso
```

* Find out where your usb stick is at, here: /dev/sda
```shell
sudo fdisk -l
```

* `bs` is the number of bytes handled at a time. The default of 512 seems low.
   The `conv=fsync` ensures the data is actually written to the end ("don't forget to flush").
```shell
dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sda bs=4M status=progress conv=fsync
```

* The `-m 1024` option refers to the amount of RAM you dedicate to the task
```shell
qemu-system-x86_64 -enable-kvm -m 1024 -drive file=/dev/sda
```

