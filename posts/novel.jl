<!DOCTYPE html>
<html lang="en">

<head>
    <meta name="viewport" content="width=device-width" />
    <title>⚡ Pluto.jl ⚡</title>
    <meta charset="utf-8" />
    <script>
        console.log("Pluto.jl, by Fons van der Plas (https://github.com/fonsp) and Mikołaj Bochenski (https://github.com/malyvsen) 🌈")
    </script>
    <meta name="author" content="Fons van der Plas; Mikołaj Bochenski" />
    <link rel="license" href="https://github.com/fonsp/Pluto.jl/blob/main/LICENSE" />
    <meta name="theme-color" content="#ffffff" />
    <link rel="icon" type="image/png" sizes="16x16" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/img/favicon-16x16.png" />
    <link rel="icon" type="image/png" sizes="32x32" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/img/favicon-32x32.png" />
    <link rel="icon" type="image/png" sizes="96x96" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/img/favicon-96x96.png" />
    <meta name="description" content="Pluto.jl notebooks" />
    <link rel="pluto-logo-big" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/img/logo.svg" />
    <link rel="pluto-logo-small" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/img/favicon_unsaturated.svg" />

    <link rel="pluto-sw" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/sw.js" />
    <script>
        navigator.serviceWorker?.register(document.head.querySelector("link[rel='pluto-sw']").getAttribute("href"), { scope: "./" }).catch(console.warn)
    </script>

    <script src="https://cdn.jsdelivr.net/npm/lodash@4.17.20/lodash.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/@observablehq/stdlib@3.3.1/dist/stdlib.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/iframe-resizer@4.2.11/js/iframeResizer.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/lib/codemirror.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/mode/julia/julia.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/mode/loadmode.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/mode/meta.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/hint/show-hint.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/display/placeholder.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/edit/matchbrackets.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/runmode/runmode.min.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/comment/comment.min.js" defer></script>
    <!-- <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/edit/closebrackets.min.js" defer></script> -->
    <!-- <script src="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/search/searchcursor.min.js" defer></script> -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/lib/codemirror.min.css" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/codemirror@5.60.0/addon/hint/show-hint.min.css" />

    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/editor.css" type="text/css" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/hide-ui.css" type="text/css" media="all" data-pluto-file="hide-ui">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/binder.css" type="text/css" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/treeview.css" type="text/css" />
    <link rel="preload" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/juliamono.css" as="style">
    <link rel="preload" href="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/vollkorn.css" as="style">

    <!-- The instant feedback form at the bottom of the page uses Google Firestore to save feedback. -->
    <script src="https://cdn.jsdelivr.net/npm/firebase@7.13.1/firebase-app.js" defer></script>
    <script src="https://cdn.jsdelivr.net/npm/firebase@7.13.1/firebase-firestore.js" defer></script>

    <script data-pluto-file="launch-parameters">
window.pluto_notebookfile = undefined
window.pluto_disable_ui = true
window.pluto_slider_server_url = undefined
window.pluto_binder_url = undefined
window.pluto_statefile = "data:;base64,i6Vib25kc4CsY2VsbF9yZXN1bHRzgdkkNDk3NzI1ZTQtMDhjMS0xMWVjLTAyYTctY2YzZWE5MzViNWU3h6ZxdWV1ZWTCsXB1Ymxpc2hlZF9vYmplY3RzgKdydW5uaW5nwqZvdXRwdXSFpGJvZHmhMrBwZXJzaXN0X2pzX3N0YXRlwqRtaW1lqnRleHQvcGxhaW6ybGFzdF9ydW5fdGltZXN0YW1wy0HYSt379IcrrHJvb3Rhc3NpZ25lZcCnY2VsbF9pZNkkNDk3NzI1ZTQtMDhjMS0xMWVjLTAyYTctY2YzZWE5MzViNWU3p3J1bnRpbWXNA9KnZXJyb3JlZMKxY2VsbF9kZXBlbmRlbmNpZXOB2SQ0OTc3MjVlNC0wOGMxLTExZWMtMDJhNy1jZjNlYTkzNWI1ZTeEtHByZWNlZGVuY2VfaGV1cmlzdGljCKdjZWxsX2lk2SQ0OTc3MjVlNC0wOGMxLTExZWMtMDJhNy1jZjNlYTkzNWI1ZTe0ZG93bnN0cmVhbV9jZWxsc19tYXCAsnVwc3RyZWFtX2NlbGxzX21hcIGhK5C0Y2VsbF9leGVjdXRpb25fb3JkZXKR2SQ0OTc3MjVlNC0wOGMxLTExZWMtMDJhNy1jZjNlYTkzNWI1ZTepc2hvcnRwYXRosk5vdmVsIGJsdWVwcmludC5qbK5wcm9jZXNzX3N0YXR1c6VyZWFkeaRwYXRo2TUvaG9tZS9qYWtvYi8uanVsaWEvcGx1dG9fbm90ZWJvb2tzL05vdmVsIGJsdWVwcmludC5qbKpjZWxsX29yZGVykdkkNDk3NzI1ZTQtMDhjMS0xMWVjLTAyYTctY2YzZWE5MzViNWU3q2NlbGxfaW5wdXRzgdkkNDk3NzI1ZTQtMDhjMS0xMWVjLTAyYTctY2YzZWE5MzViNWU3g6djZWxsX2lk2SQ0OTc3MjVlNC0wOGMxLTExZWMtMDJhNy1jZjNlYTkzNWI1ZTekY29kZaMxKzGrY29kZV9mb2xkZWTCq25vdGVib29rX2lk2SQ0OTc3ZjNjYS0wOGMxLTExZWMtMWIzZi0zMWM0Y2UxNmY0NTCraW5fdGVtcF9kaXLD"
</script>
<!-- [automatically generated launch parameters can be inserted here] -->


    <script src="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/editor.js" type="module" defer></script>
    <script src="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/warn_old_browsers.js"></script>

    <script src="https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@0.14.5/frontend/common/SetupMathJax.js"></script>
    <script type="text/javascript" id="MathJax-script" src="https://cdn.jsdelivr.net/npm/mathjax@3.1.2/es5/tex-svg-full.js" async></script>

</head>

<body class="loading no-MαθJax"></body>

</html>