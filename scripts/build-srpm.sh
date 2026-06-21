#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: build-srpm.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/rpm-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/build-srpm.sh --racket-root PATH --artifact-dir PATH --work-dir PATH --rpm-arch ARCH [options]

Build a source RPM from SPECS/racket9.spec. This SRPM contains the staged
payload tarball and generated RPM file manifest used by the binary build.
USAGE
}

DRY_RUN=0
SKIP_BUILD=0
RACKET_ROOT=
MAKE_DIR=
INSTALL_ROOT=
ARTIFACT_DIR=
WORK_DIR=
RPM_ARCH=
JOBS=1
PREFIX="$DEFAULT_PREFIX"
MAKE_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --racket-root) [ $# -ge 2 ] || usage_error "missing value for --racket-root"; RACKET_ROOT="$2"; shift 2 ;;
    --make-dir) [ $# -ge 2 ] || usage_error "missing value for --make-dir"; MAKE_DIR="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --install-root) [ $# -ge 2 ] || usage_error "missing value for --install-root"; INSTALL_ROOT="$2"; shift 2 ;;
    --artifact-dir) [ $# -ge 2 ] || usage_error "missing value for --artifact-dir"; ARTIFACT_DIR="$2"; shift 2 ;;
    --work-dir) [ $# -ge 2 ] || usage_error "missing value for --work-dir"; WORK_DIR="$2"; shift 2 ;;
    --prefix) [ $# -ge 2 ] || usage_error "missing value for --prefix"; PREFIX="$2"; shift 2 ;;
    --rpm-arch) [ $# -ge 2 ] || usage_error "missing value for --rpm-arch"; RPM_ARCH="$2"; shift 2 ;;
    --jobs) [ $# -ge 2 ] || usage_error "missing value for --jobs"; JOBS="$2"; shift 2 ;;
    --make-arg) [ $# -ge 2 ] || usage_error "missing value for --make-arg"; MAKE_ARGS+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

REPO_ROOT=$(repo_root_from_script)
require_repo_root "$REPO_ROOT"
[ -n "$ARTIFACT_DIR" ] || usage_error "--artifact-dir is required"
[ -n "$WORK_DIR" ] || usage_error "--work-dir is required"
[ -n "$RPM_ARCH" ] || usage_error "--rpm-arch is required"
NORMALIZED_ARCH=$(normalize_arch "$RPM_ARCH")
if [ "$SKIP_BUILD" = 0 ]; then
  [ -n "$RACKET_ROOT" ] || usage_error "--racket-root is required unless --skip-build is used"
fi
[ -n "$MAKE_DIR" ] || MAKE_DIR="$RACKET_ROOT"
[ -n "$INSTALL_ROOT" ] || INSTALL_ROOT="$WORK_DIR/install-root"

maybe_require_exe "$DRY_RUN" make
maybe_require_exe "$DRY_RUN" tar
maybe_require_exe "$DRY_RUN" rpmbuild

RPMBUILD_ROOT="$WORK_DIR/rpmbuild-srpm"
SPEC_PATH="$RPMBUILD_ROOT/SPECS/$SPEC_NAME"
SRPM_NAME=$(srpm_name)
SRPM_OUTPUT="$RPMBUILD_ROOT/SRPMS/$SRPM_NAME"

printf 'Repository root: %s\n' "$REPO_ROOT"
printf 'SRPM output: %s\n' "$ARTIFACT_DIR/$SRPM_NAME"

stage_install_root "$DRY_RUN" "$SKIP_BUILD" "$RACKET_ROOT" "$MAKE_DIR" "$INSTALL_ROOT" "$JOBS" "${MAKE_ARGS[@]}"
prepare_rpmbuild_tree "$DRY_RUN" "$RPMBUILD_ROOT"
if [ "$DRY_RUN" = 0 ]; then
  cp "$REPO_ROOT/SPECS/$SPEC_NAME" "$SPEC_PATH"
fi
create_payload_sources "$DRY_RUN" "$INSTALL_ROOT" "$RPMBUILD_ROOT/SOURCES"
run_cmd "$DRY_RUN" rpmbuild -bs --target "$NORMALIZED_ARCH" \
  --define "_topdir $RPMBUILD_ROOT" "$SPEC_PATH"

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would copy SRPM artifact: %s -> %s\n' "$SRPM_OUTPUT" "$ARTIFACT_DIR/$SRPM_NAME"
else
  require_nonempty_file "$SRPM_OUTPUT"
  mkdir -p "$ARTIFACT_DIR"
  cp "$SRPM_OUTPUT" "$ARTIFACT_DIR/$SRPM_NAME"
  printf 'SRPM package: %s\n' "$ARTIFACT_DIR/$SRPM_NAME"
fi
