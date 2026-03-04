# -*- mode: python; -*-
# vim: set syntax=python:

"""Module extensions for rules_libsdl12.

Provides a module extension so that Bzlmod users can set up the SDL 1.2
repositories without calling libsdl12_repositories() from their WORKSPACE.

Usage in MODULE.bazel:
    bazel_dep(name = "rules_libsdl12", version = "...")
    libsdl12 = use_extension("@rules_libsdl12//:extensions.bzl", "libsdl12")
    use_repo(libsdl12, "libsdl12", "x11repository", "xcbrepository")
"""

load("//:libsdl12.bzl", "libsdl12_repositories")

def _libsdl12_extension_impl(module_ctx):
    libsdl12_repositories()

libsdl12 = module_extension(
    implementation = _libsdl12_extension_impl,
)
