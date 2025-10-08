# Developer Guide

This guide is for developers who want to contribute to OpenStreetMapIO.jl or understand its internal architecture.

## Project Structure

```
OpenStreetMapIO.jl/
├── src/
│   ├── OpenStreetMapIO.jl          # Main module file
│   ├── map_types.jl                # Core data type definitions
│   ├── io_pbf.jl                   # PBF file reading implementation
│   ├── io_xml.jl                   # XML file reading implementation
│   └── protobuf/
│       ├── OSMPBF.jl               # Protobuf module
│       ├── fileformat_pb.jl        # Generated protobuf code
│       ├── osmformat_pb.jl         # Generated protobuf code
│       └── proto/
│           ├── fileformat.proto    # Protobuf definitions
│           └── osmformat.proto     # Protobuf definitions
├── test/
│   ├── runtests.jl                 # Test runner
│   ├── test_*.jl                   # Individual test files
│   └── data/                       # Test data files
├── docs/
│   ├── make.jl                     # Documentation builder
│   └── src/                        # Documentation source
└── scripts/
    └── update_protobuf.jl          # Protobuf update script
```

## Architecture Overview

### Core Components

1. **Data Types** (`map_types.jl`): Defines the core OSM data structures
2. **PBF Reader** (`io_pbf.jl`): Handles Protocol Buffer Format files
3. **XML Reader** (`io_xml.jl`): Handles XML format files
4. **Protobuf Layer** (`protobuf/`): Generated code for PBF parsing

### Design Principles

- **Type Safety**: Strong typing throughout the codebase
- **Performance**: Optimized for large datasets
- **Memory Efficiency**: Streaming processing where possible
- **Error Handling**: Comprehensive error handling with descriptive messages
- **Extensibility**: Callback system for custom processing

## Development Setup

### Prerequisites

- Julia 1.6 or later
- Git

### Setup

1. Clone the repository:
```bash
git clone https://github.com/moviro-hub/OpenStreetMapIO.jl.git
cd OpenStreetMapIO.jl
```

2. Start Julia and activate the project:
```julia
julia --project=.
```

3. Install dependencies:
```julia
using Pkg
Pkg.instantiate()
```

4. Run tests to verify setup:
```julia
Pkg.test()
```

## Code Style Guidelines

### General Style

- Follow Julia style guidelines
- Use descriptive variable and function names
- Add comprehensive docstrings for all public functions
- Include type annotations for function parameters and return values

### Documentation

- Use Julia's docstring format with `@docs` for API documentation
- Include examples in docstrings where helpful
- Document all public functions and types
- Keep documentation up to date with code changes

### Testing

- Write tests for all new functionality
- Include edge cases and error conditions
- Use descriptive test names
- Aim for high test coverage

## Adding New Features

### 1. Planning

- Create an issue describing the feature
- Discuss the design with maintainers
- Consider backward compatibility

### 2. Implementation

- Create a feature branch
- Implement the feature with tests
- Update documentation
- Ensure all tests pass

### 3. Testing

```julia
# Run all tests
Pkg.test()

# Run specific test file
include("test/test_specific.jl")

# Run with coverage
Pkg.test(coverage=true)
```

### 4. Documentation

- Update relevant documentation files
- Add examples if appropriate
- Update the API reference

## Protobuf Development

### Updating Protobuf Definitions

The package uses Protocol Buffers for PBF file parsing. To update the protobuf definitions:

1. Update the `.proto` files in `src/protobuf/proto/`
2. Run the update script:
```julia
julia scripts/update_protobuf.jl
```

This will regenerate the Julia protobuf code.

### Adding New Protobuf Support

1. Add the new `.proto` file to `src/protobuf/proto/`
2. Update `scripts/update_protobuf.jl` to include the new file
3. Run the update script
4. Add the generated file to `src/protobuf/OSMPBF.jl`

## Performance Considerations

### Memory Usage

- Use callbacks to filter data during reading
- Avoid loading entire datasets into memory when possible
- Use streaming processing for large files

### CPU Performance

- Optimize hot paths in file reading
- Use efficient data structures
- Profile code to identify bottlenecks

### Example Profiling

```julia
using Profile

# Profile a function
@profile readpbf("large_file.pbf")

# View results
Profile.print()
```

## Error Handling

### Error Types

- `ArgumentError`: Invalid arguments or file format issues
- `SystemError`: File system errors
- `ProtoBuf.ProtoError`: Protobuf parsing errors

### Best Practices

- Provide descriptive error messages
- Include context about what operation failed
- Handle errors gracefully where possible
- Log warnings for non-fatal issues

## Testing Strategy

### Test Categories

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test complete workflows
3. **Performance Tests**: Ensure acceptable performance
4. **Error Tests**: Test error conditions

### Test Data

- Use small, representative test files
- Include various data types and edge cases
- Keep test data in `test/data/`

### Running Tests

```julia
# Run all tests
Pkg.test()

# Run with verbose output
Pkg.test(verbose=true)

# Run specific test
include("test/test_specific.jl")
```

## Documentation Development

### Building Documentation

```julia
# Install documentation dependencies
using Pkg
Pkg.activate("docs")
Pkg.instantiate()

# Build documentation
using Documenter
include("docs/make.jl")
```

### Documentation Structure

- `index.md`: Main landing page
- `getting_started.md`: Basic usage guide
- `api.md`: Complete API reference
- `examples.md`: Comprehensive examples
- `developer.md`: This guide

## Release Process

### Version Bumping

1. Update version in `Project.toml`
2. Update `CHANGELOG.md`
3. Create a release tag
4. Update documentation

### Pre-release Checklist

- [ ] All tests pass
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated
- [ ] Version is bumped
- [ ] No breaking changes (or properly documented)

## Contributing

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Update documentation
6. Submit a pull request

### Code Review

- All changes require review
- Address review comments promptly
- Keep pull requests focused and small
- Include tests for new functionality

## Debugging

### Common Issues

1. **Protobuf errors**: Usually indicate corrupted PBF files
2. **Memory issues**: Use callbacks to reduce memory usage
3. **Performance issues**: Profile to identify bottlenecks

### Debugging Tools

```julia
# Enable debug logging
using Logging
Logging.with_logger(Logging.ConsoleLogger(stderr, Logging.Debug)) do
    readpbf("file.pbf")
end

# Use Julia's debugger
using Debugger
@enter readpbf("file.pbf")
```

## Getting Help

- Check existing issues on GitHub
- Create a new issue for bugs or feature requests
- Join discussions in GitHub Discussions
- Review the code and documentation

## License

This project is licensed under the MIT License. By contributing, you agree that your contributions will be licensed under the same license.
