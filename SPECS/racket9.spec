%{!?package_name:%global package_name racket9}
%{!?cache_mode:%global cache_mode postinstall}
%global base_package_name racket9
%global cached_package_name racket9-cached
Name: %{package_name}
Version: 9.2.2
%{!?package_system:%global package_system openeuler2403}
%{!?package_release:%global package_release 6}
Release: %{package_release}.%{package_system}
Summary: Racket programming language
License: MIT OR Apache-2.0
URL: https://racket-lang.org/
Source0: https://github.com/CutieDeng/racket/releases/download/v9.2.2/racket-minimal-9.2.2-src.tgz
AutoReqProv: no
Requires: libedit
%if "%{cache_mode}" == "cached"
Provides: %{base_package_name} = %{version}-%{release}
Conflicts: %{base_package_name}
%else
Conflicts: %{cached_package_name}
%endif
# Racket CS stores its boot image in the .rackboot ELF section. RPM debuginfo
# extraction removes that section on openEuler, so the package must keep debug
# data in the main executables.
%global debug_package %{nil}
%global __brp_compress %{nil}
%global package_prefix /usr
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
sed -i 's|))$|) (default-scope . "installation") (compiled-file-cache-roots . (user system)) (compiled-file-system-cache-root . "/var/cache/racket/compiled"))|' etc/config.rktd
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
runtime_cache_parent="/var/cache/racket"
runtime_cache_root="/var/cache/racket/compiled"
staged_cache_parent="%{buildroot}$runtime_cache_parent"
staged_cache_root="%{buildroot}$runtime_cache_root"
racket_bin="%{buildroot}%{package_prefix}/bin/racket"
runtime_share_dir="%{package_prefix}/share/racket"
runtime_collects_dir="$runtime_share_dir/collects"
runtime_lib_dir="%{package_prefix}/lib/racket"
runtime_links=
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
mkdir -p "$staged_cache_parent"
trap cleanup_runtime_links EXIT
add_runtime_link "%{buildroot}$runtime_share_dir" "$runtime_share_dir"
add_runtime_link "%{buildroot}$runtime_lib_dir" "$runtime_lib_dir"
add_runtime_link "$config_dir" "$runtime_config_dir"
add_runtime_link "$staged_cache_parent" "$runtime_cache_parent"
if ! "$racket_bin" -X "$runtime_collects_dir" -G "$runtime_config_dir" -N raco -l- raco setup --system --no-user --reset-cache -D --no-pkg-deps --no-launcher; then
  exit 1
fi
if ! "$racket_bin" -X "$runtime_collects_dir" -G "$runtime_config_dir" -N rhombus -l- rhombus/run.rhm --version >/dev/null; then
  exit 1
fi
if ! "$racket_bin" -X "$runtime_collects_dir" -G "$runtime_config_dir" -N rhombus -l- rhombus/run.rhm -e 'println("package-racket-rhombus-cache")' >/dev/null; then
  exit 1
fi
rhombus_ephemeral_cache="%{buildroot}$runtime_share_dir/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod"
find "$rhombus_ephemeral_cache" -path '*/compiled/*.zo' -type f -print -quit | grep -q . || { echo "staged Rhombus demod cache is empty: $rhombus_ephemeral_cache" >&2; exit 1; }
cleanup_runtime_links
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
rm -f "%{buildroot}/var/cache/racket/racket-compiled-cache.log"
find "$staged_cache_root" -type d -empty -delete 2>/dev/null || :
runtime_collects_cache="$staged_cache_root/${runtime_collects_dir#/}"
runtime_pkgs_cache="$staged_cache_root/${runtime_pkgs_dir#/}"
find "$runtime_collects_cache" -path '*/compiled/*.zo' -type f -print -quit | grep -q . || { echo "runtime-keyed staged system compiled cache is empty: $runtime_collects_cache" >&2; exit 1; }
find "$runtime_pkgs_cache" -path '*/compiled/*.zo' -type f -print -quit | grep -q . || { echo "runtime-keyed staged package compiled cache is empty: $runtime_pkgs_cache" >&2; exit 1; }
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

%if "%{cache_mode}" == "postinstall"
%posttrans
setup_jobs=
if [ -r /etc/os-release ]; then
  . /etc/os-release
  if [ "${ID:-}" = "fedora" ] && [ "${VERSION_ID:-}" = "44" ]; then
    setup_jobs="-j 1"
  fi
fi
if [ -n "$setup_jobs" ]; then
  raco setup $setup_jobs --system --no-user --reset-cache -D --no-pkg-deps
else
  raco setup --system --no-user --reset-cache -D --no-pkg-deps
fi
empty_home=$(mktemp -d)
if ! HOME="$empty_home" rhombus --version >/dev/null; then
  rm -rf "$empty_home"
  exit 1
fi
if ! HOME="$empty_home" rhombus -e 'println("package-racket-rhombus-cache")' >/dev/null; then
  rm -rf "$empty_home"
  exit 1
fi
rm -rf "$empty_home"
%endif

%if "%{cache_mode}" == "postinstall"
%preun
if [ "$1" = "0" ] && ! rpm -q --quiet %{cached_package_name} && command -v raco >/dev/null 2>&1; then
  raco setup --system --delete-cache || :
fi
%endif

%postun
%if "%{cache_mode}" == "cached"
other_package="%{base_package_name}"
%else
other_package="%{cached_package_name}"
%endif
if [ "$1" = "0" ] && ! rpm -q --quiet "$other_package"; then
  rm -rf /var/cache/racket/compiled
  rm -rf %{package_prefix}/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod
fi

%files -f %{name}.files
%defattr(-,root,root,-)
