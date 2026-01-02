#!/bin/bash
# Build script for creating RPM package of nw-page-editor with bundled NW.js
# This script automates the RPM build process and downloads NW.js automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RPM_DIR="$SCRIPT_DIR"

# Configuration
NAME="nw-page-editor"
VERSION="2022.09.13"
RELEASE="${RPM_RELEASE:-1}"
NWJS_VERSION="${NWJS_VERSION:-0.44.4}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    local missing_tools=()
    
    for tool in rpmbuild curl tar gzip; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install them using your package manager:"
        echo "  Fedora/RHEL: sudo dnf install rpm-build curl tar gzip"
        echo "  openSUSE: sudo zypper install rpm-build curl tar gzip"
        exit 1
    fi
    
    echo -e "${GREEN}All requirements met!${NC}"
}

# Setup RPM build directories
setup_rpmbuild() {
    echo -e "${YELLOW}Setting up RPM build directories...${NC}"
    
    local rpmbuild_dir="$HOME/rpmbuild"
    local dirs=("SOURCES" "SPECS" "BUILD" "RPMS" "SRPMS")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$rpmbuild_dir/$dir"
    done
    
    echo -e "${GREEN}RPM build directories ready!${NC}"
}

# Download NW.js if needed
download_nwjs() {
    echo -e "${YELLOW}Checking for NW.js v${NWJS_VERSION}...${NC}"
    
    local nwjs_dir="$PROJECT_ROOT/nwjs"
    local nwjs_archive="$PROJECT_ROOT/nwjs-sdk-linux-x64.tar.gz"
    local nwjs_url="https://dl.nwjs.io/v${NWJS_VERSION}/nwjs-sdk-v${NWJS_VERSION}-linux-x64.tar.gz"
    
    if [ -d "$nwjs_dir" ] && [ -f "$nwjs_dir/nw" ]; then
        echo -e "${GREEN}NW.js already present at $nwjs_dir${NC}"
        return 0
    fi
    
    echo "Downloading NW.js v${NWJS_VERSION} from $nwjs_url..."
    if curl -fLSs -o "$nwjs_archive" "$nwjs_url"; then
        echo "Extracting NW.js..."
        tar -xzf "$nwjs_archive" -C "$PROJECT_ROOT"
        local extracted_dir=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name "nwjs-sdk-v${NWJS_VERSION}-linux-x64" | head -1)
        if [ -n "$extracted_dir" ]; then
            mv "$extracted_dir" "$nwjs_dir"
        fi
        rm -f "$nwjs_archive"
        echo -e "${GREEN}NW.js downloaded and extracted successfully!${NC}"
    else
        echo -e "${RED}Warning: Could not download NW.js automatically.${NC}"
        echo "You can download it manually from: $nwjs_url"
        echo "Extract it to: $nwjs_dir"
        return 1
    fi
}

# Create source tarball
create_tarball() {
    echo -e "${YELLOW}Creating source tarball...${NC}"
    
    local rpmbuild_dir="$HOME/rpmbuild"
    local tarball="$rpmbuild_dir/SOURCES/${NAME}-${VERSION}.tar.gz"
    
    cd "$PROJECT_ROOT"
    
    # Check if we're in a git repository
    if [ -d .git ]; then
        # Initialize git submodules BEFORE creating tarball
        # git archive doesn't include submodules, so we need to handle them separately
        if [ -f .gitmodules ]; then
            echo "Initializing git submodules..."
            git submodule update --init --recursive 2>/dev/null || true
        fi
        
        echo "Creating tarball from git repository..."
        git archive --format=tar.gz \
            --prefix="${NAME}-${VERSION}/" \
            --output="$tarball" \
            HEAD
        
        # If submodules exist, we need to add them to the tarball manually
        # since git archive doesn't include them
        if [ -f .gitmodules ] && [ -d xsd/pageformat ]; then
            echo "Adding git submodules to tarball..."
            # Extract, add submodules, and recreate tarball
            local temp_dir=$(mktemp -d)
            tar -xzf "$tarball" -C "$temp_dir"
            # Copy submodule contents
            if [ -d xsd/pageformat ]; then
                cp -r xsd "$temp_dir/${NAME}-${VERSION}/" 2>/dev/null || true
            fi
            # Recreate tarball with submodules
            cd "$temp_dir"
            tar -czf "$tarball" "${NAME}-${VERSION}/"
            cd "$PROJECT_ROOT"
            rm -rf "$temp_dir"
        fi
    else
        echo "Not a git repository, creating tarball from current directory..."
        tar --exclude='.git' \
            --exclude='node_modules' \
            --exclude='rpm' \
            --exclude='*.rpm' \
            --exclude='*.tar.gz' \
            --exclude='nwjs' \
            -czf "$tarball" \
            --transform "s,^,${NAME}-${VERSION}/," \
            .
    fi
    
    echo -e "${GREEN}Source tarball created: $tarball${NC}"
}

# Build RPM
build_rpm() {
    echo -e "${YELLOW}Building RPM package...${NC}"
    
    local rpmbuild_dir="$HOME/rpmbuild"
    local specfile="$RPM_DIR/${NAME}.spec"
    
    # Update spec file with NW.js version if provided
    if [ -n "$NWJS_VERSION" ]; then
        sed -i.bak "s/%define nwjs_version .*/%define nwjs_version ${NWJS_VERSION}/" "$specfile"
    fi
    
    # Copy spec file to SPECS directory
    cp "$specfile" "$rpmbuild_dir/SPECS/"
    
    # Build RPM
    rpmbuild -ba \
        --define "_topdir $rpmbuild_dir" \
        --define "version $VERSION" \
        --define "release $RELEASE" \
        --define "nwjs_version $NWJS_VERSION" \
        "$rpmbuild_dir/SPECS/${NAME}.spec"
    
    echo -e "${GREEN}RPM package built successfully!${NC}"
    
    # Show results
    local rpm_file=$(find "$rpmbuild_dir/RPMS" -name "${NAME}-${VERSION}-${RELEASE}*.rpm" | head -1)
    local srpm_file=$(find "$rpmbuild_dir/SRPMS" -name "${NAME}-${VERSION}-${RELEASE}*.src.rpm" | head -1)
    
    if [ -n "$rpm_file" ]; then
        echo -e "${GREEN}RPM: $rpm_file${NC}"
        ls -lh "$rpm_file"
        echo ""
        echo "To install: sudo dnf install $rpm_file"
    fi
    
    if [ -n "$srpm_file" ]; then
        echo -e "${GREEN}SRPM: $srpm_file${NC}"
        ls -lh "$srpm_file"
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "Building RPM package for $NAME"
    echo "Version: $VERSION"
    echo "Release: $RELEASE"
    echo "NW.js Version: $NWJS_VERSION"
    echo "========================================="
    echo ""
    
    check_requirements
    setup_rpmbuild
    download_nwjs
    create_tarball
    build_rpm
    
    echo ""
    echo "========================================="
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo "========================================="
    echo ""
    echo "The RPM package includes NW.js and has no external dependencies."
    echo "Users can install it with: sudo dnf install <rpm-file>"
}

# Run main function
main

