# Building NexusOS Genesis

The canonical Developer Preview build runs in GitHub Actions.

1. The C++ `nexus-gamed` daemon and `nexusctl` client are compiled and tested.
2. The binaries are staged into `os/files/`.
3. Podman builds `localhost/nexusos:dp-0.1` from the Fedora bootc 44 base.
4. bootc image builder creates the installer ISO.
5. The workflow uploads `NexusOS-Genesis-DP0.1-x86_64.iso` and its SHA-256 checksum as an artifact.

You can also start the pipeline manually from **Actions → Build NexusOS ISO → Run workflow**.
