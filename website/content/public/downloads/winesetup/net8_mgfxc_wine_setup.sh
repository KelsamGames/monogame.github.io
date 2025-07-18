#!/bin/bash
# This script is used to setup the needed Wine environment
# so that mgfxc can be run on Linux / macOS systems.

# check dependencies
WINEEXECUTABLE="wine64"
if ! type "$WINEEXECUTABLE" > /dev/null 2>&1
then
    WINEEXECUTABLE="wine"
fi

if ! type "$WINEEXECUTABLE" > /dev/null 2>&1
then
    echo "$WINEEXECUTABLE not found"
    exit 1
fi

if ! type "7z" > /dev/null 2>&1
then
    echo "7z not found"
    exit 1
fi

# wine 8 is the minimum requirement for dotnet 8
# wine --version will output "wine-#.# (Distro #.#.#)" or "wine-#.#"
WINE_VERSION=$($WINEEXECUTABLE --version 2>&1 | grep -o 'wine-..' | sed 's/wine-//' | sed 's/\.//')
if (( $WINE_VERSION < 8 )); then
    echo "Wine version $WINE_VERSION is below the minimum required version (8.0)."
    exit 1
fi

# init wine stuff
export WINEARCH=win64
export WINEPREFIX=$HOME/.winemonogame
eval "$WINEEXECUTABLE wineboot"

TEMP_DIR="${TMPDIR:-/tmp}"
SCRIPT_DIR="$TEMP_DIR/winemg2"
mkdir -p "$SCRIPT_DIR"

# disable wine crash dialog
cat > "$SCRIPT_DIR"/crashdialog.reg <<_EOF_
REGEDIT4
[HKEY_CURRENT_USER\\Software\\Wine\\WineDbg]
"ShowCrashDialog"=dword:00000000
_EOF_

pushd $SCRIPT_DIR
eval "$WINEEXECUTABLE regedit crashdialog.reg"
popd

# get dotnet
DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.401/dotnet-sdk-8.0.401-win-x64.zip"
curl $DOTNET_URL --output "$SCRIPT_DIR/dotnet-sdk.zip"
7z x "$SCRIPT_DIR/dotnet-sdk.zip" -o"$WINEPREFIX/drive_c/windows/system32/" -y

# get d3dcompiler_47
FIREFOX_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/62.0.3/win64/ach/Firefox%20Setup%2062.0.3.exe"
curl $FIREFOX_URL --output "$SCRIPT_DIR/firefox.exe"
7z e "$SCRIPT_DIR/firefox.exe" "core/d3dcompiler_47.dll" -o"$WINEPREFIX/drive_c/windows/system32/" -aoa

# append MGFXC_WINE_PATH env variable
echo -e "\nexport MGFXC_WINE_PATH=\"$HOME/.winemonogame\"" >> ~/.profile
echo -e "\nexport MGFXC_WINE_PATH=\"$HOME/.winemonogame\"" >> ~/.zprofile

if ! type "wine64" > /dev/null 2>&1
then
    echo -e "\nexport PATH=\"\$PATH:$HOME/.winemonogame\"" >> ~/.profile
    echo -e "\nexport PATH=\"\$PATH:$HOME/.winemonogame\"" >> ~/.zprofile

    # create a wine wrapper script to work around oddities with symlinked wine64
    echo -e "#\!/bin/bash\nwine \"\$@\"" > "$HOME/.winemonogame/wine_wrapper.sh"
    chmod +x "$HOME/.winemonogame/wine_wrapper.sh"

    # symlink wine64 to our wrapper script
    ln -sf "$HOME/.winemonogame/wine_wrapper.sh" "$HOME/.winemonogame/wine64"
fi

# cleanup
rm -rf "$SCRIPT_DIR"
