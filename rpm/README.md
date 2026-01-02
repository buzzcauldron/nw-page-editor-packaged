# RPM Packaging for nw-page-editor

This directory contains files for building an RPM package that includes a bundled NW.js runtime.

## Quick Start

```bash
cd rpm
./build-rpm.sh
```

The built RPM will be in `~/rpmbuild/RPMS/x86_64/`

## Features

- **Bundled NW.js**: Automatically downloads and includes NW.js v0.44.4
- **No Dependencies**: Package has no external runtime dependencies
- **Self-Contained**: Works immediately after installation

## Files

- `nw-page-editor.spec` - RPM spec file
- `build-rpm.sh` - Automated build script

## Customization

To use a different NW.js version:

```bash
NWJS_VERSION=0.50.0 ./build-rpm.sh
```

## Installation

After building:

```bash
sudo dnf install ~/rpmbuild/RPMS/x86_64/nw-page-editor-*.rpm
```

See the main `PACKAGING.md` file for more details.

