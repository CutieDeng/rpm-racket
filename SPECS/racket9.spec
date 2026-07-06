%{!?package_name:%global package_name racket9}
%{!?cache_mode:%global cache_mode postinstall}
%global base_package_name racket9
%global cached_package_name racket9-cached
Name: %{package_name}
Version: 9.2.2
%{!?package_system:%global package_system openeuler2403}
%{!?package_release:%global package_release 4}
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
runtime_cache_root="/var/cache/racket/compiled"
staged_cache_root="%{buildroot}$runtime_cache_root"
racket_bin="%{buildroot}%{package_prefix}/bin/racket"
collects_dir="%{buildroot}%{package_prefix}/share/racket/collects"
backup="$config_file.package-racket-cache-backup"
[ -f "$config_file" ] || { echo "missing staged config: $config_file" >&2; exit 1; }
[ -x "$racket_bin" ] || { echo "missing staged racket: $racket_bin" >&2; exit 1; }
[ -d "$collects_dir" ] || { echo "missing staged collects: $collects_dir" >&2; exit 1; }
cp "$config_file" "$backup"
	escape_config_sed_pattern() {
	  printf '%s\n' "$1" | sed 's/[][\\.^$*|]/\\&/g'
	}
	escape_config_sed_replacement() {
	  printf '%s\n' "$1" | sed 's/[\\&|]/\\&/g'
	}
	replace_config_value() {
	  replace_config_file="$1"
	  replace_config_key="$2"
	  replace_config_from="$3"
	  replace_config_to="$4"
	  replace_config_required="$5"
	  replace_config_needle="($replace_config_key . \"$replace_config_from\")"
	  replace_config_replacement="($replace_config_key . \"$replace_config_to\")"
	  if ! grep -F "$replace_config_needle" "$replace_config_file" >/dev/null; then
	    if [ "$replace_config_required" = required ]; then
	      echo "config does not contain expected $replace_config_key value $replace_config_from: $replace_config_file" >&2
	      exit 1
	    fi
	    return 0
	  fi
	  replace_config_needle=$(escape_config_sed_pattern "$replace_config_needle")
	  replace_config_replacement=$(escape_config_sed_replacement "$replace_config_replacement")
	  replace_config_tmp="$replace_config_file.package-racket-rewrite.$$"
	  sed "s|$replace_config_needle|$replace_config_replacement|g" "$replace_config_file" > "$replace_config_tmp" || { rm -f "$replace_config_tmp"; exit 1; }
	  mv "$replace_config_tmp" "$replace_config_file"
	}
	write_staged_config() {
	  replace_config_file="$1"
	  replace_config_stage_root="$2"
	  replace_config_prefix="$3"
	  replace_config_runtime_cache_root="$4"
	  replace_config_staged_cache_root="$5"
	  replace_config_value "$replace_config_file" compiled-file-system-cache-root "$replace_config_runtime_cache_root" "$replace_config_staged_cache_root" required
	  replace_config_value "$replace_config_file" share-dir "$replace_config_prefix/share/racket" "$replace_config_stage_root$replace_config_prefix/share/racket" optional
	  replace_config_value "$replace_config_file" pkgs-dir "$replace_config_prefix/share/racket/pkgs" "$replace_config_stage_root$replace_config_prefix/share/racket/pkgs" optional
	  replace_config_value "$replace_config_file" doc-dir "$replace_config_prefix/share/doc/racket" "$replace_config_stage_root$replace_config_prefix/share/doc/racket" optional
	  replace_config_value "$replace_config_file" lib-dir "$replace_config_prefix/lib/racket" "$replace_config_stage_root$replace_config_prefix/lib/racket" optional
	  replace_config_value "$replace_config_file" include-dir "$replace_config_prefix/include/racket" "$replace_config_stage_root$replace_config_prefix/include/racket" optional
	  replace_config_value "$replace_config_file" bin-dir "$replace_config_prefix/bin" "$replace_config_stage_root$replace_config_prefix/bin" optional
	  replace_config_value "$replace_config_file" apps-dir "$replace_config_prefix/share/applications" "$replace_config_stage_root$replace_config_prefix/share/applications" optional
	  replace_config_value "$replace_config_file" man-dir "$replace_config_prefix/share/man" "$replace_config_stage_root$replace_config_prefix/share/man" optional
	}
	write_staged_config "$config_file" "%{buildroot}" "%{package_prefix}" "$runtime_cache_root" "$staged_cache_root"
mkdir -p "$staged_cache_root"
if ! "$racket_bin" -X "$collects_dir" -G "$config_dir" -N raco -l- raco setup --system --no-user --reset-cache -D --no-pkg-deps; then
  cp "$backup" "$config_file"
  rm -f "$backup"
  exit 1
fi
cp "$backup" "$config_file"
rm -f "$backup"
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
move_cache_tree "$collects_dir" "$runtime_collects_dir"
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
%endif

%if "%{cache_mode}" == "postinstall"
%preun
if [ "$1" = "0" ] && command -v raco >/dev/null 2>&1; then
  raco setup --system --delete-cache || :
fi
%endif

%postun
if [ "$1" = "0" ]; then
  rm -rf /var/cache/racket/compiled
fi

%files -f %{name}.files
%defattr(-,root,root,-)
