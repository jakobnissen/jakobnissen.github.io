function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

# Meta tags for link previews (Open Graph, used by e.g. Slack, Discord, Mastodon,
# and Twitter/Bluesky cards). Uses the page's `title` and `rss` description,
# falling back to the website's title and description.
function hfun_link_preview()
    attr(s) = replace(string(s), '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")
    site_title = globvar(:website_title)
    site_url = rstrip(globvar(:website_url), '/')
    title = something(locvar(:title), site_title)
    description = locvar(:rss_description)
    is_post = !isempty(description)
    is_post || (description = globvar(:website_description))
    # fd_url is e.g. "/posts/foo/index.html" or "404.html"
    path = replace("/" * lstrip(locvar(:fd_url), '/'), r"index\.html$" => "")
    url = site_url * path
    image = site_url * "/assets/preview.png"
    tags = [
        """<link rel="canonical" href="$(attr(url))">""",
        """<meta name="description" content="$(attr(description))">""",
        """<meta property="og:site_name" content="$(attr(site_title))">""",
        """<meta property="og:title" content="$(attr(title))">""",
        """<meta property="og:description" content="$(attr(description))">""",
        """<meta property="og:url" content="$(attr(url))">""",
        """<meta property="og:image" content="$(attr(image))">""",
        """<meta property="og:type" content="$(is_post ? "article" : "website")">""",
        """<meta name="twitter:card" content="summary">""",
    ]
    if is_post
        push!(tags, """<meta property="article:published_time" content="$(locvar(:rss_pubdate))">""")
        push!(tags, """<meta property="article:author" content="$(attr(globvar(:author)))">""")
    end
    return join(tags, "\n  ")
end
