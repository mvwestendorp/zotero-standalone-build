# Juris-M Standalone build utility

Scripts and utilities for bundling the [Juris-M core](https://github.com/Juris-M/zotero) into a standalone client installer for Mac, Windows and Linux.

The instructions here are currently limited to the building of the client. Packaging (i.e. signing the client for distribution) and distribution (i.e. generating and deploying delta images for over-the-wire updates) are not yet covered.

(Before working with the scripts here, be sure to visit the [core Juris-M repository](https://github.com/Juris-M/zotero#user-content-juris-m) *and* the [Juris-M fork of zotero-build](https://github.com/Juris-M/zotero-build#user-content-juris-m-build-scripts) and perform the build steps documented there.)

----------

## Notes from the Zotero repository

These files are used to bundle the [Zotero core](https://github.com/zotero/zotero) into distributable bundles for Mac, Windows, and Linux.

Instructions for building and packaging are available on the [Zotero wiki](https://www.zotero.org/support/dev/client_coding/building_the_standalone_client).

----------

## About this repository

The instructions and tools provided here are derived from the original Zotero Standalone build tools repository. The Juris-M build process currently stops short of full proper packaging and distribution. This is not ideal, but the initial aim is to adapt and document the basic build process, and the instructions below are limited to that aim.

The build steps in this Juris-M fork differ somewhat from its Zotero parent. Specifically:

-   The `check_requirements` script has been split into three separate scripts, with extensions `_build`, `_packaging`, and `_release`. The simplified build instructions here should work if only the `_build` requirements are satisfied.
-   The `build.sh` script has been modified to sniff the client version from the build Juris-M source, and the target platform from the environment.

## Cloning the repository

Enter the directory where your Juris-M development repositories are located, and clone this into it, using commands like the following:
```bash
  prompt> cd jurism-repos
  prompt> git clone --recursive https://github.com/Juris-M/zotero-standalone-build.git
```
If you forget to include the `--recursive` option when cloning, pull in the submodules by entering the repository directory and issuing commands like the following:
```bash
  prompt> cd zotero-standalone-build
  prompt> git submodule init
  prompt> git submodule update --remote
```

## Checking build requirements

Enter this directory and run `check_requirements_build` to check that the tools needed for the build process are available:
```bash
  prompt> cd zotero-standalone-build
  prompt> ./scripts/check_requirements_build
```
If anything turns up missing, install as necessary.

## Fetching the runtime platform code

Grab the runtime code, specifying the target platform with the `-p` option (`m=`Mac, `l=`Linux, `w=`Windows; for Mac builds, this must be done from Mac OS):
```bash
  prompt> ./fetch_xulrunner.sh -p l
```
For Linux, this will fetch two binaries, one each for 32-bit and one for 64-bit builds.

## Fetch PDF tools

Grab the PDF tools. This bundle was fetched once already when testing the Juris-M core, but the bundle is external to Juris-M (and Zotero), and must be fetched separately for the runtime build.
```bash
  prompt> ./fetch_pdftools
```

## Building the client into the `staging` directory

To check that the client works correctly when assembled, the following command will place the unpackaged runtime code under the `./staging` directory:
```bash
  prompt> ./scripts/dir_build
```
Building in this way is quick, which is nice for trialing features or checking for bugs after changes to Juris-M core. The fully functional client can then be run by entering its directory and running the `jurism` command. For example:
```bash
  prompt> cd ./staging/Jurism_linux-x86_64
  prompt> ./jurism
```

## Building the client

The client is built by running the `./build.sh` script in the root directory of the repository:
```bash
  prompt> ./build.sh
```
The script should complete without error, and leave a copy (or in the case of Linux, two copies) of the installer in the `./dist` directory. If the script complains that the platform must be specified, it can be forced with the `-p` option:
```bash
  prompt> ./build.sh -p l
```
To more quickly build only an unpacked copy of the runtime in the `./staging` directory, use the `-s` option:
```bash
  prompt> ./build.sh -s
```

## Signing, updates, and distribution

These items are left as an exercise for the reader (and the writer).
