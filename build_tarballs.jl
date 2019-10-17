# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "LibPQ"
version = v"12.0.0+0"

# Collection of sources required to build LibPQ
sources = [
    "https://ftp.postgresql.org/pub/source/v12.0/postgresql-12.0.tar.gz" =>
    "15c7f267b476d764c79401d7f61f39c76222314951f77e6893a5854db26b6616",

    "https://data.iana.org/time-zones/tzdata-latest.tar.gz" =>
    "79c7806dab09072308da0e3d22c37d3b245015a591891ea147d3b133b60ffc7c",

    "https://data.iana.org/time-zones/tzcode-latest.tar.gz" =>
    "f6ebd3668e02d5ed223d3b7b1947561bf2d2da2f4bd1db61efefd9e06c167ed4",

]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
make CC=$BUILD_CC
export ZIC=$WORKSPACE/srcdir/zic
cd postgresql-12.0/
./configure --prefix=$prefix --host=$target --with-includes=$prefix/include --with-libraries=$prefix/lib --without-readline --without-zlib --with-openssl
make -C src/interfaces/libpq install
rm -rf ${prefix}/logs
exit

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:i686, libc=:glibc),
    Linux(:x86_64, libc=:glibc),
    Linux(:aarch64, libc=:glibc),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf),
    Linux(:powerpc64le, libc=:glibc),
    Linux(:i686, libc=:musl),
    Linux(:x86_64, libc=:musl),
    Linux(:aarch64, libc=:musl),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf),
    MacOS(:x86_64),
    FreeBSD(:x86_64),
    Windows(:i686),
    Windows(:x86_64)
]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libpq", :LIBPQ_HANDLE)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    "https://gist.githubusercontent.com/giordano/9b876f8ae84421f204f803e7dc16eaf1/raw/b389179bca8062c96b6131a9be5c7ef269a1678d/build_OpenSSL.v1.1.1+c.jl"
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
