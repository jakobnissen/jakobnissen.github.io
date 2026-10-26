# Serve the site locally with syntax highlighting: `julia --project serve.jl`
# Requires `npm install` to have been run first, for Shiki.
using Franklin
include("_highlight/highlight.jl")
serve()
