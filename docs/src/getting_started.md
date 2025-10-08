# Getting Started

This guide will help you get started with OpenStreetMapIO.jl by walking through the basic usage patterns and common tasks.

## Installation

First, install the package:

```julia
using Pkg
Pkg.add("OpenStreetMapIO")
```

Then load the package:

```julia
using OpenStreetMapIO
```

## Basic Usage

### Reading OSM Files

The package supports two main file formats:

#### PBF Files (Recommended)

PBF (Protocol Buffer Format) is the most efficient format for large datasets:

```julia
# Read a PBF file
osmdata = readpbf("map.pbf")

# Check what we loaded
println("Loaded $(length(osmdata.nodes)) nodes")
println("Loaded $(length(osmdata.ways)) ways")
println("Loaded $(length(osmdata.relations)) relations")
```

#### XML Files

XML format is human-readable and compatible with standard OSM tools:

```julia
# Read an XML file
osmdata = readosm("map.osm")

# Same data structure as PBF
println("Loaded $(length(osmdata.nodes)) nodes")
```

### Working with OSM Data

Once you've loaded data, you can access the different element types:

```julia
# Access a specific node
node_id = first(keys(osmdata.nodes))
node = osmdata.nodes[node_id]

# Get coordinates
println("Node at: $(node.latlon.lat), $(node.latlon.lon)")

# Check if node has tags
if node.tags !== nothing
    println("Node tags: ", node.tags)
end

# Access a way
way_id = first(keys(osmdata.ways))
way = osmdata.ways[way_id]

# Get node references
println("Way has $(length(way.refs)) nodes")

# Access a relation
relation_id = first(keys(osmdata.relations))
relation = osmdata.relations[relation_id]

# Get members
println("Relation has $(length(relation.refs)) members")
```

### Querying from Overpass API

You can also query data directly from the Overpass API:

```julia
# Define a bounding box (lat_min, lon_min, lat_max, lon_max)
bbox = BBox(53.45, 9.95, 53.55, 10.05)

# Query data from Overpass API
osmdata = queryoverpass(bbox)

# Or query by center point and radius
center = LatLon(53.5, 10.0)
osmdata = queryoverpass(center, 1000)  # 1km radius
```

## Filtering Data with Callbacks

One of the most powerful features is the ability to filter data during reading using callback functions:

### Basic Filtering

```julia
# Filter to keep only restaurants
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing  # Exclude this node
end

# Apply filter during reading
osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
println("Found $(length(osmdata.nodes)) restaurants")
```

### Multiple Filters

You can apply different filters to different element types:

```julia
# Filter nodes for restaurants
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

# Filter ways for highways
function keep_highways(way)
    if way.tags !== nothing &&
       haskey(way.tags, "highway")
        return way
    end
    return nothing
end

# Apply both filters
osmdata = readpbf("map.pbf",
    node_callback=keep_restaurants,
    way_callback=keep_highways
)
```

### Modifying Data with Callbacks

Callbacks can also modify data during reading:

```julia
# Add a custom tag to all nodes
function add_custom_tag(node)
    new_tags = node.tags === nothing ? Dict{String,String}() : copy(node.tags)
    new_tags["processed_by"] = "OpenStreetMapIO.jl"
    return Node(node.latlon, new_tags)
end

osmdata = readpbf("map.pbf", node_callback=add_custom_tag)
```

## Working with Geographic Data

### Creating Bounding Boxes

```julia
# Create a bounding box for Hamburg, Germany
hamburg_bbox = BBox(53.4, 9.8, 53.7, 10.2)

# Create coordinates
hamburg_center = LatLon(53.55, 9.99)
```

### Spatial Queries

```julia
# Query data within a bounding box
osmdata = queryoverpass(hamburg_bbox)

# Query data around a point
osmdata = queryoverpass(hamburg_center, 5000)  # 5km radius
```

## Error Handling

The package includes robust error handling:

```julia
try
    osmdata = readpbf("nonexistent.pbf")
catch e
    if isa(e, ArgumentError)
        println("File not found or invalid format")
    else
        rethrow(e)
    end
end
```

## Performance Tips

1. **Use PBF format** for large datasets - it's much more efficient than XML
2. **Use callbacks** to filter data during reading rather than after loading
3. **Process data in chunks** for very large datasets
4. **Use specific bounding boxes** when querying Overpass API to limit data size

## Next Steps

- Check out the [API Reference](api.md) for detailed function documentation
- See [Examples](examples.md) for more complex use cases
- Read the [Developer Guide](developer.md) if you want to contribute
