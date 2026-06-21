Name: racket9
Version: 9.2.1.1
Release: 1
Summary: Racket programming language
License: MIT OR Apache-2.0
URL: https://racket-lang.org/
Source0: https://github.com/CutieDeng/racket/releases/download/v9.2.1/racket-minimal-9.2.1-src.tgz
AutoReqProv: no
%global __brp_compress %{nil}
%global package_prefix /usr

%description
Racket packaged from a stable source release archive.

%prep
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
