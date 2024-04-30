Archive of Ubuntu's .deb binary packages (and sources to comply with any
possible license requirements) required for Bazel rules for libsdl1.2 to
work.

This is done in a separate branch to avoid ballooning the size of the
code branch.

These are currently Ubuntu 20.04 (focal) binaries, where possibly
some source packages are missing by accident. See <fetch-log.html>.

Log has been generated using:

```bash
./fetch.sh | tee fetch-log.txt
yarnpkg global install ansi-to-html
~/.yarn/bin/ansi-to-html fetch-log.txt > fetch-log.html
```
