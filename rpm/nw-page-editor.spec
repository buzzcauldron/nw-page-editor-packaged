%define name nw-page-editor
%define version 2022.09.13
%define release 1
%define source_name %{name}
%define nwjs_version 0.44.4

Summary: Simple app for visual editing of Page XML files (with bundled NW.js)
Name: %{name}
Version: %{version}
Release: %{release}%{?dist}
License: MIT
Group: Applications/Text
Source0: %{source_name}-%{version}.tar.gz
Source1: https://dl.nwjs.io/v%{nwjs_version}/nwjs-sdk-v%{nwjs_version}-linux-x64.tar.gz
URL: https://github.com/mauvilsa/nw-page-editor
BuildArch: x86_64
BuildRequires: curl, tar, gzip

%description
nw-page-editor is an application for viewing/editing ground truth or predicted
information for diverse purposes related to the areas of document processing and
text recognition. The edition is done interactively and visually on top of
images of scanned documents.

This package includes a bundled version of NW.js, so no additional dependencies
are required.

%prep
%setup -q -n %{source_name}-%{version}

# Initialize git submodules if .gitmodules exists and submodules are missing
# This handles the case where git archive doesn't include submodules
if [ -f .gitmodules ]; then
    if [ ! -d xsd/pageformat ] || [ -z "$(ls -A xsd/pageformat 2>/dev/null)" ]; then
        echo "Initializing git submodules..."
        git submodule update --init --recursive 2>/dev/null || \
        echo "Warning: Could not initialize git submodules. xsd directory may be missing."
    fi
fi

# Download and extract NW.js if not already present
if [ ! -d nwjs ]; then
    echo "Downloading NW.js v%{nwjs_version}..."
    curl -fLSs -o nwjs-sdk-linux-x64.tar.gz "https://dl.nwjs.io/v%{nwjs_version}/nwjs-sdk-v%{nwjs_version}-linux-x64.tar.gz" || \
    curl -fLSs -o nwjs-sdk-linux-x64.tar.gz "%{SOURCE1}"
    
    if [ -f nwjs-sdk-linux-x64.tar.gz ]; then
        echo "Extracting NW.js..."
        tar -xzf nwjs-sdk-linux-x64.tar.gz
        mv nwjs-sdk-v%{nwjs_version}-linux-x64 nwjs
        rm -f nwjs-sdk-linux-x64.tar.gz
    else
        echo "Warning: Could not download NW.js. Build may fail."
    fi
fi

%build
# No build step required - this is a JavaScript/HTML application
# NW.js is bundled, so we just need to prepare the installation structure

%install
# Create directory structure
mkdir -p %{buildroot}%{_datadir}/%{name}
mkdir -p %{buildroot}%{_libdir}/%{name}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_docdir}/%{name}

# Install NW.js runtime
if [ -d nwjs ]; then
    echo "Installing NW.js runtime..."
    mkdir -p %{buildroot}%{_libdir}/%{name}/nwjs
    cp -r nwjs/* %{buildroot}%{_libdir}/%{name}/nwjs/
fi

# Install application files
cp -r css %{buildroot}%{_datadir}/%{name}/
cp -r html %{buildroot}%{_datadir}/%{name}/
cp -r js %{buildroot}%{_datadir}/%{name}/
cp -r node_modules %{buildroot}%{_datadir}/%{name}/
cp -r plugins %{buildroot}%{_datadir}/%{name}/
# Copy xsd directory if it exists (may be missing if git submodule not initialized)
if [ -d xsd ]; then
    cp -r xsd %{buildroot}%{_datadir}/%{name}/
fi
cp -r xslt %{buildroot}%{_datadir}/%{name}/
cp -r examples %{buildroot}%{_datadir}/%{name}/
cp package.json %{buildroot}%{_datadir}/%{name}/

# Create modified launcher script that uses bundled NW.js
# We need to use a here-document that expands macros
NWJS_PATH="%{_libdir}/%{name}/nwjs/nw"
cat > %{buildroot}%{_bindir}/nw-page-editor << 'LAUNCHER_EOF'
#!/usr/bin/env bash
(set -o igncr) 2>/dev/null && set -o igncr; # ignore \r line endings

##
## Command line launcher for nw-page-editor.
## This version uses the bundled NW.js runtime.
##

readlinkf() { perl -MCwd -e 'foreach \$line ( <STDIN> ) { \$line =~ s/\s+\$//; print Cwd::abs_path(\$line) . "\n"; }'; }

[ "\${nw_page_editor:-}" = "" ] &&
  nw_page_editor=\$(echo "\$0" | readlinkf | sed "s|/bin/\${0##*/}\$||");
[ ! -f "\$nw_page_editor/js/nw-app.js" ] && [ -f "\$nw_page_editor/share/nw-page-editor/js/nw-app.js" ] &&
  nw_page_editor="\$nw_page_editor/share/nw-page-editor";

# Use bundled NW.js if available, otherwise fall back to system PATH
if [ -f "/usr/lib64/%{name}/nwjs/nw" ]; then
  nw="/usr/lib64/%{name}/nwjs/nw"
elif [ -f "/usr/lib/%{name}/nwjs/nw" ]; then
  nw="/usr/lib/%{name}/nwjs/nw"
else
  # Fall back to system NW.js
  if [ \$( uname | grep -ci darwin ) != 0 ]; then
    nw="/Applications/nwjs.app/Contents/MacOS/nwjs";
    [ ! -f "\$nw" ] &&
      nw=\$(mdfind nwjs.app | head -n 1)"/Contents/MacOS/nwjs";
  else
    nw=\$(which nw);
  fi
fi

[ ! -f "\$nw_page_editor/js/nw-app.js" ] &&
  echo "\${0##*/}: error: unable to resolve the nw-page-editor app location" &&
  exit 1;
[ ! -f "\$nw" ] &&
  echo "\${0##*/}: error: unable find the NW.js binary" &&
  exit 1;

if [ "\$1" = "-h" ] || [ "\$1" = "--help" ]; then
  echo "Description: Simple app for visual editing of Page XML files";
  echo "Usage: \${0##*/} [page.xml]+ [pages_dir]+ [--list pages_list]+ [--css file.css]+ [--js file.js]+";
  exit 0;
fi

argv=( --wd "\$(pwd)" "\$@" );
argv=("\${argv[@]/#-l/--list}");
argv=("\${argv[@]/#--/++}");

"\$nw" --disable-features=nw2 "\$nw_page_editor" "\${argv[@]}" 2>>/tmp/nw-page-editor.log;
LAUNCHER_EOF

chmod +x %{buildroot}%{_bindir}/nw-page-editor

# Install documentation
install -m 644 README.md %{buildroot}%{_docdir}/%{name}/
install -m 644 LICENSE.md %{buildroot}%{_docdir}/%{name}/

%files
%defattr(-,root,root,-)
%{_bindir}/nw-page-editor
%{_datadir}/%{name}/
%{_libdir}/%{name}/nwjs/
%{_docdir}/%{name}/
%doc %{_docdir}/%{name}/README.md
%doc %{_docdir}/%{name}/LICENSE.md

%changelog
* %(date +"%a %b %d %Y") Mauricio Villegas <mauricio_ville@yahoo.com> - %{version}-%{release}
- Initial RPM package with bundled NW.js runtime
- No external dependencies required

