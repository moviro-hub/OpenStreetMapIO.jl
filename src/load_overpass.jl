"""
    fetch_overpass(bbox; kwargs...)

Query OpenStreetMap data from Overpass API using a bounding box.

# Arguments
- `bbox::BBox`: Geographic bounding box to query

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data within the specified bounding box

# Examples
```julia
bbox = BBox(54.0, 9.0, 55.0, 10.0)
osmdata = fetch_overpass(bbox)
```
"""
function fetch_overpass(bbox::BBox; kwargs...)::OpenStreetMap
    osmdata = fetch_overpass(
        "$(bbox.bottom_lat),$(bbox.left_lon),$(bbox.top_lat),$(bbox.right_lon)"; kwargs...
    )
    return osmdata
end

"""
    fetch_overpass(position, radius; kwargs...)

Query OpenStreetMap data from Overpass API using a center point and radius.

# Arguments
- `position::Position`: Center point for the query
- `radius::Real`: Radius in meters around the center point

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data within the specified radius

# Examples
```julia
center = Position(54.2619665, 9.9854149)
osmdata = fetch_overpass(center, 1000)  # 1km radius
```
"""
function fetch_overpass(position::Position, radius::Real; kwargs...)
    osmdata = fetch_overpass("around:$radius,$(position.lat),$(position.lon)"; kwargs...)
    return osmdata
end

"""
    fetch_overpass(bounds; timeout)

Query OpenStreetMap data from Overpass API using a bounds string.

# Arguments
- `bounds::String`: Bounds string in Overpass API format (e.g., "54.0,9.0,55.0,10.0" or "around:1000,54.0,9.0")

# Keyword Arguments
- `timeout::Int64=25`: Query timeout in seconds

# Returns
- `OpenStreetMap`: OSM data matching the query

# Examples
```julia
# Bounding box query
osmdata = fetch_overpass("54.0,9.0,55.0,10.0")

# Radius query
osmdata = fetch_overpass("around:1000,54.2619665,9.9854149")
```

# See Also
- [`read_pbf`](@ref): Read OSM PBF files
- [`read_osm`](@ref): Read OSM XML files
"""
function fetch_overpass(bounds::String; timeout::Int64 = 25)::OpenStreetMap
    query = """
    	[out:xml][timeout:$timeout];
    	(
    		node($bounds);
    		way($bounds);
    		relation($bounds);
    	);
    	out body;
    	>;
    	out skel qt;
    """

    # Try primary endpoint first, then fallback
    endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://lz4.overpass-api.de/api/interpreter",
    ]

    last_error = ErrorException("All Overpass API endpoints failed")

    for endpoint in endpoints
        url = "$(endpoint)?data=$(url_encode(query))"
        try
            response_body = download(url)
            node = XML.read(IOBuffer(response_body), XML.Node)
            return parse_osm(node)
        catch e
            last_error = e
            # Try next endpoint immediately
            continue
        end
    end

    # If all endpoints failed, throw the last error
    throw(last_error)
end
