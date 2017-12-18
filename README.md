# Bazel rules for libsdl12

This repository contains a rule to download, unpack and build SDL 1.2

## Caveat

At this time, due to the hacky way to apply some patches, these rules can only
be executed while sandboxed. Otherwise, the compiler can see the unpatched
files that it should not otherwise see.

## Building

### Linux, macOS

Both Linux and OS X have been set up so that running Bazel should work out of
the box, assuming dependencies have been installed.

Try building an example:

    bazel build //example/simple:simple

### Windows MSVC

Bazel expects you to tell it where MSVC is and where MSYS Bash is, so let's use
a wrapper script.

1.  Download Bazel executable into a known folder. For instance,
    `E:\Downloads\bazel-0.8.1-windows-x86_64.exe`.
1.  Install MSVC. This has been tested with MSVC 2017 Community Edition.
1.  Add `~/bin` to your `PATH` (`export PATH="$PATH":"${HOME}"/bin`; for future
    sessions add it to `~/.bashrc` too).
1.  Then put the following into `~/bin/bazel`:

    ```
    #!/bin/bash
    # Based on https://superuser.com/a/539680 + searching around registry.
    # Finds MSVS2017.
    # Slashes when invoking 'reg query' are replaced with dashes because MSYS2.
    VSPATH="$(cygpath -u "$(reg query 'HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7' -v 15.0 | tail -n+3 | head -n1  | awk '{for (i=3;i<=NF;i++) {printf "%s ",$i;};}' | sed 's/ *$//')")"

    export BAZEL_SH="$(cygpath -w /usr/bin/bash)"
    export BAZEL_VS="$VSPATH"
    /e/Downloads/bazel-0.8.1-windows-x86_64.exe $@
    ```

Try invoking Bazel with MSVC compiler:

    bazel build --cpu=x64_windows_msvc --host_cpu=x64_windows_msvc //example/simple:simple

### Windows MSYS

Not supported yet.

## Dependencies

List of external, systemwide dependencies. May be incomplete.

### Linux

You need to have X11 libraries and development headers.

For instance:

*   `libx11-dev`
*   `libxext-dev`
*   `libxrandr-dev`
*   `libxrender-dev`

### macOS

Even though Quartz (native) UI is built, build process still requires you to
have X11 installed. Please install XQuartz.

### Windows MSVC

Tested with MSVC2017 and msys64.

Otherwise, no fixed path for external dependencies is expected.

### Windows MSYS

Not supported yet.
