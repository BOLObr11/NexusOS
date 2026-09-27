# NexusOS Genesis in VirtualBox

Recommended VM for Developer Preview 0.1:

- Type: Linux / Fedora (64-bit), or Other Linux (64-bit)
- RAM: 4096 MB minimum
- CPU: 2 vCPUs minimum
- Disk: 32 GB dynamically allocated
- EFI: enabled
- Graphics controller: VMSVGA
- Video memory: 128 MB
- 3D acceleration: optional for the first boot; disable it if the installer shows graphics glitches
- Network: NAT
- Audio: enabled

Mount `NexusOS-Genesis-DP0.1-x86_64.iso` in the optical drive and boot the VM.

The Genesis installer is currently unattended and will erase the **virtual disk attached to the VM**. Do not boot this preview installer on a physical PC containing data you care about.

After installation, eject the ISO and boot from the virtual disk.

Developer Preview credentials:

- user: `nexus`
- password: `nexus`

The installed user belongs to `wheel` and `nexus-game`, so `nexusctl` can communicate with the Game Mode daemon.
