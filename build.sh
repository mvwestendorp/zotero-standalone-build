#!/bin/bash

# Copyright (c) 2011  Zotero
#                     Center for History and New Media
#                     George Mason University, Fairfax, Virginia, USA
#                     http://zotero.org
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

CALLDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$CALLDIR/config.sh"

if [ "`uname`" = "Darwin" ]; then
	MAC_NATIVE=1
else
	MAC_NATIVE=0
fi
if [ "`uname -o 2> /dev/null`" = "Cygwin" ]; then
	WIN_NATIVE=1
else
	WIN_NATIVE=0
fi

DEVTOOLS=0
PACKAGE=1

function usage {
	cat >&2 <<DONE
Usage: $0 [-p PLATFORMS] [-s DIR] [-v VERSION] [-c CHANNEL] [-d]
Options
 -p PLATFORMS    *    build for platforms PLATFORMS (m=Mac, w=Windows, l=Linux)
 -s DIR               build symlinked to Zotero checkout DIR (implies -d)
 -v VERSION      *    use version VERSION (with leading "v")
 -c CHANNEL           use update channel CHANNEL
 -d                   don\'t package; only build binaries in staging/ directory
 -x XPI source   *    local, remote, or none

(options marked with * are not optional)
DONE
	exit 1
}

BUILD_DIR=`mktemp -d`
function cleanup {
	rm -rf $BUILD_DIR
}
trap cleanup EXIT

function abspath {
	echo $(cd $(dirname $1); pwd)/$(basename $1);
}

function seq () {
  if [ "$1" -lt "$2" ] ; then
    for ((i="$1"; i<"$2"; i++))
      do echo $i
    done
  else
    for ((i="$1"; i>"$2"; i--))
      do echo $i
    done
  fi
}

PACKAGE=1
while getopts "p:s:v:c:x:d" opt; do
	case $opt in
		p)
			BUILD_MAC=0
			BUILD_WIN32=0
			BUILD_LINUX=0
			for i in `seq 0 1 $((${#OPTARG}-1))`
			do
				case ${OPTARG:i:1} in
					m) BUILD_MAC=1;GECKO_VERSION="40.0";GECKO_SHORT_VERSION="40.0";;
					w) BUILD_WIN32=1;GECKO_VERSION="40.0";GECKO_SHORT_VERSION="40.0";;
					l) BUILD_LINUX=1;GECKO_VERSION="39.0";GECKO_SHORT_VERSION="39.0";;
					*)
						echo "$0: Invalid platform option ${OPTARG:i:1}"
						usage
						;;
				esac
			done
			;;
		s)
			SYMLINK_DIR="$OPTARG"
			PACKAGE=0
			;;
		v)
			VERSION="$OPTARG"
			;;
		c)
			UPDATE_CHANNEL="$OPTARG"
			;;
		x)
			XPI_SOURCE="$OPTARG"
			;;
		d)
			PACKAGE=0
			;;
		*)
			usage
			;;
	esac
	shift $((OPTIND-1)); OPTIND=1
done

if [ ${BUILD_LINUX} -eq 0 -a ${BUILD_MAC} -eq 0 -a ${BUILD_WIN32} -eq 0 ]; then
    echo "Must set the platform (-p) option"
    usage
fi

# Must set the version (-v) option
if [ "${VERSION}" == "" ]; then
    echo "Must set the version (-v) option"
    usage
fi

if [ "${XPI_SOURCE}" != "local" -a "${XPI_SOURCE}" != "remote" -a "${XPI_SOURCE}" != "none" ]; then
    echo "(${XPI_SOURCE})"
    usage
fi 

# Not sure what this protects against.
if [ ! -z $1 ]; then
    echo FOUR
	usage
fi

VERSION=$(echo "${VERSION}" | sed -e "s/v\(.*\)/\1/")

echo "BUILD_LINUX=${BUILD_LINUX}"
echo "BUILD_MAC=${BUILD_MAC}"
echo "BUILD_WIN32=${BUILD_WIN32}"
echo "XPI_SOURCE=${XPI_SOURCE}"
echo "VERSION=${VERSION}"

. grab_xpis.sh "${BUILD_LINUX}${BUILD_MAC}${BUILD_WIN32}" "${XPI_SOURCE}"

# Force this one.
SOURCE_DIR=/home/bennett/JM/jurism

BUILD_ID=`date +%Y%m%d`

shopt -s extglob
mkdir -p "$BUILD_DIR/jurism"
rm -rf "$STAGE_DIR"
mkdir "$STAGE_DIR"
rm -rf "$DIST_DIR"
mkdir "$DIST_DIR"

