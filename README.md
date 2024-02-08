# rocm-bleeding-edge
## Completely unofficial Gentoo ROCm support

I was previously using the AMD fork of LLVM, but I've
switched to using the Gentoo version.  This may or may
not work with any given version. Caveat emptor.

For GCC/Offloading support, use this overlay in
conjunction with my "gentoo-gpu" overlay.


### Status
HIP is tested and working with AMD RX Vega 64 (gfx900)
and Vega8/Raven Ridge APU (gfx902), this includes OpenCL,
tested with "hashcat".  rocm-opencl-runtime currently
provides much better support for OpenCL2 than RustiCL.

I would appreciate any testing with other hardware.

### Update:
gfx902 and gfx900 with provided patches now appear to be
fully functional for both HIP and OpenCL.
