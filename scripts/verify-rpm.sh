#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: verify-rpm.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/rpm-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/verify-rpm.sh --rpm PATH --rpm-system SYSTEM --rpm-release RELEASE --rpm-arch ARCH [--cache-mode MODE] [--dry-run]

Validate RPM metadata and payload ownership boundaries.
USAGE
}

DRY_RUN=0
RPM_PATH=
RPM_SYSTEM=
RPM_RELEASE=
RPM_ARCH=
CACHE_MODE="$DEFAULT_CACHE_MODE"

while [ $# -gt 0 ]; do
  case "$1" in
    --rpm) [ $# -ge 2 ] || usage_error "missing value for --rpm"; RPM_PATH="$2"; shift 2 ;;
    --rpm-system) [ $# -ge 2 ] || usage_error "missing value for --rpm-system"; RPM_SYSTEM="$2"; shift 2 ;;
    --rpm-release) [ $# -ge 2 ] || usage_error "missing value for --rpm-release"; RPM_RELEASE="$2"; shift 2 ;;
    --rpm-arch) [ $# -ge 2 ] || usage_error "missing value for --rpm-arch"; RPM_ARCH="$2"; shift 2 ;;
    --cache-mode) [ $# -ge 2 ] || usage_error "missing value for --cache-mode"; CACHE_MODE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

REPO_ROOT=$(repo_root_from_script)
require_repo_root "$REPO_ROOT"
[ -n "$RPM_PATH" ] || usage_error "--rpm is required"
[ -n "$RPM_SYSTEM" ] || usage_error "--rpm-system is required"
[ -n "$RPM_RELEASE" ] || usage_error "--rpm-release is required"
[ -n "$RPM_ARCH" ] || usage_error "--rpm-arch is required"
validate_rpm_system "$RPM_SYSTEM"
validate_rpm_release "$RPM_RELEASE"
validate_cache_mode "$CACHE_MODE"
NORMALIZED_ARCH=$(normalize_arch "$RPM_ARCH")
RPM_PACKAGE_NAME=$(package_name_for_cache_mode "$CACHE_MODE")
RPM_FULL_RELEASE=$(rpm_full_release "$RPM_RELEASE" "$RPM_SYSTEM")
EXPECTED_RPM=$(rpm_name_for_arch "$NORMALIZED_ARCH" "$RPM_RELEASE" "$RPM_SYSTEM" "$CACHE_MODE")

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would verify RPM: %s\n' "$RPM_PATH"
  printf 'Would expect RPM system: %s\n' "$RPM_SYSTEM"
  printf 'Would expect RPM release: %s\n' "$RPM_RELEASE"
  printf 'Would expect RPM full release: %s\n' "$RPM_FULL_RELEASE"
  printf 'Would expect RPM cache mode: %s\n' "$CACHE_MODE"
  printf 'Would expect RPM package name: %s\n' "$RPM_PACKAGE_NAME"
  printf 'Would expect RPM basename: %s\n' "$EXPECTED_RPM"
  exit 0
fi

require_exe rpm
require_nonempty_file "$RPM_PATH"
[ "$(basename "$RPM_PATH")" = "$EXPECTED_RPM" ] || die "RPM basename does not match expected $EXPECTED_RPM: $RPM_PATH"

metadata=$(rpm -qip "$RPM_PATH")
printf '%s\n' "$metadata"
printf '%s\n' "$metadata" | grep -F "Name        : $RPM_PACKAGE_NAME" >/dev/null || die "RPM metadata missing expected name"
printf '%s\n' "$metadata" | grep -F "Version     : $PACKAGE_VERSION" >/dev/null || die "RPM metadata missing expected version"
printf '%s\n' "$metadata" | grep -F "Release     : $RPM_FULL_RELEASE" >/dev/null || die "RPM metadata missing expected release"
printf '%s\n' "$metadata" | grep -F "Architecture: $NORMALIZED_ARCH" >/dev/null || die "RPM metadata missing expected architecture"

payload=$(rpm -qpl "$RPM_PATH")
if printf '%s\n' "$payload" | grep -Fx '/var/cache/racket/racket-compiled-cache.log' >/dev/null; then
  die "RPM payload unexpectedly includes racket compiled cache debug log"
fi
if printf '%s\n' "$payload" | grep -Eq '^/usr$|^/usr/(bin|lib|lib64|share)$'; then
  die "RPM payload claims shared /usr parent directory"
fi
if [ "$CACHE_MODE" = postinstall ]; then
  if printf '%s\n' "$payload" | grep -E '^/var/cache/racket/compiled/.+[.]zo$' >/dev/null; then
    die "postinstall RPM payload unexpectedly includes system compiled cache .zo files"
  fi
else
  printf '%s\n' "$payload" | grep -E '^/var/cache/racket/compiled/.+[.]zo$' >/dev/null \
    || die "cached RPM payload does not include system compiled cache .zo files"
  runtime_collects_cache="/var/cache/racket/compiled/${DEFAULT_PREFIX#/}/share/racket/collects"
  printf '%s\n' "$payload" | grep -F "$runtime_collects_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached RPM payload does not include runtime-keyed collects cache .zo files"
  runtime_pkgs_cache="/var/cache/racket/compiled/${DEFAULT_PREFIX#/}/share/racket/pkgs"
  printf '%s\n' "$payload" | grep -F "$runtime_pkgs_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached RPM payload does not include runtime-keyed package cache .zo files"
  rhombus_ephemeral_cache="$DEFAULT_PREFIX/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod"
  printf '%s\n' "$payload" | grep -F "$rhombus_ephemeral_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached RPM payload does not include Rhombus demod cache .zo files"
fi
scripts=$(rpm -qp --scripts "$RPM_PATH")
if [ "$CACHE_MODE" = postinstall ]; then
  printf '%s\n' "$scripts" | grep -F 'raco setup --system --no-user --reset-cache -D --no-pkg-deps' >/dev/null \
    || die "RPM scriptlets do not build the system compiled cache"
  printf '%s\n' "$scripts" | grep -F 'raco setup --system --delete-cache' >/dev/null \
    || die "RPM scriptlets do not delete the system compiled cache"
  printf '%s\n' "$scripts" | grep -F "rpm -q --quiet $CACHED_PACKAGE_NAME >/dev/null 2>&1" >/dev/null \
    || die "RPM preun does not guard cache deletion for package replacement"
  printf '%s\n' "$scripts" | grep -F 'package-racket-rhombus-cache' >/dev/null \
    || die "RPM scriptlets do not warm the Rhombus demod cache"
  printf '%s\n' "$scripts" | grep -F 'racket -U -R "$compiled_cache_root" -N rhombus -l- rhombus/run.rhm --version' >/dev/null \
    || die "RPM scriptlets do not warm the Rhombus version cache into the system cache"
else
  if printf '%s\n' "$scripts" | grep -F 'raco setup --system --no-user --reset-cache -D --no-pkg-deps' >/dev/null; then
    die "cached RPM scriptlets unexpectedly build the system compiled cache"
  fi
  if printf '%s\n' "$scripts" | grep -F 'raco setup --system --delete-cache' >/dev/null; then
    die "cached RPM scriptlets unexpectedly delete the system compiled cache through raco"
  fi
fi
printf '%s\n' "$scripts" | grep -F 'rm -rf /var/cache/racket/compiled' >/dev/null \
  || die "RPM scriptlets do not purge the system compiled cache directory"
printf '%s\n' "$scripts" | grep -F 'rhombus-lib/rhombus/private/compiled/ephemeral/demod' >/dev/null \
  || die "RPM scriptlets do not purge the Rhombus demod cache directory"
printf '%s\n' "$scripts" | grep -F "rmdir $DEFAULT_PREFIX/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral" >/dev/null \
  || die "RPM scriptlets do not remove empty Rhombus ephemeral cache parents"
printf '%s\n' "$scripts" | grep -F 'rpm -q --quiet "$other_package" >/dev/null 2>&1' >/dev/null \
  || die "RPM postun does not guard shared cache deletion for package replacement"
printf 'Validated RPM: %s\n' "$RPM_PATH"
