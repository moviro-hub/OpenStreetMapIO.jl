#!/bin/bash

# Setup script for pre-commit hooks

echo "Setting up pre-commit hooks for OpenStreetMapIO.jl..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "pre-commit is not installed. Installing..."

    # Try pip first, then pip3
    if command -v pip &> /dev/null; then
        pip install pre-commit
    elif command -v pip3 &> /dev/null; then
        pip3 install pre-commit
    else
        echo "Error: pip or pip3 not found. Please install pre-commit manually:"
        echo "  pip install pre-commit"
        echo "  or"
        echo "  pip3 install pre-commit"
        exit 1
    fi
fi

# Install the pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

echo "Pre-commit hooks installed successfully!"
echo ""
echo "To test the hooks, run:"
echo "  pre-commit run --all-files"
echo ""
echo "To run hooks manually on staged files:"
echo "  pre-commit run"
