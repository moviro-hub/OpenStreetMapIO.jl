# Agent Guidelines for Julia Development

Guidelines for AI agents working on Julia codebases. Focus on code quality, maintainability, and Julia best practices.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Julia Style Guide](#julia-style-guide)
3. [Type System](#type-system)
4. [Function Design](#function-design)
5. [Documentation](#documentation)
6. [Performance](#performance)
7. [Error Handling](#error-handling)
8. [Design Patterns](#design-patterns)
9. [Engineering Practices](#engineering-practices)

## Core Principles

### 1. Ask Rather Than Guess
**CRITICAL**: When intent is unclear, **always ask** rather than assume. Ask about:
- Function names and signatures
- Algorithm choices
- Data structures and types
- Design decisions
- Edge case handling
- Performance vs. readability trade-offs

### 2. Function Length
- **Target**: 25 lines per function (excluding docstrings)
- **Negotiable** based on context:
  - Complex algorithms may exceed 25 lines
  - Utility functions should be shorter
  - Over 50 lines: almost always refactor
  - Over 35 lines: review for refactoring opportunities
- Each function should do one thing well (Single Responsibility)

### 3. Minimal Code
**CRITICAL**: Write minimal, clear code. Don't state the obvious.

**Don't:**
```julia
# Bad - stating the obvious
# Create a new node
node = Node(position, tags, info)
lat = position.lat  # Get latitude
result = calculate_sum(numbers)
return result
```

**Do:**
```julia
# Good - self-explanatory
node = Node(position, tags, info)
lat = position.lat
return calculate_sum(numbers)

# Good - explain why, not what
# Use LZ4: 3x faster decompression with only 10% worse compression
decompressor = LZ4FrameDecompressorStream(stream)
```

**Add comments/clarity only when:**
- Complex algorithms or business logic
- Non-obvious performance optimizations
- Edge cases or special handling
- Workarounds for bugs or limitations

### 4. One Change at a Time
**CRITICAL**: Make small, focused changes for easier review.

- **One concern per change**: Don't mix bug fixes, refactoring, and features
- **Small diffs**: Target 50-100 lines; break large refactorings into steps
- **Separate commits**: Multiple related changes = separate commits/PRs
- **Incremental refactoring**: Add new ? switch ? remove old

**Benefits:** Easier review, lower bug risk, easier revert, clearer history

## Julia Style Guide

### Naming

- **Functions**: `lowercase_with_underscores`
- **Types/Structs**: `PascalCase`
- **Constants**: `UPPERCASE_WITH_UNDERSCORES`
- **Modules**: `PascalCase` (match filename)
- **Type parameters**: `T`, `S`, `U`, `V` (single uppercase letters)

### Formatting

- **Indentation**: 4 spaces (not tabs)
- **Line length**: Prefer < 92 chars, but readability first
- **Spacing**: 
  - Spaces around binary operators: `x + y`, `a && b`
  - No space after unary: `-x`, `!flag`
  - Space after commas: `func(a, b, c)`
  - Space after colons: `x::Int64`
  - No space before colons: `Dict{String, Int}`
- **Trailing commas**: Use in multi-line definitions

### Docstrings and Comments

**Docstrings only for:**
1. Exported functions/types (public API)
2. Complex functions where use is not obvious

```julia
# Exported - always document
"""
    readpbf(path; node_callback = nothing)

Read OpenStreetMap data from a PBF file.
"""
function readpbf(path::String; node_callback = nothing)
end

# Complex internal - document if needed
"""
Parse delta-encoded node coordinates from PBF format.
Applies cumulative deltas to base coordinates.
"""
function parse_delta_encoded_nodes(base_lat, base_lon, deltas)
end

# Simple internal - no docstring needed
function get_lat(p::Position)::Float64
    return p.lat
end
```

**Inline comments:**
- Use sparingly, only when purpose isn't obvious
- Explain **why**, not **what**
- TODO/FIXME: Always include context

## Type System

### Type Annotations

- **Public APIs**: Always annotate argument and return types
- **Internal functions**: Types optional but recommended
- **Type stability**: Critical for performance; avoid type instability in hot paths

```julia
# Good - fully typed
function parse_node(data::Vector{UInt8}, offset::Int)::Node
end

# Bad - type unstable
function get_value(dict, key)
    haskey(dict, key) ? dict[key] : nothing  # Type unknown
end

# Good - explicitly typed
function get_value(dict::Dict{String, String}, key::String)::Union{String, Nothing}
    return get(dict, key, nothing)
end
```

### Union Types

- Use for optional/nullable values: `Union{Type, Nothing}`
- Avoid `Any`; prefer specific types or structured alternatives

```julia
# Good
tags::Union{Dict{String, String}, Nothing}

# Bad
meta::Dict{String, Any}

# Better - structured type
struct Metadata
    bbox::Union{BBox, Nothing}
    timestamp::Union{DateTime, Nothing}
end
```

### Parametric Types

Use for generic code with constraints:

```julia
function process_items{T}(items::Vector{T})::Vector{T} where T
end

function sum_values{T <: Number}(values::Vector{T})::T where T
end
```

## Function Design

### Signatures

- **Keyword arguments**: Use for 3+ optional parameters
- **Default arguments**: Provide sensible defaults
- **Argument order**: Required ? optional ? keyword

```julia
function read_file(
    path::String;
    node_callback::Union{Function, Nothing} = nothing,
    verbose::Bool = false,
)::OpenStreetMap
end
```

### Function Purity

- Prefer pure functions (no side effects)
- Document side effects clearly if unavoidable

```julia
# Good - pure function
function calculate_distance(p1::Position, p2::Position)::Float64
    lat_diff = p1.lat - p2.lat
    lon_diff = p1.lon - p2.lon
    return sqrt(lat_diff^2 + lon_diff^2)
end

# Document side effects
"""
Modifies `osm` in place.
"""
function parse_into!(osm::OpenStreetMap, data::Vector{UInt8})
end
```

## Documentation

### Module Documentation

Always document modules:

```julia
"""
    ModuleName

Brief description of the module's purpose.

## Features
- Feature 1
- Feature 2

## Main Functions
- [`function1`](@ref): Description

## Examples
```julia
using ModuleName
result = function1(args)
```
"""
module ModuleName
```

### Type Documentation

Only document exported types (or complex internal types):

```julia
"""
    TypeName

Description of the type.

# Fields
- `field1::Type1`: Description

# Examples
```julia
obj = TypeName(value1, value2)
```
"""
struct TypeName
    field1::Type1
end
```

### Function Documentation

Only exported or complex functions:

```julia
"""
    function_name(param1, param2; kwarg1 = default)

Brief description.

# Arguments
- `param1::Type1`: Description

# Returns
- `ReturnType`: Description

# Examples
```julia
result = function_name(value1, value2)
```
"""
function function_name(param1::Type1, param2::Type2; kwarg1::Type3 = default)::ReturnType
end
```

## Performance

### Allocation Awareness

- Pre-allocate when size is known
- Use views to avoid copying: `@view array[start:end]`
- Avoid global variables in hot paths (use `Ref` or pass as parameter)

```julia
# Good - pre-allocate
results = Vector{Node}(undef, known_size)
for i in 1:known_size
    results[i] = create_node(data[i])
end

# Avoid globals
function increment(counter::Ref{Int})
    counter[] += 1
end
```

### Type Stability

Ensure type stability in performance-critical code:

```julia
# Type stable
function sum_values(values::Vector{Float64})::Float64
    total = 0.0  # Float64, not Int
    for v in values
        total += v
    end
    return total
end
```

Use `@code_warntype` to check for type instability.

### Broadcasting

Use broadcasting for element-wise operations:

```julia
# Good
distances = sqrt.((lat1 .- lat2).^2 .+ (lon1 .- lon2).^2)
```

## Error Handling

### Exception Types

- Use appropriate exception types
- Provide helpful error messages with context

```julia
# Good - specific exception
if !isfile(path)
    throw(ArgumentError("File not found: $path"))
end

# Good - custom exception
struct OSMParseError <: Exception
    message::String
    position::Int
end

# Good - helpful message
if length(refs) != length(roles)
    throw(ArgumentError(
        "Mismatch: refs has $(length(refs)) elements but roles has $(length(roles))"
    ))
end
```

### Validation

- Validate inputs in public APIs
- Fail fast with clear error messages

```julia
function create_node(lat::Float64, lon::Float64, tags, info)
    if lat < -90 || lat > 90
        throw(ArgumentError("Latitude must be between -90 and 90, got $lat"))
    end
    if lon < -180 || lon > 180
        throw(ArgumentError("Longitude must be between -180 and 180, got $lon"))
    end
end
```

## Design Patterns

### Builder Pattern

For complex object construction:

```julia
struct NodeBuilder
    position::Union{Position, Nothing}
    tags::Union{Dict{String, String}, Nothing}
end

NodeBuilder() = NodeBuilder(nothing, nothing)

function set_position(builder::NodeBuilder, pos::Position)::NodeBuilder
    return NodeBuilder(pos, builder.tags)
end

function build(builder::NodeBuilder)::Node
    builder.position === nothing && throw(ArgumentError("Position required"))
    return Node(builder.position, builder.tags, builder.info)
end
```

### Strategy Pattern

For algorithm selection:

```julia
abstract type CompressionStrategy end
struct LZ4Strategy <: CompressionStrategy end
struct ZstdStrategy <: CompressionStrategy end

decompress(stream, ::LZ4Strategy) = LZ4FrameDecompressorStream(stream)
decompress(stream, ::ZstdStrategy) = ZstdDecompressorStream(stream)
```

### Callback Pattern

For flexible data processing:

```julia
function process_nodes(
    data::Vector{Node};
    callback::Union{Function, Nothing} = nothing,
)::Vector{Node}
    result = Node[]
    for node in data
        processed = callback === nothing ? node : callback(node)
        processed !== nothing && push!(result, processed)
    end
    return result
end
```

### Factory Pattern

For object creation with different sources:

```julia
function create_reader(source::String)::OSMReader
    if endswith(source, ".pbf")
        return PBFReader(source)
    elseif endswith(source, ".osm") || endswith(source, ".xml")
        return XMLReader(source)
    else
        throw(ArgumentError("Unknown file format: $source"))
    end
end
```

## Engineering Practices

### Testing

- Write tests for all public APIs
- Test edge cases: empty inputs, boundary values, error conditions
- Use descriptive test names

```julia
@testset "Node creation" begin
    @test_throws ArgumentError Node(Position(100.0, 0.0), nothing, nothing)
    @test Node(Position(0.0, 0.0), nothing, nothing) isa Node
end
```

### Code Reuse (DRY)

Extract common patterns:

```julia
# Bad - repeated pattern
if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
end

# Good - extracted function
function is_restaurant(node::Node)::Bool
    return node.tags !== nothing &&
           haskey(node.tags, "amenity") &&
           node.tags["amenity"] == "restaurant"
end
```

### Dependency Management

- Specify Julia version in Project.toml: `julia = "1.6"`
- Pin dependency versions
- Minimize dependencies
- Document non-standard dependencies

### Code Organization

**File structure:**
- One type per file for large types, or group related types
- Group related functionality

**Export strategy:**
- Export only public API
- Prefix internal functions with `_` or place in internal module
- Use qualified imports when names conflict

**Module structure:**
```julia
module OpenStreetMapIO
    include("map_types.jl")      # Type definitions
    include("utils.jl")           # Utility functions
    include("load_pbf.jl")        # PBF file loading
    include("load_xml.jl")        # XML file loading
    include("load_overpass.jl")   # Overpass API
end
```

### Additional Guidelines

**Memory Management:**
- Be aware of memory usage for large datasets
- Consider streaming for very large files
- Use appropriate data structures (Dict vs. Vector)

**Concurrency:**
- Document thread-safety assumptions
- Use appropriate synchronization if shared state is modified

**API Evolution:**
- Maintain backward compatibility when possible
- Deprecate rather than remove: `Base.@deprecate old_function(args...) new_function(args...)`

## Code Review Checklist

- [ ] Type annotations present for public APIs
- [ ] Documentation complete for exported/complex functions
- [ ] Error handling appropriate
- [ ] No type instability in hot paths
- [ ] Tests cover main functionality and edge cases
- [ ] Function length reasonable (target 25 lines)
- [ ] Code follows naming conventions
- [ ] No unnecessary allocations in loops
- [ ] Input validation where appropriate
- [ ] No redundant comments or obvious statements
- [ ] Code is minimal and self-documenting
- [ ] Changes focused on single concern
- [ ] Diffs kept small and reviewable

## Summary

Agents should:
1. **Always ask** when intent is unclear
2. **Target 25 lines** per function (negotiable)
3. **Write minimal code** - don't state the obvious
4. **One change at a time** - keep diffs small
5. **Follow Julia conventions** - naming, formatting, types
6. **Document** exported/complex functions only
7. **Consider performance** - type stability, allocations
8. **Handle errors** gracefully with helpful messages
9. **Write tests** for public APIs
10. **Organize code** logically

**Remember:** Quality over speed. Ask for clarification rather than guessing. Keep code minimal and clear. Make small, focused changes for easier review.
