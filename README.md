# central-launcher

Installs, launches and updates the workspace runtime as one self-contained binary per platform.

One binary carries the runtime and its child processes. It self-extracts on
first run (**install**), supervises the children from `priv/` (**launch**), and
fetches only the chunks that changed to move between versions (**update**).

    central-launcher install
    central-launcher launch
    central-launcher update

## Targets

`macos_arm64`, `linux_x86_64`, `windows_amd64`. Each is built natively on its own
runner: libgodot is glibc-entangled, so the zig cross-build other binaries here
use does not transfer, and Burrito cannot lay out a Windows ERTS from another
host.

## Update

The payload is published as a [desync](https://github.com/folbricht/desync)
index over a chunk store, so a client already holding version N fetches only the
chunks N+1 adds. Nothing server-side computes a delta, so one published copy
serves every client whatever version it is coming from.
