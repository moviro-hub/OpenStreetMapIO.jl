#!/bin/bash

# Setup script for Runic pre-commit hook

echo "Setting up Runic pre-commit hook..."

# Create the pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Runic formatting check
echo "Running Runic formatting check..."

# Get staged .jl files
staged_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.jl$')

if [ -z "$staged_files" ]; then
    echo "No Julia files to check."
    exit 0
fi

# Check each file
for file in $staged_files; do
    echo "Checking $file..."
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

echo "✅ Runic pre-commit hook installed successfully!"
echo "The hook will check Julia file formatting on every commit."
