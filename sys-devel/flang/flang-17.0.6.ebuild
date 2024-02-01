# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )

ROCM_VERSION=6.0.0

inherit cmake llvm llvm.org multilib multilib-minimal
inherit prefix python-single-r1 toolchain-funcs rocm

DESCRIPTION="Fortran language family frontend for LLVM, formally known as flang-new; f18"
HOMEPAGE="https://llvm.org/"


# MSVCSetupApi.h: MIT
# sorttable.js: MIT

LICENSE="Apache-2.0-with-LLVM-exceptions UoI-NCSA MIT"
SLOT="${LLVM_MAJOR}/${LLVM_SOABI}"
KEYWORDS="~amd64 ~arm ~arm64 ~loong ~ppc ~ppc64 ~riscv ~sparc ~x86 ~amd64-linux ~x64-macos"
IUSE="debug doc ieee-long-double +pie test xml"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RESTRICT="!test? ( test )"

DEPEND="
	~sys-devel/llvm-${PV}:${LLVM_MAJOR}=[debug=,${MULTILIB_USEDEP}]
	~dev-libs/mlir-${PV}:${LLVM_MAJOR}=[debug=,${MULTILIB_USEDEP}]
	>=sys-libs/libomp-${PV}[offload]
	xml? ( dev-libs/libxml2:2=[${MULTILIB_USEDEP}] )
"

RDEPEND="
	${PYTHON_DEPS}
	${DEPEND}
	>=sys-devel/clang-common-${PV}
