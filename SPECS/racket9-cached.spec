%global cache_mode cached
Name: racket9
Version: 9.2.2
%global package_system openeuler2403
%global package_release 7
Release: %{package_release}.2.cached.%{package_system}
Summary: Racket programming language
License: MIT OR Apache-2.0
URL: https://racket-lang.org/
Source0: https://github.com/CutieDeng/racket/releases/download/v9.2.2/racket-minimal-9.2.2-src.tgz
BuildRequires: gcc
BuildRequires: libffi-devel
BuildRequires: make
BuildRequires: ncurses-devel
BuildRequires: openssl-devel
BuildRequires: perl
BuildRequires: sqlite-devel
BuildRequires: zlib-devel
Requires: libedit
Provides: racket9(cache-mode-cached) = %{version}-%{release}
# Bounded migration from the previously published split-name cached package.
Obsoletes: racket9-cached < %{version}-%{package_release}
# Racket CS stores its boot image in the .rackboot ELF section. RPM debuginfo
# extraction removes that section on openEuler, so the package must keep debug
# data in the main executables.
%global debug_package %{nil}
%global __brp_compress %{nil}
%global package_prefix /usr
%global immutable_cache_root %{package_prefix}/lib/racket/%{version}/compiled-cache
%global dynamic_cache_root /var/cache/racket/%{version}/compiled
%global source_sha256 fc25e3ca9996f96b41edac3ab2d1517a8c42e2d0ed9107b81252bcd62895669e

%description
Racket packaged from a stable source release archive.

%prep
if [ -n "%{source_sha256}" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum %{SOURCE0} | cut -d ' ' -f 1)
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 %{SOURCE0} | cut -d ' ' -f 1)
  else
    echo "sha256 checker not found: sha256sum or shasum" >&2
    exit 1
  fi
  if [ "$actual" != "%{source_sha256}" ]; then
    echo "Source0 sha256 mismatch: expected %{source_sha256} but got $actual" >&2
    exit 1
  fi
fi
%setup -q -n racket-9.2.2

%build
sed -i 's|))$|) (default-scope . "installation") (compiled-file-cache-roots . (user system "%{immutable_cache_root}")) (compiled-file-system-cache-root . "%{dynamic_cache_root}"))|' etc/config.rktd
sed -i 's/"1[.]1"/"3"/g' collects/openssl/libssl.rkt collects/openssl/libcrypto.rkt
cd src
./configure \
  --disable-debug \
  --disable-dependency-tracking \
  --enable-origtree=no \
  --enable-sharezo \
  --prefix=%{package_prefix} \
  --sysconfdir=%{_sysconfdir} \
  --enable-useprefix
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
cd src
make install DESTDIR=%{buildroot}
cd ..
find "%{buildroot}" -type d -name compiled ! -path '*/info-domain/compiled' -prune -exec rm -rf {} +
%if "%{cache_mode}" == "cached"
config_dir="%{buildroot}%{_sysconfdir}/racket"
config_file="$config_dir/config.rktd"
runtime_config_dir="%{_sysconfdir}/racket"
runtime_cache_root="%{immutable_cache_root}"
staged_cache_root="%{buildroot}$runtime_cache_root"
racket_bin="%{buildroot}%{package_prefix}/bin/racket"
runtime_share_dir="%{package_prefix}/share/racket"
runtime_collects_dir="$runtime_share_dir/collects"
runtime_lib_dir="%{package_prefix}/lib/racket"
rhombus_compiled_root="%{buildroot}$runtime_share_dir/pkgs/rhombus-lib/rhombus/private/compiled"
runtime_links=
setup_config_dir=
[ -f "$config_file" ] || { echo "missing staged config: $config_file" >&2; exit 1; }
[ -x "$racket_bin" ] || { echo "missing staged racket: $racket_bin" >&2; exit 1; }
[ -d "%{buildroot}$runtime_collects_dir" ] || { echo "missing staged collects: %{buildroot}$runtime_collects_dir" >&2; exit 1; }
[ -d "%{buildroot}$runtime_lib_dir" ] || { echo "missing staged Racket lib directory: %{buildroot}$runtime_lib_dir" >&2; exit 1; }
cleanup_runtime_links() {
  if [ -n "${runtime_links:-}" ]; then
    printf '%s\n' "$runtime_links" | while IFS= read -r runtime_link; do
      [ -n "$runtime_link" ] || continue
      [ -L "$runtime_link" ] && rm -f "$runtime_link"
    done
  fi
}
cleanup_staging() {
  if [ -n "${setup_config_dir:-}" ]; then
    rm -rf "$setup_config_dir"
    setup_config_dir=
  fi
  cleanup_runtime_links
}
add_runtime_link() {
  runtime_link_target="$1"
  runtime_link_path="$2"
  if [ -e "$runtime_link_path" ] || [ -L "$runtime_link_path" ]; then
    echo "runtime staging link path already exists: $runtime_link_path" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$runtime_link_path")"
  ln -s "$runtime_link_target" "$runtime_link_path"
  runtime_links="$runtime_link_path
$runtime_links"
}
cleanup_rhombus_ephemeral() {
  rm -rf "$rhombus_compiled_root/ephemeral"
  rmdir "$rhombus_compiled_root" 2>/dev/null || true
}
setup_config_dir=$(mktemp -d) || exit 1
[ -n "$setup_config_dir" ] || { echo "mktemp returned an empty Racket setup config directory" >&2; exit 1; }
setup_config_file="$setup_config_dir/config.rktd"
sed -E \
  -e 's|compiled-file-system-cache-root . "%{dynamic_cache_root}"|compiled-file-system-cache-root . "%{immutable_cache_root}"|' \
  -e 's/[[:space:]]*\(compiled-file-cache-roots[[:space:]]+\.[[:space:]]+\([^)]*\)\)//' \
  "$config_file" > "$setup_config_file"
