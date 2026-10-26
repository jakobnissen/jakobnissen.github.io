// Highlight code snippets with Shiki. Called by highlight.jl.
// Input on stdin:  lang1 \0 code1 \0 lang2 \0 code2 ...
// Output on stdout: html1 \0 html2 ...
// Each html is the highlighted code, one line per "\n", without any <pre> wrapper.
// Tokens carry the light colour as `color` and the dark colour as `--shiki-dark`,
// so the CSS can pick either (e.g. dark for .shellcode boxes).
import { createHighlighter, bundledLanguages } from "shiki";

const THEMES = { light: "one-light", dark: "one-dark-pro" };

const escape = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const styleString = (style) =>
  Object.entries(style ?? {})
    .map(([k, v]) => `${k}:${v}`)
    .join(";");

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const fields = Buffer.concat(chunks).toString("utf8").split("\0");

const items = [];
for (let i = 0; i + 1 < fields.length; i += 2) {
  items.push({ lang: fields[i], code: fields[i + 1] });
}

const langs = [...new Set(items.map((x) => x.lang))].filter((l) => l in bundledLanguages);
const highlighter = await createHighlighter({ themes: Object.values(THEMES), langs });

const output = items.map(({ lang, code }) => {
  if (!langs.includes(lang)) {
    return escape(code);
  }
  const { tokens } = highlighter.codeToTokens(code, { lang, themes: THEMES });
  return tokens
    .map((line) =>
      line
        .map((tok) => `<span style="${styleString(tok.htmlStyle)}">${escape(tok.content)}</span>`)
        .join("")
    )
    .join("\n");
});

process.stdout.write(output.join("\0"));
