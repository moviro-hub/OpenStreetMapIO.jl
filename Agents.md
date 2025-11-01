# OpenStreetMapIO.jl - Agent Guide

This guide provides comprehensive information for AI agents working with the OpenStreetMapIO.jl Julia package.

## Package Overview

OpenStreetMapIO.jl is a Julia package for reading and processing OpenStreetMap (OSM) data. It supports:
- Reading OSM data from PBF (Protocol Buffer Format) files
- Reading OSM data from XML files
- Querying data directly from the Overpass API
- Filtering data during reading using callback functions

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/moviro-hub/OpenStreetMapIO.jl")
```

After installation, import the package:

```julia
using OpenStreetMapIO
```

## Core Functions

### Reading Files

#### `readpbf(filename; node_callback, way_callback, relation_callback)`

Reads OSM data from a PBF file.

**Parameters:**
- `filename::String`: Path to the PBF file
- `node_callback::Union{Function,Nothing}` (optional): Callback to filter nodes
- `way_callback::Union{Function,Nothing}` (optional): Callback to filter ways
- `relation_callback::Union{Function,Nothing}` (optional): Callback to filter relations

**Returns:** `OpenStreetMap` object

**Example:**
```julia
osmdata = readpbf("map.pbf")
```

#### `readosm(filename; node_callback, way_callback, relation_callback)`

Reads OSM data from an XML file. Same interface as `readpbf`.

**Example:**
```julia
osmdata = readosm("map.osm")
```

### Querying Overpass API

#### `queryoverpass(bbox; timeout=25)`

Queries OSM data using a bounding box.

**Parameters:**
- `bbox::BBox`: Geographic bounding box
- `timeout::Int64` (optional): Query timeout in seconds (default: 25)

**Returns:** `OpenStreetMap` object

**Example:**
```julia
bbox = BBox(54.0, 9.0, 55.0, 10.0)  # lat_min, lon_min, lat_max, lon_max
osmdata = queryoverpass(bbox)
```

#### `queryoverpass(position, radius; timeout=25)`

Queries OSM data using a center point and radius.

**Parameters:**
- `position::Position`: Center point coordinates
- `radius::Real`: Radius in meters
- `timeout::Int64` (optional): Query timeout in seconds (default: 25)

**Returns:** `OpenStreetMap` object

**Example:**
```julia
center = Position(54.2619665, 9.9854149)
osmdata = queryoverpass(center, 1000)  # 1km radius
```

## Data Types

### `OpenStreetMap`

Container for complete OSM datasets.

**Fields:**
- `nodes::Dict{Int64,Node}`: Dictionary of nodes indexed by ID
- `ways::Dict{Int64,Way}`: Dictionary of ways indexed by ID
- `relations::Dict{Int64,Relation}`: Dictionary of relations indexed by ID
- `meta::Dict{String,Any}`: Metadata (bounding box, timestamps, etc.)

### `Node`

Represents a point on the map.

**Fields:**
- `position::Position`: Geographic coordinates
- `tags::Union{Dict{String,String},Nothing}`: Key-value tags (e.g., `{"amenity" => "restaurant"}`)
- `info::Union{Info,Nothing}`: Optional metadata

### `Way`

Represents a path (road, building outline, etc.).

**Fields:**
- `refs::Vector{Int64}`: Ordered list of node IDs
- `tags::Union{Dict{String,String},Nothing}`: Key-value tags
- `info::Union{Info,Nothing}`: Optional metadata
- `positions::Union{Vector{Position},Nothing}`: Optional embedded coordinates (LocationsOnWays feature)

### `Relation`

Represents a grouping of elements (bus routes, administrative boundaries, etc.).

**Fields:**
- `refs::Vector{Int64}`: List of member element IDs
- `types::Vector{String}`: Types of each member ("node", "way", or "relation")
- `roles::Vector{String}`: Roles of each member
- `tags::Union{Dict{String,String},Nothing}`: Key-value tags
- `info::Union{Info,Nothing}`: Optional metadata

### `BBox`

Geographic bounding box.

**Fields:**
- `bottom_lat::Float64`: Minimum latitude
- `left_lon::Float64`: Minimum longitude
- `top_lat::Float64`: Maximum latitude
- `right_lon::Float64`: Maximum longitude

**Constructor:**
```julia
BBox(lat_min, lon_min, lat_max, lon_max)
```

### `Position`

Geographic coordinates.

**Fields:**
- `lat::Float64`: Latitude (-90 to 90)
- `lon::Float64`: Longitude (-180 to 180)

**Constructor:**
```julia
Position(lat, lon)
```

### `Info`

Optional metadata for OSM elements.

**Fields:**
- `version::Union{Int32,Nothing}`: Version number
- `timestamp::Union{DateTime,Nothing}`: Last modification time
- `changeset::Union{Int64,Nothing}`: Changeset ID
- `uid::Union{Int32,Nothing}`: User ID
- `user::Union{String,Nothing}`: Username
- `visible::Union{Bool,Nothing}`: Visibility flag

## Callback Functions

Callback functions allow filtering data during reading. They receive an element (Node, Way, or Relation) and return:
- The element (modified or unchanged) to include it
- `nothing` to exclude it

**Callback Signature:**
```julia
function my_callback(element::Union{Node, Way, Relation})
    # Filter logic here
    if should_include(element)
        return element  # Include
    else
        return nothing   # Exclude
    end
