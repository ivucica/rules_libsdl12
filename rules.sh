#!/bin/bash

find . -type f -not -path '*/.git/*' -name '*.deb' | xargs -i bash -c "echo '    x11_deb_repository('; echo '        name=\"'\$(dirname {} | sed s@^./@@)'\",'; echo '        urls=[\"https://github.com/ivucica/rules_libsdl12/raw/\" +  master_deb_hash + \"/'\$(echo {} | sed s@^./@@)'\"],'; echo '        sha256=\"'\$(sha256sum {} | cut -d' ' -f1)'\",'; echo '    )'; echo ''"

