# Agent Guide for OpenStreetMapIO.jl

This guide is designed for AI agents and assistants helping users work with the OpenStreetMapIO.jl package. It provides context, patterns, and best practices for common tasks.

## Package Overview

OpenStreetMapIO.jl is a Julia package for reading and processing OpenStreetMap (OSM) data. It supports:
- **PBF format** (compressed Protocol Buffer format - most common)
- **XML format** (.osm files)
- **Overpass API** queries (online data access)
- **Callback-based filtering** for memory-efficient data processing

## Project Structure

```
OpenStreetMapIO.jl/
??? src/
?   ??? OpenStreetMapIO.jl      # Main module
?   ??? map_types.jl            # Data type definitions
?   ??? load_pbf.jl             # PBF file reading
?   ??? load_xml.jl             # XML file reading
?   ??? load_overpass.jl        # Overpass API queries
?   ??? utils.jl                # Utility functions
?   ??? OSMPBF/                 # Protocol Buffer definitions
??? test/
?   ??? test_load_pbf.jl
?   ??? test_load_xml.jl
?   ??? test_load_overpass.jl
?   ??? data/                   # Test data files
??? docs/
    ??? src/                    # Documentation files
```

## Core Data Types

### OpenStreetMap
The main container returned by all reading functions:
```julia
struct OpenStreetMap
    nodes::Dict{Int64, Node}
    ways::Dict{Int64, Way}
    relations::Dict{Int64, Relation}
    meta::Dict{String, Any}
end
```

### Node
Represents a point on the map:
```julia
struct Node
    position::Position          # lat/lon coordinates
    tags::Union{Nothing, Dict{String,String}}
    info::Union{Nothing, Info}  # version, timestamp, user, etc.
end
```

### Way
Represents a path (roads, buildings, etc.):
```julia
struct Way
    refs::Vector{Int64}         # node IDs
    tags::Union{Nothing, Dict{String,String}}
    info::Union{Nothing, Info}
    positions::Union{Nothing, Vector{Position}}  # LocationsOnWays feature
end
```

### Relation
Represents a group of elements:
```julia
struct Relation
    refs::Vector{Int64}
    types::Vector{String}       # "node", "way", or "relation"
    roles::Vector{String}
    tags::Union{Nothing, Dict{String,String}}
    info::Union{Nothing, Info}
end
```

### Supporting Types
- `Position`: Geographic coordinates with `lat` and `lon` (Float64)
- `BBox`: Bounding box with `bottom_lat`, `left_lon`, `top_lat`, `right_lon`
- `Info`: Metadata with `version`, `timestamp`, `changeset`, `uid`, `user`, `visible`

## Common Agent Tasks

### Task 1: Reading OSM Data

**User request:** "Read an OSM file"

```julia
# For PBF files (most common)
osmdata = readpbf("path/to/map.pbf")

# For XML files
osmdata = readosm("path/to/map.osm")

# From Overpass API (bounding box)
bbox = BBox(lat_min, lon_min, lat_max, lon_max)
osmdata = queryoverpass(bbox)

# From Overpass API (radius around point)
center = Position(lat, lon)
osmdata = queryoverpass(center, radius_in_meters)
```

**Key points:**
- Always check if the file exists before reading
- PBF is the standard format; XML is older but still supported
- Test data is available in `test/data/` directory

### Task 2: Filtering Data with Callbacks

**User request:** "Find all restaurants" or "Filter data by specific tags"

```julia
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node  # Keep this node
    end
    return nothing   # Discard this node
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
```

**Pattern for all callbacks:**
- Return the element (possibly modified) to keep it
- Return `nothing` to discard it
- Available callbacks: `node_callback`, `way_callback`, `relation_callback`
- Callbacks run during reading, reducing memory usage

### Task 3: Accessing and Processing Data

**User request:** "Show me all the nodes" or "Process the ways"

```julia
# Iterate over nodes
for (id, node) in osmdata.nodes
    lat, lon = node.position.lat, node.position.lon
    if node.tags !== nothing
        # Process tags
        for (key, value) in node.tags
            println("$key: $value")
        end
    end
end

# Iterate over ways
for (id, way) in osmdata.ways
    num_nodes = length(way.refs)
    if way.positions !== nothing
        # Way has embedded coordinates (LocationsOnWays)
        for pos in way.positions
            # Process positions
        end
    end
end

# Iterate over relations
for (id, relation) in osmdata.relations
    for i in 1:length(relation.refs)
        ref_id = relation.refs[i]
        ref_type = relation.types[i]  # "node", "way", or "relation"
        role = relation.roles[i]
        # Process member
    end
end
```

