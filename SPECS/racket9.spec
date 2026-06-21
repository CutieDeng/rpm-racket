Name: racket9
Version: 9.2.1
Release: 1
Summary: Racket programming language
License: MIT OR Apache-2.0
URL: https://racket-lang.org/
Source0: https://github.com/CutieDeng/racket/releases/download/v9.2.1/racket-minimal-9.2.1-src.tgz
AutoReqProv: no
%global __brp_compress %{nil}
%global package_prefix /usr
%global source_sha256 b9c621e5c91822181cff1b1af8813a5abd3e89795089171552dac0f441222bbd

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
%setup -q -n racket-9.2.1

%build
sed -i 's/))$/) (default-scope . "installation"))/' etc/config.rktd
sed -i 's/"1[.]1"/"3"/g' collects/openssl/libssl.rkt collects/openssl/libcrypto.rkt
cd src
./configure \
  --disable-debug \
  --disable-dependency-tracking \
  --enable-origtree=no \
  --prefix=%{package_prefix} \
  --sysconfdir=%{_sysconfdir} \
  --enable-useprefix
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
cd src
make install DESTDIR=%{buildroot}
cd ..

manifest="%{name}.files"
paths="%{name}.paths"
: > "$manifest"
find "%{buildroot}" -mindepth 1 | sort > "$paths"
while IFS= read -r path; do
  rel=${path#"%{buildroot}"}
  [ -n "$rel" ] || continue
  case "$rel" in
    /usr|/usr/bin|/usr/lib|/usr/lib64|/usr/share) continue ;;
  esac
  if [ -d "$path" ] && [ ! -L "$path" ]; then
    printf '%%dir %s\n' "$rel" >> "$manifest"
  elif [ -f "$path" ] || [ -L "$path" ]; then
    printf '%s\n' "$rel" >> "$manifest"
  else
    printf 'unsupported staged file type: %s\n' "$path" >&2
    exit 1
  fi
done < "$paths"
grep -Eq '^(%dir )?/usr$' "$manifest" && exit 1
grep -Eq '^(%dir )?/usr/(bin|lib|lib64|share)$' "$manifest" && exit 1

%files -f %{name}.files
%defattr(-,root,root,-)
