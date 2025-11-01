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
**CRITICAL**: When intent is unclear, **always ask** rather than assume. Ask about function names, algorithms, data structures, design decisions, edge cases, and performance trade-offs.

### 2. Function Length
- **Target**: 25 lines per function (excluding docstrings)
- **Negotiable** based on context
- Over 50 lines: almost always refactor
- Over 35 lines: review for refactoring
- Each function should do one thing well

### 3. Minimal Code
**CRITICAL**: Write minimal, clear code. Don't state the obvious.

```julia
# Bad
# Create a new value
value = 42
result = sum(numbers)
return result

# Good
value = 42
return sum(numbers)

# Good - explain why, not what
# Prefer sqrt over x^0.5 for better numerical stability
result = sqrt(value)
```

Add comments only for: complex algorithms, non-obvious optimizations, edge cases, workarounds.

### 4. One Change at a Time
**CRITICAL**: Make small, focused changes for easier review.

- One concern per change
- Target 50-100 lines per diff
- Separate commits for multiple changes
- Incremental refactoring: Add new ? switch ? remove old

## Julia Style Guide

### Naming
- **Functions**: `snake_case` (`compute_value`, `parse_data`)
- **Mutating functions**: Use `!` suffix (`sort!`, `push!`, `append!`)
- **Predicates**: Use `?` suffix or `is_` prefix (`isempty`, `haskey`)
- **Types/Structs**: `PascalCase`
- **Constants**: `SCREAMING_SNAKE_CASE` with `const`
- **Modules**: `PascalCase` (match filename)
- **Type parameters**: Single uppercase letters (`T`, `S`, `U`, `V`, `N`, `M`)

### Formatting
- **Indentation**: 4 spaces
- **Line length**: Prefer < 92 chars, readability first
- **Spacing**: 
  - Spaces around binary ops (`x + y`)
  - No space after unary (`-x`, `!flag`)
  - Space after commas, space after colons (`x::Int64`)
  - No space before colons (`Dict{String, Int}`)
- **Trailing commas**: Use in multi-line definitions

### Docstrings and Comments
**Docstrings only for:**
1. Exported functions/types (public API)
2. Complex functions where use is not obvious

```julia
# Exported
"""
    compute_average(values)

Calculate the arithmetic mean of a collection of numbers.
"""
function compute_average(values::Vector{Float64})::Float64
end

# Simple internal - no docstring needed
function get_first(items::Vector{T})::Union{T, Nothing} where T
    return isempty(items) ? nothing : items[1]
end
```

**Inline comments**: Use sparingly, explain **why** not **what**. TODO/FIXME must include context.

## Type System

### Type Annotations
- **Public APIs**: Always annotate argument and return types
- **Internal functions**: Types optional but recommended
- **Type stability**: Critical for performance

```julia
# Good - fully typed
function add_numbers(a::Float64, b::Float64)::Float64
    return a + b
end

# Bad - type unstable
function get_value(container, key)
    haskey(container, key) ? container[key] : nothing
end

# Good - explicitly typed
function get_value(container::Dict{String, Int}, key::String)::Union{Int, Nothing}
    return get(container, key, nothing)
end
```

### Parametric Types vs Union Types

**Use parametric types** for type stability when type varies but is known at construction:

```julia
# Bad - abstract type field causes type instability
struct Container
    items::Vector{Number}  # Slow, type-unstable
end

# Good - parametric type is type-stable
struct Container{T <: Number}
    items::Vector{T}  # Fast, type-stable
end

# Usage
int_container = Container{Int}([1, 2, 3])
float_container = Container{Float64}([1.0, 2.0, 3.0])
```

**Use Union types** for truly optional/nullable values or when multiple specific types are needed at runtime:

```julia
# Good - optional field
name::Union{String, Nothing}

# Good - specific union for nullable
value::Union{Int, Nothing}

# Bad - avoid Any
settings::Dict{String, Any}

# Better - structured type
struct Settings
    timeout::Union{Int, Nothing}
    retries::Union{Int, Nothing}
end
```

**Guidelines:**
- **Parametric types**: When you want type stability and the type is known at construction
- **Union types**: For optional/nullable values or when you need runtime type flexibility
- **Avoid abstract types** (`Number`, `AbstractArray`) as field types - use parametric types instead
- Keep unions small (prefer `Union{A, B}` over `Union{A, B, C, ...}`)

## Function Design

### Signatures
- **Keyword arguments**: Use for 3+ optional parameters
- **Default arguments**: Provide sensible defaults
- **Argument order**: Required ? optional ? keyword

```julia
function transform_values(
    values::Vector{Float64};
    scale::Float64 = 1.0,
    offset::Float64 = 0.0,
)::Vector{Float64}
end
```

### Function Purity
- Prefer pure functions (no side effects)
- Document side effects clearly if unavoidable

```julia
# Good - pure function
function multiply(a::Float64, b::Float64)::Float64
    return a * b
end

# Document side effects
"""
Modifies `container` in place.
"""
function append!(container::Vector{T}, value::T) where T
    push!(container, value)
end
```

