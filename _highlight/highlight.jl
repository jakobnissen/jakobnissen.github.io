# Build-time syntax highlighting of code blocks.
# Julia code is highlighted with JuliaSyntaxHighlighting, everything else with Shiki
# (see shiki.mjs, which needs `npm install` to have been run in the repo root).
# The colours are set in _css/highlight.css.
#
# This overrides `Franklin.html_code`, and must therefore be included *before*
# `serve()` or `optimize()` is called. Methods defined while Franklin is running
# (e.g. in utils.jl) are not visible to it, due to Julia's world age.
module Highlight

using Franklin: Franklin, AS
using JuliaSyntaxHighlighting: JuliaSyntaxHighlighting

const SHIKI_SCRIPT = joinpath(@__DIR__, "shiki.mjs")

# (lang, code) => html. Shiki is called through Node, which is slow-ish,
# so cache results across rebuilds when serving.
const SHIKI_CACHE = Dict{Tuple{String, String}, String}()

escape_html(s::AbstractString) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;")

span(class::String, s::AbstractString) = "<span class=\"$class\">$s</span>"

# --- Julia ------------------------------------------------------------------

# The face :julia_funcall becomes the CSS class "jl-funcall", etc.
function face_class(face::Symbol)::Union{Nothing, String}
    s = String(face)
    startswith(s, "julia_") || return nothing
    s = s[7:end]
    # Rainbow brackets (julia_rainbow_paren_2 etc.) all get the same class
    startswith(s, "rainbow_") && return "jl-bracket"
    return "jl-" * s
end

function julia_html(code::AbstractString)::String
    highlighted = JuliaSyntaxHighlighting.highlight(code)
    str = String(highlighted)
    regions = Tuple{UnitRange{Int}, String}[]
    for annot in Base.annotations(highlighted)
        annot.label === :face || continue
        class = face_class(annot.value)
        isnothing(class) && continue
        push!(regions, (annot.region, class))
    end
    # Cut the string at every region boundary, and wrap each piece in a span
    # with the classes of all regions covering it. This handles nested regions.
    stop_of(r) = isvalid(str, last(r)) ? nextind(str, last(r)) : last(r) + 1
    cuts = Set{Int}([1, ncodeunits(str) + 1])
    for (r, _) in regions
        push!(cuts, first(r), stop_of(r))
    end
    cuts = sort!(collect(cuts))
    io = IOBuffer()
    for (start, stop) in zip(cuts, @view cuts[2:end])
        text = escape_html(String(codeunits(str)[start:stop-1]))
        classes = [c for (r, c) in regions if first(r) ≤ start < stop_of(r)]
        print(io, isempty(classes) ? text : span(join(unique!(classes), ' '), text))
    end
    return String(take!(io))
end

is_incomplete_julia(s::AbstractString) =
    Meta.isexpr(Meta.parse(s; raise=false, depwarn=false), :incomplete)

# --- Shiki ------------------------------------------------------------------

# Highlight all (lang, code) pairs with a single Node call. Return a vector of
# html strings, or `nothing` if Shiki could not be run.
function shiki_html(items::Vector{Tuple{String, String}})::Union{Nothing, Vector{String}}
    missing_items = unique!(filter(item -> !haskey(SHIKI_CACHE, item), items))
    if !isempty(missing_items)
        payload = join((x for item in missing_items for x in item), '\0')
        output = try
            read(pipeline(`node $SHIKI_SCRIPT`; stdin=IOBuffer(payload)), String)
        catch e
            @warn "Could not run Shiki to highlight code. Did you run `npm install`?" exception = e maxlog = 1
            return nothing
        end
        for (item, html) in zip(missing_items, split(output, '\0'))
            SHIKI_CACHE[item] = html
        end
    end
    return [SHIKI_CACHE[item] for item in items]
end

shiki_html(lang::String, code::AbstractString) = shiki_html([(lang, String(code))])

# --- REPL sessions ----------------------------------------------------------

const JULIA_PROMPTS = [
    r"^julia> ?" => "repl-julia",
    r"^(\([^)]*\) )?pkg> ?" => "repl-pkg",
    r"^help\?> ?" => "repl-help",
    r"^shell> ?" => "repl-shell",
]

