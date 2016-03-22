#!/bin/bash

SCRIPT_PATH=$(dirname "$0")
cd "${SCRIPT_PATH}"
cd ..

for f in $(jurism-suite-tools/rdfcheck.py); do
    if [ "$f" == "zotero-odf-scan" ]; then
        continue
    fi
    LATEST=$(find $f/releases -type f -name '*-fx.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | grep -v beta | sort -r | head -1 | cut -d\  -f 2)
    FILENAME="$(echo basename "${LATEST}")"
    DIRNAME="$(echo dirname "${LATEST}")"
    if [ ! -d "zotero-standalone-build/modules" ]; then
        mkdir zotero-standalone-build/modules
    fi
    
done
