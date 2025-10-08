#!/bin/bash

# Setup script for pre-commit hooks with Runic.jl

echo "Setting up pre-commit hooks for OpenStreetMapIO.jl..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "pre-commit is not installed. Installing..."

    # Try different installation methods
    if command -v pip &> /dev/null; then
        pip install pre-commit
    elif command -v pip3 &> /dev/null; then
        pip3 install pre-commit
    elif command -v conda &> /dev/null; then
        conda install -c conda-forge pre-commit
    else
        echo "Error: Could not install pre-commit. Please install it manually:"
        echo "  pip install pre-commit"
        echo "  or"
        echo "  conda install -c conda-forge pre-commit"
        exit 1
    fi
fi

# Install the pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

echo "Pre-commit hooks installed successfully!"
echo ""
echo "The following hook is now active:"
echo "  - Runic Julia Formatter: Automatically formats Julia code before commits"
echo ""
echo "To test the hook, run:"
echo "  pre-commit run --all-files"
echo ""
echo "To update the hooks, run:"
echo "  pre-commit autoupdate"
