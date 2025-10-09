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
LatLon
```

## Examples

### Basic Usage

```julia
using OpenStreetMapIO

# Read OSM PBF data
osmdata = readpbf("map.pbf")

# Query by bounding box
bbox = BBox(53.4, 9.8, 53.7, 10.2)
osmdata = queryoverpass(bbox)

# Query by center point and radius
center = LatLon(53.55, 9.99)
osmdata = queryoverpass(center, 1000)  # 1km radius
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
