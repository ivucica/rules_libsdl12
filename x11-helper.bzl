# -*- mode: python; -*-
# vim: set syntax=python:

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file", "http_archive")


def _removeprefix(s, pfx):
    if s.startswith(pfx):
        return s[len(pfx):]
    return s

def _recurse_collect_files(repository_ctx, root_dir): #, entries):
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
    out_path = repository_ctx.path('data.tar.xz')
    # label can't be used:
    # repository_ctx.path(Label('@' + repository_ctx.name + '//:data.tar.xz'))
    # but relative paths are supposed to work

    repository_ctx.report_progress('Unpacking ' + out_path.basename + ' from ' + deb_path.basename + ' using ar')
    res = repository_ctx.execute([
        repository_ctx.which('ar'),
        'x',
        #repository_ctx.path('@' + repository_ctx.name + '_deb//file:libx11-dev.deb'),
        #Label('@' + repository_ctx.name + '_deb//file:libx11-dev.deb'),
        #'../libx11-dev_deb/file/libx11-dev.deb', # <-- seems bad.
        deb_path,
        out_path.basename,
    ], working_directory=str(out_path.dirname), quiet=False)

    if res.return_code:
      fail('Unpacking failed: ' + res.stderr)
    repository_ctx.report_progress('Unpacking data from ' + out_path.basename + ' using native extract func')
    repository_ctx.extract(
        archive=out_path  # repository_ctx.path('@' + repository_ctx.name + '//:data.tar.xz')
    )

    # We care only about usr/{include,lib} for purposes of this rule.
    #root = repository_ctx.path('@' + repository_ctx.name + '//usr')
    root = repository_ctx.path('usr')
    hdrs, libs = _recurse_collect_files(repository_ctx, root) # .readdir())

    r = ''

    extra_lib_deps = []

    if repository_ctx.name == 'libx11-dev':
        # libX11 which we have insists on reallocarray, but it is not available in buildbuddy's environment.
        # http://lists.busybox.net/pipermail/buildroot/2022-May/643818.html
        # TODO: figure out a test for this at build-time
        repository_ctx.file('reallocarray-fix.c', '#include <stdlib.h>\nvoid* reallocarray(void *ptr, size_t nmemb, size_t size) { return realloc(ptr, nmemb * size); }')
        r += 'cc_library(name="reallocarray-fix", srcs=["reallocarray-fix.c"])\n'
        extra_lib_deps.append('":reallocarray-fix"')

    # Note: cc_import, cc_library etc have really interesting semantics and
    # the best way to do this should be checked.

    r += ('\n'.join(['cc_library(',
          '    name="hdrs",',
                     '    includes=[',  # if we used cc_library, these would be 'includes='; for cc_import, it's hdrs
          '        ' + ',\n        '.join(['":' + str(repository_ctx.path(e).dirname) + '"' for e in hdrs]) + '\n' +
          '    ],',
          '    visibility=["//visibility:public"],',
          ')\n']))

    if libs:
        r += ('\n'.join(['cc_library(',  # maybe cc_import here too?
              '    name="libs",',
              '    srcs=[',
              '        ' + ',\n        '.join(['":' + str(e) + '"' for e in libs]) + '\n' +
              '    ],',
              '    deps=[' + ','.join([l for l in extra_lib_deps]) + '],',
              '    visibility=["//visibility:public"],',
              ')\n']))

    r += ('\n'.join(['cc_import(',
          '    name="' + repository_ctx.name + '",',
                     '    hdrs=[',  # with cc_library, 'includes='.
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in hdrs]) + '\n' +
          '    ],'] + ([
          '    static_library=(', # =[',
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in libs if str(e).endswith('.a')]) + '\n' +
          '    ),', #],',
          #'    deps=[' + ','.join([l for l in extra_lib_deps]) + '],', # we can only do this if we have cc_library :(
          ] if libs else []) + [
          '    visibility=["//visibility:public"],',
          ')\n']))

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
        'paths_debug.tmp',
        '--output=' + str(repository_ctx.path('@' +
                                              repository_ctx.name +
                                              '//').dirname),)

    repository_ctx.file('BUILD', '\n'.join([
            # Remove this debug thing.
            'genrule(name="paths_debug", srcs=["paths_debug.tmp"],',
            '        outs=["paths_debug.txt"], cmd="cp $< $@")',
            r,
            #'genrule(name="data", srcs=["data.tar.xz"],',
            #'        outs=["data2.tar.xz"], cmd="cp $< $@")',
            # REPLACE this genrule with exports_files(["data.tar.xz"](
            #'genrule(name="data", srcs=["@' + repository_ctx.name + '_deb//file:file"],',
            #'        outs=["data.tar.xz"], cmd="echo ' + str(repository_ctx.which('ar')) + ' x $< data.tar.xz --output=$$(dirname $@) > $@")' # --output=' + str(repository_ctx.path('@' + repository_ctx.name + '//').dirname) + '")'

            '' # add final newline
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
    },)

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
        name=name,
        deb="@" + name + "_deb//file:" + name + ".deb"
    )


