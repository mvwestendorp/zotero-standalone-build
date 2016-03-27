#!/bin/bash

# Fetch most recent local XPIs

MODE="unknown"

function usage() {
    echo "grab_xpis.sh accepts 100, 010 or 001 as first argument, and local or remote as second"
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

WHENCE=$2

if [ "${WHENCE}" != "local" -a "${WHENCE}" != "remote" -a "${WHENCE}" != "none" ]; then
    usage
    exit 1
fi

if [ "${WHENCE}" != "none" ]; then

    SCRIPT_PATH=$(dirname "$0")
    cd "${SCRIPT_PATH}"
    cd ..

    if [ ! -d "zotero-standalone-build/modules" ]; then
        mkdir zotero-standalone-build/modules
    fi
    rm -fR "zotero-standalone-build/modules"/*

    dirnames="$(cat <<-EOF
zotero
abbrevs-filter
bluebook-signals-for-zotero
jurism-libreoffice-integration
jurism-word-for-mac-integration
jurism-word-for-windows-integration
myles
zotero-odf-scan-plugin
EOF
)"


    for f in $dirnames; do
        if [ "${f}" == "zotero" ]; then
            LOCAL_DIR="jurism"
        else
            LOCAL_DIR="${f}"
        fi
        if [ ! -d "zotero-standalone-build/modules/${LOCAL_DIR}" ]; then
            mkdir "zotero-standalone-build/modules/${LOCAL_DIR}"
        fi
        rm -fR "zotero-standalone-build/modules/${LOCAL_DIR}"/*
        if [ "${WHENCE}" == "local" ]; then
            LATEST=$(find "${LOCAL_DIR}"/releases -type f -name '*.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | grep -v 'beta' | sort -r | head -1 | cut -d\  -f 2)
            FILENAME="$(basename "${LATEST}")"
            echo "${FILENAME}"
            DIRNAME="$(dirname "${LATEST}")"
            cp "${DIRNAME}/${FILENAME}" "zotero-standalone-build/modules/${LOCAL_DIR}"
            cd "zotero-standalone-build/modules/${LOCAL_DIR}"
            unzip -q "${FILENAME}"
            rm "${FILENAME}"
            cd ../../..
        else
            URL=$(curl -s "https://juris-m.github.io/${f}/update.rdf" | grep -o ".*<em:updateLink>.*<\/em:updateLink>.*" | sed -e "s/\(.*<em:updateLink>\|<\/em:updateLink>.*\)//g")
            cd "zotero-standalone-build/modules/${f}"
            echo "${f}.xpi"
            echo "  ${URL}"
            echo "  $(pwd)"
            curl -s -o "${f}.xpi" -L "${URL}"
            unzip "${f}.xpi"
            rm "${f}.xpi"
            cd ../../..
        fi
    done
fi
