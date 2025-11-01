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
10. [Official Julia Documentation Guidelines](#official-julia-documentation-guidelines)

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
- **Functions**: `lowercase_with_underscores`
- **Types/Structs**: `PascalCase`
- **Constants**: `UPPERCASE_WITH_UNDERSCORES`
- **Modules**: `PascalCase` (match filename)
- **Type parameters**: `T`, `S`, `U`, `V`

### Formatting
- **Indentation**: 4 spaces
- **Line length**: Prefer < 92 chars, readability first
- **Spacing**: Spaces around binary ops (`x + y`), no space after unary (`-x`), space after commas, space after colons (`x::Int64`), no space before colons (`Dict{String, Int}`)
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
function compute_average(values::Vector{Number})::Float64
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

### Union Types
- Use for optional/nullable values: `Union{Type, Nothing}`
- Avoid `Any`; prefer specific types or structured alternatives

```julia
# Good
name::Union{String, Nothing}

# Bad
settings::Dict{String, Any}

# Better
struct Settings
    timeout::Union{Int, Nothing}
    retries::Union{Int, Nothing}
end
```

### Parametric Types
**Prefer parametric structs over structs with abstract type fields** for type stability and performance.

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

**Guidelines:**
- Always parameterize structs when fields could have different concrete types
- Avoid abstract types (`Number`, `AbstractArray`, etc.) as field types
- Use Union types only when you genuinely need mixed types at runtime

## Function Design

### Signatures
- **Keyword arguments**: Use for 3+ optional parameters
- **Default arguments**: Provide sensible defaults
- **Argument order**: Required ? optional ? keyword

```julia
function transform_values(
    values::Vector{Number};
    scale::Float64 = 1.0,
    offset::Float64 = 0.0,
)::Vector{Number}
end
```

### Function Purity
- Prefer pure functions (no side effects)
- Document side effects clearly if unavoidable

```julia
# Good - pure function
function multiply(a::Number, b::Number)::Number
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

# Use StaticArrays.jl for small fixed-size arrays (< 100 elements)
using StaticArrays
function compute_transform(point::SVector{3, Float64})::SVector{3, Float64}
    # Stack-allocated, zero heap allocation
end

# Use FixedSizeArrays.jl for pre-allocated arrays with known size
using FixedSizeArrays
const FIXED_SIZE = 10
results = FixedArray{Float64, (FIXED_SIZE,)}()

# Use Vector/Array only when:
# - Need dynamic resizing (push!, append!)
# - Performance is not a concern
# - Size is unknown at creation time
```

**Array Type Selection:**
- **StaticArrays.jl**: Small fixed-size arrays (< ~100 elements). Stack-allocated, excellent performance.
- **FixedSizeArrays.jl**: Pre-allocated arrays where size is known at compile time.
- **Vector/Array**: Only for dynamic resizing or when size is unknown.

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

function sort_values(values::Vector{Number}, ::QuickSort)::Vector{Number}
    # Implementation
end

function sort_values(values::Vector{Number}, ::MergeSort)::Vector{Number}
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
function create_container(type::String)::Vector{Any}
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
- Use appropriate data structures (Dict vs. Vector)
- Consider StaticArrays.jl and FixedSizeArrays.jl (see Performance section)

**Concurrency:**
- Document thread-safety assumptions
- Use appropriate synchronization if shared state is modified

**API Evolution:**
- Maintain backward compatibility when possible
- Deprecate rather than remove: `Base.@deprecate old_function(args...) new_function(args...)`

## Official Julia Documentation Guidelines

Based on [Julia's official documentation](https://docs.julialang.org/en/v1/), the following are critical guidelines for agents:

### Style Conventions (from Julia Style Guide)

**Functions:**
- Use `snake_case` for function names: `compute_value`, `parse_data`
- Avoid abbreviations unless widely understood: `idx` is acceptable, `comp_val` is not
- Use `!` suffix for in-place mutating functions: `sort!`, `push!`, `append!`
- Question-mark suffix for predicates (return Bool): `isempty`, `haskey`

**Types:**
- Use `PascalCase` for types and constructors
- Use short names for type parameters: `T`, `S`, `U`, `V`, `N`, `M`

**Constants:**
- Use `SCREAMING_SNAKE_CASE` for module-level constants
- Use `const` for truly constant values

### Performance Tips (from Performance Tips)

**Avoid global variables:**
```julia
# Bad
global x = 0
function increment()
    global x += 1
end

# Good
function increment(x::Ref{Int})
    x[] += 1
end
```

**Use type annotations:**
- Always annotate function arguments and return values for performance
- Use concrete types when possible, avoid `Any`

**Measure before optimizing:**
- Use `@time`, `@btime` (from BenchmarkTools.jl), and `@profview` (from ProfileView.jl)
- Profile first: `using Profile; @profile my_function(); Profile.print()`

**Avoid containers with abstract element types:**
```julia
# Bad - Vector{Any}
data = [1, 2.0, "three"]

# Good - use tuples or structs
struct DataPoint
    int_val::Int
    float_val::Float64
    str_val::String
end
```

**Pre-allocate outputs:**
- Allocate result containers before loops
- Use `sizehint!` for arrays that grow

**Access arrays in memory order:**
```julia
# Good - column-major order (Julia's default)
for j in 1:size(A, 2)
    for i in 1:size(A, 1)
        A[i, j] = ...
    end
end
```

### Type System Best Practices

**Abstract types for dispatch, not storage:**
```julia
# Bad - storing abstract type loses information
items::Vector{Number} = [1, 2.0, 3]

# Good - parametric container preserves type
struct Container{T}
    items::Vector{T}
end
```

**Type annotations in function signatures:**
- Always type function arguments and return values
- This enables optimization and helps catch errors

**Avoid field types that are too abstract:**
```julia
# Bad
struct MyType
    data::Any
end

# Good
struct MyType{T}
    data::T
end
```

### Documentation Standards (from Documenter.jl best practices)

**Docstring format:**
- Use triple-quoted strings `"""..."""`
- Start with function signature
- One-line summary, then detailed description
- Use `# Arguments`, `# Returns`, `# Examples` sections
- Include type information in signature

**Cross-references:**
- Use `` [`function_name`](@ref) `` for internal references
- Use markdown links for external references

**Examples:**
- Include runnable examples
- Test examples to ensure they work
- Keep examples simple and focused

### Package Development Guidelines

**Project structure:**
- Use `Project.toml` for dependencies (not `REQUIRE`)
- Specify compatible Julia version: `julia = "1.6"`
- Use semantic versioning
- Document all public APIs

**Testing:**
- Place tests in `test/` directory
- Use `Test.jl` standard library
- Test all exported functions
- Include integration tests

**Module organization:**
- Export only public API
- Use `__init__` function for initialization code
- Prefer `include()` over loading files separately

### Type System Guidelines

**When to use abstract types:**
- For dispatch (multiple dispatch polymorphism)
- To define interface contracts
- NOT for storage or performance

**When to use concrete types:**
- For data storage
- For performance-critical code
- For type stability

**Union types:**
- Use for truly optional/nullable values
- Keep unions small (prefer `Union{A, B}` over `Union{A, B, C, ...}`)
- Consider `Nothing` unions: `Union{String, Nothing}`

### Error Handling Guidelines

**Exception hierarchy:**
- `ArgumentError`: Invalid argument value
- `BoundsError`: Index out of bounds
- `TypeError`: Type conversion/assertion error
- `MethodError`: Method doesn't exist
- `ErrorException`: Generic error (use sparingly)

**Best practices:**
- Use specific exception types
- Include context in error messages
- Fail fast with clear messages
- Document exceptions in docstrings

### Memory and Performance

**Avoid allocations in hot loops:**
- Pre-allocate result containers
- Use `@views` to avoid copying
- Reuse buffers when possible

**Use appropriate data structures:**
- `Vector` for ordered collections
- `Set` for membership testing
- `Dict` for key-value lookups
- `Tuple` for immutable small collections

**Consider StaticArrays.jl:**
- For small fixed-size arrays (< ~100 elements)
- Stack-allocated, zero heap allocation
- Excellent performance for small sizes

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
8. **Consider performance** - type stability, allocations
9. **Handle errors** gracefully with helpful messages
10. **Test everything** - 100% line and branch coverage, no untested code branches
11. **Organize code** logically

**Remember:** Quality over speed. Ask for clarification rather than guessing. Keep code minimal and clear. Make small, focused changes for easier review.
