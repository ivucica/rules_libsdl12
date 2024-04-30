# -*- mode: python; -*-
# vim: set syntax=python:

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

def _removeprefix(s, pfx):
    if s.startswith(pfx):
        return s[len(pfx):]
    return s

def dedup(lst):
    fakeset = {k: 1 for k in lst}
    return fakeset.keys()

def _recurse_collect_files(repository_ctx, root_dir):  #, entries):
    hdrs = []
    libs = []

    # recursion is banned in starlark, and glob does not exist
    #for e in entries:
    #    if len(e.readdir()): # e.is_dir():
    #        new_h, new_l = _recurse_collect_files(repository_ctx, e.readdir())
    #        hdrs.extend(new_h)
    #        libs.extend(new_l)
    #    elif e.basename().ends_with('.h'):
    #        hdrs.append(e)
    #    elif e.basename().ends_with('.a') or e.basename().ends_with('.so'):
    #        libs.append(e)  # is this right?

    res = repository_ctx.execute(["find", str(root_dir), "-type", "f", "-name", "*.h"])
    hdrs = [e for e in res.stdout.split("\n") if e]
    hdrs = [_removeprefix(_removeprefix(e, str(repository_ctx.path(".")) + "/"), "./") for e in hdrs]

    res = repository_ctx.execute(["find", str(root_dir), "-type", "f", "-and", "(", "-name", "*.a", "-or", "-name", "*.so", "-or", "-name", "*.so.*", ")"])
    libs = [e for e in res.stdout.split("\n") if e]
    libs = [_removeprefix(_removeprefix(e, str(repository_ctx.path(".")) + "/"), "./") for e in libs]

    return (hdrs, libs)

