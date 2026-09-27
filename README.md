# NexusOS Developer Preview 0.1

> Codename: **Genesis** — project name is provisional until trademark review.

NexusOS is an experimental, gaming-first, immutable desktop operating system built as a bootable OCI image. The goal of this repository is to establish a production-oriented foundation: atomic upgrades/rollback, Wayland/KDE desktop, networking/audio/Bluetooth, and Nexus-owned gaming services.

## What this preview is

This is **not** a from-scratch kernel. NexusOS uses the Linux kernel for hardware support and builds its own product layer above it. The earlier BolinhoKernel experiments remain useful as a separate research project.

Preview 0.1 includes:

- Fedora bootc base (immutable/transactional system image)
- KDE Plasma + Wayland session
- NetworkManager + Wi‑Fi/Ethernet
- BlueZ Bluetooth stack
- PipeWire + WirePlumber audio
- Flatpak support
- Firefox
- `nexus-gamed`: Nexus gaming performance service
- `nexusctl`: command-line client for Game Mode
- systemd units and hardened service sandboxing
- NexusOS first-boot defaults and visual identity
- ISO / QCOW2 build scripts using bootc image tooling
- VirtualBox test guide

## What is intentionally NOT promised yet

- Universal Windows-game compatibility
- NVIDIA proprietary driver redistribution
- kernel anti-cheat compatibility
- HDR/VRR on every GPU/display
- a custom Wayland compositor
- a custom installer UI
- global DLSS injection
- guaranteed FPS improvements over Windows

Those require staged engineering and hardware validation.

## Repository layout

```text
NexusOS/
├── os/                 Bootable OS image definition
├── packages/           Nexus-owned components
│   └── nexus-gamed/    Gaming performance daemon + client
├── installer/          bootc image-builder configuration
├── scripts/            Local build helpers
├── tests/              Smoke tests
├── docs/               Architecture, UX and release docs
└── .github/workflows/  CI and ISO build pipelines
```

## Build the ISO on GitHub

Open **Actions → Build NexusOS ISO → Run workflow**. The workflow builds the bootc image and then generates an installer ISO with the upstream OSBuild bootc-image-builder action.

Expected artifact:

```text
NexusOS-Genesis-DP0.1-x86_64.iso
```

## VirtualBox target

For DP0.1, use a VM with:

- 4 GB RAM
- 2 vCPUs
- 32–64 GB virtual disk
- EFI enabled
- VMSVGA graphics
- 128 MB video memory
- NAT networking

See `docs/VIRTUALBOX.md` for details.

## Security model

`nexus-gamed` is an early prototype. Long term, privileged operations will move behind a narrow D-Bus API with PolicyKit authorization and explicit per-feature permissions.

## License

Original NexusOS code in this preview is released under Apache-2.0 unless a directory states otherwise. Linux and third-party components retain their upstream licenses.
