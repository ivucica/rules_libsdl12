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

    res = repository_ctx.execute(["find", str(root_dir), "-type", "f", "-and", "(", "-name", "*.a", "-or", "-name", "*.so", ")"])
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
        '--output=' + str(out_path.dirname),
        ''
    ], quiet=False)

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

    # Note: cc_import, cc_library etc have really interesting semantics and
    # the best way to do this should be checked.

    r += ('\n'.join(['cc_import(',
          '    name="hdrs",',
                     '    hdrs=[',  # if we used cc_library, these would be 'includes='
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in hdrs]) + '\n' +
          '    ],',
          '    visibility=["//visibility:public"],',
          ')\n']))

    r += ('\n'.join(['cc_library(',  # maybe cc_import here too?
          '    name="libs",',
          '    srcs=[',
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in libs]) + '\n' +
          '    ],',
          '    visibility=["//visibility:public"],',
          ')\n']))

    r += ('\n'.join(['cc_import(',
          '    name="' + repository_ctx.name + '",',
                     '    hdrs=[',  # with cc_library, 'includes='.
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in hdrs]) + '\n' +
          '    ],',
          '    static_library=(', # =[',
          '        ' + ',\n        '.join(['":' + str(e) + '"' for e in libs]) + '\n' +
          '    ),', #],',
          '    visibility=["//visibility:public"],',
          ')\n']))


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
    x11_deb_repository(
        name="libx11-dev",
        urls = ["https://github.com/ivucica/rules_libsdl12/raw/master.deb/libx11-dev/libx11-dev_2%253a1.8.4-2+deb12u2_amd64.deb"],
        sha256 = "8493220d4309af1907a1f2f6eeb204c8103dafcc368394fbc4a0858c28612ff9",
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