def _x11_deb_repository_rule_impl(repository_ctx):
    # path where the deb to unpack using ar will be found
    deb_path = repository_ctx.path(repository_ctx.attr.deb)  # label -> path

    # path where the named file will be unpacked the named file
    # we want it in the repo root's directory
    out_path = repository_ctx.path("data.tar.xz")
    # label can't be used:
    # repository_ctx.path(Label('@' + repository_ctx.name + '//:data.tar.xz'))
    # but relative paths are supposed to work

    repository_ctx.report_progress("Unpacking " + out_path.basename + " from " + deb_path.basename + " using ar")
    res = repository_ctx.execute([
        repository_ctx.which("ar"),
        "x",
        #repository_ctx.path('@' + repository_ctx.name + '_deb//file:libx11-dev.deb'),
        #Label('@' + repository_ctx.name + '_deb//file:libx11-dev.deb'),
        #'../libx11-dev_deb/file/libx11-dev.deb', # <-- seems bad.
        deb_path,
        out_path.basename,
    ], working_directory = str(out_path.dirname), quiet = False)

    if res.return_code:
        fail("Unpacking failed: " + res.stderr)
    repository_ctx.report_progress("Unpacking data from " + out_path.basename + " using native extract func")
    repository_ctx.extract(
        archive = out_path,  # repository_ctx.path('@' + repository_ctx.name + '//:data.tar.xz')
    )

    # We care only about usr/{include,lib} for purposes of this rule.
    #root = repository_ctx.path('@' + repository_ctx.name + '//usr')
    root = repository_ctx.path("usr")
    hdrs, libs = _recurse_collect_files(repository_ctx, root)  # .readdir())

    r = ""

    r += 'load("@rules_libsdl12//:x11-helper.bzl", "dedup")\n\n'

    extra_lib_deps = []

    repository_ctx.file("usr/include/dummy-" + repository_ctx.name + ".h", '/* dummy file, a hack to make "includes=" propagate the -isystem/-iquote/-I correctly */')
    repository_ctx.file("dummy-" + repository_ctx.name + ".h", '/* dummy file, a hack to make "includes=" propagate the -isystem/-iquote/-I correctly */')

    if repository_ctx.name == "libx11-dev":
        # libX11 which we have insists on reallocarray, but it is not available in buildbuddy's environment.
        # http://lists.busybox.net/pipermail/buildroot/2022-May/643818.html
        # TODO: figure out a test for this at build-time
        repository_ctx.file("reallocarray-fix.c", "#include <stdlib.h>\nvoid* reallocarray(void *ptr, size_t nmemb, size_t size) { return realloc(ptr, nmemb * size); }")
        r += 'cc_library(name="reallocarray-fix", srcs=["reallocarray-fix.c"])\n'
        extra_lib_deps.append('":reallocarray-fix"')

    if repository_ctx.name == "libgl-dev":
        extra_lib_deps.append('"@libgl1//:libgl1"')
        extra_lib_deps.append('"@libgl1//:libGL"')

    if repository_ctx.name == "libglu1-mesa-dev":
        extra_lib_deps.append('"@libglu1-mesa//:libglu1-mesa"')
        extra_lib_deps.append('"@libglu1-mesa//:libGLU"')

    if True:
        for e in hdrs:
            if str(repository_ctx.path(e)).startswith(str(repository_ctx.path("./usr/include"))):
                repository_ctx.report_progress("Creating symlink from " +
                                               _removeprefix(str(repository_ctx.path(e)), str(repository_ctx.path(".")) + "/") + " to " +
                                               _removeprefix(str(repository_ctx.path(e)), str(repository_ctx.path("./usr/include")) + "/"))

                # TODO: might not be needed:
                repository_ctx.execute([
                    "mkdir",
                    "-f",
                    _removeprefix(str(repository_ctx.path(e).dirname), str(repository_ctx.path(".")) + "/"),
                ])

                repository_ctx.symlink(
                    _removeprefix(str(repository_ctx.path(e)), str(repository_ctx.path(".")) + "/"),
                    _removeprefix(str(repository_ctx.path(e)), str(repository_ctx.path("./usr/include")) + "/"),
                )

    if repository_ctx.name == "libgl1":
        repository_ctx.file("libGL.so.1.7.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGL.so.1", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGL.so", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        libs = [
            "libGL.so",
            "libGL.so.1",
            "libGL.so.1.7.0",
        ]

        r += 'cc_library(name="libGL", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"], deps=["@libglvnd0//:libGLdispatch"])\n'
        extra_lib_deps.append('"@libglvnd0//:libGLdispatch"')
        extra_lib_deps.append('"@libglx0//:libGLX"')

    if repository_ctx.name == "libglu1-mesa":
        repository_ctx.file("libGLU.so.1.3.1", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLU.so.1", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLU.so", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        libs = [
            "libGLU.so",
            "libGLU.so.1",
            "libGLU.so.1.3.1",
        ]

        r += 'cc_library(name="libGLU", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglvnd0":
        repository_ctx.file("libGLdispatch.so.0.0.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLdispatch.so.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLdispatch.so", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        libs = [
            "libGLdispatch.so",
            "libGLdispatch.so.0",
            "libGLdispatch.so.0.0.0",
        ]

        # THIS DOES NOTHING: Our real problem is BuildBuddy's default platform is Ubuntu 16.04, so linking to GLIBC 2.34 is not going to happen.
        repository_ctx.file('dl_dummy.c', '#include <dlfcn.h>\n#include <gnu/lib-names.h>\nvoid unlikely_to_be_used_fn_name() {dlopen(LIBM_SO, RTLD_LAZY);}')
        r += 'cc_library(name="dl", srcs=["dl_dummy.c"], alwayslink=1, linkopts=["-ldl"])\n'
        r += 'cc_library(name="libGLdispatch", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], linkopts=["-ldl"], deps=[":dl"], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglx-mesa0":
        # expected that libs[0] will be libGLX_mesa.so.0{,.0.0}, not libGLX_indirect.so.0
        libs = [e for e in libs if 'libGLX_mesa' in str(e)]
        repository_ctx.file("libGLX_mesa.so.0.0.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLX_mesa.so.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLX_mesa.so", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        libs = [
            "libGLX_mesa.so",
            "libGLX_mesa.so.0",
            "libGLX_mesa.so.0.0.0",
        ]

        r += 'cc_library(name="libGLX_mesa", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglx0":
        libs = [e for e in libs if 'libGLX.so.0.0.0' in str(e)]
        repository_ctx.file("libGLX.so.0.0.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLX.so.0", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        repository_ctx.file("libGLX.so", repository_ctx.read(libs[0]), executable = False, legacy_utf8 = False)
        libs = [
            "libGLX.so",
            "libGLX.so.0",
            "libGLX.so.0.0.0",
        ]

        r += 'cc_library(name="libGLX", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"], deps=["@libglvnd0//:libGLdispatch", "@libglx-mesa0//:libGLX_mesa"])\n'



    # Note: cc_import, cc_library etc have really interesting semantics and
    # the best way to do this should be checked.

    if hdrs:
        r += ("\n".join([
            "cc_library(",
            '    name="hdrs",',
            "    includes=dedup([",  # if we used cc_library, these would be 'includes='; for cc_import, it's hdrs
            # Do NOT use labels / colons in cc_library includes=.
            '        ".",',
            '        "usr/include",',
            #'        "usr/include/dummy-' + repository_ctx.name + '.h",\n' +
            #'        "dummy-' + repository_ctx.name + '.h",\n' +
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname), str(repository_ctx.path(".")) + "/") + '"' for e in hdrs]) + ",\n" +
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname.dirname), str(repository_ctx.path(".")) + "/") + '"' for e in hdrs]) + ",\n" +
            #'        ' + ',\n        '.join(['"' + str(e) + '"' for e in hdrs]) + ',\n' +
            #"        " + ",\n        ".join(['"' + _removeprefix(str(e), "usr/include") + '"' for e in hdrs]) + ",\n" +
            "    ]),",
            '    visibility=["//visibility:public"],',
            ")\n",
        ]))

    if libs or extra_lib_deps:
        r += ("\n".join([
            "cc_library(",  # maybe cc_import here too?
            '    name="libs",',
        ] + ([
            "    srcs=dedup([",
            "        " + ",\n        ".join(['":' + str(e) + '"' for e in libs]) + "\n" +
            "    ]),",
        ] if libs else []) + [
            "    deps=[" + ",".join([l for l in extra_lib_deps]) + "],",
            "    includes=dedup([",
            '        ".",\n',
            '        "usr/include",\n',  # /dummy-' + repository_ctx.name + '.h",\n',
            '        # ":dummy-' + repository_ctx.name + '.h",\n',
        ] + ([
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname), str(repository_ctx.path(".")) + "/") + '"' for e in hdrs]) + ",\n",
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname.dirname), str(repository_ctx.path(".")) + "/") + '"' for e in hdrs]) + ",\n",
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname), str(repository_ctx.path("usr/include")) + "/") + '"' for e in hdrs]) + ",\n",
            "        " + ",\n        ".join(['"' + _removeprefix(str(repository_ctx.path(e).dirname.dirname), str(repository_ctx.path("usr/include")) + "/") + '"' for e in hdrs]) + ",\n",
            #'        ' + ',\n        '.join(['"' + str(e) + '"' for e in hdrs]) + ',\n',
            #'        ' + ',\n        '.join(['"' + _removeprefix(str(e), "usr/include/") + '"' for e in hdrs]) + ',\n',
        ] if hdrs else []) + [
            "    ]),",
            '    visibility=["//visibility:public"],',
            ")\n",
        ]))

    static_libs = [e for e in libs if str(e).endswith(".a")]

    r += ("\n".join([
        "cc_import(",
        '    name="' + repository_ctx.name + '",',
    ] + ([
        # Do NOT use labels / colons in cc_import's hdrs!
        "    hdrs=dedup([",  # with cc_library, 'includes='.
        '        "usr/include/dummy-' + repository_ctx.name + '.h",\n',
        '        "dummy-' + repository_ctx.name + '.h",\n',
        "        " + ",\n        ".join(['"' + _removeprefix(str(e), "usr/include/") + '"' for e in hdrs]) + ",\n",
        "        " + ",\n        ".join(['"' + _removeprefix(str(e), "/") + '"' for e in hdrs]) + "\n" +
        "    ]),",
    ] if hdrs else []) + ([
        "    static_library=(",  # =[',
        "        " + ",\n        ".join(['":' + str(e) + '"' for e in static_libs]) + "\n" +
        "    ),",  #],',
        #'    deps=[' + ','.join([l for l in extra_lib_deps]) + '],', # we can only do this if we have cc_library :(
    ] if static_libs else []) + [
        '    visibility=["//visibility:public"],',
        ")\n",
    ]))

    # Try a hack to make system headers like /usr/include/X11/Xlib.h visible.
    # (This does not really make an effort to make pkg-config files etc visible.
    # Maybe use data= attribute?)
    #for e in hdrs:
    #    repository_ctx.symlink(e, _removeprefix(str(e), 'usr/include/')) # bad: needs to ignore files in usr/share/doc (as do other places)
    #for e in libs:
    #    repository_ctx.symlink(e, _removeprefix(
    #        _removeprefix(str(e), 'usr/lib/x86_64-linux-gnu/'),
    #        'usr/lib/'))

    repository_ctx.file(
        "paths_debug.tmp",
        "--output=" + str(repository_ctx.path("@" +
                                              repository_ctx.name +
                                              "//").dirname),
    )

    repository_ctx.file("BUILD", "\n".join([
        # Remove this debug thing.
        'genrule(name="paths_debug", srcs=["paths_debug.tmp"],',
        '        outs=["paths_debug.txt"], cmd="cp $< $@")',
        r,
        #'genrule(name="data", srcs=["data.tar.xz"],',
        #'        outs=["data2.tar.xz"], cmd="cp $< $@")',
        # REPLACE this genrule with exports_files(["data.tar.xz"](
        #'genrule(name="data", srcs=["@' + repository_ctx.name + '_deb//file:file"],',
        #'        outs=["data.tar.xz"], cmd="echo ' + str(repository_ctx.which('ar')) + ' x $< data.tar.xz --output=$$(dirname $@) > $@")' # --output=' + str(repository_ctx.path('@' + repository_ctx.name + '//').dirname) + '")'
        "",  # add final newline
    ]))