# x11_repository_deb adds all repos.
def x11_repository_deb():
    # master_deb_hash = 'master.deb'
    master_deb_hash = '7c16d8c2cc980f8366b3056a519cad93829542c6'

    x11_deb_repository(
        name="libx11-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" + master_deb_hash + "/libx11-dev/libx11-dev_2%253a1.8.4-2+deb12u2_amd64.deb"],
        sha256 = "8493220d4309af1907a1f2f6eeb204c8103dafcc368394fbc4a0858c28612ff9",
    )

    x11_deb_repository(
        name="libxext-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" + master_deb_hash + "/libxext-dev/libxext-dev_2%253a1.3.4-1%2Bb1_amd64.deb"],
        sha256 = "591456aba90eeed7a1c1b044d469fd7704bf7d83af9dc574bbe2efc4a2fd1dba",
    )

    x11_deb_repository(
        name="libgl-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" + master_deb_hash + "/libgl-dev/libgl-dev_1.6.0-1_amd64.deb"],
        sha256 = "ebc12df48ae53924e114d9358ef3da4306d7ef8f7179300af52f1faef8b5db3e",
    )

    x11_deb_repository(
        name="x11proto-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/" + master_deb_hash + "/x11proto-dev/x11proto-dev_2023.2-1_all.deb"],
        sha256 = "4b9a0df6ffa80436add5fe64c24dd68a3174dddc42c67f5c007835b674d21c59",
    )

    x11_deb_repository(
        name="libxrandr-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxrandr-dev/libxrandr-dev_2%3a1.5.2-2+b1_amd64.deb"],
        sha256="a0048d088226403419d9b0856e2d6d29a4facdd1708b6ceda095d7190f819ff3",
    )

    x11_deb_repository(
        name="libxrender-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxrender-dev/libxrender-dev_1%3a0.9.10-1.1_amd64.deb"],
        sha256="51be2e92b7bb9a81f8dbcad7a0086a58c779761c17f8aa13893b843bced0ae9b",
    )

    x11_deb_repository(
        name="libxcb1-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxcb1-dev/libxcb1-dev_1.15-1_amd64.deb"],
        sha256="c078c024114fdada06d3158af1771d7ed8763ab434cfbcbe6a334aa8a9cae358",
    )

    x11_deb_repository(
        name="libx11-xcb-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libx11-xcb-dev/libx11-xcb-dev_1.8.4-2+deb12u2_amd64.deb"],
        sha256="47e203c32aea08b81dc8fb3c25052b2431da184f7716b7d4ff92628dfe675534",
    )

    x11_deb_repository(
        name="libxau-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxau-dev/libxau-dev_1.0.9-1_amd64.deb"],
        sha256="d1a7f5d484e0879b3b2e8d512894744505e53d078712ce65903fef2ecfd824bb",
    )

    x11_deb_repository(
        name="libxdmcp-dev",
        urls=[
            "https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libxdmcp-dev/libxdmcp-dev_1.1.2-3_amd64.deb",
        ],
        sha256="c6733e5f6463afd261998e408be6eb37f24ce0a64b63bed50a87ddb18ebc1699",
    )

    # Not X11, but temporarily it is ok to have it live here.
    x11_deb_repository(
        name="libalsaplayer-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libalsaplayer-dev/libalsaplayer-dev_0.99.81-2+b3_amd64.deb"],
        sha256="c7be38adb91e8fcb809a17bb7deba4d8f2cd3b805d1c3a14ff491d6a3f332d03",
    )

    x11_deb_repository(
        name="libasound2-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libasound2-dev/libasound2-dev_1.2.8-1+b1_amd64.deb"],
        sha256="6eddd5b43c03cdd769f6b6f4506abcbc84c19d4bada2b3036d1fd921a9875d7a",
    )

    # X11 adjacent, temporarily it is ok to have it live here.
    x11_deb_repository(
        name="libgl-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libgl-dev/libgl-dev_1.6.0-1_amd64.deb"],
        sha256="ebc12df48ae53924e114d9358ef3da4306d7ef8f7179300af52f1faef8b5db3e",
    )

    x11_deb_repository(
        name="libglu1-mesa-dev",
        urls=["https://github.com/ivucica/rules_libsdl12/raw/" +  master_deb_hash + "/libglu1-mesa-dev/libglu1-mesa-dev_9.0.2-1.1_amd64.deb"],
        sha256="c58945175e46cf0465e8fd72e573f5728e2f42ca1ab5a275b34718c9c6ebf65e",
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
