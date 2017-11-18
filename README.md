# Bazel rules for libsdl12

This repository contains a rule to download, unpack and build SDL 1.2

## Caveat

At this time, due to the hacky way to apply some patches, these rules can only
be executed while sandboxed. Otherwise, the compiler can see the unpatched
files that it should not otherwise see.

## Dependencies

List of external, systemwide dependencie. May be incomplete.

### X11

You need to have X11 libraries and development headers.

For instance:

*   `libx11-dev`
*   `libxext-dev`
*   `libxrandr-dev`
*   `libxrender-dev`
