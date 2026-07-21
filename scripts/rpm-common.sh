#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: rpm-common.sh

BASE_PACKAGE_NAME='racket9'
PACKAGE_NAME="$BASE_PACKAGE_NAME"
PACKAGE_VERSION='9.2.4'
PACKAGE_SOURCE_VERSION='9.2.4'
DEFAULT_RPM_SYSTEM='openeuler2403'
DEFAULT_RPM_RELEASE='3'
DEFAULT_PREFIX='/usr'
DEFAULT_CACHE_MODE=cached
SOURCE_ARCHIVE_NAME='racket-minimal-9.2.4-src.tgz'
DEFAULT_SOURCE_URL='https://github.com/CutieDeng/racket/releases/download/v9.2.4/racket-minimal-9.2.4-src.tgz'
SOURCE_SHA256='a1b4c1acc5ba2ccd5373c09926afe0ad4ce4010d8564234b15699340f8605956'
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  die "$1. Run with --help for usage."
}

repo_root_from_script() {
  local script_dir
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  CDPATH= cd -- "$script_dir/.." && pwd
}

require_repo_root() {
  local root="$1"
  [ -d "$root" ] || die "repository root does not exist: $root"
  [ -f "$root/SPECS/racket9-cached.spec" ] || die "missing spec file: $root/SPECS/racket9-cached.spec"
  [ -f "$root/SPECS/racket9-postinstall.spec" ] || die "missing spec file: $root/SPECS/racket9-postinstall.spec"
  [ -f "$root/scripts/rpm-common.sh" ] || die "missing common script: $root/scripts/rpm-common.sh"
}

require_file() {
  [ -f "$1" ] || die "file does not exist: $1"
}

require_nonempty_file() {
  require_file "$1"
  [ -s "$1" ] || die "file is empty: $1"
}

require_dir() {
  [ -d "$1" ] || die "directory does not exist: $1"
}

require_nonempty_dir() {
  require_dir "$1"
  if ! find "$1" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    die "directory is empty: $1"
  fi
}

