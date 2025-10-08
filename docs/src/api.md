# API Reference

This page provides detailed documentation for all public functions and types in OpenStreetMapIO.jl.

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

## Internal Functions

The following functions are used internally but may be useful for advanced users:

### XML Processing

These functions are internal to the XML processing module and are not exported. They handle URL encoding and HTML entity decoding for XML parsing.

## Examples

### Basic Usage

```julia
using OpenStreetMapIO

# Read OSM data
osmdata = readpbf("map.pbf")

# Access elements
for (id, node) in osmdata.nodes
    println("Node $id at $(node.latlon.lat), $(node.latlon.lon)")
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

### Overpass Queries

```julia
# Query by bounding box
bbox = BBox(53.4, 9.8, 53.7, 10.2)
osmdata = queryoverpass(bbox)

# Query by center point and radius
center = LatLon(53.55, 9.99)
osmdata = queryoverpass(center, 1000)  # 1km radius
```

## Error Handling

All functions include comprehensive error handling:

- **File not found**: `ArgumentError` with descriptive message
- **Invalid file format**: `ArgumentError` with format details
- **Network errors**: Handled gracefully for Overpass queries
- **Callback errors**: Logged as warnings, processing continues

## Performance Considerations

- **PBF files** are significantly faster than XML for large datasets
- **Callback filtering** reduces memory usage by filtering during reading
- **Streaming processing** allows handling of very large files
- **Optimized protobuf parsing** for maximum performance