## Documentation

**CRITICAL**: Documentation must be **simple and clean** - both in text content and formatting.

**Principles:**
- Simple text: Clear, straightforward language
- Clean formatting: Consistent, minimal markdown
- Be concise: Get to the point
- Focus on usage: What it does and how to use it
- Consistent structure: Same format across all docstrings

### Module Documentation
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
```julia
"""
    Point

A 2D point with x and y coordinates.

# Fields
- `x::Float64`: X coordinate
- `y::Float64`: Y coordinate

# Examples
```julia
p = Point(1.0, 2.0)
```
"""
struct Point
    x::Float64
    y::Float64
end
```

### Function Documentation
```julia
"""
    divide(a, b)

Divide `a` by `b`.

# Arguments
- `a::Float64`: Numerator
- `b::Float64`: Denominator (must not be zero)

# Returns
- `Float64`: Result of division

# Examples
```julia
result = divide(10.0, 2.0)
```
"""
function divide(a::Float64, b::Float64)::Float64
    b == 0 && throw(DivideError("Cannot divide by zero"))
    return a / b
end
```

**Formatting rules:**
- Plain markdown, avoid excessive formatting
- One sentence per line for readability
- Keep examples minimal
- Use simple language
- Remove redundant words

## Performance

### Array Type Selection

**Choose the right array type:**

1. **StaticArrays.jl** - Small fixed-size arrays (< ~100 elements)
   ```julia
   using StaticArrays
   function compute_transform(point::SVector{3, Float64})::SVector{3, Float64}
       # Stack-allocated, zero heap allocation, excellent performance
   end
   ```

2. **FixedSizeArrays.jl** - Pre-allocated arrays with known compile-time size
   ```julia
   using FixedSizeArrays
   const FIXED_SIZE = 10
   results = FixedArray{Float64, (FIXED_SIZE,)}()
   ```

3. **Vector/Array** - Only when:
   - Need dynamic resizing (`push!`, `append!`)
   - Size is unknown at creation time
   - Performance is not a concern

### Allocation Awareness
- Pre-allocate when size is known
- Use views to avoid copying: `@view array[start:end]`
- Avoid global variables in hot paths (use `Ref` or pass as parameter)

```julia
# Good - pre-allocate
results = Vector{Float64}(undef, length(inputs))
for i in eachindex(inputs)
    results[i] = compute(inputs[i])
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
function sum_floats(values::Vector{Float64})::Float64
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
squared = values .^ 2
sums = a .+ b
```