# Save build id, which is needed for updates manifest
echo $BUILD_ID > "$DIST_DIR/build_id"

if [ -z "$UPDATE_CHANNEL" ]; then UPDATE_CHANNEL="default"; fi

if [ -n "$ZIP_FILE" ]; then
	ZIP_FILE="`abspath $ZIP_FILE`"
	echo "Building from $ZIP_FILE"
	unzip -q $ZIP_FILE -d "$BUILD_DIR/jurism"
else
	# TODO: Could probably just mv instead, at least if these repos are merged
	rsync -a "$SOURCE_DIR/" "$BUILD_DIR/jurism/"
fi

cd "$BUILD_DIR/jurism"

# Upstream Zotero code to extract version number from install.rdf
# omitted here.

rm install.rdf

echo
echo "Version: $VERSION"

# Delete Mozilla signing info if present
rm -rf META-INF

# Copy branding
cp -R "$CALLDIR/assets/branding" "$BUILD_DIR/jurism/chrome/branding"

# Add to chrome manifest
echo "" >> "$BUILD_DIR/jurism/chrome.manifest"
cat "$CALLDIR/assets/chrome.manifest" >> "$BUILD_DIR/jurism/chrome.manifest"

# Copy Error Console files
cp "$CALLDIR/assets/console/jsconsole-clhandler.js" "$BUILD_DIR/jurism/components/"
echo >> "$BUILD_DIR/jurism/chrome.manifest"
cat "$CALLDIR/assets/console/jsconsole-clhandler.manifest" >> "$BUILD_DIR/jurism/chrome.manifest"
cp -R "$CALLDIR/assets/console/content" "$BUILD_DIR/jurism/chrome/console"
cp -R "$CALLDIR/assets/console/skin/osx" "$BUILD_DIR/jurism/chrome/console/skin"
cp -R "$CALLDIR/assets/console/locale/en-US" "$BUILD_DIR/jurism/chrome/console/locale"
cat "$CALLDIR/assets/console/jsconsole.manifest" >> "$BUILD_DIR/jurism/chrome.manifest"

# Delete files that shouldn't be distributed
find "$BUILD_DIR/jurism/chrome" -name .DS_Store -exec rm -f {} \;

# Zip chrome into JAR
cd "$BUILD_DIR/jurism"
zip -r -q jurism.jar chrome deleted.txt resource styles.zip translators.index translators.zip styles translators.json translators
rm -rf "chrome/"* install.rdf deleted.txt resource styles.zip translators.index translators.zip styles translators.json translators

# Copy updater.ini
cp "$CALLDIR/assets/updater.ini" "$BUILD_DIR/jurism"

# Adjust chrome.manifest
perl -pi -e 's^(chrome|resource)/^jar:jurism.jar\!/$1/^g' "$BUILD_DIR/jurism/chrome.manifest"

# Adjust connector pref
perl -pi -e 's/pref\("extensions\.zotero\.httpServer\.enabled", false\);/pref("extensions.zotero.httpServer.enabled", true);/g' "$BUILD_DIR/jurism/defaults/preferences/zotero.js"
perl -pi -e 's/pref\("extensions\.zotero\.connector\.enabled", false\);/pref("extensions.zotero.connector.enabled", true);/g' "$BUILD_DIR/jurism/defaults/preferences/zotero.js"

# Copy icons
cp -r "$CALLDIR/assets/icons" "$BUILD_DIR/jurism/chrome/icons"

# Copy application.ini and modify
cp "$CALLDIR/assets/application.ini" "$BUILD_DIR/application.ini"
perl -pi -e "s/\{\{VERSION}}/$VERSION/" "$BUILD_DIR/application.ini"
perl -pi -e "s/\{\{BUILDID}}/$BUILD_ID/" "$BUILD_DIR/application.ini"

# Copy prefs.js and modify
cp "$CALLDIR/assets/prefs.js" "$BUILD_DIR/jurism/defaults/preferences"
perl -pi -e 's/pref\("app\.update\.channel", "[^"]*"\);/pref\("app\.update\.channel", "'"$UPDATE_CHANNEL"'");/' "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
perl -pi -e 's/%GECKO_VERSION%/'"$GECKO_VERSION"'/g' "$BUILD_DIR/jurism/defaults/preferences/prefs.js"