### Task 4: Working with Tags

**User request:** "Find elements with specific tags"

OSM tags are key-value pairs stored in `Dict{String,String}`:

```julia
# Common tag categories:
# - amenity: restaurant, cafe, school, hospital, etc.
# - highway: motorway, primary, residential, footway, etc.
# - building: yes, house, commercial, etc.
# - tourism: hotel, museum, attraction, etc.
# - shop: supermarket, bakery, clothes, etc.
# - natural: water, tree, peak, etc.
# - landuse: residential, commercial, forest, etc.

# Check for specific tag
if node.tags !== nothing && haskey(node.tags, "amenity")
    amenity_type = node.tags["amenity"]
end

# Check multiple conditions
if node.tags !== nothing &&
   haskey(node.tags, "amenity") &&
   node.tags["amenity"] == "restaurant" &&
   haskey(node.tags, "cuisine")
    cuisine = node.tags["cuisine"]
end
```

### Task 5: Memory-Efficient Processing

**User request:** "Count elements without loading everything"

```julia
# Use callbacks that return nothing to avoid storing data
counter = 0

function count_only(node)
    global counter
    if meets_condition(node)
        counter += 1
    end
    return nothing  # Don't store
end

readpbf("large_map.pbf", node_callback=count_only)
println("Found $counter matching elements")
```

## Testing Best Practices

When helping users add or modify code:

1. **Run existing tests:**
   ```julia
   using Pkg
   Pkg.test("OpenStreetMapIO")
   ```

2. **Test files are in:** `test/test_load_pbf.jl`, `test_load_xml.jl`, etc.

3. **Test data available:** `test/data/map.osm` and `test/data/map.pbf`

4. **Write tests for new features:**
   ```julia
   @testset "New feature" begin
       osmdata = readpbf("test/data/map.pbf")
       @test length(osmdata.nodes) > 0
       # Add specific tests
   end
   ```

## Common Pitfalls and Solutions

### Pitfall 1: Assuming tags always exist
```julia
# ? Wrong - will error if tags is nothing
value = node.tags["amenity"]

# ? Correct - check for nothing first
if node.tags !== nothing && haskey(node.tags, "amenity")
    value = node.tags["amenity"]
end
```

### Pitfall 2: Assuming info always exists
```julia
# ? Wrong
version = node.info.version

# ? Correct
if node.info !== nothing
    version = node.info.version
end
```

### Pitfall 3: Not checking for LocationsOnWays
```julia
# ? Wrong - positions might be nothing
for pos in way.positions
    # ...
end

# ? Correct
if way.positions !== nothing
    for pos in way.positions
        # ...
    end
end
```

### Pitfall 4: Incorrect bounding box order
```julia
# ? Wrong - incorrect parameter order
bbox = BBox(lon_min, lat_min, lon_max, lat_max)

# ? Correct - lat before lon
bbox = BBox(lat_min, lon_min, lat_max, lon_max)
```

### Pitfall 5: Forgetting to handle callback return values
```julia
# ? Wrong - callback doesn't return anything
function filter_nodes(node)
    if node.tags !== nothing
        # ... check condition ...
    end
end

# ? Correct - explicitly return node or nothing
function filter_nodes(node)
    if node.tags !== nothing && meets_condition(node)
        return node
    end
    return nothing
end
```

## File Format Notes

### PBF Format
- Binary format, highly compressed
- Most common format for OSM data
- Supports multiple compression: zlib, lz4, zstd, xz
- Much faster to read than XML
- Typical file extensions: `.pbf`, `.osm.pbf`

### XML Format
- Human-readable text format
- Older format, less efficient
- Typical extensions: `.osm`, `.osm.xml`
- Good for small datasets or debugging

