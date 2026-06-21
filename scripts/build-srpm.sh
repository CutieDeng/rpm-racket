#!/usr/bin/env bash
set -euo pipefail

# GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.
# Generated entrypoint: build-srpm.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/rpm-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/build-srpm.sh --artifact-dir PATH --work-dir PATH --rpm-arch ARCH [options]

Build a source RPM from SPECS/racket9.spec and a stable source archive.

Options:
  --source-archive PATH  Local racket-minimal-9.2.1-src.tgz to copy into rpmbuild.
  --source-url URL       Source archive URL. Defaults to the generated release URL.
  --artifact-dir PATH    Directory that receives the final .src.rpm.
  --work-dir PATH        Build work directory for rpmbuild.
  --prefix PATH          Install prefix inside the package. Defaults to generated /usr.
  --rpm-arch ARCH        x86_64, amd64, x64, aarch64, or arm64.
  --jobs N               Parallel jobs recorded in generated build macros.
  --rpmbuild-arg ARG     Extra rpmbuild argument. May be repeated.
  --dry-run              Print checks and commands without writing outputs.
USAGE
}

DRY_RUN=0
SOURCE_ARCHIVE=
SOURCE_URL="$DEFAULT_SOURCE_URL"
SOURCE_URL_EXPLICIT=0
ARTIFACT_DIR=
WORK_DIR=
RPM_ARCH=
JOBS=1
PREFIX="$DEFAULT_PREFIX"
RPMBUILD_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --source-archive) [ $# -ge 2 ] || usage_error "missing value for --source-archive"; SOURCE_ARCHIVE="$2"; shift 2 ;;
    --source-url) [ $# -ge 2 ] || usage_error "missing value for --source-url"; SOURCE_URL="$2"; SOURCE_URL_EXPLICIT=1; shift 2 ;;
    --artifact-dir) [ $# -ge 2 ] || usage_error "missing value for --artifact-dir"; ARTIFACT_DIR="$2"; shift 2 ;;
    --work-dir) [ $# -ge 2 ] || usage_error "missing value for --work-dir"; WORK_DIR="$2"; shift 2 ;;
    --prefix) [ $# -ge 2 ] || usage_error "missing value for --prefix"; PREFIX="$2"; shift 2 ;;
    --rpm-arch) [ $# -ge 2 ] || usage_error "missing value for --rpm-arch"; RPM_ARCH="$2"; shift 2 ;;
    --jobs) [ $# -ge 2 ] || usage_error "missing value for --jobs"; JOBS="$2"; shift 2 ;;
    --rpmbuild-arg) [ $# -ge 2 ] || usage_error "missing value for --rpmbuild-arg"; RPMBUILD_ARGS+=("$2"); shift 2 ;;
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
if [ -n "$SOURCE_ARCHIVE" ] && [ "$SOURCE_URL_EXPLICIT" = 1 ]; then
  usage_error "use either --source-archive or --source-url, not both"
fi

maybe_require_exe "$DRY_RUN" tar
maybe_require_exe "$DRY_RUN" rpmbuild

RPMBUILD_ROOT="$WORK_DIR/rpmbuild-srpm"
SPEC_PATH="$RPMBUILD_ROOT/SPECS/$SPEC_NAME"
SOURCE_PATH="$RPMBUILD_ROOT/SOURCES/$SOURCE_ARCHIVE_NAME"
SRPM_NAME=$(srpm_name)
SRPM_OUTPUT="$RPMBUILD_ROOT/SRPMS/$SRPM_NAME"

printf 'Repository root: %s\n' "$REPO_ROOT"
printf 'Source archive: %s\n' "${SOURCE_ARCHIVE:-$SOURCE_URL}"
printf 'SRPM output: %s\n' "$ARTIFACT_DIR/$SRPM_NAME"

prepare_rpmbuild_tree "$DRY_RUN" "$RPMBUILD_ROOT"
if [ "$DRY_RUN" = 0 ]; then
  cp "$REPO_ROOT/SPECS/$SPEC_NAME" "$SPEC_PATH"
fi
prepare_source_archive "$DRY_RUN" "$SOURCE_ARCHIVE" "$SOURCE_URL" "$SOURCE_PATH"
if [ "${#RPMBUILD_ARGS[@]}" -gt 0 ]; then
  run_cmd "$DRY_RUN" rpmbuild -bs --target "$NORMALIZED_ARCH" \
    --define "_topdir $RPMBUILD_ROOT" \
    --define "package_prefix $PREFIX" \
    --define "_smp_mflags -j$JOBS" \
    "${RPMBUILD_ARGS[@]}" \
    "$SPEC_PATH"
else
  run_cmd "$DRY_RUN" rpmbuild -bs --target "$NORMALIZED_ARCH" \
    --define "_topdir $RPMBUILD_ROOT" \
    --define "package_prefix $PREFIX" \
    --define "_smp_mflags -j$JOBS" \
    "$SPEC_PATH"
fi

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would copy SRPM artifact: %s -> %s\n' "$SRPM_OUTPUT" "$ARTIFACT_DIR/$SRPM_NAME"
else
  require_nonempty_file "$SRPM_OUTPUT"
  mkdir -p "$ARTIFACT_DIR"
  cp "$SRPM_OUTPUT" "$ARTIFACT_DIR/$SRPM_NAME"
  printf 'SRPM package: %s\n' "$ARTIFACT_DIR/$SRPM_NAME"
fi
