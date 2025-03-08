# -*- mode: python; -*-
# vim: set syntax=python:

load("//:x11-helper.bzl", "x11_repository", "xcb_repository", "x11_repository_deb")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")


def libsdl12_repositories():
    http_archive(
            name = "libsdl12",
            url = "http://www.libsdl.org/release/SDL-1.2.15.tar.gz",
            sha256 = "d6d316a793e5e348155f0dd93b979798933fb98aa1edebcc108829d6474aad00",
            strip_prefix = "SDL-1.2.15/",

            # TODO(ivucica): cannot grab from VCS: no ./configure
            #url = "http://hg.libsdl.org/SDL/archive/0c1a8b0429a9.tar.gz",
            #sha256 = "f4be8ec4c1f465438b90395bf370ab7cb39fb3ffff9fc46f8f3941100de6acee",
            #strip_prefix = "SDL-0c1a8b0429a9",

            type = "tar.gz",
            build_file = "@rules_libsdl12//:BUILD.libsdl12",
    )

    x11_repository()
    xcb_repository()

    x11_repository_deb()


# 1. Using https://bazel.build/rules/lib/repo/utils#maybe macro we could add a repository only if it is not already present.
# 2. Excluding based on OS could be done via:
#    _repository_select = repository_rule(
#        _repository_select_impl,
#        attrs = {},
#    )
#    def _repository_select_impl(ctx):
#        if ctx.os.name == "linux" or ctx.os.name = "mac os x":
#            # ...
#    See https://github.com/improbable-io/rules_go/blob/adfad77dabd529ed9d90a4e7b823323628e908d9/go/private/go_repositories.bzl#L147
#
#    However, the repos still need to exist even if only referenced in select()s in actual build targets (e.g. to link with libglu1-mesa-dev).
#
#    Let's instead do this in x11-helper.bzl for now.