"
BDEPEND="
	${PYTHON_DEPS}
	>=dev-build/cmake-3.16
	doc? ( $(python_gen_cond_dep '
		dev-python/recommonmark[${PYTHON_USEDEP}]
		dev-python/sphinx[${PYTHON_USEDEP}]
	') )
	xml? ( virtual/pkgconfig )
"
PDEPEND="
	sys-devel/clang-toolchain-symlinks:${LLVM_MAJOR}
"

LLVM_COMPONENTS=(
	flang cmake llvm
)
LLVM_MANPAGES=1
LLVM_TEST_COMPONENTS=(
	llvm/utils
)
LLVM_USE_TARGETS=llvm
llvm.org_set_globals

PATCHES=(
	 "${FILESDIR}"/${PN}-17.0.5-flang-new-rename-to-flang.patch
	 "${FILESDIR}"/${PN}-17.0.5-enable-dynamic.patch
	 "${FILESDIR}"/${PN}-17.0.5-runtime-libdir.patch
)

# Multilib notes:
# 1. ABI_* flags control ABIs libflang* is built for only.
# 2. flang is always capable of compiling code for all ABIs for enabled
#    target.
# 3. ${CHOST}-flang wrappers are always installed for all ABIs included
#    in the current profile (i.e. alike supported by sys-devel/gcc).
#
# Therefore: use sys-devel/flang[${MULTILIB_USEDEP}] only if you need
# multilib clang* libraries (not runtime, not wrappers).

pkg_setup() {
	LLVM_MAX_SLOT=${LLVM_MAJOR} llvm_pkg_setup
	python-single-r1_pkg_setup
	export CC=clang CXX=clang++ CPP=clang LD=ld.lld
	tc-is-clang || die Needs Clang
	strip-unsupported-flags

	# avoid sandbox violation
	addpredict /dev/kfd
	addpredict /dev/dri/
}

src_prepare() {
	llvm.org_src_prepare

	#https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-${PV/_/-}/clang/include/clang/Driver/Options.td
	#https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-${PV/_/-}/mlir/test/lib/Analysis/TestAliasAnalysis.h

	# Needed from clang for man page (Fedora does this)
	#mkdir -p ${WORKDIR}/clang/include/clang/Driver
	#mv ${FILESDIR}/Options.td ${WORKDIR}/clang/include/clang/Driver || die

	# Also from Fedora
	#mkdir -p ${S}/include/mlir/test/lib/Analysis/
	#mv ${FILESDIR}/TestAliasAnalysis.h ${S}/include/mlir/test/lib/Analysis/ || die
}

multilib_src_configure() {
	local mycmakeargs=(
		-DFLANG_USE_LEGACY_NAME=OFF
		-DMLIR_TABLEGEN_EXE="${EPREFIX}/usr/lib/llvm/${LLVM_MAJOR}/bin/mlir-tblgen"
		-DCLANG_DIR="${EPREFIX}/usr/lib/llvm/${LLVM_MAJOR}/$(get_libdir)/cmake/clang"
		-DLLVM_MAIN_SRC_DIR=${WORKDIR}/llvm

		-DDEFAULT_SYSROOT=$(usex prefix-guest "" "${EPREFIX}")
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/lib/llvm/${LLVM_MAJOR}"
		-DCMAKE_INSTALL_MANDIR="${EPREFIX}/usr/lib/llvm/${LLVM_MAJOR}/share/man"
		
		-DBUILD_SHARED_LIBS=ON
		-DCLANG_LINK_CLANG_DYLIB=ON
		-DFLANG_INCLUDE_TESTS=$(usex test)

		-DFLANG_EXPERIMENTAL_OMP_OFFLOAD_BUILD="host_device"
		-DFLANG_OMP_DEVICE_ARCHITECTURES="$(echo $(get_amdgpu_flags)|sed 's/;$//')"
	)

	use test && mycmakeargs+=(
		-DLLVM_BUILD_TESTS=ON
		-DLLVM_LIT_ARGS="$(get_lit_flags)"
	)

	if multilib_is_native_abi; then
		local build_docs=OFF
		if llvm_are_manpages_built; then
			build_docs=ON
			mycmakeargs+=(
			
				-DLLVM_BUILD_DOCS=ON
				-DLLVM_ENABLE_SPHINX=ON
				-DFLANG_INSTALL_SPHINX_HTML_DIR="${EPREFIX}/usr/share/doc/${PF}/html"
				-DSPHINX_WARNINGS_AS_ERRORS=OFF
			)
		fi
		mycmakeargs+=(
			-DFLANG_INCLUDE_DOCS=${build_docs}
		)
	fi

	if [[ -n ${EPREFIX} ]]; then
		mycmakeargs+=(
			-DGCC_INSTALL_PREFIX="${EPREFIX}/usr"
		)
	fi

	if tc-is-cross-compiler; then
		has_version -b sys-devel/flang:${LLVM_MAJOR} ||
			die "sys-devel/flang:${LLVM_MAJOR} is required on the build host."
		local tools_bin=${BROOT}/usr/lib/llvm/${LLVM_MAJOR}/bin
		mycmakeargs+=(
			-DLLVM_TOOLS_BINARY_DIR="${tools_bin}"
			-DCLANG_TABLEGEN="${tools_bin}"/clang-tblgen
		)
	fi

	# LLVM can have very high memory consumption while linking,
	# exhausting the limit on 32-bit linker executable
	use x86 && local -x LDFLAGS="${LDFLAGS} -Wl,--no-keep-memory"

	# LLVM_ENABLE_ASSERTIONS=NO does not guarantee this for us, #614844
	use debug || local -x CPPFLAGS="${CPPFLAGS} -DNDEBUG"
	cmake_src_configure
}

multilib_src_compile() {
	cmake_build flang FortranRuntime
}

multilib_src_test() {
	# respect TMPDIR!
	local -x LIT_PRESERVES_TMP=1
	local test_targets=( check-flang )
	cmake_build "${test_targets[@]}"
}

src_install() {
	MULTILIB_WRAPPED_HEADERS=(
		/usr/include/flang/Config/config.h
	)

	multilib-minimal_src_install

	# Move runtime headers to /usr/lib/flang, where they belong
	#mv "${ED}"/usr/include/flangrt "${ED}"/usr/lib/flang || die
	# move (remaining) wrapped headers back
	#mv "${ED}"/usr/include "${ED}"/usr/lib/llvm/${LLVM_MAJOR}/include || die

	# Apply CHOST and version suffix to flang tools
	local flang_tools=( flang tco bbc flang-to-external-fc fir-opt )
	local abi i

	# cmake gives us:
	# - flang-X
	# - flang -> flang-X
	# - flang++, flang-cl, flang-cpp -> flang
	# we want to have:
	# - flang-X
	# - flang++-X, flang-cl-X, flang-cpp-X -> flang-X
	# - flang, flang++, flang-cl, flang-cpp -> flang*-X
	# also in CHOST variant
	for i in "${flang_tools[@]:1}"; do
		rm "${ED}/usr/lib/llvm/${LLVM_MAJOR}/bin/${i}" || die
		dosym "flang-${LLVM_MAJOR}" "/usr/lib/llvm/${LLVM_MAJOR}/bin/${i}-${LLVM_MAJOR}"
		dosym "${i}-${LLVM_MAJOR}" "/usr/lib/llvm/${LLVM_MAJOR}/bin/${i}"
	done

	# now create target symlinks for all supported ABIs
	for abi in $(get_all_abis); do
		local abi_chost=$(get_abi_CHOST "${abi}")
		for i in "${flang_tools[@]}"; do
			dosym "${i}-${LLVM_MAJOR}" \
				"/usr/lib/llvm/${LLVM_MAJOR}/bin/${abi_chost}-${i}-${LLVM_MAJOR}"
			dosym "${abi_chost}-${i}-${LLVM_MAJOR}" \
				"/usr/lib/llvm/${LLVM_MAJOR}/bin/${abi_chost}-${i}"
		done
	done
}

multilib_src_install() {
	DESTDIR=${D} cmake_build install
}

#multilib_src_install_all() {
#	docompress "/usr/lib/llvm/${LLVM_MAJOR}/share/man"
#	llvm_install_manpages
#}

pkg_postinst() {
	if [[ -z ${ROOT} && -f ${EPREFIX}/usr/share/eselect/modules/compiler-shadow.eselect ]] ; then
		eselect compiler-shadow update all
	fi
}

pkg_postrm() {
	if [[ -z ${ROOT} && -f ${EPREFIX}/usr/share/eselect/modules/compiler-shadow.eselect ]] ; then
		eselect compiler-shadow clean all
	fi
}
