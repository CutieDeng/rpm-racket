#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: build-rpm.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/rpm-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/build-rpm.sh --racket-root PATH --artifact-dir PATH --work-dir PATH --rpm-arch ARCH [options]

Build a binary RPM from SPECS/racket9.spec. All mutable paths are named.

Options:
  --racket-root PATH     Racket source checkout used by make unix-style.
  --make-dir PATH        Directory containing Makefile. Defaults to --racket-root.
  --skip-build           Reuse --install-root instead of running make.
  --install-root PATH    Staged filesystem root. Required with --skip-build.
  --artifact-dir PATH    Directory that receives the final .rpm.
  --work-dir PATH        Build work directory for rpmbuild and staging.
  --prefix PATH          Install prefix inside the package. Defaults to generated /usr.
  --rpm-arch ARCH        x86_64, amd64, x64, aarch64, or arm64.
  --jobs N               Parallel jobs passed to make unix-style.
  --make-arg ARG         Extra make argument. May be repeated.
  --dry-run              Print checks and commands without writing outputs.
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
maybe_require_exe "$DRY_RUN" rpm
maybe_require_exe "$DRY_RUN" rpmbuild

RPMBUILD_ROOT="$WORK_DIR/rpmbuild"
SPEC_PATH="$RPMBUILD_ROOT/SPECS/$SPEC_NAME"
RPM_NAME=$(rpm_name_for_arch "$NORMALIZED_ARCH")
RPM_OUTPUT="$RPMBUILD_ROOT/RPMS/$NORMALIZED_ARCH/$RPM_NAME"

printf 'Repository root: %s\n' "$REPO_ROOT"
printf 'RPM output: %s\n' "$ARTIFACT_DIR/$RPM_NAME"

stage_install_root "$DRY_RUN" "$SKIP_BUILD" "$RACKET_ROOT" "$MAKE_DIR" "$INSTALL_ROOT" "$JOBS" "${MAKE_ARGS[@]}"
prepare_rpmbuild_tree "$DRY_RUN" "$RPMBUILD_ROOT"
if [ "$DRY_RUN" = 0 ]; then
  cp "$REPO_ROOT/SPECS/$SPEC_NAME" "$SPEC_PATH"
fi
create_payload_sources "$DRY_RUN" "$INSTALL_ROOT" "$RPMBUILD_ROOT/SOURCES"
run_cmd "$DRY_RUN" rpmbuild -bb --target "$NORMALIZED_ARCH" \
  --define "_topdir $RPMBUILD_ROOT" --define "_build_id_links none" "$SPEC_PATH"

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would copy RPM artifact: %s -> %s\n' "$RPM_OUTPUT" "$ARTIFACT_DIR/$RPM_NAME"
else
  require_nonempty_file "$RPM_OUTPUT"
  mkdir -p "$ARTIFACT_DIR"
  cp "$RPM_OUTPUT" "$ARTIFACT_DIR/$RPM_NAME"
  "$REPO_ROOT/scripts/verify-rpm.sh" --rpm "$ARTIFACT_DIR/$RPM_NAME" --rpm-arch "$NORMALIZED_ARCH"
  printf 'RPM package: %s\n' "$ARTIFACT_DIR/$RPM_NAME"
fi
