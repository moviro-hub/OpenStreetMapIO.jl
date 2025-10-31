# OSMPBF module is included internally in io_pbf.jl

"""
    BBox

Represents a geographic bounding box with latitude and longitude boundaries.

# Fields
- `bottom_lat::Float32`: Minimum latitude (southern boundary)
- `left_lon::Float32`: Minimum longitude (western boundary)
- `top_lat::Float32`: Maximum latitude (northern boundary)
- `right_lon::Float32`: Maximum longitude (eastern boundary)

# Examples
```julia
bbox = BBox(54.0f0, 9.0f0, 55.0f0, 10.0f0)  # lat_min, lon_min, lat_max, lon_max
```
"""
struct BBox
    bottom_lat::Float32
    left_lon::Float32
    top_lat::Float32
    right_lon::Float32
end

"""
    LatLon

Represents a geographic coordinate with latitude and longitude.

# Fields
- `lat::Float32`: Latitude in decimal degrees (-90 to 90)
- `lon::Float32`: Longitude in decimal degrees (-180 to 180)

# Examples
```julia
coord = LatLon(54.2619665, 9.9854149)
```
"""
struct LatLon
    lat::Float32
    lon::Float32
end

"""
    ElementMetadata

Optional metadata attached to OSM primitives. Fields may be `nothing`
when the PBF file omits the respective value.

# Fields
- `version::Union{Int32,Nothing}`: Element version number.
- `timestamp::Union{DateTime,Nothing}`: Last modification timestamp (UTC).
- `changeset::Union{Int64,Nothing}`: Changeset identifier.
- `uid::Union{Int32,Nothing}`: User identifier.
- `user::Union{String,Nothing}`: Username (resolved from the string table).
- `visible::Union{Bool,Nothing}`: Historical visibility flag (if present).
"""
struct ElementMetadata
    version::Union{Int32, Nothing}
    timestamp::Union{DateTime, Nothing}
    changeset::Union{Int64, Nothing}
    uid::Union{Int32, Nothing}
    user::Union{String, Nothing}
    visible::Union{Bool, Nothing}
end

ElementMetadata() = ElementMetadata(nothing, nothing, nothing, nothing, nothing, nothing)

"""
    Node

Represents an OpenStreetMap node (point) with geographic coordinates and optional tags.

# Fields
- `latlon::LatLon`: Geographic coordinates of the node
- `tags::Union{Dict{String,String},Nothing}`: Key-value pairs describing the node, or `nothing` if no tags
- `metadata::Union{ElementMetadata,Nothing}`: Optional metadata extracted from the PBF file

# Examples
```julia
node = Node(
    LatLon(54.2619665, 9.9854149),
    Dict("amenity" => "restaurant"),
    ElementMetadata(1, nothing, 1234, 567, "mapper", true),
)
```
"""
struct Node
    latlon::LatLon
    tags::Union{Dict{String, String}, Nothing}
    metadata::Union{ElementMetadata, Nothing}
end

"""
    Way

Represents an OpenStreetMap way (path) as an ordered list of node references.

# Fields
- `refs::Vector{Int64}`: Ordered list of node IDs that form the way
- `tags::Union{Dict{String,String},Nothing}`: Key-value pairs describing the way, or `nothing` if no tags
- `metadata::Union{ElementMetadata,Nothing}`: Optional metadata extracted from the PBF file
- `coordinates::Union{Vector{LatLon},Nothing}`: Optional embedded node coordinates (LocationsOnWays)

# Examples
```julia
way = Way(
    [12345, 67890, 11111],
    Dict("highway" => "primary"),
    nothing,
    nothing,
)
```
"""
struct Way
    refs::Vector{Int64}
    tags::Union{Dict{String, String}, Nothing}
    metadata::Union{ElementMetadata, Nothing}
    coordinates::Union{Vector{LatLon}, Nothing}
end

"""
    Relation

Represents an OpenStreetMap relation (grouping) of nodes, ways, and other relations.

# Fields
- `refs::Vector{Int64}`: List of element IDs that are members of this relation
- `types::Vector{String}`: Types of each member ("node", "way", or "relation")
- `roles::Vector{String}`: Roles of each member in the relation
- `tags::Union{Dict{String,String},Nothing}`: Key-value pairs describing the relation, or `nothing` if no tags
- `metadata::Union{ElementMetadata,Nothing}`: Optional metadata extracted from the PBF file

# Examples
```julia
relation = Relation(
    [12345, 67890],
    ["node", "way"],
    ["stop", "platform"],
    Dict("route" => "bus"),
    nothing,
)
```
"""
struct Relation
    refs::Vector{Int64}
    types::Vector{String}
    roles::Vector{String}
    tags::Union{Dict{String, String}, Nothing}
    metadata::Union{ElementMetadata, Nothing}
end

"""
    OpenStreetMap

Container for complete OpenStreetMap data including nodes, ways, relations, and metadata.

# Fields
- `nodes::Dict{Int64,Node}`: Dictionary mapping node IDs to Node objects
- `ways::Dict{Int64,Way}`: Dictionary mapping way IDs to Way objects
- `relations::Dict{Int64,Relation}`: Dictionary mapping relation IDs to Relation objects
- `meta::Dict{String,Any}`: Metadata about the dataset (bounding box, timestamps, etc.)

# Constructors
- `OpenStreetMap()`: Create empty OpenStreetMap object
- `OpenStreetMap(nodes, ways, relations, meta)`: Create with pre-populated data

# Examples
```julia
osmdata = OpenStreetMap()
osmdata = readpbf("map.pbf")  # Load from file
```
"""
struct OpenStreetMap
    nodes::Dict{Int64, Node}
    ways::Dict{Int64, Way}
    relations::Dict{Int64, Relation}
    meta::Dict{String, Any}

    OpenStreetMap() = new(Dict(), Dict(), Dict(), Dict())
    function OpenStreetMap(
            nodes::Dict{Int64, Node},
            ways::Dict{Int64, Way},
            relations::Dict{Int64, Relation},
            meta::Dict{String, Any},
        )
        return new(nodes, ways, relations, meta)
    end
end
