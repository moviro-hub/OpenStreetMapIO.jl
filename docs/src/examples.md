# Examples

This page provides comprehensive examples showing how to use OpenStreetMapIO.jl for various tasks.

## Basic File Reading

### Reading PBF Files

```julia
using OpenStreetMapIO

# Read a PBF file
osmdata = read_pbf("map.pbf")

# Explore the data
println("Dataset contains:")
println("  $(length(osmdata.nodes)) nodes")
println("  $(length(osmdata.ways)) ways")
println("  $(length(osmdata.relations)) relations")

# Check metadata
if haskey(osmdata.meta, "bbox")
    bbox = osmdata.meta["bbox"]
    println("Bounding box: $bbox")
end
```

### Reading XML Files

```julia
# Read an XML file (same interface as PBF)
osmdata = read_osm("map.osm")

# Data structure is identical
println("Loaded $(length(osmdata.nodes)) nodes from XML")
```

### Querying from Overpass

```julia
# Query data for a specific area
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osmdata = fetch_overpass(bbox)

# Query around a specific point
center = Position(53.55, 9.99)
osmdata = fetch_overpass(center, 2000)  # 2km radius
```

## Data Filtering and Processing

In the following examples, we will demonstrate the functionality of the package.

### Filtering by Tags

```julia
# Find all restaurants with specific cuisine
function keep_italian_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant" &&
       haskey(node.tags, "cuisine") &&
       node.tags["cuisine"] == "italian"
        return node
    end
    return nothing
end

italian_restaurants = read_pbf("map.pbf", node_callback=keep_italian_restaurants)
println("Found $(length(italian_restaurants.nodes)) Italian restaurants")

# Find all highways
function keep_highways(way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

highways = read_pbf("map.pbf", way_callback=keep_highways)
println("Found $(length(highways.ways)) highways")

# Find all bus routes
function keep_bus_routes(relation)
    if relation.tags !== nothing &&
       haskey(relation.tags, "route") &&
       relation.tags["route"] == "bus"
        return relation
    end
    return nothing
end

# Apply all filters
osmdata = read_pbf("map.pbf",
    node_callback=keep_italian_restaurants,
    way_callback=keep_highways,
    relation_callback=keep_bus_routes
)

println("Filtered dataset:")
println("  $(length(osmdata.nodes)) Italian restaurants")
println("  $(length(osmdata.ways)) highways")
println("  $(length(osmdata.relations)) bus routes")
```

### Finding Points of Interest

```julia
# Find all points of interest in an area
function keep_pois(node)
    if node.tags !== nothing
        # Check for common POI tags
        poi_tags = ["amenity", "tourism", "shop", "leisure", "historic"]
        for tag in poi_tags
            if haskey(node.tags, tag)
                return node
            end
        end
    end
    return nothing
end

pois = read_pbf("map.pbf", node_callback=keep_pois)
println("Found $(length(pois.nodes)) points of interest")

# Analyze POI types
poi_types = Dict{String,Int}()
for (id, node) in pois.nodes
    if node.tags !== nothing
        for (key, value) in node.tags
            if key in ["amenity", "tourism", "shop", "leisure", "historic"]
                poi_types[value] = get(poi_types, value, 0) + 1
            end
        end
    end
end

# Show most common POI types
sorted_types = sort(collect(poi_types), by=x->x[2], rev=true)
for (type, count) in sorted_types[1:10]
    println("$type: $count")
end
```
