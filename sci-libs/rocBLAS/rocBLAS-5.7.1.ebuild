# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOCS_BUILDER="doxygen"
DOCS_DIR="docs"
DOCS_DEPEND="media-gfx/graphviz"
ROCM_VERSION=${PV}
inherit cmake docs edo multiprocessing prefix rocm

DESCRIPTION="AMD's library for BLAS on ROCm"
HOMEPAGE="https://github.com/ROCmSoftwarePlatform/rocBLAS"
SRC_URI="https://github.com/ROCmSoftwarePlatform/rocBLAS/archive/rocm-${PV}.tar.gz -> rocm-${P}.tar.gz"
S="${WORKDIR}/${PN}-rocm-${PV}"

LICENSE="BSD"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"
IUSE="benchmark test"
REQUIRED_USE="${ROCM_REQUIRED_USE}"
RESTRICT="!test? ( test )"

BDEPEND="
	dev-build/rocm-cmake
	dev-util/Tensile:${SLOT}
"

DEPEND="
	dev-util/hip
	dev-cpp/msgpack-cxx
	test? (
		virtual/blas
		dev-cpp/gtest
		sys-libs/libomp
	)
	benchmark? (
		virtual/blas
		sys-libs/libomp
	)
"

PATCHES=(
	"${FILESDIR}"/${PN}-5.7.1-change-default-Tensile-library-dir.patch
	"${FILESDIR}"/${PN}-5.7.1-unbundle-Tensile.patch
	)

pkg_setup() {
	export CC="$(get_llvm_prefix ${LLVM_MAX_SLOT})/bin/clang" CXX="$(get_llvm_prefix ${LLVM_MAX_SLOT})/bin/clang++" F77="$(get_llvm_prefix)/bin/flang" FC="$(get_llvm_prefix)/bin/flang" LD=ld.lld
	tc-is-clang || die Clang required
	strip-unsupported-flags
	filter-flags -fuse-ld=*
	append-flags -fuse-ld=lld
}

src_prepare() {
	cmake_src_prepare

	# Fit for Gentoo FHS rule
	sed -e "/PREFIX rocblas/d" \
		-e "/<INSTALL_INTERFACE/s:include:include/rocblas:" \
		-e "s:rocblas/include:include/rocblas:" \
		-e "s:\\\\\${CPACK_PACKAGING_INSTALL_PREFIX}rocblas/lib:${EPREFIX}/usr/$(get_libdir)/rocblas:" \
		-e "s:share/doc/rocBLAS:share/doc/${P}:" \
		-e "/rocm_install_symlink_subdir( rocblas )/d" -i library/src/CMakeLists.txt || die

	sed -e "s:,-rpath=.*\":\":" -i clients/CMakeLists.txt || die

	eprefixify library/src/tensile_host.cpp
}

src_configure() {
	addpredict /dev/random
	addpredict /dev/kfd
	addpredict /dev/dri/

	strip-flags

	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=On
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-DTensile_LOGIC="asm_full"
		-DTensile_COMPILER="hipcc"
		-DTensile_LIBRARY_FORMAT="msgpack"
		-DTensile_CODE_OBJECT_VERSION="V5"
		-DTensile_TEST_LOCAL_PATH="${EPREFIX}/usr/share/Tensile"
		-DTensile_ROOT="${EPREFIX}/usr/share/Tensile"
		-DBUILD_WITH_PIP=OFF
		-DBUILD_WITH_TENSILE=ON
		-DCMAKE_INSTALL_INCLUDEDIR="include"
		-DBUILD_TESTING=OFF
		-DBUILD_CLIENTS_SAMPLES=OFF
		-DBUILD_CLIENTS_TESTS=$(usex test ON OFF)
		-DBUILD_CLIENTS_BENCHMARKS=$(usex benchmark ON OFF)
		-DTensile_CPU_THREADS=$(makeopts_jobs)
		-DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF
		-DROCM_SYMLINK_LIBS=OFF
	)

	CXX=hipcc cmake_src_configure
}

src_compile() {
	docs_compile
	cmake_src_compile
}

src_test() {
	check_amdgpu
	cd "${BUILD_DIR}"/clients/staging || die
	export ROCBLAS_TEST_TIMEOUT=3600 ROCBLAS_TENSILE_LIBPATH="${BUILD_DIR}/Tensile/library"
	export LD_LIBRARY_PATH="${BUILD_DIR}/clients:${BUILD_DIR}/library/src"
	edob ./${PN,,}-test
}

src_install() {
	cmake_src_install

	if use benchmark; then
		cd "${BUILD_DIR}" || die
		dolib.so clients/librocblas_fortran_client.so
		dobin clients/staging/rocblas-bench
	fi
}
