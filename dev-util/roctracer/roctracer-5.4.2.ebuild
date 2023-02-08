# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{9..10} )

inherit cmake prefix python-any-r1

DESCRIPTION="Callback/Activity Library for Performance tracing AMD GPU's"
HOMEPAGE="https://github.com/ROCm-Developer-Tools/roctracer.git"
SRC_URI="https://github.com/ROCm-Developer-Tools/roctracer/archive/rocm-${PV}.tar.gz -> rocm-tracer-${PV}.tar.gz
		https://github.com/ROCm-Developer-Tools/rocprofiler/archive/rocm-${PV}.tar.gz -> rocprofiler-${PV}.tar.gz"
S="${WORKDIR}/roctracer-rocm-${PV}"

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64"

RDEPEND="dev-libs/rocr-runtime:${SLOT}
	dev-util/hip:${SLOT}"
DEPEND="${RDEPEND}"
BDEPEND="
	$(python_gen_any_dep '
	dev-python/CppHeaderParser[${PYTHON_USEDEP}]
	dev-python/ply[${PYTHON_USEDEP}]
	')
"

PATCHES=(
	"${FILESDIR}"/${P}-cmake-find-hip.patch
)

python_check_deps() {
	python_has_version "dev-python/CppHeaderParser[${PYTHON_USEDEP}]" \
		"dev-python/ply[${PYTHON_USEDEP}]"
}

src_prepare() {
	cmake_src_prepare

	mv "${WORKDIR}"/rocprofiler-rocm-${PV} "${WORKDIR}"/rocprofiler || die

	# change destination for headers to include/roctracer;

	sed -e "/LIBRARY DESTINATION/s,lib,$(get_libdir)," \
		-e "/DESTINATION/s,\${DEST_NAME}/include,include/roctracer," \
		-e "/install ( FILES \${PROJECT_BINARY_DIR}\/so/d" \
		-e "/DESTINATION/s,\${DEST_NAME}/lib64,$(get_libdir),g" \
		-e "/add_subdirectory(test)/s/^/#/" \
		-i CMakeLists.txt || die

	# do not download additional sources via git
	sed -e "/execute_process ( COMMAND sh -xc \"if/d" \
		-e "/DESTINATION/s,\${DEST_NAME}/tool,$(get_libdir),g" \
		-i test/CMakeLists.txt || die

	hprefixify script/*.py
}

src_configure() {
	export HIP_PATH="$(hipconfig -p)"

	local mycmakeargs=(
		-DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=OFF
	)

	cmake_src_configure
}
