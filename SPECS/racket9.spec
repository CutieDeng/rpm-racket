Name: racket9
Version: 9.2.1.1
Release: 1
Summary: Racket programming language
License: MIT OR Apache-2.0
URL: https://racket-lang.org/
Source0: racket9-9.2.1.1-payload.tar.gz
Source1: racket9.files
AutoReqProv: no
%global __brp_compress %{nil}

%description
Racket packaged from a local checkout.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
tar -xzf %{SOURCE0} -C %{buildroot}

%files -f %{SOURCE1}
%defattr(-,root,root,-)
