# AI Agents for Julia Development

This guide explains how to use AI agents (like Cursor agents) effectively for Julia development workflows.

## Overview

AI agents can assist with various Julia development tasks, including:
- Code generation and refactoring
- Package development and testing
- Documentation generation
- Bug fixing and optimization
- Dependency management

## Setting Up Your Julia Environment

### Prerequisites

Ensure you have Julia installed and configured:

```julia
# Check Julia version
julia --version

# Start Julia REPL
julia
```

### Project Setup

For package development, use Julia's built-in package manager:

```julia
using Pkg

# Activate the project environment
Pkg.activate(".")

# Instantiate dependencies
Pkg.instantiate()

# Add new dependencies
Pkg.add("PackageName")
```

## Working with Agents

### Code Generation

Agents can help generate Julia code following best practices:

```julia
# Example: Generate a function to process OSM data
function process_osm_nodes(osmdata::OpenStreetMap)
    filtered_nodes = Dict{Int64, Node}()
    for (id, node) in osmdata.nodes
        if node.tags !== nothing && haskey(node.tags, "amenity")
            filtered_nodes[id] = node
        end
    end
    return filtered_nodes
end
```

### Type Definitions

Agents can help create comprehensive type definitions:

```julia
# Example: Define custom types for OSM data processing
struct ProcessedNode
    id::Int64
    position::Position
    tags::Dict{String, String}
    category::String
end

function categorize_node(node::Node)::ProcessedNode
    category = "other"
    if node.tags !== nothing
        if haskey(node.tags, "amenity")
            category = "amenity"
        elseif haskey(node.tags, "tourism")
            category = "tourism"
        end
    end
    return ProcessedNode(node.position, node.tags, category)
end
```

### Testing

Agents can generate test cases:

```julia
# Example: Write tests for your functions
using Test

@testset "OSM Processing Tests" begin
    # Test node filtering
    test_node = Node(Position(53.5, 10.0), Dict("amenity" => "restaurant"), nothing)
    @test haskey(test_node.tags, "amenity")
    
    # Test bounding box
    bbox = BBox(53.0, 9.0, 54.0, 11.0)
    @test bbox.bottom_lat == 53.0
    @test bbox.top_lat == 54.0
end
```

## Best Practices

### 1. Type Annotations

Always use type annotations for function parameters and return types:

```julia
function process_data(osmdata::OpenStreetMap)::Dict{String, Int}
    # Implementation
end
```

### 2. Documentation Strings

Document your functions using Julia's docstring syntax:

```julia
"""
    process_osm_data(osmdata::OpenStreetMap)

Process OpenStreetMap data and return filtered results.

# Arguments
- `osmdata::OpenStreetMap`: The OSM data to process

# Returns
- `Dict{String, Int}`: Dictionary with counts of different element types

# Examples
```julia
data = readpbf("map.pbf")
results = process_osm_data(data)
```
"""
function process_osm_data(osmdata::OpenStreetMap)::Dict{String, Int}
    # Implementation
end
```

### 3. Error Handling

Use Julia's exception handling:

```julia
function safe_read_file(filename::String)
    try
        return readpbf(filename)
    catch e
        @error "Failed to read file: $filename" exception=e
        rethrow(e)
    end
end
```

### 4. Performance Considerations

- Use type stability
- Prefer `Dict` over `Array` for lookups
- Consider using `@inbounds` for performance-critical loops
- Profile code with `ProfileView` or `BenchmarkTools`

```julia
using BenchmarkTools

# Benchmark your functions
@btime process_osm_data($osmdata)
```

## Common Tasks

### Package Development

```julia
# Create a new package
using Pkg
Pkg.generate("MyPackage")

# Add dependencies
Pkg.add("Package1")
Pkg.add("Package2")

# Update Project.toml
```

### Working with OpenStreetMapIO.jl

```julia
using OpenStreetMapIO

# Read data
osmdata = readpbf("map.pbf")

# Query Overpass API
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osmdata = queryoverpass(bbox)

# Process with callbacks
function custom_filter(node)
    # Your filtering logic
    return node
end

filtered_data = readpbf("map.pbf", node_callback=custom_filter)
```

## Tips for Effective Agent Interaction

1. **Be Specific**: Provide clear requirements and context
2. **Show Examples**: Include example data structures and expected outputs
3. **Specify Constraints**: Mention performance requirements, style preferences, etc.
4. **Iterate**: Refine requests based on generated code
5. **Test**: Always test generated code before integration

## Troubleshooting

### Common Issues

1. **Type Errors**: Ensure types match between function signatures
2. **Method Ambiguity**: Use explicit type annotations
3. **Package Loading**: Check `Project.toml` and `Manifest.toml`
4. **Performance**: Profile code to identify bottlenecks

### Getting Help

```julia
# Check function documentation
?function_name

# Inspect types
typeof(variable)

# Check available methods
methods(function_name)
```

## Resources

- [Julia Documentation](https://docs.julialang.org/)
- [Julia Package Development Guide](https://pkgdocs.julialang.org/)
- [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- [OpenStreetMapIO.jl Documentation](https://moviro-hub.github.io/OpenStreetMapIO.jl/)
