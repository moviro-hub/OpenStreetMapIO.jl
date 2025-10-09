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

# Create a simple pre-commit hook that works with Cursor
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Simple pre-commit hook for Runic formatting
echo "Running Runic formatting check..."

# Get list of staged .jl files
staged_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.jl$')

if [ -z "$staged_files" ]; then
    echo "No Julia files to check."
    exit 0
fi

# Check each file
for file in $staged_files; do
    echo "Checking $file..."
    # Use diff to detect if formatting is needed
    if julia -e "using Runic; Runic.main([\"--diff\", \"$file\"])" 2>&1 | grep -q "^diff --git"; then
        echo "❌ $file is not properly formatted!"
        echo "Please run: julia -m Runic --inplace $file"
        exit 1
    fi
done

echo "✅ All Julia files are properly formatted!"
exit 0
EOF

chmod +x .git/hooks/pre-commit

echo "Pre-commit hooks installed successfully!"
echo ""
echo "The hook will automatically check Julia file formatting on every commit."
echo "If formatting is needed, the commit will be blocked with instructions."