if grep -F '(compiled-file-cache-roots .' "$setup_config_file" >/dev/null; then
  echo "could not prepare isolated Racket setup config" >&2
  exit 1
fi
grep -F '(compiled-file-system-cache-root . "%{immutable_cache_root}")' "$setup_config_file" >/dev/null || { echo "isolated setup config did not select the immutable cache root" >&2; exit 1; }
# Reset the target before Racket starts so setup and its workers use the same root.
rm -rf "$staged_cache_root"
mkdir -p "$staged_cache_root"
trap cleanup_staging EXIT
add_runtime_link "%{buildroot}$runtime_share_dir" "$runtime_share_dir"
add_runtime_link "%{buildroot}$runtime_lib_dir" "$runtime_lib_dir"
add_runtime_link "$config_dir" "$runtime_config_dir"
if ! "$racket_bin" -U -R "$runtime_cache_root" -X "$runtime_collects_dir" -G "$setup_config_dir" -N raco -l- raco setup --no-user -D --no-pkg-deps --no-launcher; then
  exit 1
fi
cleanup_rhombus_ephemeral
if find "%{buildroot}$runtime_share_dir" -type d -name compiled ! -path '*/info-domain/compiled' -print -quit | grep -q .; then
  echo "setup leaked compiled files into the staged runtime tree" >&2
  exit 1
fi
if ! "$racket_bin" -U -R "$runtime_cache_root" -X "$runtime_collects_dir" -G "$runtime_config_dir" -N rhombus -l- rhombus/run.rhm --version >/dev/null; then
  exit 1
fi
if ! "$racket_bin" -U -R "$runtime_cache_root" -X "$runtime_collects_dir" -G "$runtime_config_dir" -N rhombus -l- rhombus/run.rhm -e 'println("package-racket-rhombus-cache")' >/dev/null; then
  exit 1
