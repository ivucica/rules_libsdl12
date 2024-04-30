#!/bin/bash

find . -type f -not -path '*/.git/*' -name '*.deb' | xargs -i bash -c "echo '    x11_deb_repository('; echo '        name = \"'\$(dirname {} | sed s@^./@@)'\",'; echo '        urls = [\"https://github.com/ivucica/rules_libsdl12/raw/\" +  master_deb_hash + \"/'\$(echo -n {} | sed s@^./@@ | cut -d'/' -f 1)/\$(echo -n \$(echo -n {} | sed s@^./@@ | cut -d'/' -f2) | jq -sRr @uri)'\"],'; echo '        sha256 = \"'\$(sha256sum {} | cut -d' ' -f1)'\",'; echo '    )'; echo ''"