end
```

**Example - Filter Restaurants:**
```julia
function keep_restaurants(node::Node)
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        return node
    end
    return nothing
end

osmdata = readpbf("map.pbf", node_callback=keep_restaurants)
```

**Example - Filter Highways:**
```julia
function keep_highways(way::Way)
    if way.tags !== nothing && haskey(way.tags, "highway")
        return way
    end
    return nothing
end

osmdata = readpbf("map.pbf", way_callback=keep_highways)
```

## Common Use Cases

### 1. Find Points of Interest

```julia
function find_pois(osmdata::OpenStreetMap)
    pois = Dict{String, Vector{Tuple{Int64, Node}}}()
    for (id, node) in osmdata.nodes
        if node.tags !== nothing
            # Common POI tag keys
            poi_keys = ["amenity", "tourism", "shop", "leisure", "historic"]
            for key in poi_keys
                if haskey(node.tags, key)
                    poi_type = node.tags[key]
                    if !haskey(pois, poi_type)
                        pois[poi_type] = []
                    end
                    push!(pois[poi_type], (id, node))
                    break
                end
            end
        end
    end
    return pois
end

osmdata = readpbf("map.pbf")
pois = find_pois(osmdata)
```

### 2. Extract Road Network

```julia
function extract_roads(osmdata::OpenStreetMap)
    roads = Dict{Int64, Way}()
    for (id, way) in osmdata.ways
        if way.tags !== nothing && haskey(way.tags, "highway")
            roads[id] = way
        end
    end
    return roads
end
```

### 3. Get Coordinates from Ways

```julia
function way_coordinates(way::Way, osmdata::OpenStreetMap)
    coords = Position[]
    
    # Check if way has embedded coordinates (LocationsOnWays)
    if way.positions !== nothing
        return way.positions
    end
    
    # Otherwise, look up node coordinates
    for node_id in way.refs
        if haskey(osmdata.nodes, node_id)
            push!(coords, osmdata.nodes[node_id].position)
        end
    end
    
    return coords
end
```

### 4. Filter by Geographic Area

```julia
function filter_by_bbox(osmdata::OpenStreetMap, bbox::BBox)
    filtered = OpenStreetMap()
    
    # Filter nodes
    for (id, node) in osmdata.nodes
        pos = node.position
        if bbox.bottom_lat <= pos.lat <= bbox.top_lat &&
           bbox.left_lon <= pos.lon <= bbox.right_lon
            filtered.nodes[id] = node
        end
    end
    
    # Note: Ways and relations may extend beyond bbox
    # Filter based on whether any referenced nodes are in bbox
    for (id, way) in osmdata.ways
        if any(has_key(filtered.nodes, ref) for ref in way.refs)
            filtered.ways[id] = way
        end
    end
    
    return filtered
end
```

### 5. Count Elements by Tag

```julia
function count_by_tag(osmdata::OpenStreetMap, tag_key::String)
    counts = Dict{String, Int}()
    
    for (id, node) in osmdata.nodes
        if node.tags !== nothing && haskey(node.tags, tag_key)
            value = node.tags[tag_key]
            counts[value] = get(counts, value, 0) + 1
        end
    end
    
    return counts
end

# Example: Count restaurants by cuisine type
osmdata = readpbf("map.pbf")
cuisine_counts = count_by_tag(osmdata, "cuisine")
```

## Best Practices for Agents

### 1. Handle Missing Data

Always check for `nothing` when accessing optional fields:

```julia
if node.tags !== nothing && haskey(node.tags, "amenity")
    # Safe to access
    amenity = node.tags["amenity"]
