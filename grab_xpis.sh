
#!/bin/bash

# Fetch most recent local XPIs

set +e
gsed --version > /dev/null 2<&1
if [ $? -gt 0 ]; then
    GSED="sed"
else
    GSED="gsed"
fi
gfind --version > /dev/null 2<&1
if [ $? -gt 0 ]; then
    GFIND="find"
else
    GFIND="gfind"
fi
set -e

CALLDIR="$2"
if [ "" == "$2" ]; then
	echo "Second argument must be absolute path to dir in which to run this script."
	exit 1
fi
cd $CALLDIR
. "$CALLDIR/config.sh"

BUILD_DIR="$3"
if [ "" == "$3" ]; then
	echo "Third argument must be absolute path to build dir."
	exit 1
fi

MODE="unknown"

function usage() {
    echo "grab_xpis.sh accepts 100, 010 or 001 as first argument"
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

if [ ! -d "$CALLDIR/modules" ]; then
    mkdir "$CALLDIR/modules"
fi

for f in "$CALLDIR"/modules/*; do
    DIRNAME=$(basename "$f")
    if [ "$DIRNAME" != "zotero-libreoffice-integration" -a "$DIRNAME" != "zotero-word-for-mac-integration" -a "$DIRNAME" != "zotero-word-for-windows-integration" ]; then
        rm -fR "$f"
    fi
done

dirnames=$(cat <<-EOF
abbrevs-filter
bluebook-signals-for-zotero
myles
zotero-odf-scan-plugin
EOF
)


CONTAINER_DIR=$(dirname "$CALLDIR")

for f in $dirnames; do
    echo "${f}"
    LOCAL_DIR="${f}"
	if [ ! -d "$CALLDIR/modules/${LOCAL_DIR}" ]; then
	    mkdir "$CALLDIR/modules/${LOCAL_DIR}"
   	fi
	LATEST=$(${GFIND} "$CONTAINER_DIR/${LOCAL_DIR}"/releases -type f -name '*.xpi' -printf '%AY%Am%Ad%AH%AI%AM%AS %h/%f\n' | sort -r | head -1 | cut -d\  -f 2);
    unzip -q "${LATEST}" -d "$CALLDIR/modules/$LOCAL_DIR/"
done
