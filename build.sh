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

[ "`uname`" != "Darwin" ]
MAC_NATIVE=$?
[ "`uname -o 2> /dev/null`" != "Cygwin" ]
WIN_NATIVE=$?

function usage {
	cat >&2 <<DONE
Usage: $0 [-p PLATFORMS] [-s DIR] [-v VERSION] [-c CHANNEL] [-d]
Options
 -p PLATFORMS    *    build for platforms PLATFORMS (m=Mac, w=Windows, l=Linux)
 -s DIR               build symlinked to Zotero checkout DIR (implies -d)
 -v VERSION      *    use version VERSION
 -c CHANNEL           use update channel CHANNEL
 -d                   don\'t package; only build binaries in staging/ directory
 -x XPI source   *    local, remote, or none

(options marked with * are not optional)
DONE
	exit 1
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
    echo ONE
    usage
fi

if [ "${VERSION}" == "" ]; then
    echo TWO
    usage
fi

if [ "${XPI_SOURCE}" != "local" -a "${XPI_SOURCE}" != "remote" -a "${XPI_SOURCE}" != "none" ]; then
    echo "(${XPI_SOURCE})"
    usage
fi 

if [ ! -z $1 ]; then
    echo FOUR
	usage
fi

. grab_xpis.sh "${BUILD_LINUX}${BUILD_MAC}${BUILD_WIN32}" "${XPI_SOURCE}"

BUILDID=`date +%Y%m%d`

shopt -s extglob
mkdir "$BUILDDIR"
rm -rf "$STAGEDIR"
mkdir "$STAGEDIR"
rm -rf "$DISTDIR"
mkdir "$DISTDIR"

if [ -z "$UPDATE_CHANNEL" ]; then UPDATE_CHANNEL="default"; fi

if [ ! -z "$SYMLINK_DIR" ]; then
	echo "Building Jurism from $SYMLINK_DIR"
	
	cp -RH "$SYMLINK_DIR" "$BUILDDIR/zotero"
	cd "$BUILDDIR/zotero"
	if [ $? != 0 ]; then
		exit
	fi
	REV=`git log -n 1 --pretty='format:%h'`
	VERSION="$DEFAULT_VERSION_PREFIX$REV"
	find . -depth -type d -name .git -exec rm -rf {} \;
	
	# Windows can't actually symlink; copy instead, with a note
	if [ "$WIN_NATIVE" == 1 ]; then
		echo "Windows host detected; copying files instead of symlinking"
		
		# Copy branding
		cp -R "$CALLDIR/assets/branding" "$BUILDDIR/zotero/chrome/branding"
		find "$BUILDDIR/zotero/chrome/branding" -depth -type d -name .git -exec rm -rf {} \;
		find "$BUILDDIR/zotero/chrome/branding" -name .DS_Store -exec rm -f {} \;
	else	
		# Symlink chrome dirs
		rm -rf "$BUILDDIR/zotero/chrome/"*
		for i in `ls $SYMLINK_DIR/chrome`; do
			ln -s "$SYMLINK_DIR/chrome/$i" "$BUILDDIR/zotero/chrome/$i"
		done
		
		# Symlink translators and styles
		rm -rf "$BUILDDIR/zotero/translators" "$BUILDDIR/zotero/styles"
		ln -s "$SYMLINK_DIR/translators" "$BUILDDIR/zotero/translators"
		ln -s "$SYMLINK_DIR/styles" "$BUILDDIR/zotero/styles"
		
		# Symlink branding
		ln -s "$CALLDIR/assets/branding" "$BUILDDIR/zotero/chrome/branding"
	fi
	
	# Add to chrome manifest
	echo "" >> "$BUILDDIR/zotero/chrome.manifest"
	cat "$CALLDIR/assets/chrome.manifest" >> "$BUILDDIR/zotero/chrome.manifest"

else
	echo "Building from bundled submodule"
	
	# Copy Jurism directory
	cd "$CALLDIR/modules/jurism"
	REV=`git log -n 1 --pretty='format:%h'`
	cp -RH "$CALLDIR/modules/jurism" "$BUILDDIR/jurism"
	cd "$BUILDDIR/jurism"
	
	if [ -z "$VERSION" ]; then
		VERSION="$DEFAULT_VERSION_PREFIX$REV"
	fi
	
	# Copy branding
	cp -R "$CALLDIR/assets/branding" "$BUILDDIR/jurism/chrome/branding"
	
	# Delete files that shouldn't be distributed
    # JURISM: these deletes have no effect for jurism build
	find "$BUILDDIR/jurism/chrome" -depth -type d -name .git -exec rm -rf {} \;
	find "$BUILDDIR/jurism/chrome" -name .DS_Store -exec rm -f {} \;
	
	# Set version
	perl -pi -e "s/VERSION: *\'[^\"]*\'/VERSION: \'$VERSION\'/" \
		"$BUILDDIR/jurism/resource/config.js"
	
	# Zip chrome into JAR
	cd "$BUILDDIR/jurism/chrome"
	# Checkout failed -- bail
	if [ $? -eq 1 ]; then
		exit;
	fi
	
	# Build jurism.jar
	cd "$BUILDDIR/jurism"
	zip -r -q jurism.jar chrome deleted.txt resource styles.zip translators.index translators.zip
	rm -rf "chrome/"* install.rdf deleted.txt resource styles.zip translators.index translators.zip
	
	# Adjust chrome.manifest
	echo "" >> "$BUILDDIR/jurism/chrome.manifest"
	cat "$CALLDIR/assets/chrome.manifest" >> "$BUILDDIR/jurism/chrome.manifest"
	
	# Copy updater.ini
	cp "$CALLDIR/assets/updater.ini" "$BUILDDIR/jurism"
	
	perl -pi -e 's^(chrome|resource)/^jar:jurism.jar\!/$1/^g' "$BUILDDIR/jurism/chrome.manifest"

	# Remove test directory
    # JURISM: no effect in jurism build based on distro XPI
	rm -rf "$BUILDDIR/jurism/test"
fi

# Adjust connector pref
perl -pi -e 's/pref\("extensions\.zotero\.httpServer\.enabled", false\);/pref("extensions.zotero.httpServer.enabled", true);/g' "$BUILDDIR/jurism/defaults/preferences/zotero.js"
perl -pi -e 's/pref\("extensions\.zotero\.connector\.enabled", false\);/pref("extensions.zotero.connector.enabled", true);/g' "$BUILDDIR/jurism/defaults/preferences/zotero.js"

# Copy icons
cp -r "$CALLDIR/assets/icons" "$BUILDDIR/jurism/chrome/icons"

# Copy application.ini and modify
cp "$CALLDIR/assets/application.ini" "$BUILDDIR/application.ini"
perl -pi -e "s/{{VERSION}}/$VERSION/" "$BUILDDIR/application.ini"
perl -pi -e "s/{{BUILDID}}/$BUILDID/" "$BUILDDIR/application.ini"

# Copy prefs.js and modify
cp "$CALLDIR/assets/prefs.js" "$BUILDDIR/jurism/defaults/preferences"
perl -pi -e 's/pref\("app\.update\.channel", "[^"]*"\);/pref\("app\.update\.channel", "'"$UPDATE_CHANNEL"'");/' "$BUILDDIR/jurism/defaults/preferences/prefs.js"
perl -pi -e 's/%GECKO_VERSION%/'"$GECKO_VERSION"'/g' "$BUILDDIR/jurism/defaults/preferences/prefs.js"

# Delete .DS_Store, .git, and tests
find "$BUILDDIR" -depth -type d -name .git -exec rm -rf {} \;
find "$BUILDDIR" -depth -type d -name .gitignore -exec rm -rf {} \;
find "$BUILDDIR" -name .DS_Store -exec rm -f {} \;

cd "$CALLDIR"

# Mac
if [ $BUILD_MAC == 1 ]; then
	echo 'Building Jurism.app'
		
	# Set up directory structure
	APPDIR="$STAGEDIR/Jurism.app"
	rm -rf "$APPDIR"
	mkdir "$APPDIR"
	chmod 755 "$APPDIR"
	cp -r "$CALLDIR/mac/Contents" "$APPDIR"
	CONTENTSDIR="$APPDIR/Contents"
	
	# Merge relevant assets from Firefox
	mkdir "$CONTENTSDIR/MacOS"
	cp -r "$MAC_RUNTIME_PATH/Contents/MacOS/"!(firefox-bin|crashreporter.app) "$CONTENTSDIR/MacOS"
	cp -r "$MAC_RUNTIME_PATH/Contents/Resources/"!(application.ini|updater.ini|update-settings.ini|browser|precomplete|removed-files|webapprt*|*.icns|defaults|*.lproj) "$CONTENTSDIR/Resources"

	# Use our own launcher
	mv "$CONTENTSDIR/MacOS/firefox" "$CONTENTSDIR/MacOS/jurism-bin"
	cp "$CALLDIR/mac/jurism" "$CONTENTSDIR/MacOS/jurism"
	cp "$BUILDDIR/application.ini" "$CONTENTSDIR/Resources"
	
	# Modify Info.plist
	perl -pi -e "s/{{VERSION}}/$VERSION/" "$CONTENTSDIR/Info.plist"
	perl -pi -e "s/{{VERSION_NUMERIC}}/$VERSION_NUMERIC/" "$CONTENTSDIR/Info.plist"
	# Needed for "monkeypatch" Windows builds: 
	# http://www.nntp.perl.org/group/perl.perl5.porters/2010/08/msg162834.html
	rm -f "$CONTENTSDIR/Info.plist.bak"
	
	# Add components
	cp -R "$BUILDDIR/zotero/"* "$CONTENTSDIR/Resources"
	
	# Add Mac-specific Standalone assets
	cd "$CALLDIR/assets/mac"
	zip -r -q "$CONTENTSDIR/Resources/jurism.jar" *
	
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
	
    # XXX RESTORE
    # Add ODF/RTF Scan (zotero-odf-scan)
	#cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$CONTENTSDIR/Resources/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
	
	# Delete extraneous files
	find "$CONTENTSDIR" -depth -type d -name .git -exec rm -rf {} \;
	find "$CONTENTSDIR" \( -name .DS_Store -or -name update.rdf \) -exec rm -f {} \;
	find "$CONTENTSDIR/Resources/extensions" -depth -type d -name build -exec rm -rf {} \;

	# Copy over removed-files and make a precomplete file since it
	# needs to be stable for the signature
	cp "$CALLDIR/update-packaging/removed-files_mac" "$CONTENTSDIR/Resources/removed-files"
	touch "$CONTENTSDIR/Resources/precomplete"
	
	# Sign
    # When I have a hundred bucks to spare, this can happen.
	#if [ $SIGN == 1 ]; then
	#	/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR/Contents/MacOS/jurism-bin"
	#	/usr/bin/codesign --force --sign "$DEVELOPER_ID" "$APPDIR"
	#	/usr/bin/codesign --verify -vvvv "$APPDIR"
	#fi
	
	# Build disk image
	if [ $PACKAGE == 1 ]; then
		if [ $MAC_NATIVE == 1 ]; then
			echo 'Creating Mac installer'
			"$CALLDIR/mac/pkg-dmg" --source "$STAGEDIR/Jurism.app" \
				--target "$DISTDIR/Jurism-$VERSION.dmg" \
				--sourcefile --volname Jurism --copy "$CALLDIR/mac/DSStore:/.DS_Store" \
				--symlink /Applications:"/Drag Here to Install" > /dev/null
		else
			echo 'Not building on Mac; creating Mac distribution as a zip file'
			rm -f "$DISTDIR/Jurism_mac.zip"
			cd "$STAGEDIR" && zip -rqX "$DISTDIR/Jurism-$VERSION_mac.zip" Jurism.app
		fi
	fi
fi

# Win32
if [ $BUILD_WIN32 == 1 ]; then
	echo 'Building Jurism_win32'
	
	# Set up directory
	APPDIR="$STAGEDIR/Jurism_win32"
	mkdir "$APPDIR"
	
	# Merge xulrunner and relevant assets
	cp -R "$BUILDDIR/jurism/"* "$BUILDDIR/application.ini" "$APPDIR"
	cp -r "$WIN32_RUNTIME_PATH" "$APPDIR/xulrunner"
	
	cat "$CALLDIR/win/installer/updater_append.ini" >> "$APPDIR/updater.ini"
	mv "$APPDIR/xulrunner/xulrunner-stub.exe" "$APPDIR/jurism.exe"
	
	# This used to be bug 722810, but that bug was actually fixed for Gecko 12.
	# Then it was broken again. Now it seems okay...
	# cp "$WIN32_RUNTIME_PATH/msvcp120.dll" \
	#    "$WIN32_RUNTIME_PATH/msvcr120.dll" \
	#    "$APPDIR/"
	
	# Add Windows-specific Standalone assets
	cd "$CALLDIR/assets/win"
	zip -r -q "$APPDIR/zotero.jar" *
	
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
	
    ## RESTORE
    # Add ODF/RTF Scan (zotero-odf-scan)
	#cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$APPDIR/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
		
	# Remove unnecessary dlls
	INTEGRATIONDIR="$APPDIR/extensions/jurismWinWordIntegration@juris-m.github.io/"
	rm -rf "$INTEGRATIONDIR/"components-!($GECKO_SHORT_VERSION)

	# Fix chrome.manifest
	perl -pi -e 's/^binary-component.*(?:\n|$)//sg' "$INTEGRATIONDIR/chrome.manifest"
	echo "binary-component components-$GECKO_SHORT_VERSION/zoteroWinWordIntegration.dll" >> "$INTEGRATIONDIR/chrome.manifest"
	
	# Delete extraneous files
	rm "$APPDIR/xulrunner/js.exe" "$APPDIR/xulrunner/redit.exe"
	find "$APPDIR" -depth -type d -name .git -exec rm -rf {} \;
	find "$APPDIR" \( -name .DS_Store -or -name update.rdf \) -exec rm -f {} \;
	find "$APPDIR/extensions" -depth -type d -name build -exec rm -rf {} \;
	find "$APPDIR" \( -name '*.exe' -or -name '*.dll' \) -exec chmod 755 {} \;
	
	if [ $PACKAGE == 1 ]; then
		if [ $WIN_NATIVE == 1 ]; then
			INSTALLER_PATH="$DISTDIR/Jurism-${VERSION}_setup.exe"
			
			# Add icon to xulrunner-stub
			"$CALLDIR/win/ReplaceVistaIcon/ReplaceVistaIcon.exe" "`cygpath -w \"$APPDIR/jurism.exe\"`" \
				"`cygpath -w \"$CALLDIR/assets/icons/default/main-window.ico\"`"
			
			echo 'Creating Windows installer'
			# Copy installer files
			cp -r "$CALLDIR/win/installer" "$BUILDDIR/win_installer"
			
			# Build and sign uninstaller
			perl -pi -e "s/{{VERSION}}/$VERSION/" "$BUILDDIR/win_installer/defines.nsi"
			"`cygpath -u \"$MAKENSISU\"`" /V1 "`cygpath -w \"$BUILDDIR/win_installer/uninstaller.nsi\"`"
			mkdir "$APPDIR/uninstall"
			mv "$BUILDDIR/win_installer/helper.exe" "$APPDIR/uninstall"
			
			# Sign jurism.exe, dlls, updater, and uninstaller
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/jurism.exe\"`"
				for dll in "$APPDIR/"*.dll "$APPDIR/xulrunner/"*.dll; do
					"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism" \
						/du "$SIGNATURE_URL" "`cygpath -w \"$dll\"`"
				done
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism Updater" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/xulrunner/updater.exe\"`"
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism Uninstaller" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$APPDIR/uninstall/helper.exe\"`"
			fi
			
			# Stage installer
			INSTALLERSTAGEDIR="$BUILDDIR/win_installer/staging"
			mkdir "$INSTALLERSTAGEDIR"
			cp -R "$APPDIR" "$INSTALLERSTAGEDIR/core"
			
			# Build and sign setup.exe
			"`cygpath -u \"$MAKENSISU\"`" /V1 "`cygpath -w \"$BUILDDIR/win_installer/installer.nsi\"`"
			mv "$BUILDDIR/win_installer/setup.exe" "$INSTALLERSTAGEDIR"
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism Setup" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$INSTALLERSTAGEDIR/setup.exe\"`"
			fi
			
			# Compress application
			cd "$INSTALLERSTAGEDIR" && "`cygpath -u \"$EXE7ZIP\"`" a -r -t7z "`cygpath -w \"$BUILDDIR/app_win32.7z\"`" \
				-mx -m0=BCJ2 -m1=LZMA:d24 -m2=LZMA:d19 -m3=LZMA:d19  -mb0:1 -mb0s1:2 -mb0s2:3 > /dev/null
				
			# Compress 7zSD.sfx
			"`cygpath -u \"$UPX\"`" --best -o "`cygpath -w \"$BUILDDIR/7zSD.sfx\"`" \
				"`cygpath -w \"$CALLDIR/win/installer/7zstub/firefox/7zSD.sfx\"`" > /dev/null
			
			# Combine 7zSD.sfx and app.tag into setup.exe
			cat "$BUILDDIR/7zSD.sfx" "$CALLDIR/win/installer/app.tag" \
				"$BUILDDIR/app_win32.7z" > "$INSTALLER_PATH"
			
			# Sign Jurism_setup.exe
			if [ $SIGN == 1 ]; then
				"`cygpath -u \"$SIGNTOOL\"`" sign /a /d "Jurism Setup" \
					/du "$SIGNATURE_URL" "`cygpath -w \"$INSTALLER_PATH\"`"
			fi
			
			chmod 755 "$INSTALLER_PATH"
		else
			echo 'Not building on Windows; only building zip file'
		fi
		cd "$STAGEDIR" && zip -rqX "$DISTDIR/Jurism-${VERSION}_win32.zip" Jurism_win32
	fi
fi

# Linux
if [ $BUILD_LINUX == 1 ]; then
	for arch in "i686" "x86_64"; do
		RUNTIME_PATH=`eval echo '$LINUX_'$arch'_RUNTIME_PATH'`
		
		# Set up directory
		echo 'Building Jurism_linux-'$arch
		APPDIR="$STAGEDIR/Jurism_linux-$arch"
		rm -rf "$APPDIR"
		mkdir "$APPDIR"
		
		# Merge xulrunner and relevant assets
		cp -R "$BUILDDIR/jurism/"* "$BUILDDIR/application.ini" "$APPDIR"
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
		
        ## RESTORE
        # Add ODF/RTF Scan (zotero-odf-scan)
		#cp -RH "$CALLDIR/modules/zotero-odf-scan-plugin" "$APPDIR/extensions/rtf-odf-scan-for-zotero@mystery-lab.com"
		
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
			rm -f "$DISTDIR/Jurism-${VERSION}_linux-$arch.tar.bz2"
			cd "$STAGEDIR"
			tar -cjf "$DISTDIR/Jurism-${VERSION}_linux-$arch.tar.bz2" "Jurism_linux-$arch"
		fi
	done
fi

rm -rf $BUILDDIR
