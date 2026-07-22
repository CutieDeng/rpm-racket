# rpm-racket

GENERATED RPM PACKAGING METADATA - DO NOT EDIT IN rpm-racket.

This repository is the generated RPM packaging and two-channel repository.
Treat `SPECS/`, `SOURCES/`, `scripts/`, `.github/workflows/`,
`racket9-SYSTEM.repo`, and `README.md` as outputs from
`package-racket`; do not hand-edit them for production changes. The
`rpm-repo` target maintains system-isolated trees below `repo/cached/` and
`repo/postinstall/`.

Both cache modes use the RPM package name `racket9`. `cached` is
the default channel and embeds a versioned immutable compiled cache;
`postinstall` is the optional channel and builds a versioned dynamic cache in
`%posttrans`. Their Release values are ordered and distinct:
`RELEASE.2.cached.SYSTEM` and `RELEASE.1.postinstall.SYSTEM`.
Both carry a bounded `Obsoletes: racket9-cached`
rule so installations of the old split-name cached package migrate in one
transaction; no cross-name lifecycle checks remain in scriptlets.

## Layout

- `SPECS/racket9-cached.spec`: concrete cached build definition.
- `SPECS/racket9-postinstall.spec`: concrete postinstall build
  definition.
- `SOURCES/.gitkeep`: source placeholder; build scripts copy or download the
  stable source archive into their explicit work directory.
- `scripts/rpm-common.sh`: shared safety checks and staging helpers.
- `scripts/build-rpm.sh`: builds a binary RPM from the generated spec.
- `scripts/build-srpm.sh`: builds a source RPM from the same stable source
  archive.
- `scripts/verify-rpm.sh`: validates RPM name, metadata, arch, and payload
  ownership boundaries.
- `racket9-SYSTEM.repo`: one client file per supported RPM
  system; each enables cached by default and leaves postinstall disabled.
- `repo/cached/SYSTEM/$basearch`: default cached metadata and packages.
- `repo/postinstall/SYSTEM/$basearch`: optional postinstall metadata and
  packages. System isolation prevents DNF from comparing incompatible distro
  builds as upgrade candidates.
- `.github/workflows/build-rpm.yml`: builds configured RPM targets with GitHub
  Actions, uploads immutable release assets, and deploys metadata-only channel
  repositories through GitHub Pages. Configure the repository's Pages source
  to `GitHub Actions` before the first deployment.

## Regenerate

Run from `package-racket` to overwrite the SPEC and scripts:

```sh
racket package-racket.rkt \
  --target rpm-spec \
  --prefix /usr \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --rpm-repo-config /Users/cutiedeng/Y2026/M06/D21/package-racket/rpm-repo-config.rktd
```

Run from `package-racket` to overwrite the generated RPM CI workflow:

```sh
racket package-racket.rkt \
  --target rpm-ci \
  --prefix /usr \
  --rpm-repo-config /Users/cutiedeng/Y2026/M06/D21/package-racket/rpm-repo-config.rktd \
  --rpm-ci-config /Users/cutiedeng/Y2026/M06/D21/package-racket/rpm-ci-config.rktd
```

On a supported Linux builder, build both flavors and update both repository
channels:

```sh
racket package-racket.rkt \
  --target rpm \
  --target rpm-repo \
  --prefix /usr \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --rpm-repo-config /Users/cutiedeng/Y2026/M06/D21/package-racket/rpm-repo-config.rktd
```

## Build

Build a binary RPM on a target Linux host from the generated GitHub Release
source URL:

```sh
scripts/build-rpm.sh \
  --artifact-dir /path/to/artifacts \
  --work-dir /path/to/work \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --cache-mode cached \
  --prefix /usr
```

Use a local source archive for offline or pinned local builds:

```sh
scripts/build-rpm.sh \
  --source-archive /path/to/racket-minimal-9.2.5-src.tgz \
  --artifact-dir /path/to/artifacts \
  --work-dir /path/to/work \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --cache-mode postinstall \
  --prefix /usr
```

Supported RPM systems are `el9`, `fc40`, `fc43`, `fc44`, `openeuler2203`, and
`openeuler2403`. The generic `openeuler` value is intentionally rejected for
production artifacts. Common explicit target examples:

```sh
--rpm-system el9 --rpm-release 3 --rpm-arch x86_64
--rpm-system fc40 --rpm-release 3 --rpm-arch x86_64
--rpm-system fc43 --rpm-release 3 --rpm-arch x86_64
--rpm-system fc44 --rpm-release 3 --rpm-arch x86_64
--rpm-system openeuler2203 --rpm-release 3 --rpm-arch x86_64
--rpm-system openeuler2203 --rpm-release 3 --rpm-arch arm64
--rpm-system openeuler2403 --rpm-release 3 --rpm-arch x86_64
--rpm-system openeuler2403 --rpm-release 3 --rpm-arch arm64
```

Build the matching SRPM from the generated GitHub Release source URL:

```sh
scripts/build-srpm.sh \
  --artifact-dir /path/to/artifacts \
  --work-dir /path/to/work \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --cache-mode cached \
  --prefix /usr
```

Use a local source archive for the matching SRPM:

```sh
scripts/build-srpm.sh \
  --source-archive /path/to/racket-minimal-9.2.5-src.tgz \
  --artifact-dir /path/to/artifacts \
  --work-dir /path/to/work \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --cache-mode postinstall \
  --prefix /usr
```

Validate an existing RPM:

```sh
scripts/verify-rpm.sh \
  --rpm /path/to/artifacts/racket9-9.2.5-3.2.cached.el9.aarch64.rpm \
  --rpm-system el9 \
  --rpm-release 3 \
  --rpm-arch arm64 \
  --cache-mode cached
```

## Select a channel

Install only the matching `racket9-el9.repo`
into `/etc/yum.repos.d/`. Exactly one channel should be enabled. This
one-shot command switches to the optional postinstall channel and converges the
installed package:

```sh
dnf --disablerepo=cutiedeng-racket-el9-cached \
    --enablerepo=cutiedeng-racket-el9-postinstall \
    --refresh distro-sync racket9
```

For a persistent switch, reverse the two `enabled` values in the installed
repo file. Switch back by enabling cached, disabling postinstall, and running
the same `dnf --refresh distro-sync` command.

Inspect the installed identity and selected flavor:

```sh
rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' racket9
rpm -q --provides racket9 | grep 'cache-mode-'
```
