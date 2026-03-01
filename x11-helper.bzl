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

def _copy_file(repository_ctx, src, dest):
    # Make a byte-for-byte copy using the host cp to avoid binary data going through Starlark strings.
    repository_ctx.execute([
        "mkdir",
        "-p",
        str(repository_ctx.path(dest).dirname),
    ])
    res = repository_ctx.execute([
        "cp",
        str(repository_ctx.path(src)),
        str(repository_ctx.path(dest)),
    ])
    if res.return_code:
        fail("copy failed: " + res.stderr)

def _copy_and_alias(repository_ctx, libs, target_name, alias_names):
    real = None
    for e in libs:
        if str(e).endswith(target_name):
            real = e
            break
    if real == None:
        real = libs[0]

    _copy_file(repository_ctx, real, target_name)
    for alias in alias_names:
        repository_ctx.symlink(target_name, alias)

    return [target_name] + alias_names

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

    if repository_ctx.os.name != 'linux':
        # Ideally we would leave this empty for non-Debian targets (or when we
        # do not want to use Debian binaries as a source of headers and
        # libraries). However, let's just create an empty repository for now,
        # only populating targets we offer with stubs.
        #
        # Under Windows, we don't want to do anything too complicated, since
        # running shell commands is tricky. Since we're not doing it on Windows,
        # we might as well skip it on other non-Linux OSes (e.g. macOS which
        # would likely be "mac os x" in the os name -- something that needs
        # verification).
        repository_ctx.report_progress("Skipping x11_deb repository on non-Linux OS")
        root = repository_ctx.path("usr")

        buildfile = '\n'.join([
            'cc_import(',
            '  name = "hdrs",',
            '  hdrs = [],',
            '  visibility = ["//visibility:public"],',
            ')',
            'cc_library(',
            '  name = "libs",',
            '  srcs = [],',
            '  visibility = ["//visibility:public"],',
            ')',
            'cc_import(',
            '  name = "' + repository_ctx.name + '",',
            '  hdrs = [],',
            '  visibility = ["//visibility:public"],',
            ')',
        ]) + '\n'
        repository_ctx.file("BUILD", buildfile)
        return

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
        extra_lib_deps.append('"@libx11-6//:libx11-6"')
        extra_lib_deps.append('"@libx11-6//:libX11"')

    if repository_ctx.name == "libxcb1-dev":
        extra_lib_deps.append('"@libxcb1//:libxcb1"')
        extra_lib_deps.append('"@libxcb1//:libxcb"')

    if repository_ctx.name == "libxau-dev":
        extra_lib_deps.append('"@libxau6//:libxau6"')
        extra_lib_deps.append('"@libxau6//:libXau"')

    if repository_ctx.name == "libxdmcp-dev":
        extra_lib_deps.append('"@libxdmcp6//:libxdmcp6"')
        extra_lib_deps.append('"@libxdmcp6//:libXdmcp"')

    if repository_ctx.name == "libgl-dev":
        extra_lib_deps.append('"@libgl1//:libgl1"')
        extra_lib_deps.append('"@libgl1//:libGL"')

    if repository_ctx.name == "libglu1-mesa-dev":
        extra_lib_deps.append('"@libglu1-mesa//:libglu1-mesa"')
        extra_lib_deps.append('"@libglu1-mesa//:libGLU"')

    if repository_ctx.name == "libgl1":
        extra_lib_deps.append('"@libglapi-mesa//:libglapi-mesa"')
        extra_lib_deps.append('"@libglapi-mesa//:libglapi"')

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

    if repository_ctx.name == "libx11-6":
        libs = _copy_and_alias(repository_ctx, libs, "libX11.so.6.3.0", ["libX11.so.6", "libX11.so"])

        r += 'cc_library(name="libX11", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb1":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb.so.1.1.0", ["libxcb.so.1", "libxcb.so"])

        r += 'cc_library(name="libxcb", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxau6":
        libs = _copy_and_alias(repository_ctx, libs, "libXau.so.6.0.0", ["libXau.so.6", "libXau.so"])

        r += 'cc_library(name="libXau", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxdmcp6":
        libs = _copy_and_alias(repository_ctx, libs, "libXdmcp.so.6.0.0", ["libXdmcp.so.6", "libXdmcp.so"])

        # deps from lddtree:
        # libbsd.so.0 => /lib/x86_64-linux-gnu/libbsd.so.0
        deps = [
            # "libbsd.so has a corrupt section with a size (c32884c383c2480a) larger than the file size"
            # Maybe it'll be in RBE. Let's try without it.
            # "@libbsd0//:libbsd",
        ]

        deps_str = ",".join([str('"' + e + '"') for e in deps])

        r += 'cc_library(name="libXdmcp", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], deps=[' + deps_str + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libx11-xcb1":
        libs = sorted([e for e in libs if "libX11-xcb.so" in str(e)], key = lambda e: len(str(e)), reverse = True)
        libs = _copy_and_alias(repository_ctx, libs, "libX11-xcb.so.1.0.0", ["libX11-xcb.so.1", "libX11-xcb.so"])

        r += 'cc_library(name="libx11-xcb", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libgl1":
        libs = _copy_and_alias(repository_ctx, libs, "libGL.so.1.7.0", ["libGL.so.1", "libGL.so"])

        r += 'cc_library(name="libGL", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"], deps=["@libglvnd0//:libGLdispatch"])\n'
        extra_lib_deps.append('"@libglvnd0//:libGLdispatch"')
        extra_lib_deps.append('"@libglx0//:libGLX"')

    if repository_ctx.name == "libglu1-mesa":
        libs = _copy_and_alias(repository_ctx, libs, "libGLU.so.1.3.1", ["libGLU.so.1", "libGLU.so"])

        r += 'cc_library(name="libGLU", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglvnd0":
        libs = _copy_and_alias(repository_ctx, libs, "libGLdispatch.so.0.0.0", ["libGLdispatch.so.0", "libGLdispatch.so"])

        # THIS DOES NOTHING: Our real problem is BuildBuddy's default platform is Ubuntu 16.04, so linking to GLIBC 2.34 is not going to happen.
        repository_ctx.file('dl_dummy.c', '#include <dlfcn.h>\n#include <gnu/lib-names.h>\nvoid unlikely_to_be_used_fn_name() {dlopen(LIBM_SO, RTLD_LAZY);}')
        r += 'cc_library(name="dl", srcs=["dl_dummy.c"], alwayslink=1, linkopts=["-ldl"])\n'
        r += 'cc_library(name="libGLdispatch", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], linkopts=["-ldl"], deps=[":dl"], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglx-mesa0":
        # expected that libs[0] will be libGLX_mesa.so.0{,.0.0}, not libGLX_indirect.so.0
        libs = [e for e in libs if 'libGLX_mesa' in str(e)]
        libs = _copy_and_alias(repository_ctx, libs, "libGLX_mesa.so.0.0.0", ["libGLX_mesa.so.0", "libGLX_mesa.so"])

        # deps from lddtree:
        # libdrm.so.2 => /lib/x86_64-linux-gnu/libdrm.so.2
        # libxcb-glx.so.0 => /lib/x86_64-linux-gnu/libxcb-glx.so.0
        # libX11-xcb.so.1 => /lib/x86_64-linux-gnu/libX11-xcb.so.1
        # libxcb-dri2.so.0 => /lib/x86_64-linux-gnu/libxcb-dri2.so.0
        # libXext.so.6 => /lib/x86_64-linux-gnu/libXext.so.6
        # libXfixes.so.3 => /lib/x86_64-linux-gnu/libXfixes.so.3
        # libXxf86vm.so.1 => /lib/x86_64-linux-gnu/libXxf86vm.so.1
        # libxcb-shm.so.0 => /lib/x86_64-linux-gnu/libxcb-shm.so.0
        # libexpat.so.1 => /lib/x86_64-linux-gnu/libexpat.so.1
        # libxcb-dri3.so.0 => /lib/x86_64-linux-gnu/libxcb-dri3.so.0
        # libxcb-present.so.0 => /lib/x86_64-linux-gnu/libxcb-present.so.0
        # libxcb-sync.so.1 => /lib/x86_64-linux-gnu/libxcb-sync.so.1
        # libxshmfence.so.1 => /lib/x86_64-linux-gnu/libxshmfence.so.1
        # libxcb-xfixes.so.0 => /lib/x86_64-linux-gnu/libxcb-xfixes.so.0
        deps = [
            "@libdrm2//:libdrm",
            "@libxcb-glx0//:libxcb-glx",
            "@libx11-xcb1//:libx11-xcb",
            "@libxcb-dri2-0//:libxcb-dri2",
            "@libxext6//:libXext",
            "@libxfixes3//:libXfixes",
            "@libxxf86vm1//:libXxf86vm",
            "@libxcb-shm0//:libxcb-shm",
            "@libexpat1//:libexpat",
            "@libxcb-dri3-0//:libxcb-dri3",
            "@libxcb-present0//:libxcb-present",
            "@libxcb-sync1//:libxcb-sync",
            "@libxshmfence1//:libxshmfence",
            "@libxcb-xfixes0//:libxcb-xfixes",
        ]

        deps_str = ",".join([str('"' + e + '"') for e in deps])

        r += 'cc_library(name="libGLX_mesa", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], deps=[' + deps_str + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libglx0":
        libs = [e for e in libs if 'libGLX.so.0.0.0' in str(e)]
        libs = _copy_and_alias(repository_ctx, libs, "libGLX.so.0.0.0", ["libGLX.so.0", "libGLX.so"])

        r += 'cc_library(name="libGLX", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"], deps=["@libglvnd0//:libGLdispatch", "@libglx-mesa0//:libGLX_mesa"])\n'

    if repository_ctx.name == "libglapi-mesa":
        libs = _copy_and_alias(repository_ctx, libs, "libglapi.so.0.0.0", ["libglapi.so.0", "libglapi.so"])

        r += 'cc_library(name="libglapi", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxext6":
        libs = _copy_and_alias(repository_ctx, libs, "libXext.so.6.4.0", ["libXext.so.6", "libXext.so"])
        r += 'cc_library(name="libXext", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxfixes3":
        libs = _copy_and_alias(repository_ctx, libs, "libXfixes.so.3.1.0", ["libXfixes.so.3", "libXfixes.so"])
        r += 'cc_library(name="libXfixes", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxxf86vm1":
        libs = _copy_and_alias(repository_ctx, libs, "libXxf86vm.so.1.0.0", ["libXxf86vm.so.1", "libXxf86vm.so"])
        r += 'cc_library(name="libXxf86vm", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-glx0":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-glx.so.0.0.0", ["libxcb-glx.so.0", "libxcb-glx.so"])
        r += 'cc_library(name="libxcb-glx", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-dri2-0":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-dri2.so.0.0.0", ["libxcb-dri2.so.0", "libxcb-dri2.so"])
        r += 'cc_library(name="libxcb-dri2", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-dri3-0":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-dri3.so.0.0.0", ["libxcb-dri3.so.0", "libxcb-dri3.so"])
        r += 'cc_library(name="libxcb-dri3", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-present0":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-present.so.0.0.0", ["libxcb-present.so.0", "libxcb-present.so"])
        r += 'cc_library(name="libxcb-present", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-sync1":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-sync.so.1.0.0", ["libxcb-sync.so.1", "libxcb-sync.so"])
        r += 'cc_library(name="libxcb-sync", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-xfixes0":
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-xfixes.so.0.0.0", ["libxcb-xfixes.so.0", "libxcb-xfixes.so"])
        r += 'cc_library(name="libxcb-xfixes", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxcb-shm0":
        libs = sorted([e for e in libs if "libxcb-shm.so" in str(e)], key = lambda e: len(str(e)), reverse = True)
        libs = _copy_and_alias(repository_ctx, libs, "libxcb-shm.so.0.0.0", ["libxcb-shm.so.0", "libxcb-shm.so"])
        r += 'cc_library(name="libxcb-shm", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libxshmfence1":
        libs = _copy_and_alias(repository_ctx, libs, "libxshmfence.so.1.0.0", ["libxshmfence.so.1", "libxshmfence.so"])
        r += 'cc_library(name="libxshmfence", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libdrm2":
        libs = _copy_and_alias(repository_ctx, libs, "libdrm.so.2.4.0", ["libdrm.so.2", "libdrm.so"])
        r += 'cc_library(name="libdrm", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libexpat1":
        libs = _copy_and_alias(repository_ctx, libs, "libexpat.so.1.6.0", ["libexpat.so.1", "libexpat.so"])
        r += 'cc_library(name="libexpat", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libbsd0":
        libs = _copy_and_alias(repository_ctx, libs, "libbsd.so.0.8.0", ["libbsd.so.0", "libbsd.so"])
        r += 'cc_library(name="libbsd", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

    if repository_ctx.name == "libmd0":
        libs = _copy_and_alias(repository_ctx, libs, "libmd.so.0.0.2", ["libmd.so.0", "libmd.so"])
        r += 'cc_library(name="libmd", srcs=[' + ",".join(['":' + str(e) + '"' for e in libs]) + '], visibility=["//visibility:public"])\n'

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
    #master_deb_hash = 'master.deb'
    master_deb_hash = "2aa9c52b29ce3afc08b95c43c8853f4a1dcfe6fc"

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
        name = "libx11-6",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libx11-6/libx11-6_2%253a1.6.9-2ubuntu1.6_amd64.deb"],
        sha256 = "20d7c0a8ea7a138d49d777a5db8e652071a3c47c78136450ec7417b5232b84ac",
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

    x11_deb_repository(
        name = "libxcb1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb1/libxcb1_1.14-2_amd64.deb"],
        sha256 = "3fcab5cc6a70bcb1e4157748f9c626be21bc18b4c8459447e4c213cba98b9831",
    )

    x11_deb_repository(
        name = "libxau6",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxau6/libxau6_1%253a1.0.9-0ubuntu1_amd64.deb"],
        sha256 = "58a0d78302a35e4584f96cd598af16b563ae7aae4af589e2a7cee6dc6666d979",
    )

    x11_deb_repository(
        name = "libxdmcp6",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxdmcp6/libxdmcp6_1%253a1.1.3-0ubuntu1_amd64.deb"],
        sha256 = "8a612b0fb60a41b92698f87258bc5ec6467da88e38d3de79411e02921c42af87",
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

    x11_deb_repository(
        name = "libglapi-mesa",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglapi-mesa/libglapi-mesa_21.2.6-0ubuntu0.1~20.04.2_amd64.deb"],
        sha256 = "30d27c6b71753bea3f144d91756ca440a9f7cf3842497a3af4cf228e615c15b2",
    )

    x11_deb_repository(
        name = "libx11-xcb1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libx11-xcb1/libx11-xcb1_2%253a1.6.9-2ubuntu1.6_amd64.deb"],
        sha256 = "da988703b47d7923d4bee2be97dd91b8225efaa70ea284e1bc84e025992c449f",
    )

    x11_deb_repository(
        name = "libxext6",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxext6/libxext6_2%253a1.3.4-0ubuntu1_amd64.deb"],
        sha256 = "a3c546490c0ae0f9247cf8f2919fc7b99b386a538ac91ae48a4ebb96a2a69834",
    )

    x11_deb_repository(
        name = "libxfixes3",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxfixes3/libxfixes3_1%253a5.0.3-2_amd64.deb"],
        sha256 = "ee3d380e5f825048a381fea92e8215bc65662fa4ce06346579fbaada2b1f7acc",
    )

    x11_deb_repository(
        name = "libxxf86vm1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxxf86vm1/libxxf86vm1_1%253a1.1.4-1build1_amd64.deb"],
        sha256 = "45f668e2bb605559261db4651348d4c248ee871610b541a076e4fc2f05807cc0",
    )

    x11_deb_repository(
        name = "libxcb-glx0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-glx0/libxcb-glx0_1.14-2_amd64.deb"],
        sha256 = "7c4b5d4a025a1ba37439a89dcf9f51ed031e038555759ce745072976b4f7b743",
    )

    x11_deb_repository(
        name = "libxcb-dri2-0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-dri2-0/libxcb-dri2-0_1.14-2_amd64.deb"],
        sha256 = "36fb1a063de7d5337887f0ca8e7a0f43ec0c82b3c022af439a6f896fa5a80535",
    )

    x11_deb_repository(
        name = "libxcb-dri3-0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-dri3-0/libxcb-dri3-0_1.14-2_amd64.deb"],
        sha256 = "d6df34fbf1b2cd584ad51839037e3da2b4131f239c6d1ef2cb41e6757fc5d48e",
    )

    x11_deb_repository(
        name = "libxcb-present0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-present0/libxcb-present0_1.14-2_amd64.deb"],
        sha256 = "fb608f5fbdd36ca851118754a990e55309f4cf538db17b7dd91eb117bc06ff5e",
    )

    x11_deb_repository(
        name = "libxcb-sync1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-sync1/libxcb-sync1_1.14-2_amd64.deb"],
        sha256 = "d79b16f888b16031cfc25bbf6f92b404f421d7965e625cede4825b15aa795e6e",
    )

    x11_deb_repository(
        name = "libxcb-xfixes0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-xfixes0/libxcb-xfixes0_1.14-2_amd64.deb"],
        sha256 = "9fbb1bbb105749359d99580bd388bcfec472cf3c6ff7f3b353ee78e61ec1bb81",
    )

    x11_deb_repository(
        name = "libxshmfence1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxshmfence1/libxshmfence1_1.3-1_amd64.deb"],
        sha256 = "f5fa812a85d8f4aa6b2760ba838ce9608297a2336b53e555efd3837b80d5dc10",
    )

    x11_deb_repository(
        name = "libdrm2",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libdrm2/libdrm2_2.4.107-8ubuntu1~20.04.2_amd64.deb"],
        sha256 = "9b01d73313841abe8e3f24c2715edced675fbe329bbd10be912a5b135cd51fb6",
    )

    x11_deb_repository(
        name = "libexpat1",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libexpat1/libexpat1_2.2.9-1ubuntu0.7_amd64.deb"],
        sha256 = "42dd972877a1212686846db5a9a78c3cecfc3da56249d3beecd53c4ff9d51453",
    )

    x11_deb_repository(
        name = "libbsd0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libbsd0/libbsd0_0.10.0-1_amd64.deb"],
        sha256 = "4f668025fe923a372eb7fc368d6769fcfff6809233d48fd20fc072917cd82e60",
    )

    x11_deb_repository(
        name = "libmd0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libmd0/libmd0_1.0.1-3_amd64.deb"],
        sha256 = "fe904769ee32a2250a40fce092a92c9ad0baaf34e1ae4a2c90f8c2a3d536a98d",
    )

    x11_deb_repository(
        name = "libxcb-shm0",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb-shm0/libxcb-shm0_1.14-2_amd64.deb"],
        sha256 = "776c691acd4fcdad314f0f09c98927a608cbc422007ce0f0c88e9d6711773217",
    )