fi
cleanup_rhombus_ephemeral
cleanup_staging
trap - EXIT
move_cache_tree() {
  from_source="$1"
  to_source="$2"
  from="$staged_cache_root/${from_source#/}"
  to="$staged_cache_root/${to_source#/}"
  [ -e "$from" ] || return 0
  [ "$from" = "$to" ] && return 0
  mkdir -p "$(dirname "$to")"
  if [ -e "$to" ]; then
    cp -a "$from"/. "$to"/
    rm -rf "$from"
  else
    mv "$from" "$to"
  fi
}
runtime_collects_dir="%{package_prefix}/share/racket/collects"
runtime_pkgs_dir="%{package_prefix}/share/racket/pkgs"
move_cache_tree "%{buildroot}$runtime_collects_dir" "$runtime_collects_dir"
move_cache_tree "%{buildroot}$runtime_pkgs_dir" "$runtime_pkgs_dir"
rm -f "%{buildroot}%{package_prefix}/lib/racket/%{version}/racket-compiled-cache.log"
find "$staged_cache_root" -type d -empty -delete 2>/dev/null || :
runtime_collects_cache="$staged_cache_root/${runtime_collects_dir#/}"
runtime_pkgs_cache="$staged_cache_root/${runtime_pkgs_dir#/}"
find "$runtime_collects_cache" -path '*/compiled/*.zo' -type f -print -quit | grep -q . || { echo "runtime-keyed staged system compiled cache is empty: $runtime_collects_cache" >&2; exit 1; }
find "$runtime_pkgs_cache" -path '*/compiled/*.zo' -type f -print -quit | grep -q . || { echo "runtime-keyed staged package compiled cache is empty: $runtime_pkgs_cache" >&2; exit 1; }
[ ! -e "$rhombus_compiled_root/ephemeral" ] || { echo "Rhombus ephemeral cache must not be packaged: $rhombus_compiled_root/ephemeral" >&2; exit 1; }
%endif

manifest="%{name}.files"
paths="%{name}.paths"
: > "$manifest"
find "%{buildroot}" -mindepth 1 | sort > "$paths"
while IFS= read -r path; do
  rel=${path#"%{buildroot}"}
  [ -n "$rel" ] || continue
  case "$rel" in
    /bin|/boot|/dev|/etc|/lib|/lib64|/opt|/run|/sbin|/usr|/usr/bin|/usr/etc|/usr/games|/usr/include|/usr/lib|/usr/lib64|/usr/libexec|/usr/local|/usr/sbin|/usr/share|/usr/share/applications|/usr/share/doc|/usr/share/icons|/usr/share/icons/hicolor|/usr/share/man|/usr/share/man/man1|/usr/share/man/man2|/usr/share/man/man3|/usr/share/man/man4|/usr/share/man/man5|/usr/share/man/man6|/usr/share/man/man7|/usr/share/man/man8|/var) continue ;;
  esac
  if [ -d "$path" ] && [ ! -L "$path" ]; then
    printf '%s %s\n' '%%dir' "$rel" >> "$manifest"
  elif [ -f "$path" ] || [ -L "$path" ]; then
    printf '%s\n' "$rel" >> "$manifest"
  else
    printf 'unsupported staged file type: %s\n' "$path" >&2
    exit 1
  fi
done < "$paths"
grep -Eq '^(%dir )?(/bin|/boot|/dev|/etc|/lib|/lib64|/opt|/run|/sbin|/usr|/usr/bin|/usr/etc|/usr/games|/usr/include|/usr/lib|/usr/lib64|/usr/libexec|/usr/local|/usr/sbin|/usr/share|/usr/share/applications|/usr/share/doc|/usr/share/icons|/usr/share/icons/hicolor|/usr/share/man|/usr/share/man/man1|/usr/share/man/man2|/usr/share/man/man3|/usr/share/man/man4|/usr/share/man/man5|/usr/share/man/man6|/usr/share/man/man7|/usr/share/man/man8|/var)$' "$manifest" && exit 1

