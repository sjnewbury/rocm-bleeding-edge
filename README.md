# rocm-bleeding-edge
Completely unofficial Gentoo ROCm support

This overlay is maintained against current/next ROCm
LLVM downstream and replaces the system LLVM packages
entirely with live (branch) versions from
https://github.com/radeonopencompute/llvm-project.git

If this is a problem for you, and you don't want to
use the supplied llvm.org.eclass you can try to build
against the Gentoo official versions but I can't
guarantee it will work.

For GCC/Offloading support, use this overlay in
conjunction with my "gentoo-gpu" overlay.