function julia_repl_html(code::AbstractString)::String
    lines = split(code, '\n')
    out = String[]
    i = 1
    while i ≤ length(lines)
        line = lines[i]
        m = findfirst(p -> occursin(first(p), line), JULIA_PROMPTS)
        if isnothing(m)
            # Output line
            push!(out, startswith(line, "ERROR:") ? span("repl-error", escape_html(line)) : escape_html(line))
            i += 1
            continue
        end
        regex, class = JULIA_PROMPTS[m]
        prompt = match(regex, line).match
        input = line[ncodeunits(prompt)+1:end]
        if class == "repl-julia"
            # Like the REPL, keep reading lines until the input is a complete expression
            j = i
            while is_incomplete_julia(input) && j < length(lines)
                j += 1
                input *= "\n" * lines[j]
            end
            push!(out, span(class, escape_html(prompt)) * julia_html(input))
            i = j + 1
        else
            push!(out, span(class, escape_html(prompt)) * escape_html(input))
            i += 1
        end
    end
    return join(out, '\n')
end

# Python REPL and shell sessions: Input lines start with a prompt, and may be
# followed by continuation lines. Input is highlighted with Shiki as `lang`.
function session_html(code::AbstractString, lang::String, prompt::Regex, is_continuation)::String
    lines = split(code, '\n')
    # Each group is (prompts, input lines) or (nothing, output line)
    groups = Tuple{Union{Nothing, Vector{String}}, Vector{String}}[]
    i = 1
    while i ≤ length(lines)
        m = match(prompt, lines[i])
        if isnothing(m)
            push!(groups, (nothing, [String(lines[i])]))
            i += 1
            continue
        end
        prompts, inputs = String[m.match], String[lines[i][ncodeunits(m.match)+1:end]]
        while i < length(lines) && is_continuation(lines[i], lines[i+1])
            i += 1
            p = something(match(prompt, lines[i]), (; match=""))
            push!(prompts, p.match)
            push!(inputs, lines[i][ncodeunits(p.match)+1:end])
        end
        push!(groups, (prompts, inputs))
        i += 1
    end
    input_groups = [(lang, join(inputs, '\n')) for (prompts, inputs) in groups if !isnothing(prompts)]
    highlighted = something(shiki_html(input_groups), map(escape_html ∘ last, input_groups))
    out = String[]
    k = 0
    for (prompts, lines) in groups
        if isnothing(prompts)
            push!(out, escape_html(only(lines)))
        else
            k += 1
            for (p, html_line) in zip(prompts, split(highlighted[k], '\n'))
                push!(out, (isempty(p) ? "" : span("repl-prompt", escape_html(p))) * html_line)
            end
        end
    end
    return join(out, '\n')
end

python_repl_html(code) = session_html(
    code, "python", r"^(>>>|\.\.\.) ?",
    (_, next) -> startswith(next, "... "),
)

shell_session_html(code) = session_html(
    code, "bash", r"^\$ ",
    (line, _) -> endswith(rstrip(line), '\\'),
)

# --- Franklin hook ----------------------------------------------------------

# Franklin's original html_code (without its support for hidden lines)
function html_code_unhighlighted(c::AS, lang::AS, class::String)::String
    isempty(lang) && return "<pre><code class=\"plaintext$(class)\">$c</code></pre>"
    c = Franklin.is_html_escaped(c) ? c : Franklin.htmlesc(c)
    return "<pre><code class=\"language-$(lang)$(class)\">$c</code></pre>"
end

function highlight_html(code::AbstractString, lang::AbstractString)::String
    lang == "julia" && return julia_html(code)
    lang == "julia-repl" && return julia_repl_html(code)
    lang == "python-repl" && return python_repl_html(code)
    lang == "shell" && return shell_session_html(code)
    lang == "plaintext" && return escape_html(code)
    html = shiki_html(String(lang), code)
    return isnothing(html) ? escape_html(code) : only(html)
end

function html_code(c::AS, lang::AS; class::String)::String
    isempty(c) && return ""
    class = isempty(class) ? "" : " $class"
    # Indented code blocks have their language resolved later. Leave those unhighlighted.
    if isempty(lang) || occursin("{{", lang)
        return html_code_unhighlighted(c, lang, class)
    end
    code = Franklin.is_html_escaped(c) ? Franklin.html_unescape(c) : String(c)
    return "<pre class=\"highlighted\"><code class=\"language-$(lang)$(class)\">$(highlight_html(code, lang))</code></pre>"
end

end # module Highlight

@eval Franklin html_code(c::AS, lang::AS=""; class::String="") = $(Highlight.html_code)(c, lang; class)