require_absolute_path() {
  case "$1" in
    /*) ;;
    *) die "$2 must be an absolute path: $1" ;;
  esac
}

require_exe() {
  command -v "$1" >/dev/null 2>&1 || die "executable not found in PATH: $1"
}

maybe_require_exe() {
  local dry_run="$1"
  local exe="$2"
  if [ "$dry_run" = 1 ]; then
    printf 'Would require executable: %s\n' "$exe"
  else
    require_exe "$exe"
  fi
}

run_cmd() {
  local dry_run="$1"
  shift
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  if [ "$dry_run" = 0 ]; then
    "$@"
  fi
}

normalize_arch() {
  case "$1" in
    x86_64|x64|amd64) printf 'x86_64\n' ;;
    aarch64|arm64) printf 'aarch64\n' ;;
    *) die "rpm arch must be x86_64, amd64, x64, aarch64, or arm64: $1" ;;
  esac
}

validate_rpm_system() {
  case "$1" in
    el9|fc40|fc43|fc44|openeuler2203|openeuler2403) ;;
    *) die "rpm system must be el9, fc40, fc43, fc44, openeuler2203, or openeuler2403: $1" ;;
  esac
}

validate_rpm_release() {
  local release="$1"
  [ -n "$release" ] || die "rpm release is required"
  case "$release" in
    *.*) die "rpm release must not contain . because system is appended separately: $release" ;;
    [0-9]*) ;;
    *) die "rpm release must start with a digit: $release" ;;
  esac
  case "$release" in
    *[!A-Za-z0-9_+~-]*) die "rpm release contains unsupported characters: $release" ;;
  esac
}

validate_cache_mode() {
  case "$1" in
    postinstall|cached) ;;
    *) die "cache mode must be postinstall or cached: $1" ;;
  esac
}

package_name_for_cache_mode() {
  local mode="$1"
  validate_cache_mode "$mode"
  printf '%s\n' "$BASE_PACKAGE_NAME"
}

cache_mode_rank() {
  local mode="$1"
  validate_cache_mode "$mode"
  case "$mode" in
    postinstall) printf '1\n' ;;
    cached) printf '2\n' ;;
  esac
}

spec_name_for_cache_mode() {
  local mode="$1"
  validate_cache_mode "$mode"
  printf '%s-%s.spec\n' "$BASE_PACKAGE_NAME" "$mode"
}

rpm_full_release() {
  local release="$1"
  local system="$2"
  local mode="${3:-$DEFAULT_CACHE_MODE}"
  printf '%s.%s.%s.%s\n' "$release" "$(cache_mode_rank "$mode")" "$mode" "$system"
}

rpm_name_for_arch() {
  local arch="$1"
  local release="$2"
  local system="$3"
  local mode="${4:-$DEFAULT_CACHE_MODE}"
  local package_name
  package_name=$(package_name_for_cache_mode "$mode")
  printf '%s-%s-%s.%s.rpm\n' "$package_name" "$PACKAGE_VERSION" "$(rpm_full_release "$release" "$system" "$mode")" "$arch"
}

srpm_name() {
  local release="$1"
  local system="$2"
  local mode="${3:-$DEFAULT_CACHE_MODE}"
  printf '%s-%s-%s.src.rpm\n' "$PACKAGE_NAME" "$PACKAGE_VERSION" "$(rpm_full_release "$release" "$system" "$mode")"
}

materialize_spec() {
  local source_spec="$1"
  local dest_spec="$2"
  local mode="$3"
  local release="$4"
  local system="$5"
  local prefix="$6"
  validate_cache_mode "$mode"
  awk -v mode="$mode" -v release="$release" -v target_system="$system" -v prefix="$prefix" '
$1 == "%global" && $2 == "cache_mode" { print "%global cache_mode " mode; next }
$1 == "%global" && $2 == "package_release" { print "%global package_release " release; next }
$1 == "%global" && $2 == "package_system" { print "%global package_system " target_system; next }
$1 == "%global" && $2 == "package_prefix" { print "%global package_prefix " prefix; next }
{ print }
' "$source_spec" > "$dest_spec"
  grep -Fx "%global cache_mode $mode" "$dest_spec" >/dev/null || die "failed to materialize cache mode in spec"
  grep -Fx "%global package_release $release" "$dest_spec" >/dev/null || die "failed to materialize release in spec"
  grep -Fx "%global package_system $system" "$dest_spec" >/dev/null || die "failed to materialize system in spec"
  grep -Fx "%global package_prefix $prefix" "$dest_spec" >/dev/null || die "failed to materialize prefix in spec"
}

reset_output_dir() {
  local dry_run="$1"
  local path="$2"
  require_absolute_path "$path" "output directory"
  if [ "$path" = / ]; then
    die "refusing to reset / as output directory"
  fi
  if [ "$dry_run" = 1 ]; then
    printf 'Would reset output directory: %s\n' "$path"
  else
    rm -rf "$path"
    mkdir -p "$path"
  fi
}

prepare_rpmbuild_tree() {
  local dry_run="$1"
  local rpm_root="$2"
  reset_output_dir "$dry_run" "$rpm_root"
  if [ "$dry_run" = 0 ]; then
    mkdir -p "$rpm_root/BUILD" "$rpm_root/BUILDROOT" "$rpm_root/RPMS" \
             "$rpm_root/SOURCES" "$rpm_root/SPECS" "$rpm_root/SRPMS"
  fi
}

validate_source_archive() {
  local dry_run="$1"
  local archive="$2"
  local expected_root="racket-$PACKAGE_SOURCE_VERSION"
  if [ "$dry_run" = 1 ]; then
    printf 'Would validate source archive: %s\n' "$archive"
    return
  fi
  require_nonempty_file "$archive"
  tar -tzf "$archive" "$expected_root/src/configure" >/dev/null \
    || die "source archive missing $expected_root/src/configure: $archive"
  tar -tzf "$archive" "$expected_root/collects/racket/main.rkt" >/dev/null \
    || die "source archive missing $expected_root/collects/racket/main.rkt: $archive"
}

verify_source_sha256() {
  local dry_run="$1"
  local archive="$2"
  if [ -z "$SOURCE_SHA256" ]; then
    printf 'No generated source sha256 is pinned; skipping source sha256 check.\n'
    return
  fi
  if [ "$dry_run" = 1 ]; then
    printf 'Would verify source sha256: %s\n' "$SOURCE_SHA256"
    return
  fi
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$archive" | cut -d ' ' -f 1)
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
  else
    die "executable not found in PATH: sha256sum or shasum"
  fi
  [ "$actual" = "$SOURCE_SHA256" ] \
    || die "source sha256 mismatch: expected $SOURCE_SHA256 but got $actual"
}

prepare_source_archive() {
  local dry_run="$1"
  local source_archive="$2"
  local source_url="$3"
  local dest="$4"
  require_absolute_path "$dest" "source archive destination"
  if [ "$dry_run" = 0 ]; then
    mkdir -p "$(dirname "$dest")"
  fi
  if [ -n "$source_archive" ]; then
    require_nonempty_file "$source_archive"
    run_cmd "$dry_run" cp "$source_archive" "$dest"
  else
    [ -n "$source_url" ] || die "source URL is empty"
    maybe_require_exe "$dry_run" curl
    run_cmd "$dry_run" curl -fL --retry 3 --output "$dest" "$source_url"
  fi
  validate_source_archive "$dry_run" "$dest"
  verify_source_sha256 "$dry_run" "$dest"
}
