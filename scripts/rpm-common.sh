#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: rpm-common.sh

PACKAGE_NAME='racket9'
PACKAGE_VERSION='9.2.1.1'
PACKAGE_SOURCE_VERSION='9.2.1'
PACKAGE_RELEASE='1'
DEFAULT_PREFIX='/usr'
SOURCE_ARCHIVE_NAME='racket-minimal-9.2.1-src.tgz'
DEFAULT_SOURCE_URL='https://github.com/CutieDeng/racket/releases/download/v9.2.1/racket-minimal-9.2.1-src.tgz'
SOURCE_SHA256='b9c621e5c91822181cff1b1af8813a5abd3e89795089171552dac0f441222bbd'
FILE_LIST_SOURCE_NAME='racket9.files'
SPEC_NAME='racket9.spec'

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
  [ -d "$root/.git" ] || die "repository root is not a Git repository: $root"
  [ -f "$root/SPECS/$SPEC_NAME" ] || die "missing spec file: $root/SPECS/$SPEC_NAME"
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

rpm_name_for_arch() {
  local arch="$1"
  printf '%s-%s-%s.%s.rpm\n' "$PACKAGE_NAME" "$PACKAGE_VERSION" "$PACKAGE_RELEASE" "$arch"
}

srpm_name() {
  printf '%s-%s-%s.src.rpm\n' "$PACKAGE_NAME" "$PACKAGE_VERSION" "$PACKAGE_RELEASE"
}

is_shared_dir() {
  case "$1" in
    /bin|/boot|/dev|/etc|/lib|/lib64|/opt|/run|/sbin|/usr|/usr/bin|/usr/etc|/usr/games|/usr/include|/usr/lib|/usr/lib64|/usr/libexec|/usr/local|/usr/sbin|/usr/share|/usr/share/applications|/usr/share/doc|/usr/share/icons|/usr/share/icons/hicolor|/usr/share/man|/usr/share/man/man1|/usr/share/man/man2|/usr/share/man/man3|/usr/share/man/man4|/usr/share/man/man5|/usr/share/man/man6|/usr/share/man/man7|/usr/share/man/man8|/var) return 0 ;;
    *) return 1 ;;
  esac
}

rpm_file_list_quote() {
  case "$1" in
    *[!A-Za-z0-9_./:=+@%,-]*)
      printf '"%s"' "$(printf '%s' "$1" | sed 's/["\\]/\\&/g')"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

assert_manifest_safe() {
  local manifest="$1"
  require_nonempty_file "$manifest"
  if grep -Eq '^(%dir )?/usr$' "$manifest"; then
    die "manifest must not claim shared /usr: $manifest"
  fi
  if grep -Eq '^(%dir )?/usr/(bin|lib|lib64|share)$' "$manifest"; then
    die "manifest must not claim shared /usr parent directories: $manifest"
  fi
}

generate_file_list() {
  local install_root="$1"
  local manifest="$2"
  require_nonempty_dir "$install_root$PREFIX"
  : > "$manifest"
  while IFS= read -r -d '' path; do
    local rel
    rel=${path#"$install_root"}
    [ -n "$rel" ] || continue
    if [ -d "$path" ] && [ ! -L "$path" ]; then
      if is_shared_dir "$rel"; then
        continue
      fi
      printf '%%dir %s\n' "$(rpm_file_list_quote "$rel")" >> "$manifest"
    elif [ -f "$path" ] || [ -L "$path" ]; then
      printf '%s\n' "$(rpm_file_list_quote "$rel")" >> "$manifest"
    else
      die "unsupported staged file type: $path"
    fi
  done < <(find "$install_root" -mindepth 1 -print0 | sort -z)
  assert_manifest_safe "$manifest"
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
