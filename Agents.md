# Agent Guidelines for Julia Development

This document provides comprehensive guidelines for AI agents working on Julia codebases. Agents should follow these rules to ensure code quality, maintainability, and adherence to Julia best practices.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Julia Style Guide](#julia-style-guide)
3. [Type System Best Practices](#type-system-best-practices)
4. [Function Design](#function-design)
5. [Documentation Standards](#documentation-standards)
6. [Performance Best Practices](#performance-best-practices)
7. [Error Handling](#error-handling)
8. [Design Patterns](#design-patterns)
9. [Engineering Best Practices](#engineering-best-practices)
10. [Code Organization](#code-organization)

## Core Principles

### 1. Ask Rather Than Guess
**CRITICAL**: When user intent is unclear or ambiguous, **always ask for clarification** rather than making assumptions. This applies to:
- Function names and signatures
- Algorithm choices
- Data structures and types
- Design decisions
- Edge case handling
- Performance vs. readability trade-offs

**Examples of when to ask:**
- "Should this function handle missing values or should callers validate input?"
- "Would you prefer a more generic solution or one optimized for this specific use case?"
- "Should I optimize for memory or speed here?"
- "What should happen if the input is empty/invalid?"

### 2. Function Length Guidelines
- **Target length**: 25 lines per function (excluding docstrings)
- **This is negotiable** based on context:
  - Complex algorithms may reasonably exceed 25 lines
  - Utility functions should be shorter
  - If a function exceeds 25 lines, consider:
    - Can it be split into smaller, focused functions?
    - Are there repeated patterns that can be extracted?
    - Is the complexity justified by the domain logic?

**Refactoring triggers:**
- Functions over 50 lines should almost always be refactored
- Functions over 35 lines should be reviewed for refactoring opportunities
- Single Responsibility Principle: each function should do one thing well

### 3. Minimal Commands and Code Clarity
**CRITICAL**: Write minimal, clear code. Do not state the obvious. Only add comments, intermediate variables, or verbose explanations if the code would otherwise be difficult to read or understand.

**Guidelines:**
- **Avoid redundant comments** that simply restate what the code does
  ```julia
  # Bad - stating the obvious
  # Create a new node
  node = Node(position, tags, info)
  
  # Bad - obvious variable naming doesn't need explanation
  # Get the latitude from the position
  lat = position.lat
  
  # Good - code is self-explanatory
  node = Node(position, tags, info)
  lat = position.lat
  ```

- **Skip obvious intermediate steps** unless they improve readability
  ```julia
  # Bad - unnecessary intermediate variable
  result = calculate_sum(numbers)
  return result
  
  # Good - direct return
  return calculate_sum(numbers)
  ```

- **Only add comments when code needs explanation** (why, not what)
  ```julia
  # Good - explains non-obvious reasoning
  # Use LZ4 instead of zlib: 3x faster decompression with only 10% worse compression
  decompressor = LZ4FrameDecompressorStream(stream)
  
  # Good - clarifies complex logic or edge case
  # Handle historical data where nodes may have been deleted
  if info !== nothing && info.visible === false
      continue
  end
  ```

- **Use descriptive names** instead of comments
  ```julia
  # Bad - needs comment because name is unclear
  # Check if node is within bounding box
  if check(n, b)
  
  # Good - self-documenting code
  if is_within_bbox(node, bbox)
  ```

- **Avoid verbose variable names** that repeat type information
  ```julia
  # Bad - unnecessarily verbose
  node_dictionary_dict = Dict{Int64, Node}()
  
  # Good - concise and clear
  nodes = Dict{Int64, Node}()
  ```

**When to add clarity:**
- Complex algorithms or business logic
- Non-obvious performance optimizations
- Edge cases or special handling
- Workarounds for bugs or limitations
- Domain-specific knowledge not obvious from code

**When to keep it minimal:**
- Simple assignments and operations
- Standard library function calls
- Type conversions that are obvious
- Iteration patterns (for loops, comprehensions)
- Standard control flow (if/else, return)

## Julia Style Guide

### Naming Conventions

1. **Functions**: Use lowercase with underscores for readability
   ```julia
   # Good
   function calculate_distance(a, b)
   function parse_xml_content(content)
   
   # Avoid
   function calculateDistance(a, b)
   function ParseXMLContent(content)
   ```

2. **Types/Structs**: Use PascalCase
   ```julia
   # Good
   struct Node
   struct Position
   mutable struct BufferedReader
   
   # Avoid
   struct node
   struct position
   ```

3. **Constants**: Use UPPERCASE with underscores
   ```julia
   # Good
   const DEFAULT_TIMEOUT = 60
   const MAX_BUFFER_SIZE = 1024 * 1024
   
   # Avoid
   const defaultTimeout = 60
   const DefaultTimeout = 60
   ```

4. **Module names**: Use PascalCase, matching filename
   ```julia
   # File: OpenStreetMapIO.jl
   module OpenStreetMapIO
   ```

5. **Type parameters**: Use single uppercase letters (T, S, U, V, etc.)
   ```julia
   function process_data{T}(data::Vector{T}) where T
   ```

### Code Formatting

1. **Indentation**: Use 4 spaces (not tabs)
   ```julia
   # Good
   function example(x, y)
       if x > y
           return x
       else
           return y
       end
   end
   ```

2. **Line length**: Prefer lines under 92 characters, but readability over strict limits
   ```julia
   # Good - readable even if slightly long
   function long_function_name(parameter1::Type1, parameter2::Type2)::ReturnType
       # ...
   end
   
   # Better - if it's too long, split parameters
   function long_function_name(
       parameter1::Type1,
       parameter2::Type2,
       parameter3::Type3,
   )::ReturnType
       # ...
   end
   ```

3. **Spacing**:
   - Use spaces around binary operators: `x + y`, `a && b`
   - No space after unary operators: `-x`, `!flag`
   - Space after commas: `func(a, b, c)`
   - Space after colons in type annotations: `x::Int64`
   - No space before colons: `Dict{String, Int}`

4. **Trailing commas**: Use trailing commas in multi-line function calls/definitions
   ```julia
   function example(
       param1::Type1,
       param2::Type2,
       param3::Type3,  # trailing comma
   )
   ```

### Comments and Docstrings

1. **Docstrings**: Use triple-quoted strings (`"""`) **only** for:
   - **Exported functions/types** (public API)
   - **Complex functions** where the use is not obvious
   
   ```julia
   # Good - exported function (always needs docstring)
   """
       readpbf(path; node_callback = nothing, way_callback = nothing)
   
   Read OpenStreetMap data from a PBF file.
   
   # Arguments
   - `path::String`: Path to the PBF file
   - `node_callback::Union{Function, Nothing} = nothing`: Optional callback to filter nodes
   
   # Returns
   - `OpenStreetMap`: Parsed OSM data
   """
   function readpbf(path::String; node_callback = nothing, way_callback = nothing)
       # ...
   end
   ```
   
   ```julia
   # Good - complex function where use might not be obvious
   """
       parse_delta_encoded_nodes(base_lat, base_lon, deltas)
   
   Parse delta-encoded node coordinates from PBF format.
   Applies cumulative deltas to base coordinates.
   """
   function parse_delta_encoded_nodes(base_lat::Float64, base_lon::Float64, deltas::Vector{Int64})
       # Complex delta decoding logic...
   end
   ```
   
   ```julia
   # Good - simple internal function, no docstring needed
   function validate_position(lat::Float64, lon::Float64)::Nothing
       if lat < -90 || lat > 90
           throw(ArgumentError("Invalid latitude: $lat"))
       end
       if lon < -180 || lon > 180
           throw(ArgumentError("Invalid longitude: $lon"))
       end
   end
   ```
   
   ```julia
   # Good - simple helper, use is obvious from name and types
   function get_tag_value(tags::Union{Dict{String, String}, Nothing}, key::String)::Union{String, Nothing}
       return tags === nothing ? nothing : get(tags, key, nothing)
   end
   ```

2. **Inline comments**: Use sparingly, only when code purpose isn't obvious (see [Core Principle #3](#3-minimal-commands-and-code-clarity))
   ```julia
   # Good - explains why, not what
   # Use LZ4 for faster decompression with acceptable compression ratio
   decompressor = LZ4FrameDecompressorStream(stream)
   
   # Bad - states the obvious
   # Create a new node
   node = Node(position, tags, info)
   ```

3. **TODO/FIXME comments**: Always include context
   ```julia
   # TODO: Optimize for large datasets (>1M nodes) - consider streaming
   # FIXME: Handle timezone conversion when timestamps are present
   ```

## Type System Best Practices

### Type Annotations

1. **Function arguments**: Always annotate types for public APIs
   ```julia
   # Good
   function parse_node(data::Vector{UInt8}, offset::Int)::Node
   function calculate_distance(p1::Position, p2::Position)::Float64
   
   # For internal functions, types are optional but recommended
   function _helper_function(data)
   ```

2. **Return types**: Annotate return types, especially for public functions
   ```julia
   function read_file(path::String)::OpenStreetMap
   function get_node_count(osm::OpenStreetMap)::Int64
   ```

3. **Type stability**: Avoid type instability in hot code paths
   ```julia
   # Bad - type unstable
   function get_value(dict, key)
       if haskey(dict, key)
           return dict[key]  # Type depends on dict contents
       else
           return nothing
       end
   end
   
   # Good - explicitly typed
   function get_value(dict::Dict{String, String}, key::String)::Union{String, Nothing}
       return get(dict, key, nothing)
   end
   ```

### Union Types

1. **Use Union types** for optional or nullable values
   ```julia
   # Good
   tags::Union{Dict{String, String}, Nothing}
   info::Union{Info, Nothing}
   
   # Better - consider using concrete types with sentinel values or Options.jl
   ```

2. **Avoid Any**: Minimize use of `Any`; prefer specific types or Union types
   ```julia
   # Bad
   meta::Dict{String, Any}
   
   # Better
   meta::Dict{String, Union{String, Int64, Float64, BBox}}
   
   # Or use a structured type
   struct Metadata
       bbox::Union{BBox, Nothing}
       timestamp::Union{DateTime, Nothing}
       # ...
   end
   ```

### Parametric Types

1. **Use parametric types** for generic code
   ```julia
   # Good
   function process_items{T}(items::Vector{T})::Vector{T} where T
       # ...
   end
   
   # Better - with constraints
   function sum_values{T <: Number}(values::Vector{T})::T where T
       # ...
   end
   ```

## Function Design

### Function Signatures

1. **Keyword arguments**: Use for optional parameters (more than 2-3 optional params)
   ```julia
   # Good
   function read_file(
       path::String;
       node_callback::Union{Function, Nothing} = nothing,
       way_callback::Union{Function, Nothing} = nothing,
       verbose::Bool = false,
   )::OpenStreetMap
   ```

2. **Default arguments**: Provide sensible defaults
   ```julia
   function create_buffer(size::Int = 1024, growable::Bool = true)
   ```

3. **Argument order**: Required arguments first, then optional, then keyword arguments
   ```julia
   function example(
       required1::Type1,
       required2::Type2,
       optional::Type3 = default_value;
       kwarg1::Type4 = default1,
       kwarg2::Type5 = default2,
   )
   ```

### Function Purity

1. **Prefer pure functions**: Functions without side effects are easier to test and reason about
   ```julia
   # Good - pure function
   function calculate_distance(p1::Position, p2::Position)::Float64
       lat_diff = p1.lat - p2.lat
       lon_diff = p1.lon - p2.lon
       return sqrt(lat_diff^2 + lon_diff^2)
   end
   
   # Document side effects clearly if unavoidable
   """
   Parse OSM data and populate the provided OpenStreetMap structure.
   Modifies `osm` in place.
   """
   function parse_into!(osm::OpenStreetMap, data::Vector{UInt8})
   ```

### Single Responsibility

1. **Each function should do one thing well**
   ```julia
   # Bad - does too much
   function process_and_save_and_log(data)
       processed = process(data)
       save(processed)
       log("Saved")
       return processed
   end
   
   # Good - separate concerns
   function process_data(data)
       return process(data)
   end
   
   function save_data(data, path)
       save(data, path)
   end
   ```

## Documentation Standards

**Important**: Docstrings should **only** be used for:
1. **Exported functions/types** (public API) - always document these
2. **Complex functions** where the use is not obvious - document if clarity is needed

Simple internal functions with clear names and obvious behavior do **not** need docstrings.

### Module Documentation

Modules should always be documented:

```julia
"""
    ModuleName

Brief description of the module's purpose.

## Features

- Feature 1
- Feature 2

## Main Functions

- [`function1`](@ref): Description
- [`function2`](@ref): Description

## Examples

```julia
using ModuleName
result = function1(args)
```
"""
module ModuleName
```

### Type Documentation

**Only document exported types** (or complex internal types if use is not obvious):

```julia
"""
    TypeName

Description of the type and its purpose.

# Fields
- `field1::Type1`: Description of field1
- `field2::Type2`: Description of field2

# Examples
```julia
obj = TypeName(value1, value2)
```
"""
struct TypeName
    field1::Type1
    field2::Type2
end
```

### Function Documentation

**Only document exported functions or complex functions**:

```julia
"""
    function_name(param1, param2; kwarg1 = default)

Brief one-line description.

Extended description if needed, explaining use cases, edge cases, or important
implementation details.

# Arguments
- `param1::Type1`: Description of param1
- `param2::Type2`: Description of param2

# Keyword Arguments
- `kwarg1::Type3 = default`: Description of kwarg1

# Returns
- `ReturnType`: Description of return value

# Examples
```julia
result = function_name(value1, value2; kwarg1 = value3)
```

# See Also
- [`related_function`](@ref)
"""
function function_name(param1::Type1, param2::Type2; kwarg1::Type3 = default)::ReturnType
```

**Simple internal functions don't need docstrings**:
```julia
# No docstring needed - function name and types make use obvious
function get_lat(p::Position)::Float64
    return p.lat
end
```

## Performance Best Practices

### Allocation Awareness

1. **Pre-allocate when size is known**
   ```julia
   # Good
   results = Vector{Node}(undef, known_size)
   for i in 1:known_size
       results[i] = create_node(data[i])
   end
   
   # Less optimal for known sizes
   results = Node[]
   for data_item in data
       push!(results, create_node(data_item))
   end
   ```

2. **Use views when possible** to avoid copying
   ```julia
   # Good
   subarray = @view array[start_idx:end_idx]
   
   # Avoids copying
   ```

3. **Avoid global variables** in hot code paths
   ```julia
   # Bad
   global counter = 0
   function increment()
       global counter += 1
   end
   
   # Good
   function increment(counter::Ref{Int})
       counter[] += 1
   end
   ```

### Type Stability

1. **Ensure type stability** in performance-critical code
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

2. **Use @code_warntype** to check for type instability

### Broadcasting

1. **Use broadcasting** for element-wise operations
   ```julia
   # Good
   distances = sqrt.((lat1 .- lat2).^2 .+ (lon1 .- lon2).^2)
   
   # Less efficient
   distances = [sqrt((lat1[i] - lat2[i])^2 + (lon1[i] - lon2[i])^2) for i in 1:length(lat1)]
   ```

## Error Handling

### Exception Types

1. **Use appropriate exception types**
   ```julia
   # Good - specific exception
   if !isfile(path)
       throw(ArgumentError("File not found: $path"))
   end
   
   # Good - custom exception type
   struct OSMParseError <: Exception
       message::String
       position::Int
   end
   
   throw(OSMParseError("Invalid node format", current_offset))
   ```

2. **Provide helpful error messages**
   ```julia
   # Good
   if length(refs) != length(roles)
       throw(ArgumentError(
           "Mismatch: refs has $(length(refs)) elements but roles has $(length(roles))"
       ))
   end
   
   # Bad
   if length(refs) != length(roles)
       throw(ErrorException("Error"))
   end
   ```

### Validation

1. **Validate inputs** in public APIs
   ```julia
   function create_node(lat::Float64, lon::Float64, tags, info)
       if lat < -90 || lat > 90
           throw(ArgumentError("Latitude must be between -90 and 90, got $lat"))
       end
       if lon < -180 || lon > 180
           throw(ArgumentError("Longitude must be between -180 and 180, got $lon"))
       end
       # ...
   end
   ```

2. **Fail fast**: Validate early rather than failing later with confusing errors

## Design Patterns

### Builder Pattern

For complex object construction:
```julia
struct NodeBuilder
    position::Union{Position, Nothing}
    tags::Union{Dict{String, String}, Nothing}
    info::Union{Info, Nothing}
end

NodeBuilder() = NodeBuilder(nothing, nothing, nothing)

function set_position(builder::NodeBuilder, pos::Position)::NodeBuilder
    return NodeBuilder(pos, builder.tags, builder.info)
end

function build(builder::NodeBuilder)::Node
    if builder.position === nothing
        throw(ArgumentError("Position is required"))
    end
    return Node(builder.position, builder.tags, builder.info)
end
```

### Strategy Pattern

For algorithm selection:
```julia
abstract type CompressionStrategy end

struct LZ4Strategy <: CompressionStrategy end
struct ZstdStrategy <: CompressionStrategy end

function decompress(stream, strategy::LZ4Strategy)
    return LZ4FrameDecompressorStream(stream)
end

function decompress(stream, strategy::ZstdStrategy)
    return ZstdDecompressorStream(stream)
end
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
        if processed !== nothing
            push!(result, processed)
        end
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

## Engineering Best Practices

### Testing

1. **Write tests** for all public APIs
   ```julia
   @testset "Node creation" begin
       @test_throws ArgumentError Node(Position(100.0, 0.0), nothing, nothing)
       @test Node(Position(0.0, 0.0), nothing, nothing) isa Node
   end
   ```

2. **Test edge cases**: empty inputs, boundary values, error conditions

3. **Use descriptive test names** that explain what is being tested

### Code Reuse

1. **Don't repeat yourself (DRY)**: Extract common patterns into functions
   ```julia
   # Bad - repeated pattern
   if node.tags !== nothing && haskey(node.tags, "amenity") && node.tags["amenity"] == "restaurant"
       # ...
   end
   
   # Good - extracted function
   function is_restaurant(node::Node)::Bool
       return node.tags !== nothing &&
              haskey(node.tags, "amenity") &&
              node.tags["amenity"] == "restaurant"
   end
   ```

2. **Use helper functions** for complex logic
   ```julia
   # Extract complex validation
   function validate_position(lat::Float64, lon::Float64)::Nothing
       # ... validation logic
   end
   ```

### Version Compatibility

1. **Specify Julia version** in Project.toml
   ```toml
   [compat]
   julia = "1.6"
   ```

2. **Use Compat.jl** for cross-version compatibility when needed

### Dependency Management

1. **Pin dependency versions** in Project.toml
   ```toml
   [compat]
   ProtoBuf = "1.2.0"
   ```

2. **Minimize dependencies**: Only include what's necessary

3. **Document why** non-standard dependencies are needed

## Code Organization

### File Structure

1. **One type per file** for large types, or group related types together

2. **Module organization**: Group related functionality
   ```julia
   # OpenStreetMapIO.jl - main module
   module OpenStreetMapIO
       include("map_types.jl")      # Type definitions
       include("utils.jl")           # Utility functions
       include("load_pbf.jl")        # PBF file loading
       include("load_xml.jl")        # XML file loading
       include("load_overpass.jl")   # Overpass API
   end
   ```

### Export Strategy

1. **Export only public API**: Don't export internal helper functions
   ```julia
   # Good
   export readpbf, readosm, queryoverpass
   export OpenStreetMap, Node, Way, Relation
   
   # Internal helpers not exported
   function _parse_node_internal(data)
   ```

2. **Use qualified imports** when names might conflict
   ```julia
   import ProtoBuf: decode as pb_decode
   ```

### Internal vs. Public

1. **Prefix internal functions** with underscore or place in internal module
   ```julia
   function _helper_function(data)
   # or
   module Internal
       function helper_function(data)
   end
   ```

## Additional Guidelines

### Memory Management

1. **Be aware of memory usage** for large datasets
2. **Consider streaming** for very large files instead of loading entirely into memory
3. **Use appropriate data structures**: Dict vs. Vector based on access patterns

### Concurrency

1. **Thread safety**: Document thread-safety assumptions
2. **Use appropriate synchronization** if shared state is modified

### API Evolution

1. **Maintain backward compatibility** when possible
2. **Deprecate** rather than remove: use `Base.@deprecate`
   ```julia
   Base.@deprecate old_function(args...) new_function(args...)
   ```

### Code Review Checklist

When reviewing or writing code, check:
- [ ] Type annotations present for public APIs
- [ ] Documentation complete for exported functions and complex functions
- [ ] Error handling appropriate
- [ ] No type instability in hot paths
- [ ] Tests cover main functionality and edge cases
- [ ] Function length reasonable (target 25 lines)
- [ ] Code follows naming conventions
- [ ] No unnecessary allocations in loops
- [ ] Input validation where appropriate
- [ ] No redundant comments or obvious statements
- [ ] Code is minimal and self-documenting

## Summary

Agents should:
1. **Always ask** when user intent is unclear
2. **Target 25 lines** per function, but be flexible based on context
3. **Write minimal code** - don't state the obvious; only add comments/clarity when code would otherwise be difficult to read
4. **Follow Julia conventions** for naming, formatting, and type annotations
5. **Write documentation** for exported functions/types and complex functions where use is not obvious
6. **Consider performance** implications, especially type stability
7. **Handle errors** gracefully with informative messages
8. **Write tests** for public APIs
9. **Organize code** logically and maintain separation of concerns

Remember: **Quality over speed**. It's better to ask for clarification than to implement the wrong solution. Keep code minimal and clear?avoid redundancy.
