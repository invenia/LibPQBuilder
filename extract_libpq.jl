using BinaryBuilder
using BinaryProvider
using Glob
using SHA

const DOWNLOADS_DIR = joinpath(get(ENV, "TRAVIS_BUILD_DIR", @__DIR__), "downloads")
const PRODUCTS_DIR = joinpath(get(ENV, "TRAVIS_BUILD_DIR", @__DIR__), "products")

const DEFAULT_TAG = "v10.3-1-0"
const TAG_REGEX = r"v([\d\.]+)-(\d+)-(\d+)"
const TAG_MATCH = let
    tag = get(ENV, "TRAVIS_TAG", DEFAULT_TAG)
    tag_match = match(TAG_REGEX, tag)
    if tag_match === nothing
        tag_match = match(TAG_REGEX, DEFAULT_TAG)
    end

    tag_match
end

const POSTGRESQL_VERSION = String(TAG_MATCH.captures[1])
const EDB_BUILD = String(TAG_MATCH.captures[2])
const BUILDER_BUILD = String(TAG_MATCH.captures[3])

@show POSTGRESQL_VERSION
@show EDB_BUILD
@show BUILDER_BUILD

const EDB_PLATFORMS = [
    (Windows(:i686), "windows", ".zip")
    (Windows(:x86_64), "windows-x64", ".zip")
    (Linux(:i686, :glibc), "linux", ".tar.gz")
    (Linux(:x86_64, :glibc), "linux-x64", ".tar.gz")
    (MacOS(), "osx", ".zip")
]

const URL_HASHES = Dict(
    "https://get.enterprisedb.com/postgresql/postgresql-10.3-1-windows-binaries.zip" => "7ad56fa515673060fa797208f314431fdcce36db9fdd3bb5b6fbb1d569aa548b",
    "https://get.enterprisedb.com/postgresql/postgresql-10.3-1-windows-x64-binaries.zip" => "9e5cc5c4d8d368042f5e3ad3a2e8a530a8d9ae9e61354ff3dece6462eccfac00",
    "https://get.enterprisedb.com/postgresql/postgresql-10.3-1-linux-binaries.tar.gz" => "e9368c04db17c085c5a443280903cdaf893ea90590694362c5e4d3e54cd0e181",
    "https://get.enterprisedb.com/postgresql/postgresql-10.3-1-linux-x64-binaries.tar.gz" => "2f3dd0235dfcfb52ce268a68af3d00ace68dd42b08ff2631934f47dbe455e0f0",
    "https://get.enterprisedb.com/postgresql/postgresql-10.3-1-osx-binaries.zip" => "eba4747e500c25e499a69533eedd0983ab6ae5377096d8689ffffaada8e98dca",
)

function edb_binary_url(platform::String, version::String, build::String, ext::String)
    "https://get.enterprisedb.com/postgresql/postgresql-$version-$build-$platform-binaries$ext"
end

function hash_file(filepath::String, hashfn=sha256)
    open(filepath, "r") do f
        bytes2hex(hashfn(f))
    end
end

function download(url::String, dir::String)
    filepath = joinpath(dir, basename(url))

    # exit early if we already have the file
    if isfile(filepath) && URL_HASHES[url] == hash_file(filepath)
        info("Found $(basename(filepath)), not redownloading")
        return filepath
    end

    if !isdir(dir)
        mkpath(dir)
    end

    run(`wget -O $filepath --no-verbose $url`)

    if !isfile(filepath)
        error("Downloaded file isn't at $filepath like we expected")
    end

    return filepath
end

function extract(filepath::String, ext::String)
    dir = replace(filepath, ext, "")

    if contains(ext, "zip")
        extract_zip(filepath, dir)
    else
        extract_tar(filepath, dir)
    end

    if !isdir(dir)
        error("Extracted files aren't in $dir like we expected")
    end

    return dir
end

function extract_tar(filepath::String, dir::String)
    if !isdir(dir)
        mkpath(dir)
    end

    run(pipeline(`tar -C $dir -xf $filepath`, stdout=DevNull))
end
extract_zip(filepath::String, dir::String) = run(pipeline(`unzip -d $dir $filepath`, stdout=DevNull))

function find_prefixdir(dir::String, prefixdir::String)
    glob("*/$prefixdir/*libpq.*", dir)
end

function copy_files(srcdir::String, destdir::String)
    for prefixdir in ("lib", "bin")
        prefixdest = joinpath(destdir, prefixdir)

        files = find_prefixdir(srcdir, prefixdir)

        if !isempty(files)
            if !isdir(prefixdest)
                mkpath(prefixdest)
            end

            for filepath in files
                cp(filepath, joinpath(prefixdest, basename(filepath)); remove_destination=true)
            end
        end
    end
end

function archive(dir::String)
    output = "$dir.tar.gz"

    run(pipeline(`tar -C $dir -czf $output .`, stdout=DevNull))
end

function make_tarballs(
    download_dir::String,
    product_dir::String;
    postgresql_version::String=POSTGRESQL_VERSION,
    edb_build::String=EDB_BUILD,
)
    for (platform, edb_name, archive_ext) in EDB_PLATFORMS
        product_name = "libpq.$(triplet(platform))"
        product_path = joinpath(product_dir, product_name)
        mkpath(product_path)
        info("Downloading binaries for $platform")
        url = edb_binary_url(edb_name, postgresql_version, edb_build, archive_ext)
        downloaded = download(url, download_dir)
        info("Extracting binaries for $platform")
        extracted = extract(downloaded, archive_ext)
        info("Picking relevant libpq files for $platform")
        copy_files(extracted, product_path)
        info("Archiving libpq files for $platform")
        archive(product_path)
        info("Done with $platform")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    make_tarballs(DOWNLOADS_DIR, PRODUCTS_DIR)
end