# Add devtools manifest and pref
if [ $DEVTOOLS -eq 1 ]; then
	cat "$CALLDIR/assets/devtools.manifest" >> "$BUILD_DIR/jurism/chrome.manifest"
	echo 'pref("devtools.debugger.remote-enabled", true);' >> "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
	echo 'pref("devtools.debugger.remote-port", 6100);' >> "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
	echo 'pref("devtools.debugger.prompt-connection", false);' >> "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
fi

echo -n "Channel: "
grep app.update.channel "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
echo

# Remove unnecessary files
find "$BUILD_DIR" -name .DS_Store -exec rm -f {} \;
rm -rf "$BUILD_DIR/jurism/test"

cd "$CALLDIR"

# Mac
if [ $BUILD_MAC == 1 ]; then
	echo 'Building Jurism.app'
		
	# Set up directory structure
	APPDIR="$STAGE_DIR/Jurism.app"
	rm -rf "$APPDIR"
	mkdir "$APPDIR"
	chmod 755 "$APPDIR"
	cp -r "$CALLDIR/mac/Contents" "$APPDIR"
	CONTENTSDIR="$APPDIR/Contents"
	
	# Modify platform-specific prefs
	perl -pi -e 's/pref\("browser\.preferences\.instantApply", false\);/pref\("browser\.preferences\.instantApply", true);/' "$BUILD_DIR/jurism/defaults/preferences/prefs.js"
	
	# Merge relevant assets from Firefox
	mkdir "$CONTENTSDIR/MacOS"
	cp -r "$MAC_RUNTIME_PATH/Contents/MacOS/"!(firefox-bin|crashreporter.app) "$CONTENTSDIR/MacOS"
	cp -r "$MAC_RUNTIME_PATH/Contents/Resources/"!(application.ini|updater.ini|update-settings.ini|browser|precomplete|removed-files|webapprt*|*.icns|defaults|*.lproj) "$CONTENTSDIR/Resources"

	# Use our own launcher
	mv "$CONTENTSDIR/MacOS/firefox" "$CONTENTSDIR/MacOS/jurism-bin"
	cp "$CALLDIR/mac/zotero" "$CONTENTSDIR/MacOS/jurism"
	cp "$BUILD_DIR/application.ini" "$CONTENTSDIR/Resources"
	
	cd "$CONTENTSDIR/MacOS"
	tar -xjf "$CALLDIR/mac/updater.tar.bz2"
	
	# Modify Info.plist
	perl -pi -e "s/{{VERSION}}/$VERSION/" "$CONTENTSDIR/Info.plist"
	perl -pi -e "s/{{VERSION_NUMERIC}}/$VERSION_NUMERIC/" "$CONTENTSDIR/Info.plist"
	# Needed for "monkeypatch" Windows builds: 
	# http://www.nntp.perl.org/group/perl.perl5.porters/2010/08/msg162834.html
	rm -f "$CONTENTSDIR/Info.plist.bak"
	
	# Add components
	cp -R "$BUILD_DIR/jurism/"* "$CONTENTSDIR/Resources"
	
	# Add Mac-specific Standalone assets
	cd "$CALLDIR/assets/mac"
	zip -r -q "$CONTENTSDIR/Resources/jurism.jar" *
	
	# Add devtools
	if [ $DEVTOOLS -eq 1 ]; then
		cp -r "$MAC_RUNTIME_PATH"/Contents/Resources/devtools-files/chrome/* "$CONTENTSDIR/Resources/chrome/"
		cp "$MAC_RUNTIME_PATH/Contents/Resources/devtools-files/components/interfaces.xpt" "$CONTENTSDIR/Resources/components/"
	fi
	
	# Add word processor plug-ins
	mkdir "$CONTENTSDIR/Resources/extensions"
	cp -RH "$CALLDIR/modules/jurism-word-for-mac-integration" "$CONTENTSDIR/Resources/extensions/jurismMacWordIntegration@juris-m.github.io"
	cp -RH "$CALLDIR/modules/jurism-libreoffice-integration" "$CONTENTSDIR/Resources/extensions/jurismOpenOfficeIntegration@juris-m.github.io"
	
    # Add Abbreviation Filter (abbrevs-filter)
	cp -RH "$CALLDIR/modules/abbrevs-filter" "$CONTENTSDIR/Resources/extensions/abbrevs-filter@juris-m.github.io"
    
    # Add jurisdiction support (myles)
	cp -RH "$CALLDIR/modules/myles" "$CONTENTSDIR/Resources/extensions/myles@juris-m.github.io"
	
    # Add Bluebook signal helper (bluebook-signals-for-zotero)
	cp -RH "$CALLDIR/modules/bluebook-signals-for-zotero" "$CONTENTSDIR/Resources/extensions/bluebook-signals-for-zotero@mystery-lab.com"
	
    # Add ODF/RTF Scan (zotero-odf-scan)
	cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$CONTENTSDIR/Resources/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
	
	# Delete extraneous files
	find "$CONTENTSDIR" -depth -type d -name .git -exec rm -rf {} \;
	find "$CONTENTSDIR" \( -name .DS_Store -or -name update.rdf \) -exec rm -f {} \;
	find "$CONTENTSDIR/Resources/extensions" -depth -type d -name build -exec rm -rf {} \;

	# Copy over removed-files and make a precomplete file since it
	# needs to be stable for the signature
	cp "$CALLDIR/update-packaging/removed-files_mac" "$CONTENTSDIR/Resources/removed-files"
	touch "$CONTENTSDIR/Resources/precomplete"
	
	# Sign
	if [ $SIGN == 1 ]; then
		/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR/Contents/MacOS/updater.app/Contents/MacOS/org.mozilla.updater"
		/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR/Contents/MacOS/updater.app"
		/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR/Contents/MacOS/zotero-bin"
		/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR"
		/usr/bin/codesign --verify -vvvv "$APPDIR"
	fi
	
	# Build disk image
	if [ $PACKAGE == 1 ]; then
		if [ $MAC_NATIVE == 1 ]; then
			echo 'Creating Mac installer'
			"$CALLDIR/mac/pkg-dmg" --source "$STAGE_DIR/Jurism.app" \
				--target "$DIST_DIR/jurism-for-mac-all-$VERSION.dmg" \
				--sourcefile --volname Jurism --copy "$CALLDIR/mac/DSStore:/.DS_Store" \
				--symlink /Applications:"/Drag Here to Install" > /dev/null
		else
			echo 'Not building on Mac; creating Mac distribution as a zip file'
			rm -f "$DIST_DIR/Jurism_mac.zip"
			cd "$STAGE_DIR" && zip -rqX "$DIST_DIR/jurism-for-mac-all-$VERSION.zip" Jurism.app
		fi
	fi
fi

# Win32
if [ $BUILD_WIN32 == 1 ]; then
	echo 'Building Jurism_win32'
	
	# Set up directory
	APPDIR="$STAGE_DIR/Jurism_win32"
	rm -rf "$APPDIR"
	mkdir "$APPDIR"
	
	# Copy relevant assets from Firefox
	mkdir "$APPDIR/xulrunner"
	cp -R "$WIN32_RUNTIME_PATH"/!(api-ms*.dll|application.ini|browser|defaults|devtools-files|crashreporter*|firefox.exe|maintenanceservice*|precomplete|removed-files|uninstall|update*) "$APPDIR/xulrunner"
	
	# Copy zotero.exe, which is xulrunner-stub from https://github.com/duanyao/xulrunner-stub
	# modified with ReplaceVistaIcon.exe and edited with Resource Hacker
	#
	#   "$CALLDIR/win/ReplaceVistaIcon/ReplaceVistaIcon.exe" \
	#       "`cygpath -w \"$APPDIR/zotero.exe\"`" \
	#       "`cygpath -w \"$CALLDIR/assets/icons/default/main-window.ico\"`"
	#
	cp "$CALLDIR/win/zotero.exe" "$APPDIR"
	
	# Use our own updater, because Mozilla's requires updates signed by Mozilla
	cp "$CALLDIR/win/updater.exe" "$APPDIR/xulrunner"
	cat "$CALLDIR/win/installer/updater_append.ini" >> "$APPDIR/xulrunner/updater.ini"
	
	# Copy files to root as required by xulrunner-stub
	cp "$WIN32_RUNTIME_PATH/mozglue.dll" \
		"$WIN32_RUNTIME_PATH/msvcp120.dll" \
		"$WIN32_RUNTIME_PATH/msvcr120.dll" \
		"$APPDIR/"
	
	cp -R "$BUILD_DIR/jurism/"* "$BUILD_DIR/application.ini" "$APPDIR"
	
	# Add Windows-specific Standalone assets
	cd "$CALLDIR/assets/win"
	zip -r -q "$APPDIR/jurism.jar" *
	
	# Add devtools
	if [ $DEVTOOLS -eq 1 ]; then
		cp -r "$WIN32_RUNTIME_PATH"/devtools-files/chrome/* "$APPDIR/chrome/"
		cp "$WIN32_RUNTIME_PATH/devtools-files/components/interfaces.xpt" "$APPDIR/components/"
	fi
	
	# Add word processor plug-ins
	mkdir "$APPDIR/extensions"
	cp -RH "$CALLDIR/modules/jurism-word-for-windows-integration" "$APPDIR/extensions/jurismWinWordIntegration@juris-m.github.io"
	cp -RH "$CALLDIR/modules/jurism-libreoffice-integration" "$APPDIR/extensions/jurismOpenOfficeIntegration@juris-m.github.io"

    # Add Abbreviation Filter (abbrevs-filter)
	cp -RH "$CALLDIR/modules/abbrevs-filter" "$APPDIR/extensions/abbrevs-filter@juris-m.github.io"

    # Add Jurisdiction Support (myles)
	cp -RH "$CALLDIR/modules/myles" "$APPDIR/extensions/myles@juris-m.github.io"
	
    # Add Bluebook signal helper (bluebook-signals-for-zotero)
	cp -RH "$CALLDIR/modules/bluebook-signals-for-zotero" "$APPDIR/extensions/bluebook-signals-for-zotero@mystery-lab.com"
	
    # Add ODF/RTF Scan (zotero-odf-scan)
	cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$APPDIR/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
		
	# Delete extraneous files
	find "$APPDIR" -depth -type d -name .git -exec rm -rf {} \;
	find "$APPDIR" \( -name .DS_Store -or -name '.git*' -or -name '.travis.yml' -or -name update.rdf -or -name '*.bak' \) -exec rm -f {} \;
	find "$APPDIR/extensions" -depth -type d -name build -exec rm -rf {} \;
	find "$APPDIR" \( -name '*.exe' -or -name '*.dll' \) -exec chmod 755 {} \;

	if [ $PACKAGE == 1 ]; then
		if [ $WIN_NATIVE == 1 ]; then
			INSTALLER_PATH="$DIST_DIR/jurism-for-windows-all-${VERSION}_setup.exe"
			
			echo 'Creating Windows installer'
			# Copy installer files
			cp -r "$CALLDIR/win/installer" "$BUILD_DIR/win_installer"
			
			# Build and sign uninstaller
			perl -pi -e "s/\{\{VERSION}}/$VERSION/" "$BUILD_DIR/win_installer/defines.nsi"
			"`cygpath -u \"$MAKENSISU\"`" /V1 "`cygpath -w \"$BUILD_DIR/win_installer/uninstaller.nsi\"`"
			mkdir "$APPDIR/uninstall"
			mv "$BUILD_DIR/win_installer/helper.exe" "$APPDIR/uninstall"
			
			# Sign zotero.exe, dlls, updater, and uninstaller
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /n "$SIGNTOOL_CERT_SUBJECT" /d "Zotero" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/zotero.exe\"`"
				for dll in "$APPDIR/"*.dll "$APPDIR/xulrunner/"*.dll; do
					"`cygpath -u \"$SIGNTOOL\"`" sign /n "$SIGNTOOL_CERT_SUBJECT" /d "Zotero" \
						/du "$SIGNATURE_URL" "`cygpath -w \"$dll\"`"
				done
				"`cygpath -u \"$SIGNTOOL\"`" sign /n "$SIGNTOOL_CERT_SUBJECT" /d "Zotero Updater" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/xulrunner/updater.exe\"`"
				"`cygpath -u \"$SIGNTOOL\"`" sign /n "$SIGNTOOL_CERT_SUBJECT" /d "Zotero Uninstaller" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/uninstall/helper.exe\"`"
			fi
			
			# Stage installer
			INSTALLER_STAGE_DIR="$BUILD_DIR/win_installer/staging"
			mkdir "$INSTALLER_STAGE_DIR"
			cp -R "$APPDIR" "$INSTALLER_STAGE_DIR/core"
			
			# Build and sign setup.exe
			"`cygpath -u \"$MAKENSISU\"`" /V1 "`cygpath -w \"$BUILD_DIR/win_installer/installer.nsi\"`"
			mv "$BUILD_DIR/win_installer/setup.exe" "$INSTALLER_STAGE_DIR"
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /n "$SIGNTOOL_CERT_SUBJECT" /d "Zotero Setup" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$INSTALLER_STAGE_DIR/setup.exe\"`"
			fi
			
			# Compress application
			cd "$INSTALLER_STAGE_DIR" && 7z a -r -t7z "`cygpath -w \"$BUILD_DIR/app_win32.7z\"`" \
				-mx -m0=BCJ2 -m1=LZMA:d24 -m2=LZMA:d19 -m3=LZMA:d19  -mb0:1 -mb0s1:2 -mb0s2:3 > /dev/null
				
			# Compress 7zSD.sfx
			upx --best -o "`cygpath -w \"$BUILD_DIR/7zSD.sfx\"`" \
				"`cygpath -w \"$CALLDIR/win/installer/7zstub/firefox/7zSD.sfx\"`" > /dev/null
			
			# Combine 7zSD.sfx and app.tag into setup.exe
			cat "$BUILD_DIR/7zSD.sfx" "$CALLDIR/win/installer/app.tag" \
				"$BUILD_DIR/app_win32.7z" > "$INSTALLER_PATH"
			
			# Sign Zotero_setup.exe
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Zotero Setup" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$INSTALLER_PATH\"`"
			fi
			
			chmod 755 "$INSTALLER_PATH"
		else
			echo 'Not building on Windows; only building zip file'
		fi
		cd "$STAGE_DIR" && zip -rqX "$DIST_DIR/jurism-for-windows-all-${VERSION}_win32.zip" Jurism_win32
	fi
fi

# Linux
if [ $BUILD_LINUX == 1 ]; then
	for arch in "i686" "x86_64"; do
		if [ "${arch}" == "i686" ]; then
			description="32bit"
		else
			description="64bit"
		fi
		RUNTIME_PATH=`eval echo '$LINUX_'$arch'_RUNTIME_PATH'`
		
		# Set up directory
		echo 'Building Jurism_linux-'$arch
		APPDIR="$STAGE_DIR/Jurism_linux-$arch"
		rm -rf "$APPDIR"
		mkdir "$APPDIR"
		
		# Merge xulrunner and relevant assets
		cp -R "$BUILD_DIR/jurism/"* "$BUILDDIR/application.ini" "$APPDIR"
		cp -r "$RUNTIME_PATH" "$APPDIR/xulrunner"
		rm "$APPDIR/xulrunner/xulrunner-stub"
		cp "$CALLDIR/linux/xulrunner-stub-$arch" "$APPDIR/jurism"
		chmod 755 "$APPDIR/jurism"
	
		# Add Unix-specific Standalone assets
		cd "$CALLDIR/assets/unix"
		zip -0 -r -q "$APPDIR/jurism.jar" *
		
		# Add word processor plug-ins
		mkdir "$APPDIR/extensions"
		cp -RH "$CALLDIR/modules/jurism-libreoffice-integration" "$APPDIR/extensions/jurismOpenOfficeIntegration@juris-m.github.io"

        # Add Abbreviation Filter (abbrevs-filter)
		cp -RH "$CALLDIR/modules/abbrevs-filter" "$APPDIR/extensions/abbrevs-filter@juris-m.github.io"

        # Add Jurisdiction Support (myles)
		cp -RH "$CALLDIR/modules/myles" "$APPDIR/extensions/myles@juris-m.github.io"
		
        # Add Bluebook signal helper (bluebook-signals-for-zotero)
		cp -RH "$CALLDIR/modules/bluebook-signals-for-zotero" "$APPDIR/extensions/bluebook-signals-for-zotero@mystery-lab.com"
		
        # Add ODF/RTF Scan (zotero-odf-scan)
		cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$APPDIR/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
		
        # Add ZotFile (zotfile-for-jurism)
	    cp -RH "$CALLDIR/modules/zotfile" "$APPDIR/extensions/zotfile@juris-m.github.io"
	
		# Delete extraneous files
		find "$APPDIR" -depth -type d -name .git -exec rm -rf {} \;
		find "$APPDIR" \( -name .DS_Store -or -name update.rdf \) -exec rm -f {} \;
		find "$APPDIR/extensions" -depth -type d -name build -exec rm -rf {} \;
		
		# Add run-zotero.sh
		cp "$CALLDIR/linux/run-zotero.sh" "$APPDIR/run-zotero.sh"
		
		# Move icons, so that updater.png doesn't fail
		mv "$APPDIR/xulrunner/icons" "$APPDIR/icons"
		
		if [ $PACKAGE == 1 ]; then
			# Create tar
			rm -f "$DIST_DIR/jurism-for-linux-${description}-${VERSION}.tar.bz2"
			cd "$STAGE_DIR"
			tar -cjf "$DIST_DIR/jurism-for-linux-${description}-${VERSION}.tar.bz2" "Jurism_linux-$arch"
		fi
	done
fi

rm -rf $BUILD_DIR
