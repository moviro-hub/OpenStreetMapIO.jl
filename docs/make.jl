using Documenter, OpenStreetMapIO

# Set up the documentation environment
makedocs(;
    sitename="OpenStreetMapIO.jl",
    authors="MOVIRO",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://moviro.github.io/OpenStreetMapIO.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "API Reference" => "api.md",
        "Examples" => "examples.md",
        "Developer Guide" => "developer.md",
    ],
    checkdocs=:exports,
)

deploydocs(; repo="github.com/moviro-hub/OpenStreetMapIO.jl.git", devbranch="main")
