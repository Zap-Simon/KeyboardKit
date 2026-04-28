#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_FILE="$ROOT_DIR/Demo/Demo.xcodeproj/project.pbxproj"

usage() {
  cat <<'EOF'
Usage:
  ./bump                  # increment build number only
  ./bump patch            # bump patch version and increment build number
  ./bump minor            # bump minor version and increment build number
  ./bump major            # bump major version and increment build number
  ./bump 1.0.1            # set marketing version, increment build number
  ./bump 1.0.1 42         # set marketing version and build number
  ./bump --build 42       # set build number only

Notes:
  - Updates MARKETING_VERSION and CURRENT_PROJECT_VERSION in Demo/Demo.xcodeproj/project.pbxproj
  - Applies to both the app and keyboard extension targets
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

current_marketing=$(awk -F' = ' '/MARKETING_VERSION = / { gsub(/;/, "", $2); print $2; exit }' "$PROJECT_FILE")
current_build=$(awk -F' = ' '/CURRENT_PROJECT_VERSION = / { gsub(/;/, "", $2); print $2; exit }' "$PROJECT_FILE")

IFS='.' read -r current_major current_minor current_patch <<< "$current_marketing"
current_patch=${current_patch:-0}

new_marketing="$current_marketing"
new_build="$current_build"

if [[ $# -eq 0 ]]; then
  new_build=$((current_build + 1))
elif [[ $# -eq 1 ]]; then
  if [[ $1 == "--build" ]]; then
    echo "Missing build number after --build" >&2
    usage >&2
    exit 1
  fi

  case "$1" in
    patch)
      new_marketing="$current_major.$current_minor.$((current_patch + 1))"
      new_build=$((current_build + 1))
      ;;
    minor)
      new_marketing="$current_major.$((current_minor + 1)).0"
      new_build=$((current_build + 1))
      ;;
    major)
      new_marketing="$((current_major + 1)).0.0"
      new_build=$((current_build + 1))
      ;;
    *)
      if [[ $1 =~ ^[0-9]+$ ]]; then
        new_build="$1"
      else
        new_marketing="$1"
        new_build=$((current_build + 1))
      fi
      ;;
  esac
elif [[ $# -eq 2 && $1 == "--build" ]]; then
  new_build="$2"
elif [[ $# -eq 2 ]]; then
  new_marketing="$1"
  new_build="$2"
else
  usage >&2
  exit 1
fi

if [[ ! $new_marketing =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid marketing version: $new_marketing" >&2
  echo "Expected format like 1.0 or 1.0.1" >&2
  exit 1
fi

if [[ ! $new_build =~ ^[0-9]+$ ]]; then
  echo "Invalid build number: $new_build" >&2
  exit 1
fi

export PROJECT_FILE new_marketing new_build

perl -0pi -e 's/MARKETING_VERSION = [^;]+;/sprintf("MARKETING_VERSION = %s;", $ENV{"new_marketing"})/ge; s/CURRENT_PROJECT_VERSION = [^;]+;/sprintf("CURRENT_PROJECT_VERSION = %s;", $ENV{"new_build"})/ge' "$PROJECT_FILE"

echo "Updated marketing version: $current_marketing -> $new_marketing"
echo "Updated build number: $current_build -> $new_build"