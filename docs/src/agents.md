# Agents and OpenStreetMapIO
Use `OpenStreetMapIO.jl` together with [`Agents.jl`](https://juliadynamics.github.io/Agents.jl/stable/) to build agent-based simulations that move through real street networks or points of interest extracted from OpenStreetMap. This guide walks through the workflow from downloading data to running a simple simulation.

## Prerequisites
- Julia 1.9 or newer (matching the rest of the project)
- Packages: `OpenStreetMapIO`, `Agents`, `Graphs`, and optionally `AgentsPlots` or `CairoMakie` for visualization

Install the extras inside your documentation or project environment:

```julia
using Pkg
Pkg.add(["Agents", "Graphs", "AgentsPlots", "CairoMakie"])
```

`AgentsPlots` is optional but convenient for inspecting the simulation.

## Loading Map Data
You can read OpenStreetMap data from a local `.pbf`/`.osm` file or query a bounding box from Overpass. The resulting `OpenStreetMap` struct stores element dictionaries keyed by their OSM identifiers.

```julia
using OpenStreetMapIO

# Example: load a bundled test file
osm = readpbf(joinpath(pkgdir(OpenStreetMapIO), "test", "data", "map.pbf"))

# Basic counts
println("nodes = $(length(osm.nodes))")
println("ways = $(length(osm.ways))")
println("relations = $(length(osm.relations))")
```

To work with a fresh snapshot, call `queryoverpass` with either a bounding box or a point-plus-radius:

```julia
bbox = BBox(53.45, 9.95, 53.55, 10.05)
osm = queryoverpass(bbox)
```

## Building a Walkable Graph
Agent simulations on street networks usually operate on a graph whose vertices are OSM nodes and whose edges come from way segments. The snippet below keeps pedestrian-friendly ways, constructs a `SimpleGraph`, and records coordinate metadata for later use.

```julia
using Graphs

function build_walk_graph(osm)
    node_positions = Dict(id => node.position for (id, node) in osm.nodes)

    function is_walkable(way)
        tags = way.tags
        tags === nothing && return false
        highway = get(tags, "highway", nothing)
        highway === nothing && return false
        return highway ∉ ("motorway", "motorway_link", "trunk", "trunk_link")
    end

    node_ids = collect(keys(node_positions))
    id_to_index = Dict(id => i for (i, id) in enumerate(node_ids))
    graph = SimpleGraph(length(node_ids))

    for way in values(osm.ways)
        is_walkable(way) || continue
        refs = way.refs
        for i in 1:length(refs)-1
            u, v = refs[i], refs[i + 1]
            haskey(id_to_index, u) && haskey(id_to_index, v) || continue
            add_edge!(graph, id_to_index[u], id_to_index[v])
        end
    end

    coords = [node_positions[id] for id in node_ids]
    return graph, node_ids, coords, id_to_index
end

graph, node_ids, coords, id_to_index = build_walk_graph(osm)
```

The helper returns both the graph and lookup vectors so you can map between agent positions (graph vertex indices) and geographic coordinates.

## Defining Agents
`Agents.jl` supplies the `GraphAgent` interface for graph-based simulations. Store any domain-specific information (e.g. desired speed or goal) directly on the agent struct.

```julia
using Agents

@agent StreetAgent GraphAgent begin
    speed::Float64
    goal::Int
end

function random_walk!(agent, model)
    neighbors = node_neighbors(agent, model)
    isempty(neighbors) && return
    move_agent!(agent, model, rand(neighbors))
end
```

`node_neighbors` returns neighboring vertex indices, while `move_agent!` updates both the agent position and the model state.

## Creating the Model
Agents on graphs are typically managed with `StandardABM`. Pass the graph space, the coordinate metadata, and any global parameters in the model properties dictionary.

```julia
space = GraphSpace(graph)
properties = Dict(
    :node_ids => node_ids,
    :coordinates => coords,
)

model = StandardABM(StreetAgent, space; properties)

# Populate with a few walkers
for _ in 1:25
    start_vertex = rand(1:nv(graph))
    goal_vertex = rand(1:nv(graph))
    add_agent!(StreetAgent(start_vertex, 1.4, goal_vertex), model)
end
```

The first positional argument in each agent constructor is the initial vertex index (required by `GraphAgent`). Additional fields follow in the order defined in the `@agent` block.

## Running and Analyzing the Simulation
Step the model synchronously or asynchronously depending on your process. The example below advances 200 steps, collecting agent positions over time for later processing.

```julia
using Statistics

data, _ = run!(model, random_walk!, 200; adata = [(agents) -> [a.pos for a in agents]])

avg_degree = mean(degree(graph))
println("average degree in walk graph: $avg_degree")
```

When `adata` is provided, `run!` returns a vector of recorded values for each step. Here every element of `data` contains the agent positions at that timestep. Replace `random_walk!` with domain-specific logic (e.g. routing, demand modeling, evacuation).

## Visualization Tips
- Call `plotabm(model; coords = model.properties[:coordinates])` from `AgentsPlots` to inspect agent movement on top of the OSM-derived graph.
- Use the `node_ids` vector to recover OSM identifiers for logging or map matching.
- For geographic rendering, convert the positions to projected coordinates via `Proj4.jl` or `GeoInterface.jl` before plotting with Makie.

## Working With Larger Areas
- Limit your Overpass query to the smallest bounding box that covers the scenario.
- Drop unused nodes before constructing the graph to save memory.
- Consider compressing parallel edges (e.g. two-way streets) into undirected connections for faster simulations.
- Persist the graph and lookup tables with `Serialization.serialize` so the expensive parsing step runs only once per scenario.

With these pieces in place, you can quickly prototype agent-based models grounded in real OSM data while taking full advantage of Julia's ecosystem.
