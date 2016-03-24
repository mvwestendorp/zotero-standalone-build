#!/bin/bash

MODE="unknown"

function usage() {
    echo "grab_xpis.sh accepts only 100, 010 or 001 as argument, \"$1\" seen"
    exit 1
}

case $1 in
    100)
        MODE="linux"
        
        ;;
    010)
        MODE="mac"
        ;;
    001)
        MODE="win"
        ;;
    *)
        usage $1
        ;;
esac

SCRIPT_PATH=$(dirname "$0")
cd "${SCRIPT_PATH}"
cd ..

if [ ! -d "zotero-standalone-build/modules" ]; then
    mkdir zotero-standalone-build/modules
fi
rm -fR "zotero-standalone-build/modules"/*

for f in $(jurism-suite-tools/rdfcheck.py); do
    if [ "$f" == "zotero-odf-scan" ]; then
        continue
    fi
    #if [ "${MODE}" != "linux" -a "$f" == "jurism-libreoffice-integration" ]; then
    #    continue
    #fi
    if [ "${MODE}" != "mac" -a "$f" == "jurism-word-for-mac-integration" ]; then
        continue
    fi
    if [ "${MODE}" != "win" -a "$f" == "jurism-word-for-windows-integration" ]; then
        continue
    fi
    if [ "$f" == "propachi-upper" ]; then
        continue
    fi
    if [ "$f" == "propachi-vanilla" ]; then
        continue
    fi
    LATEST=$(find $f/releases -type f -name '*-fx.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | grep -v 'beta' | sort -r | head -1 | cut -d\  -f 2)
    FILENAME="$(basename "${LATEST}")"
    echo "${FILENAME}"
    DIRNAME="$(dirname "${LATEST}")"
    if [ ! -d "zotero-standalone-build/modules/${f}" ]; then
        mkdir "zotero-standalone-build/modules/${f}"
    fi
    rm -fR "zotero-standalone-build/modules/${f}"/*
    cp "${DIRNAME}/${FILENAME}" "zotero-standalone-build/modules/${f}"
    cd "zotero-standalone-build/modules/${f}"
    unzip -q "${FILENAME}"
    rm "${FILENAME}"
    cd ../../..
done
