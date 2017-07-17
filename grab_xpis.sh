
#!/bin/bash

# Fetch most recent local XPIs

set -e


CALLDIR="$3"
if [ "" == "$3" ]; then
	echo "Third argument must be absolute path to dir in which to run this script."
	exit 1
fi
cd $CALLDIR
. "$CALLDIR/config.sh"

BUILD_DIR="$4"
if [ "" == "$4" ]; then
	echo "Fourth argument must be absolute path to build dir."
	exit 1
fi

set +e
gfind --version > /dev/null 2<&1
if [ $? -gt 0 ]; then
    GFIND="find"
else
    GFIND="gfind"
fi
set -e

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

    if [ ! -d "$CALLDIR/modules" ]; then
        mkdir "$CALLDIR/modules"
    fi
    rm -fR "$CALLDIR/modules"/*

    dirnames="$(cat <<-EOF
abbrevs-filter
bluebook-signals-for-zotero
jurism-libreoffice-integration
jurism-word-for-mac-integration
jurism-word-for-windows-integration
myles
zotero-odf-scan-plugin
zotero
EOF
)"

CONTAINER_DIR=$(dirname "$CALLDIR")

    for f in $dirnames; do
        echo "${f}"
        if [ "${f}" == "zotero" ]; then
            LOCAL_DIR="jurism"
        else
            LOCAL_DIR="${f}"
	        if [ ! -d "$CALLDIR/modules/${LOCAL_DIR}" ]; then
	            mkdir "$CALLDIR/modules/${LOCAL_DIR}"
       	    fi
        fi
        #rm -fR "zotero-standalone-build/modules/${LOCAL_DIR}"/*
        if [ "${WHENCE}" == "local" ]; then
            #LATEST=$(find "$CONTAINER_DIR/${LOCAL_DIR}"/releases -type f -name '*.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | grep -v 'beta' | sort -r | head -1 | cut -d\  -f 2)
            if [ "${LOCAL_DIR}" == "jurism" ]; then
	        LATEST="${CONTAINER_DIR}/jurism/build"
		echo "Building Jurism from ${LATEST}"
                cp -r "${LATEST}" -d "$BUILD_DIR/jurism"
	    else
	        LATEST=$(${GFIND} "$CONTAINER_DIR/${LOCAL_DIR}"/releases -type f -name '*.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | sort -r | head -1 | cut -d\  -f 2);
                unzip -q "${LATEST}" -d "$CALLDIR/modules/$LOCAL_DIR/"
            fi
        else
            echo "Sorry, -x local is the only functional source parameter."
            exit 1
	        echo "https://juris-m.github.io/${f}/update.rdf"
            URL=$(curl -s "https://juris-m.github.io/${f}/update.rdf" | grep -o ".*<em:updateLink>.*<\/em:updateLink>.*" | sed -e "s/.*<em:updateLink>//g" | sed -e "s/<\/em:updateLink>.*//g")
            cd "zotero-standalone-build/modules/${LOCAL_DIR}"
            echo "  ${URL} -> ${f}.xpi"
            curl -s -o "${f}.xpi" -L "${URL}"
            unzip -q "${f}.xpi"
            rm "${f}.xpi"
            cd ../../..
        fi
    done
fi
