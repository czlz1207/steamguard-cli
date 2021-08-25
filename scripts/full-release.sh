#!/bin/bash

set -e

DRY_RUN=true

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --execute)
      DRY_RUN=false
      shift # past argument
      ;;
    --bump)
      BUMP="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

echo """
This will do everything needed to release a new version:
- bump the version number
- create a git tag
- build all artifacts
- publish crates on crates.io
- upload artifacts to a new release on github
"""
if [ "$DRY_RUN" = true ]; then
	echo "This is a dry run, nothing will be done. Artifacts will be built, but not published."
else
	echo "This is not a dry run. This is the real deal!"
fi
echo "Press any key to continue..."
read -n 1 -s -r

params=()
if [[ $DRY_RUN == false ]]; then
	params+=(--execute)
fi
if [[ $BUMP != "" ]]; then
	params+=(--bump "$BUMP")
fi
cargo smart-release "${params[@]}"

./scripts/package-deb.sh

BIN_PATH="target/release/steamguard-cli"
RAW_VERSION="$("$BIN_PATH" --version | cut -d " " -f 2)"
VERSION="v$RAW_VERSION"

if [[ $DRY_RUN == false ]]; then
	gh release create "$VERSION" --title "$VERSION" --draft "$BIN_PATH" "./steamguard-cli_$RAW_VERSION-0.deb"
fi

# update PKGBUILD for AUR
if [[ -d "aur" ]]; then
	rm -rf aur
fi
git clone ssh://aur@aur.archlinux.org/steamguard-cli-git.git aur
cargo pkgbuild
mv PKGBUILD aur/PKGBUILD
cd aur
git commit -m "release $VERSION" PKGBUILD
if [[ $DRY_RUN == false ]]; then
	git push
	rm -rf aur
fi
cd ..
