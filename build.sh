#!/usr/bin/env bash
set -euo pipefail

BRAND="BigoGram"
TWEAK_DYLIB="${BRAND}.dylib"
BUNDLE_NAME="${BRAND}.bundle"

if [ -z "${THEOS:-}" ]; then
    if [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    else
        echo "THEOS not set and ~/theos not found."
        exit 1
    fi
fi

copy_localization_into_bundle() {
    local dest="$1"
    local src="src/Localization/Resources"
    [ -d "$src" ] || return 0
    mkdir -p "$dest"
    for lproj in "$src"/*.lproj; do
        [ -d "$lproj" ] || continue
        cp -R "$lproj" "$dest/"
    done
}

copy_bundle_assets() {
    local dest="$1"
    local src="src/BundleAssets"
    [ -d "$src" ] || return 0
    mkdir -p "$dest"
    find "$src" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.pdf' \) -exec cp {} "$dest/" \;
}

build_zxpi_dylib() {
    local mod_dir="modules/zxPluginsInject"
    local out="$mod_dir/.theos/obj/zxPluginsInject.dylib"
    ( cd "$mod_dir" && make FINALPACKAGE=1 >/dev/null )
    [ -f "$out" ] || { echo "zxPluginsInject build failed" >&2; exit 1; }
    mkdir -p packages
    cp "$out" packages/zxPluginsInject.dylib
    install_name_tool -id "@rpath/zxPluginsInject.dylib" packages/zxPluginsInject.dylib 2>/dev/null || true
}

find_instagram_ipa() {
    mkdir -p packages
    local ipa
    ipa="$(find ./packages/ -maxdepth 1 -type f \( -iname '*com.burbn.instagram*.ipa' -o -iname 'Instagram*.ipa' -o -iname '[0-9]*.ipa' \) ! -iname "${BRAND}*.ipa" -exec basename {} \; 2>/dev/null | head -1)"
    if [ -z "$ipa" ]; then
        local cwd_ipa
        cwd_ipa="$(find . -maxdepth 1 -type f \( -iname '*com.burbn.instagram*.ipa' -o -iname 'Instagram*.ipa' -o -iname '[0-9]*.ipa' \) 2>/dev/null | head -1)"
        if [ -n "$cwd_ipa" ]; then
            mv "$cwd_ipa" packages/
            ipa="$(basename "$cwd_ipa")"
        fi
    fi
    [ -n "$ipa" ] || { echo "Instagram IPA not found. Place it in ./packages." >&2; exit 1; }
    echo "$ipa"
}

bundle_path="packages/${BUNDLE_NAME}"
make_bundle() {
    rm -rf "$bundle_path"
    mkdir -p "$bundle_path"
    copy_localization_into_bundle "$bundle_path"
    copy_bundle_assets "$bundle_path"
}

embed_safari_extension() {
    local ipa="$1"
    local appex_src="extensions/OpenInstagramSafariExtension.appex"
    [ -d "$appex_src" ] || return 0
    local tmp
    tmp="$(mktemp -d)"
    unzip -q "$ipa" -d "$tmp"
    local app_dir
    app_dir="$(find "$tmp/Payload" -maxdepth 1 -type d -name '*.app' | head -1)"
    if [ -n "$app_dir" ]; then
        mkdir -p "$app_dir/PlugIns"
        rm -rf "$app_dir/PlugIns/OpenInstagramSafariExtension.appex"
        cp -R "$appex_src" "$app_dir/PlugIns/"
        ( cd "$tmp" && zip -qr ../repacked.ipa Payload )
        mv "$tmp/../repacked.ipa" "$ipa"
    fi
    rm -rf "$tmp"
}

run_ipapatch() {
    local ipa="$1"
    command -v ipapatch >/dev/null || { echo "ipapatch not found" >&2; exit 1; }
    ipapatch --input "$ipa" --inplace --noconfirm --dylib packages/zxPluginsInject.dylib
}

build_dylib() {
    [ "${1:-}" = "--fast" ] || { make clean 2>/dev/null || true; rm -rf .theos; }
    make
    mkdir -p packages
    cp ".theos/obj/debug/${TWEAK_DYLIB}" "packages/${TWEAK_DYLIB}"
    make_bundle
    echo "Done. Library: $(pwd)/packages/${TWEAK_DYLIB}"
    echo "Bundle: $(pwd)/packages/${BUNDLE_NAME}"
}

build_sideload() {
    command -v cyan >/dev/null || { echo "cyan not found" >&2; exit 1; }
    local ipa
    ipa="$(find_instagram_ipa)"
    make clean 2>/dev/null || true
    rm -rf .theos
    make SIDELOAD=1
    build_zxpi_dylib
    mkdir -p packages
    cp ".theos/obj/debug/${TWEAK_DYLIB}" "packages/${TWEAK_DYLIB}"
    make_bundle
    local out="packages/${BRAND}-sideloaded.ipa"
    rm -f "$out"
    cyan -i "packages/${ipa}" -o "$out" -f "packages/${TWEAK_DYLIB}" "$bundle_path" -c 9 -m 15.0 -du
    embed_safari_extension "$out"
    run_ipapatch "$out"
    echo "Done. IPA: $(pwd)/$out"
}

build_trollstore() {
    build_sideload
    mv "packages/${BRAND}-sideloaded.ipa" "packages/${BRAND}-trollstore.tipa"
    echo "TIPA: $(pwd)/packages/${BRAND}-trollstore.tipa"
}

inject_bundle_into_deb() {
    local deb="$1"
    local tmp
    tmp="$(mktemp -d)"
    dpkg-deb -R "$deb" "$tmp"
    local dylib_dir
    dylib_dir="$(find "$tmp" -name "${TWEAK_DYLIB}" -exec dirname {} \; | head -1)"
    [ -n "$dylib_dir" ] || { rm -rf "$tmp"; return 0; }
    local prefix=""
    [[ "$dylib_dir" == *"/var/jb/"* ]] && prefix="var/jb/"
    local dest="$tmp/${prefix}Library/Application Support/${BUNDLE_NAME}"
    ( cd .. && copy_localization_into_bundle "$dest" && copy_bundle_assets "$dest" )
    dpkg-deb -b "$tmp" "$deb"
    rm -rf "$tmp"
}

build_deb() {
    local mode="$1"
    make clean 2>/dev/null || true
    rm -rf .theos
    if [ "$mode" = "rootless" ]; then
        export THEOS_PACKAGE_SCHEME=rootless
    else
        unset THEOS_PACKAGE_SCHEME
    fi
    make package
    cd packages
    local deb
    deb="$(ls -t *.deb | head -n1)"
    if [ -n "$deb" ]; then
        inject_bundle_into_deb "$deb"
        mv "$deb" "${deb%.deb}-${mode}.deb"
    fi
    cd ..
    echo "Done. Packages are in $(pwd)/packages"
}

case "${1:-}" in
    dylib) build_dylib "${2:-}" ;;
    sideload) build_sideload ;;
    trollstore) build_trollstore ;;
    rootless) build_deb rootless ;;
    rootful) build_deb rootful ;;
    *)
        echo "Usage: ./build.sh <dylib/sideload/trollstore/rootless/rootful>"
        exit 1
        ;;
esac
