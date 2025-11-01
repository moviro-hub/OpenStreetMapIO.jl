# Agent-Based Modeling with Agents.jl

This guide shows how to combine `OpenStreetMapIO.jl` with [Agents.jl](https://juliadynamics.github.io/Agents.jl/stable/) to build agent-based models that move on real-world street networks. The examples assume you already know the basics of `Agents.jl`; here we focus on extracting network data from OSM and turning it into a simulation space.

## Installation

Add the required packages to your project:

```julia
using Pkg
Pkg.add(url="https://github.com/moviro-hub/OpenStreetMapIO.jl")
Pkg.add(["Agents", "Graphs", "NearestNeighbors"])
```

`Graphs.jl` is helpful for representing the street network, while `NearestNeighbors.jl` provides fast lookups from geographic coordinates to graph nodes when you spawn agents.

## Loading OpenStreetMap Data

You can ingest map data from a local file or query a bounding box via Overpass.

```julia
using OpenStreetMapIO

# Option 1: read a local extract (XML or PBF)
osm = readpbf("data/hamburg.pbf")

# Option 2: fetch a small bounding box
bbox = BBox(53.55, 9.95, 53.58, 10.02)
osm = queryoverpass(bbox)
```

Inspect the data to confirm that it contains the ways you need:

```julia
filter(pair -> get(pair[2].tags, "highway", nothing) == "residential", osm.ways)
```

## Building a Street Graph

Agents that move along a road network typically use a graph where vertices are OSM nodes and edges connect consecutive nodes in a way. The snippet below keeps only highway-classified ways, removes duplicates, and produces a `SimpleGraph`:

```julia
using Graphs

highway_ways = [
    way
    for way in values(osm.ways)
    if way.tags !== nothing && haskey(way.tags, "highway")
]

edges = Set{Tuple{Int64, Int64}}()

for way in highway_ways
    refs = way.refs
    length(refs) < 2 && continue
    for i in 1:length(refs)-1
        a, b = refs[i], refs[i + 1]
        a == b && continue
        push!(edges, a < b ? (a, b) : (b, a))
    end
end

node_ids = collect(Set(vcat(first.(edges), last.(edges))))
id_to_index = Dict(node_id => idx for (idx, node_id) in enumerate(node_ids))

g = SimpleGraph(length(node_ids))

for (src, dst) in edges
    add_edge!(g, id_to_index[src], id_to_index[dst])
end
```

Store the reverse mapping if you need geographic coordinates later:

```julia
index_to_position = Dict(
    id_to_index[node_id] => osm.nodes[node_id].position
    for node_id in keys(id_to_index)
)
```

## Defining Agents

With the graph prepared, define your agent type. The example below represents a pedestrian walking from a current to a destination node.

```julia
using Agents
using Graphs: dijkstra_shortest_paths, enumerate_paths

mutable struct Pedestrian <: AbstractAgent
    id::Int
    pos::Int                # node index in the graph
    goal::Int               # node index in the graph
    route::Vector{Int}      # remaining path nodes
end

function plan_route(graph, start, goal)
    start == goal && return Int[]
    state = dijkstra_shortest_paths(graph, start)
    path = enumerate_paths(state, goal)
    path === nothing && return Int[]
    return length(path) <= 1 ? Int[] : path[2:end]
end
```

Helper functions convert coordinates to the closest node using a KD-tree:

```julia
using NearestNeighbors

ordered_vertices = sort!(collect(keys(index_to_position)))
coords = hcat([ [index_to_position[v].lon, index_to_position[v].lat] for v in ordered_vertices ]...)

tree = KDTree(coords)

function nearest_node(lon, lat)
    idxs, _ = knn(tree, [lon, lat], 1)
    return ordered_vertices[idxs[1]]
end
```

## Creating the Model

Set up a graph-based ABM and seed a few agents on the network:

```julia
space = GraphSpace(g)
properties = Dict(:positions => index_to_position)

model = ABM(Pedestrian, space; properties)

function random_goal(rng)
    rand(rng, vertices(g))
end

for _ in 1:25
    start = random_goal(model.rng)
    goal = random_goal(model.rng)
    route = plan_route(g, start, goal)
    add_agent!(start, model) do id
        Pedestrian(id, start, goal, route)
    end
end
```

The example above relies on `plan_route` to compute a shortest path using `Graphs.jl`.

## Stepping Agents

Implement a simple scheduler that moves each agent along the precomputed route and respawns a new destination on arrival:

```julia
function agent_step!(agent, model)
    isempty(agent.route) && return
    next_vertex = popfirst!(agent.route)
    move_agent!(agent, next_vertex, model)

    if isempty(agent.route)
        agent.goal = random_goal(model.rng)
        agent.route = plan_route(model.space.graph, agent.pos, agent.goal)
    end
end

step!(model, agent_step!, 100)
```

The model now simulates pedestrians circulating on a real street graph derived from OpenStreetMap data.

## Tips for Larger Studies

- **Filter aggressively**: keep only the ways and nodes relevant to your question to reduce graph size.
- **Reproject coordinates**: convert lat/lon to meters (e.g. with `Proj4.jl`) when speed depends on physical distance instead of edge counts.
- **Cache processed graphs**: save the serialized graph or adjacency matrix to skip preprocessing for repeated experiments.
- **Combine datasets**: relations and points of interest can provide destinations (e.g. bus stops, shops) for different agent types.

With these building blocks you can model urban mobility, pedestrian flow, or other agent-based scenarios using real map data in Julia.