end
```

### 2. Use Callbacks for Large Files

For memory efficiency with large files, use callbacks to filter during reading:

```julia
# Efficient: Filter during read
function keep_restaurants(node)
    node.tags !== nothing &&
    haskey(node.tags, "amenity") &&
    node.tags["amenity"] == "restaurant" ? node : nothing
end

osmdata = readpbf("large_file.pbf", node_callback=keep_restaurants)
```

### 3. Check File Existence

The package throws `ArgumentError` if a file doesn't exist. Handle it appropriately:

```julia
try
    osmdata = readpbf("map.pbf")
catch e
    if isa(e, ArgumentError) && occursin("does not exist", string(e))
        # Handle missing file
    else
        rethrow(e)
    end
end
```

### 4. Query Overpass API Responsibly

- Use appropriate bounding boxes (not too large)
- Set reasonable timeouts
- Consider caching results for repeated queries
- Be aware of API rate limits

```julia
# Good: Small, focused query
bbox = BBox(53.45, 9.95, 53.55, 10.05)  # ~10km x 10km
osmdata = queryoverpass(bbox, timeout=30)

# Avoid: Very large bounding boxes
# bbox = BBox(0.0, 0.0, 90.0, 180.0)  # Entire hemisphere
```

### 5. Access Metadata

Check for bounding box and other metadata:

```julia
osmdata = readpbf("map.pbf")

if haskey(osmdata.meta, "bbox")
    bbox = osmdata.meta["bbox"]
    println("Dataset covers: ($(bbox.bottom_lat), $(bbox.left_lon)) to ($(bbox.top_lat), $(bbox.right_lon))")
end
```

### 6. Work with Relations

Relations can be complex. Access member information correctly:

```julia
for (id, relation) in osmdata.relations
    if relation.tags !== nothing && haskey(relation.tags, "route")
        println("Route $(relation.tags["route"]) has $(length(relation.refs)) members")
        
        # Access members with their types and roles
        for (i, (ref, type, role)) in enumerate(zip(relation.refs, relation.types, relation.roles))
            println("  Member $i: $type $ref with role '$role'")
        end
    end
end
```

## Error Handling

Common errors and how to handle them:

1. **File not found:**
   ```julia
   ArgumentError("File 'map.pbf' does not exist")
   ```

2. **Invalid file format:**
   ```julia
   ArgumentError("Expected blob type 'OSMHeader', got '...'")
   ```

3. **Overpass API timeout:**
   ```julia
   # Increase timeout or reduce query size
   osmdata = queryoverpass(bbox, timeout=60)
   ```

4. **Corrupted data:**
   ```julia
   ArgumentError("Failed to decode blob: ...")
   ```

## Performance Tips

1. **PBF files are more efficient** than XML for large datasets
2. **Use callbacks** to avoid loading unnecessary data into memory
3. **LocationsOnWays** feature provides embedded coordinates, avoiding node lookups
4. **Batch processing** with callbacks is faster than post-processing

## Example: Complete Workflow

```julia
using OpenStreetMapIO

# Read data (or query from Overpass)
osmdata = readpbf("map.pbf")

# Or query a specific area
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osmdata = queryoverpass(bbox)

# Find restaurants
restaurants = Dict{Int64, Node}()
for (id, node) in osmdata.nodes
    if node.tags !== nothing &&
       haskey(node.tags, "amenity") &&
       node.tags["amenity"] == "restaurant"
        restaurants[id] = node
    end
end

# Print restaurant locations
for (id, node) in restaurants
    println("Restaurant $id at ($(node.position.lat), $(node.position.lon))")
    if node.tags !== nothing && haskey(node.tags, "name")
        println("  Name: $(node.tags["name"])")
    end
end

# Get road network
roads = Dict{Int64, Way}()
for (id, way) in osmdata.ways
    if way.tags !== nothing && haskey(way.tags, "highway")
        roads[id] = way
    end
end

println("Found $(length(restaurants)) restaurants and $(length(roads)) roads")
```

## Additional Resources

- **Package Documentation:** See `docs/src/` directory
- **OSM Data Sources:**
  - [Geofabrik](https://download.geofabrik.de/) - Regional extracts
  - [Overpass API](https://overpass-api.de/) - Online query service
  - [Planet.osm](https://planet.openstreetmap.org/) - Full planet data
- **OSM Wiki:** https://wiki.openstreetmap.org/ for tag documentation and data structure details
