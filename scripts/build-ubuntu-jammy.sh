#!/usr/bin/env bash
# Build a Debian package of cockpit-navigator for Ubuntu Jammy.
# Run from the repository root: ./scripts/build-ubuntu-jammy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PACKAGING_DIR="$REPO_ROOT/packaging/ubuntu-jammy"
MANIFEST="$REPO_ROOT/manifest.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Build dependencies: package-name -> command it provides
BUILD_DEPS=(
    python3
    dpkg-dev
    debhelper
    fakeroot
)

install_build_deps() {
    local missing=()
    for pkg in "${BUILD_DEPS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "==> All build dependencies already installed"
        return
    fi

    echo "==> Installing missing build dependencies: ${missing[*]}"
    if [[ $EUID -eq 0 ]]; then
        apt-get update -qq
        apt-get install -y -qq "${missing[@]}"
    else
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${missing[@]}"
    fi
}

# Read a simple top-level string value from manifest.json (no nested keys).
json_val() {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$MANIFEST" "$1"
}

# Read a nested value using dot-separated key path (e.g. architecture.ubuntu).
json_nested() {
    python3 -c "
import json, sys, functools, operator
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split('.')
print(functools.reduce(operator.getitem, keys, data))
" "$MANIFEST" "$1"
}

# Read a nested list and join with ', ' (for dependencies).
json_join_list() {
    python3 -c "
import json, sys, functools, operator
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split('.')
print(', '.join(functools.reduce(operator.getitem, keys, data)))
" "$MANIFEST" "$1"
}

# ---------------------------------------------------------------------------
# Install build dependencies if missing
# ---------------------------------------------------------------------------
install_build_deps

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Read values from manifest.json
# ---------------------------------------------------------------------------
PKG_NAME="$(json_val name)"
PKG_VERSION="$(json_val version)"
PKG_DESCRIPTION="$(json_val description)"
PKG_AUTHOR="$(json_val author)"
PKG_GIT_URL="$(json_val git_url)"
PKG_ARCH="$(json_nested architecture.ubuntu)"
PKG_DEPS="$(json_join_list dependencies.ubuntu_common)"

echo "==> Building $PKG_NAME $PKG_VERSION for Ubuntu Jammy"

# ---------------------------------------------------------------------------
# Render Jinja2-style templates into debian/ directory
# ---------------------------------------------------------------------------
DEBIAN_DIR="$REPO_ROOT/debian"
rm -rf "$DEBIAN_DIR"
mkdir -p "$DEBIAN_DIR/source"

# control
sed -e "s/{{ name }}/$PKG_NAME/g" \
    -e "s/{{ author }}/$PKG_AUTHOR/g" \
    -e "s/{{ git_url }}/${PKG_GIT_URL//\//\\/}/g" \
    -e "s/{{ architecture.ubuntu }}/$PKG_ARCH/g" \
    -e "s/{{ dependencies.ubuntu_common | join(',') }}/$PKG_DEPS/g" \
    -e "s/{{ description }}/$PKG_DESCRIPTION/g" \
    "$PACKAGING_DIR/control.j2" > "$DEBIAN_DIR/control"

# copyright
sed -e "s/{{ name }}/$PKG_NAME/g" \
    -e "s/{{ author }}/$PKG_AUTHOR/g" \
    -e "s/{{ git_url }}/${PKG_GIT_URL//\//\\/}/g" \
    "$PACKAGING_DIR/copyright.j2" > "$DEBIAN_DIR/copyright"

# changelog, rules, source/format (plain copies)
cp "$PACKAGING_DIR/changelog"       "$DEBIAN_DIR/changelog"
cp "$PACKAGING_DIR/rules"           "$DEBIAN_DIR/rules"
cp "$PACKAGING_DIR/source/format"   "$DEBIAN_DIR/source/format"

chmod +x "$DEBIAN_DIR/rules"

echo "==> debian/ directory prepared"

# ---------------------------------------------------------------------------
# Build the package
# ---------------------------------------------------------------------------
echo "==> Running dpkg-buildpackage"
dpkg-buildpackage -us -uc -b

echo ""
echo "==> Build complete. Package(s):"
ls -1 "$REPO_ROOT"/../${PKG_NAME}_*.deb 2>/dev/null || echo "(check parent directory for .deb files)"
