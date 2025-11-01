using Documenter, OpenStreetMapIO

# Set up the documentation environment
makedocs(;
    sitename = "OpenStreetMapIO.jl",
    authors = "MOVIRO",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://moviro-hub.github.io/OpenStreetMapIO.jl",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
        "Examples" => "examples.md",
        "Agents" => "agents.md",
    ],
    checkdocs = :exports,
)

deploydocs(;
    repo = "github.com/moviro-hub/OpenStreetMapIO.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
)
