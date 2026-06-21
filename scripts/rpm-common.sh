#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: rpm-common.sh

PACKAGE_NAME='racket9'
PACKAGE_VERSION='9.2.1.1'
PACKAGE_RELEASE='1'
DEFAULT_PREFIX='/usr'
PAYLOAD_SOURCE_NAME='racket9-9.2.1.1-payload.tar.gz'
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

stage_install_root() {
  local dry_run="$1"
  local skip_build="$2"
  local racket_root="$3"
  local make_dir="$4"
  local install_root="$5"
  local jobs="$6"
  shift 6
  local make_args=("$@")
  require_absolute_path "$install_root" "install root"
  if [ "$skip_build" = 1 ]; then
    require_nonempty_dir "$install_root$PREFIX"
    return
  fi
  require_dir "$racket_root/racket/src"
  require_dir "$racket_root/racket/collects"
  require_file "$racket_root/racket/src/version/racket_version.h"
  require_file "$make_dir/Makefile"
  reset_output_dir "$dry_run" "$install_root"
  run_cmd "$dry_run" make -C "$make_dir" unix-style \
    "PREFIX=$PREFIX" "DESTDIR=$install_root" "JOBS=$jobs" "${make_args[@]}"
}

create_payload_sources() {
  local dry_run="$1"
  local install_root="$2"
  local sources_dir="$3"
  local payload_path="$sources_dir/$PAYLOAD_SOURCE_NAME"
  local manifest_path="$sources_dir/$FILE_LIST_SOURCE_NAME"
  if [ "$dry_run" = 0 ]; then
    mkdir -p "$sources_dir"
  fi
  run_cmd "$dry_run" tar -C "$install_root" -czf "$payload_path" .
  if [ "$dry_run" = 1 ]; then
    printf 'Would generate RPM file manifest: %s\n' "$manifest_path"
  else
    generate_file_list "$install_root" "$manifest_path"
  fi
}
