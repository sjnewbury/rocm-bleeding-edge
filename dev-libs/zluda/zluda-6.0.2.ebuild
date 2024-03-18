# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=${PV}

inherit cmake cargo edo rocm

DESCRIPTION="CUDA on AMD GPUs"
HOMEPAGE="https://github.com/vosen/ZLUDA"
SRC_URI="https://github.com/sjnewbury/ZLUDA/archive/refs/tags/v3.tar.gz -> zluda-${PV}.tar.gz"

LICENSE="BSD"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"
IUSE="test"

RDEPEND="dev-util/hip
	dev-util/hipify-clang
	dev-util/rocm-smi:${SLOT}"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-build/cmake-3.22
	>=dev-build/rocm-cmake-5.0.2-r1
	test? ( dev-cpp/gtest )"

RESTRICT="!test? ( test )"
S="${WORKDIR}/rccl-rocm-${PV}"

PATCHES=("${FILESDIR}"/rocm-version.patch)

pkg_setup() {
	export CC=clang CXX=clang++
	tc-is-clang || Clang required
	strip-unsupported-flags
	
	#filter-flags ${LDFLAGS}
	#strip-flags
	append-cxxflags -O3 -flto=thin

	addpredict /dev/kfd
	addpredict /dev/dri/
}

src_prepare() {
	sed	-e '/parallel-jobs/s/^/#/g' \
		-i CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF
		-DBUILD_LOCAL_GPU_TARGET_ONLY=ON
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-DBUILD_TESTS=$(usex test ON OFF)
		-Wno-dev
	)

	ROCM_VERSION=${ROCM_VERSION} CXX=hipcc cmake_src_configure
}

src_install() {
        cmake_src_install
        rm -rf "${ED}"/usr/${PN} || die
}

src_test() {
	check_amdgpu
	LD_LIBRARY_PATH="${BUILD_DIR}" edob test/UnitTests
}
