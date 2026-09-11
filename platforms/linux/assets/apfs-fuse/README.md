# Precompiled apfs-fuse for Debian 13 amd64

Upstream: https://github.com/sgan81/apfs-fuse
Source commit: 66b86bd525e8cb90f9012543be89b1f092b75cf3
LZFSE submodule: e634ca58b4821d9f3d560cdc6df5dec02ffc93fd

Packaged from this workstation's existing clean-source Release build (GCC 14,
USE_FUSE3=ON) on September 11, 2026. The apfs-fuse binary is byte-for-byte equal
to the already-installed working /usr/local/bin/apfs-fuse. These are local
LarryBootstrap binaries, not upstream release binaries. Upstream publishes no
binary releases. Source and both licenses are included for redistribution.

Runtime: Debian 13 amd64, libfuse3-4, zlib1g, libbz2-1.0, libstdc++6, libgcc-s1,
libc6. Installer verifies SHA256SUMS, architecture and dynamic dependencies.
It installs tools only; it does not mount or modify any partition.

Rebuild separately (not during bootstrap): extract source.tar.gz, then run
`cmake -S apfs-fuse -B build -DCMAKE_BUILD_TYPE=Release -DUSE_FUSE3=ON`
and `cmake --build build`. Build dependencies are build-essential, cmake,
libfuse3-dev, libbz2-dev, zlib1g-dev. The matching LZFSE source is included.