%posttrans
rm -rf /var/cache/racket/compiled
rm -f /var/cache/racket/racket-compiled-cache.log
rhombus_compiled_root="%{package_prefix}/share/racket/pkgs/rhombus-lib/rhombus/private/compiled"
cleanup_rhombus_ephemeral() {
  rm -rf "$rhombus_compiled_root/ephemeral"
  rmdir "$rhombus_compiled_root" 2>/dev/null || true
}
setup_config_dir=
empty_home=
cleanup_posttrans() {
  if [ -n "${setup_config_dir:-}" ]; then
    rm -rf "$setup_config_dir"
    setup_config_dir=
  fi
  if [ -n "${empty_home:-}" ]; then
    rm -rf "$empty_home"
    empty_home=
  fi
  cleanup_rhombus_ephemeral
}
trap cleanup_posttrans EXIT
%if "%{cache_mode}" == "postinstall"
compiled_cache_root="%{dynamic_cache_root}"
setup_jobs=
if [ -r /etc/os-release ]; then
  . /etc/os-release
  if [ "${ID:-}" = "fedora" ] && [ "${VERSION_ID:-}" = "44" ]; then
    setup_jobs="-j 1"
  fi
fi
setup_config_source="%{_sysconfdir}/racket/config.rktd"
setup_config_dir=$(mktemp -d) || exit 1
[ -n "$setup_config_dir" ] || { echo "mktemp returned an empty Racket setup config directory" >&2; exit 1; }
setup_config_file="$setup_config_dir/config.rktd"
sed -E 's/[[:space:]]*\(compiled-file-cache-roots[[:space:]]+\.[[:space:]]+\([^)]*\)\)//' "$setup_config_source" > "$setup_config_file"
if grep -F '(compiled-file-cache-roots .' "$setup_config_file" >/dev/null; then
  echo "could not prepare isolated Racket setup config" >&2
  exit 1
fi
grep -F '(compiled-file-system-cache-root . "%{dynamic_cache_root}")' "$setup_config_file" >/dev/null || { echo "isolated setup config did not select the dynamic cache root" >&2; exit 1; }
# Reset the target before Racket starts so setup and its workers use the same root.
rm -rf "$compiled_cache_root"
mkdir -p "$compiled_cache_root"
if ! %{package_prefix}/bin/racket -U -R "$compiled_cache_root" -X %{package_prefix}/share/racket/collects -G "$setup_config_dir" -N raco -l- raco setup $setup_jobs --no-user -D --no-pkg-deps --no-launcher; then
  exit 1
fi
cleanup_rhombus_ephemeral
rm -rf "$setup_config_dir"
setup_config_dir=
empty_home=$(mktemp -d) || exit 1
[ -n "$empty_home" ] || { echo "mktemp returned an empty Racket smoke-test home directory" >&2; exit 1; }
if ! HOME="$empty_home" %{package_prefix}/bin/racket -U -R "$compiled_cache_root" -N rhombus -l- rhombus/run.rhm --version >/dev/null; then
  exit 1
fi
if ! HOME="$empty_home" %{package_prefix}/bin/racket -U -R "$compiled_cache_root" -N rhombus -l- rhombus/run.rhm -e 'println("package-racket-rhombus-cache")' >/dev/null; then
  exit 1
fi
rm -rf "$empty_home"
empty_home=
rm -f "/var/cache/racket/%{version}/racket-compiled-cache.log"
%else
rm -rf "%{dynamic_cache_root}"
rm -f "/var/cache/racket/%{version}/racket-compiled-cache.log"
%endif
cleanup_posttrans
[ ! -e "$rhombus_compiled_root/ephemeral" ] || { echo "Rhombus ephemeral cache must not be installed" >&2; exit 1; }
trap - EXIT
exit 0

%postun
if [ "$1" = "0" ]; then
  rm -rf /var/cache/racket/compiled
  rm -f /var/cache/racket/racket-compiled-cache.log
  rm -rf "%{dynamic_cache_root}"
  rm -f "/var/cache/racket/%{version}/racket-compiled-cache.log"
  rmdir "/var/cache/racket/%{version}" /var/cache/racket 2>/dev/null || :
fi
exit 0

%files -f %{name}.files
%defattr(-,root,root,-)