def _x11_repository_rule_impl(ctx):
    primary_path = ctx.path(ctx.attr.primary_path)

    # Determine the path to use
    if primary_path.exists:
        actual_path = primary_path
    else:
        # Falls back to a dummy dir in the root of the workspace calling this rule.
        # 'x11_dummy' must exist in the helper root.
        helper_root = ctx.path(Label("@rules_libsdl12//:WORKSPACE")).dirname
        actual_path = helper_root.get_child(ctx.attr.dummy_path)  # ctx.path(ctx.attr.dummy_path)

    # Symlink the BUILD file provided in the attributes
    ctx.template("BUILD.bazel", ctx.attr.build_file)

    # Link the contents of the chosen directory into this external repo
    # This mimics what new_local_repository does under the hood
    if actual_path.exists:
        for item in actual_path.readdir():
            ctx.symlink(item, item.basename)
    else:
        # Create an empty file to ensure the repo is valid if path is missing
        ctx.file("empty.txt", "")


x11_repository_rule = repository_rule(
    implementation = _x11_repository_rule_impl,
    attrs = {
        "build_file":   attr.label(allow_single_file = True),
        "primary_path": attr.string(default = "/usr/include/X11"),
        "dummy_path":   attr.string(default = "x11_dummy"),
    },
)