### Performance Best Practices
- **Measure before optimizing**: Use `@time`, `@btime` (BenchmarkTools.jl), `@profview` (ProfileView.jl)
- **Avoid containers with abstract element types**: Use parametric types or structs instead
- **Pre-allocate outputs**: Allocate result containers before loops, use `sizehint!` for growing arrays
- **Access arrays in column-major order** (Julia's default): Outer loop over columns, inner loop over rows

## Error Handling

### Exception Types
- Use appropriate exception types
- Provide helpful error messages with context

```julia
# Good
if divisor == 0
    throw(DivideError("Cannot divide by zero"))
end

# Custom exception
struct ValidationError <: Exception
    message::String
    field::String
end

# Helpful message
if length(keys) != length(values)
    throw(ArgumentError(
        "Mismatch: keys has $(length(keys)) elements but values has $(length(values))"
    ))
end
```

**Exception hierarchy:**
- `ArgumentError`: Invalid argument value
- `BoundsError`: Index out of bounds
- `TypeError`: Type conversion/assertion error
- `MethodError`: Method doesn't exist
- `ErrorException`: Generic error (use sparingly)

### Validation
- Validate inputs in public APIs
- Fail fast with clear error messages

```julia
function divide(a::Float64, b::Float64)::Float64
    if b == 0
        throw(DivideError("Cannot divide by zero: $a / $b"))
    end
    return a / b
end
```

## Design Patterns

### Composition Over Inheritance
**Prefer composition over inheritance.** Use structs containing other structs rather than abstract type hierarchies.

```julia
# Good - composition
struct Logger
    level::String
end

struct Config
    timeout::Int
    retries::Int
end

struct Processor
    logger::Logger
    config::Config
end

# Good - composition with parametric types
struct Buffer{T}
    data::Vector{T}
    capacity::Int
end

struct Transformer{T}
    buffer::Buffer{T}
    multiplier::Float64
end
```

**When to use:**
- **Composition**: Default choice. Flexible, testable.
- **Abstract types**: For dispatch-based polymorphism (multiple dispatch), not code reuse.
- **Inheritance**: Only when you truly need is-a relationships and polymorphic dispatch.

### Builder Pattern
For complex object construction:

```julia
struct ValueBuilder
    base::Union{Int, Nothing}
    multiplier::Union{Float64, Nothing}
end

ValueBuilder() = ValueBuilder(nothing, nothing)

function set_base(builder::ValueBuilder, base::Int)::ValueBuilder
    return ValueBuilder(base, builder.multiplier)
end

function build(builder::ValueBuilder)::Float64
    builder.base === nothing && throw(ArgumentError("Base value required"))
    multiplier = builder.multiplier === nothing ? 1.0 : builder.multiplier
    return builder.base * multiplier
end
```

### Strategy Pattern
For algorithm selection:

```julia
abstract type SortStrategy end
struct QuickSort <: SortStrategy end
struct MergeSort <: SortStrategy end

function sort_values(values::Vector{Float64}, ::QuickSort)::Vector{Float64}
    # Implementation
end

function sort_values(values::Vector{Float64}, ::MergeSort)::Vector{Float64}
    # Implementation
end
```

### Callback Pattern
For flexible data processing:

```julia
function filter_values(
    values::Vector{T};
    predicate::Union{Function, Nothing} = nothing,
)::Vector{T} where T
    predicate === nothing && return values
    result = T[]
    for value in values
        predicate(value) && push!(result, value)
    end
    return result
end
```

### Factory Pattern
For object creation with different types:

```julia
function create_container(type::String)
    if type == "int"
        return Vector{Int}()
    elseif type == "float"
        return Vector{Float64}()
    elseif type == "string"
        return Vector{String}()
    else
        throw(ArgumentError("Unknown container type: $type"))
    end
end
```

## Engineering Practices

### Testing
**CRITICAL**: Test every line and branch. No untested code branches allowed.

- **Complete coverage**: Every line executed by at least one test
- **Branch coverage**: Test all conditionals (`if/else`, ternary, `&&`, `||`)
- **Edge cases**: Empty inputs, boundary values, error conditions
- **Public APIs**: All exported functions must have comprehensive tests

```julia
# Function to test
function divide(a::Float64, b::Float64)::Float64
    if b == 0
        throw(DivideError("Cannot divide by zero"))
    end
    if a < 0
        return -abs(a / b)
    end
    return a / b
end

# Complete test covering all branches
@testset "divide - complete coverage" begin
    @test_throws DivideError divide(10.0, 0.0)  # Error branch
    @test divide(10.0, 2.0) == 5.0              # Normal branch
    @test divide(0.0, 5.0) == 0.0               # Zero numerator
    @test divide(-10.0, 2.0) == -5.0            # Negative branch
end
```

**Testing requirements:**
- If statements: Test both `true` and `false` branches
- Ternary operators: Test both sides
- Short-circuit operators: Test both cases
- Error paths: Test all exception-throwing branches
- Early returns: Test early return conditions

Use coverage tools to ensure 100% line and branch coverage.

### Code Reuse (DRY)
Extract common patterns:

```julia
# Bad - repeated pattern
if x > 0 && x < 100 && x % 2 == 0
end

if y > 0 && y < 100 && y % 2 == 0
end

# Good - extracted function
function is_valid_even(x::Int)::Bool
    return x > 0 && x < 100 && x % 2 == 0
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
module PackageName
    include("types.jl")      # Type definitions
    include("utils.jl")       # Utility functions
    include("io.jl")          # I/O operations
    include("process.jl")     # Processing logic
    include("api.jl")         # Public API
end
```

### Additional Guidelines

**Memory Management:**
- Be aware of memory usage for large datasets
- Consider streaming for very large files
- Use appropriate data structures: `Vector` (ordered), `Set` (membership), `Dict` (key-value), `Tuple` (immutable small collections)
- See [Array Type Selection](#array-type-selection) for array allocation guidance

**Concurrency:**
- Document thread-safety assumptions
- Use appropriate synchronization if shared state is modified

**API Evolution:**
- Maintain backward compatibility when possible
- Deprecate rather than remove: `Base.@deprecate old_function(args...) new_function(args...)`

## Code Review Checklist

- [ ] Type annotations present for public APIs
- [ ] Documentation complete for exported/complex functions
- [ ] Documentation is simple and clean (text and formatting)
- [ ] Error handling appropriate
- [ ] No type instability in hot paths
- [ ] **Tests cover 100% of code lines and branches** (no untested code branches)
- [ ] All conditional branches tested
- [ ] All error paths tested
- [ ] All early returns tested
- [ ] Function length reasonable (target 25 lines)
- [ ] Code follows naming conventions
- [ ] Appropriate array types used (StaticArrays.jl, FixedSizeArrays.jl, or Vector)
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
6. **Prefer composition over inheritance** - use struct composition, not deep type hierarchies
7. **Document** exported/complex functions only - keep it simple and clean
8. **Consider performance** - type stability, allocations, appropriate array types
9. **Handle errors** gracefully with helpful messages
10. **Test everything** - 100% line and branch coverage, no untested code branches
11. **Organize code** logically

**Remember:** Quality over speed. Ask for clarification rather than guessing. Keep code minimal and clear. Make small, focused changes for easier review.
