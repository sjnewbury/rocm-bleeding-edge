# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..11} )
ROCM_VERSION=5.4.2
MULTILIB_WRAPPED_HEADERS=("/usr/include/hostrpc.h")

inherit flag-o-matic rocm cmake-multilib linux-info llvm llvm.org python-any-r1

DESCRIPTION="OpenMP runtime library for LLVM/clang compiler"
HOMEPAGE="https://openmp.llvm.org"

LICENSE="Apache-2.0-with-LLVM-exceptions || ( UoI-NCSA MIT )"
SLOT="0/${LLVM_SOABI}"
KEYWORDS=""
IUSE="
	debug hwloc offload ompt test
	llvm_targets_AMDGPU llvm_targets_NVPTX
"
RESTRICT="!test? ( test )"

RDEPEND="
	hwloc? ( >=sys-apps/hwloc-2.5:0=[${MULTILIB_USEDEP}] )
	offload? (
		virtual/libelf:=[${MULTILIB_USEDEP}]
		dev-libs/libffi:=[${MULTILIB_USEDEP}]
		~sys-devel/llvm-${PV}[${MULTILIB_USEDEP}]
	)
"
# tests:
# - dev-python/lit provides the test runner
# - sys-devel/llvm provide test utils (e.g. FileCheck)
# - sys-devel/clang provides the compiler to run tests
DEPEND="
	${RDEPEND}
"
BDEPEND="
	dev-lang/perl
	offload? (
		llvm_targets_AMDGPU? ( sys-devel/clang )
		llvm_targets_NVPTX? ( sys-devel/clang )
		virtual/pkgconfig
	)
	test? (
		$(python_gen_any_dep 'dev-python/lit[${PYTHON_USEDEP}]')
		sys-devel/clang
	)
"

PATCHES=(
	"${FILESDIR}"/build-fix.patch
	"${FILESDIR}"/no-rocm-without-being-enabled.patch
)

LLVM_COMPONENTS=( openmp cmake llvm/include )
llvm.org_set_globals

EGIT_BRANCH=rocm-5.4.x

python_check_deps() {
	python_has_version "dev-python/lit[${PYTHON_USEDEP}]"
}

kernel_pds_check() {
	if use kernel_linux && kernel_is -lt 4 15 && kernel_is -ge 4 13; then
		local CONFIG_CHECK="~!SCHED_PDS"
		local ERROR_SCHED_PDS="\
PDS scheduler versions >= 0.98c < 0.98i (e.g. used in kernels >= 4.13-pf11
< 4.14-pf9) do not implement sched_yield() call which may result in horrible
performance problems with libomp. If you are using one of the specified
kernel versions, you may want to disable the PDS scheduler."

		check_extra_config
	fi
}

pkg_pretend() {
	kernel_pds_check
}

pkg_setup() {
	use offload && LLVM_MAX_SLOT=${LLVM_MAJOR} llvm_pkg_setup
	use test && python-any-r1_pkg_setup
}

src_prepare() {
	sed -i \
		-e 's/LLVMOffloadArch/LLVM/g' \
		libomptarget/src/CMakeLists.txt || die sed failed
	cmake_src_prepare
}

multilib_src_configure() {
	# LTO causes issues in other packages building, #870127
	filter-lto

	# LLVM_ENABLE_ASSERTIONS=NO does not guarantee this for us, #614844
	use debug || local -x CPPFLAGS="${CPPFLAGS} -DNDEBUG"

	local libdir="$(get_libdir)"
	local mycmakeargs=(
		-DOPENMP_LIBDIR_SUFFIX="${libdir#lib}"

		-DLIBOMP_USE_HWLOC=$(usex hwloc)
		-DLIBOMP_OMPT_SUPPORT=$(usex ompt)

		# do not install libgomp.so & libiomp5.so aliases
		-DLIBOMP_INSTALL_ALIASES=OFF
		# disable unnecessary hack copying stuff back to srcdir
		-DLIBOMP_COPY_EXPORTS=OFF

		-DOPENMP_ENABLE_LIBOMPTARGET=$(usex offload)
	)

	if use offload; then
		if has "${CHOST%%-*}" aarch64 powerpc64le x86_64; then
			mycmakeargs+=(
				-DLIBOMPTARGET_AMDGCN_GFXLIST="$(get_amdgpu_flags)"
				-DDEVICELIBS_ROOT=/usr/lib/amdgcn
				-DLIBOMPTARGET_BUILD_AMDGPU_PLUGIN=$(usex llvm_targets_AMDGPU)
				-DLIBOMPTARGET_BUILD_CUDA_PLUGIN=$(usex llvm_targets_NVPTX)
			)
		else
			mycmakeargs+=(
				-DLIBOMPTARGET_BUILD_AMDGPU_PLUGIN=OFF
				-DLIBOMPTARGET_BUILD_CUDA_PLUGIN=OFF
			)
		fi
	fi

	use test && mycmakeargs+=(
		# this project does not use standard LLVM cmake macros
		-DOPENMP_LLVM_LIT_EXECUTABLE="${EPREFIX}/usr/bin/lit"
		-DOPENMP_LIT_ARGS="$(get_lit_flags)"

		-DOPENMP_TEST_C_COMPILER="$(type -P "${CHOST}-clang")"
		-DOPENMP_TEST_CXX_COMPILER="$(type -P "${CHOST}-clang++")"
	)
	addpredict /dev/nvidiactl
	cmake_src_configure
}

multilib_src_test() {
	# respect TMPDIR!
	local -x LIT_PRESERVES_TMP=1

	cmake_build check-libomp
}

multilib_src_install() {
	cmake_src_install

	if has "${CHOST%%-*}" aarch64 powerpc64le x86_64; then
		# Install bitcode which doesn't get installed otherwise
		# (libm/libhostrpc)
		insinto /usr/$(get_libdir)
		doins *.bc

		if use offload && use llvm_targets_AMDGPU; then
			# Clang can't find it otherwise!
			dodir $(get_llvm_prefix)/lib
			mv ${ED}/usr/$(get_libdir)/*.bc ${ED}/$(get_llvm_prefix)/lib || die moving bitcode failed
		fi
	fi
}