def x11_repository():
    # We may be also be able to check 'defines = native.settings_user_defined_variables'
    # via 'is_deps_bin = defines.get("libsdl12_linux_deps_bin") == "true"' and simply
    # instantiate a differente repo.

    return x11_repository_rule(
        name = "x11repository",
        build_file = "@rules_libsdl12//:BUILD.x11helper",
        dummy_path = "x11_dummy",
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

# Dependencies loaded by the built binary:
# yatc => bazel-bin/yatc (interpreter => /lib64/ld-linux-x86-64.so.2)
#     libX11.so.6 => bazel-bin/_solib_k8/_U@libx11-6_S_S_ClibX11___U/libX11.so.6
#     libxcb.so.1 => /lib/x86_64-linux-gnu/libxcb.so.1
#     libXau.so.6 => /lib/x86_64-linux-gnu/libXau.so.6
#     libXdmcp.so.6 => /lib/x86_64-linux-gnu/libXdmcp.so.6
#         libbsd.so.0 => /lib/x86_64-linux-gnu/libbsd.so.0
#     libGL.so.1 => /lib/x86_64-linux-gnu/libGL.so.1
#     libglapi.so.0 => /lib/x86_64-linux-gnu/libglapi.so.0
#     libGLX.so.0 => /lib/x86_64-linux-gnu/libGLX.so.0
#     libGLdispatch.so.0 => /lib/x86_64-linux-gnu/libGLdispatch.so.0
#     libGLX_mesa.so.0 => /lib/x86_64-linux-gnu/libGLX_mesa.so.0
#         libdrm.so.2 => /lib/x86_64-linux-gnu/libdrm.so.2
#         libxcb-glx.so.0 => /lib/x86_64-linux-gnu/libxcb-glx.so.0
#         libX11-xcb.so.1 => /lib/x86_64-linux-gnu/libX11-xcb.so.1
#         libxcb-dri2.so.0 => /lib/x86_64-linux-gnu/libxcb-dri2.so.0
#         libXext.so.6 => /lib/x86_64-linux-gnu/libXext.so.6
#         libXfixes.so.3 => /lib/x86_64-linux-gnu/libXfixes.so.3
#         libXxf86vm.so.1 => /lib/x86_64-linux-gnu/libXxf86vm.so.1
#         libxcb-shm.so.0 => /lib/x86_64-linux-gnu/libxcb-shm.so.0
#         libexpat.so.1 => /lib/x86_64-linux-gnu/libexpat.so.1
#         libxcb-dri3.so.0 => /lib/x86_64-linux-gnu/libxcb-dri3.so.0
#         libxcb-present.so.0 => /lib/x86_64-linux-gnu/libxcb-present.so.0
#         libxcb-sync.so.1 => /lib/x86_64-linux-gnu/libxcb-sync.so.1
#         libxshmfence.so.1 => /lib/x86_64-linux-gnu/libxshmfence.so.1
#         libxcb-xfixes.so.0 => /lib/x86_64-linux-gnu/libxcb-xfixes.so.0
#     libGLU.so.1 => /lib/x86_64-linux-gnu/libGLU.so.1
#     libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2
#         ld-linux-x86-64.so.2 => /lib64/ld-linux-x86-64.so.2
#     libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6
#     libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6
#     libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1
#     libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0
#     libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
#
# We need to load system versions of libdl, libstdc++, libm, libgcc_s,
# libpthread, libc, libbsd even inside the remote build environment. The rest we
# need to include from Debian, as we can't expect it to be installed in RBE.

# Note to self:
# We could tell Bazel that a rule is running under Windows like so:
# some_rule_impl(name = name, src = src, is_windows = select({
#             "@bazel_tools//src/conditions:host_windows": True,
#             "//conditions:default": False,
#         }),
# See https://github.com/bazelbuild/bazel-skylib/blob/0171c69e5cc691e2d0cd9f3f3e4c3bf112370ca2/rules/private/copy_file_private.bzl