# Debian binary package that is a source for the X11 headers and libs.
# Useful for remote builds where the local files might not be installed.
# Useful only for Linux systems.
#
# Not a macro because we need ctx to expand location.
_x11_deb_repository_rule = repository_rule(
    implementation = _x11_deb_repository_rule_impl,
    attrs = {
        # "deps": attr.label_list(),
        "deb": attr.label(),
    },
)

# x11_deb_repository creates one repo from a deb. (x11_ prefix is superfluous.)
def x11_deb_repository(name, urls, sha256):
    #http_archive(
    http_file(
        name = name + "_deb",
        urls = urls,
        sha256 = sha256,
        # http_archive with type = "ar" and type = "deb" are supported only from Bazel 5.2 onwards.
        # workaround: unpack x11bin_deb//file:file / x11bin_deb//file:libx11-dev.deb.
        downloaded_file_path = name + ".deb",
    )

    #http_archive(
    #  build_file = "@rules_libsdl12//:BUILD.x11helperdeb",
    #  name = "x11bin_tarxz",
    #  # ...............??? how to expand location of data.tar.xz if we can't put this repository_rule() inside a rule's impl?
    #  url = repository_ctx.expand_location("file://$(location @x11bin_deb//:data.tar.xz)"),
    #)

    _x11_deb_repository_rule(
        name = name,
        deb = "@" + name + "_deb//file:" + name + ".deb",
    )

