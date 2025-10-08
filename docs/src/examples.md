# Examples

This page provides comprehensive examples showing how to use OpenStreetMapIO.jl for various tasks.

## Basic File Reading

### Reading PBF Files

```julia
using OpenStreetMapIO

# Read a PBF file
osmdata = readpbf("map.pbf")

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
osmdata = readosm("map.osm")

# Data structure is identical
println("Loaded $(length(osmdata.nodes)) nodes from XML")
```

## Working with Geographic Data

### Creating and Using Bounding Boxes

```julia
# Create a bounding box for a specific area
# Format: BBox(lat_min, lon_min, lat_max, lon_max)
hamburg_bbox = BBox(53.4, 9.8, 53.7, 10.2)

# Create coordinate points
hamburg_center = LatLon(53.55, 9.99)
altona_station = LatLon(53.552, 9.935)

# Check if a point is within a bounding box
function point_in_bbox(point::LatLon, bbox::BBox)
    return bbox.bottom_lat <= point.lat <= bbox.top_lat &&
           bbox.left_lon <= point.lon <= bbox.right_lon
end

println("Altona station in Hamburg bbox: ",
        point_in_bbox(altona_station, hamburg_bbox))
```

### Querying from Overpass API

```julia
# Query data for a specific area
bbox = BBox(53.4, 9.8, 53.7, 10.2)
osmdata = queryoverpass(bbox)

# Query around a specific point
center = LatLon(53.55, 9.99)
osmdata = queryoverpass(center, 2000)  # 2km radius

# Query with custom timeout
osmdata = queryoverpass(bbox, timeout=60)  # 60 second timeout
```

## Data Filtering and Processing

### Filtering by Tags

```julia
# Find all restaurants
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

restaurants = readpbf("map.pbf", node_callback=keep_restaurants)
println("Found $(length(restaurants.nodes)) restaurants")

# Find all highways
function keep_highways(way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

highways = readpbf("map.pbf", way_callback=keep_highways)
println("Found $(length(highways.ways)) highways")
```

### Complex Filtering

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

italian_restaurants = readpbf("map.pbf", node_callback=keep_italian_restaurants)
println("Found $(length(italian_restaurants.nodes)) Italian restaurants")
```

### Multiple Element Filtering

```julia
# Filter multiple element types simultaneously
function keep_restaurants(node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

function keep_highways(way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

function keep_bus_routes(relation)
    if relation.tags !== nothing &&
       haskey(relation.tags, "route") &&
       relation.tags["route"] == "bus"
        return relation
    end
    return nothing
end

# Apply all filters
osmdata = readpbf("map.pbf",
    node_callback=keep_restaurants,
    way_callback=keep_highways,
    relation_callback=keep_bus_routes
)

println("Filtered dataset:")
println("  $(length(osmdata.nodes)) restaurants")
println("  $(length(osmdata.ways)) highways")
println("  $(length(osmdata.relations)) bus routes")
```

## Data Modification

### Adding Custom Tags

```julia
# Add processing metadata to all nodes
function add_processing_info(node)
    new_tags = node.tags === nothing ? Dict{String,String}() : copy(node.tags)
    new_tags["processed_by"] = "OpenStreetMapIO.jl"
    new_tags["processed_at"] = string(now())
    return Node(node.latlon, new_tags)
end

processed_data = readpbf("map.pbf", node_callback=add_processing_info)
```

### Data Transformation

```julia
# Convert all coordinates to a different format
function convert_coordinates(node)
    # Convert to UTM or other coordinate system
    # This is just an example - you'd use a proper coordinate conversion library
    new_lat = node.latlon.lat
    new_lon = node.latlon.lon

    # Add converted coordinates as tags
    new_tags = node.tags === nothing ? Dict{String,String}() : copy(node.tags)
    new_tags["utm_x"] = string(round(new_lon * 1000, digits=2))
    new_tags["utm_y"] = string(round(new_lat * 1000, digits=2))

    return Node(node.latlon, new_tags)
end

converted_data = readpbf("map.pbf", node_callback=convert_coordinates)
```

## Analysis Examples

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

pois = readpbf("map.pbf", node_callback=keep_pois)
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

### Network Analysis

```julia
# Analyze road network
function keep_roads(way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

roads = readpbf("map.pbf", way_callback=keep_roads)

# Analyze road types
road_types = Dict{String,Int}()
for (id, way) in roads.ways
    if way.tags !== nothing && haskey(way.tags, "highway")
        road_type = way.tags["highway"]
        road_types[road_type] = get(road_types, road_type, 0) + 1
    end
end

println("Road network analysis:")
for (type, count) in sort(collect(road_types), by=x->x[2], rev=true)
    println("$type: $count ways")
end
```

## Error Handling Examples

### Robust File Reading

```julia
function safe_read_osm(filename)
    try
        if endswith(filename, ".pbf")
            return readpbf(filename)
        elseif endswith(filename, ".osm")
            return readosm(filename)
        else
            throw(ArgumentError("Unsupported file format. Use .pbf or .osm files."))
        end
    catch e
        if isa(e, SystemError)
            throw(ArgumentError("Cannot read file '$filename': $(e.msg)"))
        elseif isa(e, ArgumentError)
            rethrow(e)
        else
            throw(ArgumentError("Unexpected error reading '$filename': $e"))
        end
    end
end

# Usage
try
    osmdata = safe_read_osm("map.pbf")
    println("Successfully loaded $(length(osmdata.nodes)) nodes")
catch e
    println("Error: $e")
end
```

### Handling Large Datasets

```julia
# Process large files in chunks using callbacks
function process_large_file(filename)
    node_count = 0
    way_count = 0

    function count_nodes(node)
        node_count += 1
        if node_count % 10000 == 0
            println("Processed $node_count nodes...")
        end
        return node  # Keep all nodes for now
    end

    function count_ways(way)
        way_count += 1
        if way_count % 1000 == 0
            println("Processed $way_count ways...")
        end
        return way  # Keep all ways for now
    end

    osmdata = readpbf(filename,
        node_callback=count_nodes,
        way_callback=count_ways
    )

    println("Final counts: $node_count nodes, $way_count ways")
    return osmdata
end
```

## Performance Optimization

### Memory-Efficient Processing

```julia
# Process data without storing everything in memory
function analyze_without_storage(filename)
    restaurant_count = 0
    highway_count = 0

    function count_restaurants(node)
        if node.tags !== nothing &&
           haskey(node.tags, "amenity") &&
           node.tags["amenity"] == "restaurant"
            restaurant_count += 1
        end
        return nothing  # Don't store the node
    end

    function count_highways(way)
        if way.tags !== nothing && haskey(way.tags, "highway")
            highway_count += 1
        end
        return nothing  # Don't store the way
    end

    readpbf(filename,
        node_callback=count_restaurants,
        way_callback=count_highways
    )

    println("Found $restaurant_count restaurants and $highway_count highways")
end
```

These examples demonstrate the flexibility and power of OpenStreetMapIO.jl for various data processing tasks. The callback system allows for efficient filtering and processing of large datasets without loading everything into memory.
