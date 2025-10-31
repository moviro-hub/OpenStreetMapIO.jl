# API Reference

This page provides documentation for all public functions and types in OpenStreetMapIO.jl.

## Core Functions

### File Reading

```@docs
readpbf
readosm
```

### Online Queries

```@docs
queryoverpass
```

## Data Types

### Core Types

```@docs
OpenStreetMap
Node
Way
Relation
BBox
Position
Info
```

## Examples

### Basic Usage

```julia
using OpenStreetMapIO

# Read OSM PBF data (supports all compression formats)
osmdata = readpbf("map.pbf")

# Query by bounding box
bbox = BBox(53.4, 9.8, 53.7, 10.2)
osmdata = queryoverpass(bbox)

# Query by center point and radius
center = Position(53.55, 9.99)
osmdata = queryoverpass(center, 1000)  # 1km radius

# Access node data
for (id, node) in osmdata.nodes
    println("Node $id at ($(node.position.lat), $(node.position.lon))")
    if node.info !== nothing
        println("  Version: $(node.info.version), User: $(node.info.user)")
    end
end

# Access way data with LocationsOnWays
for (id, way) in osmdata.ways
    if way.positions !== nothing
        println("Way $id has embedded coordinates")
    end
end
```

### Callback Filtering

```julia
# Filter restaurants
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
```
