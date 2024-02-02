# rocm-bleeding-edge
## Completely unofficial Gentoo ROCm support

I was previously using the AMD fork of LLVM, but I've
switched to using the Gentoo version.  This may or may
not work with any given version. Caveat emptor.

For GCC/Offloading support, use this overlay in
conjunction with my "gentoo-gpu" overlay.


### Status
HIP is tested and working with AMD RX Vega 64 (gfx900),
however OpenCL hasn't been working properly for me since
version 5.7.2. I hadn't initially noticed since I was
using RustiCL.

I would appreciate any testing with other hardware.

~~Builds for Raven Ridge (gfx902) but there's currently a
runtime issue initialiasing with the HSA Agent not
reporting the "Cache info" for the GPU.  I'm not sure
if this is a problem in the ROCR runtime or the kernel
kfd driver.~~

# Update:
gfx902 works with kernel 6.6.6, at least it passes a simple
API test, however it then causes the GPU to trigger
a reset loop, at least when running under KDE Wayland.
(Under investigation)