# x11_repository_deb adds all repos.
def x11_repository_deb():
    master_deb_hash = 'master.deb'
    #master_deb_hash = "8a3188cd87e2961b0f8db2015e7e5d40c345a3ad"

    x11_deb_repository(
        name = "libx11-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libx11-dev/libx11-dev_2%253a1.6.9-2ubuntu1.6_amd64.deb"],
        sha256 = "dfdc060c5550fbffefbead0976a8bb89ac3bbb80b80878fdfc06df26860fbc23",
    )

    x11_deb_repository(
        name = "libxext-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxext-dev/libxext-dev_2%253a1.3.4-0ubuntu1_amd64.deb"],
        sha256 = "b39e2d033916a4e2c1e970465517e285c3e532d3e2f451b720e67ba09cbb2733",
    )

    x11_deb_repository(
        name = "x11proto-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/x11proto-dev/x11proto-dev_2019.2-1ubuntu1_all.deb"],
        sha256 = "4144072931cbfbb422b465ae4775ce906d01ea816d432ed820b301e08cfef975",
    )

    x11_deb_repository(
        name = "libxrender-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxrender-dev/libxrender-dev_1%253a0.9.10-1_amd64.deb"],
        sha256 = "aeb7abe8409afbb484c06882c158e7e695743d678387064ef95bdb3d6edbce15",
    )

    x11_deb_repository(
        name = "libxcb1-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb1-dev/libxcb1-dev_1.14-2_amd64.deb"],
        sha256 = "824b00562519ccfdd9dd5faa58bbc5cb60b7a6b4eea09eca58c989bd921f88d5",
    )

    x11_deb_repository(
        name = "libxrandr-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxrandr-dev/libxrandr-dev_2%253a1.5.2-0ubuntu1_amd64.deb"],
        sha256 = "8e3d54f0605a4aa192d8413ed0f3e2c82dff606b81499710208190cd965a31f2",
    )

    x11_deb_repository(
        name = "libxau-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxau-dev/libxau-dev_1%253a1.0.9-0ubuntu1_amd64.deb"],
        sha256 = "61d3505d0db08c398e91ca5b51f928aa5dbb4d384ccfa2e5c6f0419a57ecf524",
    )

    x11_deb_repository(
        name = "libx11-xcb-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libx11-xcb-dev/libx11-xcb-dev_2%253a1.6.9-2ubuntu1.6_amd64.deb"],
        sha256 = "93fdbd64619ace78387946ccdec07c88294015aa8b3052cd2c3a6b28ce21e239",
    )

    x11_deb_repository(
        name = "libxdmcp-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxdmcp-dev/libxdmcp-dev_1%253a1.1.3-0ubuntu1_amd64.deb"],
        sha256 = "977cb912f49638434a2bdb8947ac44897f25e5552448576c7d7a5f9a0d9bf1a3",
    )

    x11_deb_repository(
        name = "xorg-sgml-doctools",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/xorg-sgml-doctools/xorg-sgml-doctools_1%253a1.11-1_all.deb"],
        sha256 = "2f6463489813c2a08e077a6502453c3252453f7cbdab9f323006e081b33e7ad3",
    )

    # Not X11, but temporarily it is ok to have it live here.
    x11_deb_repository(
        name = "libalsaplayer-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libalsaplayer-dev/libalsaplayer-dev_0.99.81-2build2_amd64.deb"],
        sha256 = "ffb8cf7209bf7c111e4d28c5704df8c58223a69c12799a603d39727ce67b0763",
    )

    x11_deb_repository(
        name = "libasound2-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libasound2-dev/libasound2-dev_1.2.2-2.1ubuntu2.5_amd64.deb"],
        sha256 = "f10cbb3ccdab80e162e64255e3dfe1e04b02fe1d59d082a7a3d760f0623da9dc",
    )

    # X11 adjacent, temporarily it is ok to have it live here.
    x11_deb_repository(
        name = "libgl-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libgl-dev/libgl-dev_1.3.2-1~ubuntu0.20.04.2_amd64.deb"],
        sha256 = "435e6e224ac2c4a15f4f5409bd35f776d195ab08a86475ae7933af005e392c71",
    )

    x11_deb_repository(
        name = "libglu1-mesa-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglu1-mesa-dev/libglu1-mesa-dev_9.0.1-1build1_amd64.deb"],
        sha256 = "abeb351931541392d0dee175d5effb0f35bc2728ec037360c2392555c4c60ac6",
    )

    x11_deb_repository(
        name = "libgl1",  # libgl-dev's libGL.so is a symlink to an .so shipped in this package
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libgl1/libgl1_1.3.2-1~ubuntu0.20.04.2_amd64.deb"],
        sha256 = "bf37a7087ce67518b0d1e377c9058ef19db431599cec653a743e8379fa1a4a37",
    )

    x11_deb_repository(
        name = "libglu1-mesa",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglu1-mesa/libglu1-mesa_9.0.1-1build1_amd64.deb"],
        sha256 = "3db22def57927f3d11d676e7160856a723fa8c3553b76971327de5b707c86973",
    )

    x11_deb_repository(
        name = "libglvnd0",  # required at runtime for libgl
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglvnd0/libglvnd0_1.3.2-1~ubuntu0.20.04.2_amd64.deb"],
        sha256 = "df7ebdaef90e7e912147f5dd2f6568759b9111890b61936443a8b1fde1982655",
    )

    x11_deb_repository(
        name = "libglx-mesa0",  # required at runtime for libglx0
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglx-mesa0/libglx-mesa0_21.2.6-0ubuntu0.1~20.04.2_amd64.deb"],
        sha256 = "b8f2bef5e58bf22b1a1b1b12618d717f71681c91f53525e872d7cf578d079b61",
    )

    x11_deb_repository(
        name = "libglx0",  # required at runtime for libgl
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglx0/libglx0_1.3.2-1~ubuntu0.20.04.2_amd64.deb"],
        sha256 = "2620a3da6755af5df028a6f48c56e754ce90eef58c201dc9a289d5736eaad0c4",
    )


def x11_repository():
    return native.new_local_repository(
        name = "x11repository",
        build_file = "@rules_libsdl12//:BUILD.x11helper",
        path = "/usr/include/X11",
    )

def xcb_repository():
    return native.new_local_repository(
        name = "xcbrepository",
        build_file_content = "\n".join([
            "exports_files(glob(['xcb/**']), ",
            "              visibility = ['//visibility:public'])",
        ]),
        path = "/usr/include",
    )