### Data Sources
- **Geofabrik**: Regional extracts (https://download.geofabrik.de/)
- **Planet.osm**: Full planet data (https://planet.openstreetmap.org/)
- **Overpass API**: Online queries (https://overpass-api.de/)

## Example Workflows

### Workflow 1: Extract specific amenities from a region
```julia
using OpenStreetMapIO

# Define filter
function keep_restaurants_and_cafes(node)
    if node.tags !== nothing && haskey(node.tags, "amenity")
        amenity = node.tags["amenity"]
        if amenity in ["restaurant", "cafe"]
            return node
        end
    end
    return nothing
end

# Read and filter
osmdata = readpbf("hamburg.pbf", node_callback=keep_restaurants_and_cafes)

# Analyze results
println("Found $(length(osmdata.nodes)) restaurants and cafes")

# Export to custom format
for (id, node) in osmdata.nodes
    name = get(node.tags, "name", "Unknown")
    amenity = node.tags["amenity"]
    lat, lon = node.position.lat, node.position.lon
    println("$amenity: $name at ($lat, $lon)")
end
```

### Workflow 2: Analyze road network
```julia
using OpenStreetMapIO

# Filter highways
function keep_highways(way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

osmdata = readpbf("city.pbf", way_callback=keep_highways)

# Count by road type
highway_types = Dict{String,Int}()
for (id, way) in osmdata.ways
    if way.tags !== nothing
        htype = way.tags["highway"]
        highway_types[htype] = get(highway_types, htype, 0) + 1
    end
end

# Display results
for (htype, count) in sort(collect(highway_types), by=x->x[2], rev=true)
    println("$htype: $count")
end
```

### Workflow 3: Query data from Overpass API
```julia
using OpenStreetMapIO

# Query Hamburg city center
bbox = BBox(53.54, 9.98, 53.56, 10.00)
osmdata = queryoverpass(bbox)

# Or query around a specific location
university = Position(53.5677, 9.9856)
osmdata = queryoverpass(university, 500)  # 500m radius

# Process downloaded data
println("Downloaded:")
println("  $(length(osmdata.nodes)) nodes")
println("  $(length(osmdata.ways)) ways")
println("  $(length(osmdata.relations)) relations")
```

## Dependencies

When helping users with installation or environment issues:

```julia
# Required packages (from Project.toml)
using ProtoBuf          # Protocol Buffer support
using CodecZlib         # Zlib compression
using CodecLz4          # LZ4 compression
using CodecZstd         # Zstd compression
using CodecXz           # XZ compression
using Dates             # Timestamp handling
using XML               # XML parsing
using Downloads         # HTTP downloads for Overpass
```

## Performance Tips

1. **Use callbacks for large files:** Avoid loading entire datasets into memory
2. **PBF over XML:** PBF files are much faster to read
3. **Filter early:** Apply callbacks during reading rather than filtering afterward
4. **LocationsOnWays:** Check if ways have embedded positions to avoid node lookups
5. **Batch processing:** Process multiple elements in loops rather than one at a time

## When to Suggest This Package

This package is appropriate when users need to:
- Read OSM data from files or online
- Filter OSM data by specific criteria
- Extract POIs (points of interest) from map data
- Analyze road networks, buildings, or land use
- Convert OSM data to custom formats
- Work with geographic data in Julia

This package is NOT designed for:
- Rendering maps (use other packages for visualization)
- Routing/pathfinding (use specialized routing packages)
- Writing OSM data back to files (read-only)
- Real-time map editing (use OSM editors)

## Getting Help

- **Documentation**: https://moviro-hub.github.io/OpenStreetMapIO.jl/
- **Repository**: https://github.com/moviro-hub/OpenStreetMapIO.jl
- **OSM Wiki**: https://wiki.openstreetmap.org/ (for OSM tag documentation)
- **Overpass API**: https://wiki.openstreetmap.org/wiki/Overpass_API

## Quick Reference

```julia
# Reading data
osmdata = readpbf("file.pbf")
osmdata = readosm("file.osm")
osmdata = queryoverpass(BBox(lat_min, lon_min, lat_max, lon_max))
osmdata = queryoverpass(Position(lat, lon), radius)

# With callbacks
osmdata = readpbf("file.pbf",
    node_callback=f_node,
    way_callback=f_way,
    relation_callback=f_relation
)

# Accessing data
for (id, node) in osmdata.nodes; end
for (id, way) in osmdata.ways; end
for (id, relation) in osmdata.relations; end

# Safe tag access
if node.tags !== nothing && haskey(node.tags, "key")
    value = node.tags["key"]
end

# Check for optional fields
if node.info !== nothing; version = node.info.version; end
if way.positions !== nothing; coords = way.positions; end
```
