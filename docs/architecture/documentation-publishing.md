# Documentation publishing direction

## Recommendation

Use Quartz when the documentation site is ready to be made real. It keeps the
source as Markdown, supports ordinary relative links, and provides full-text
search, wikilinks, backlinks, graph view, Mermaid diagrams, explorer navigation,
breadcrumbs, and table of contents as built-in features. It also deploys to
GitHub Pages. The tradeoff is a Node-based site toolchain and a convention of
putting published Markdown under `content/`.

MkDocs Material is the strongest conventional documentation alternative. It is
simple, Python-based, has excellent navigation and built-in browser search, and
renders Mermaid through its Markdown extensions. It is better for a manually
curated reference manual, but backlinks and graph navigation need additional
plugins or generated pages.

Docusaurus is a good choice if the project later needs a React/MDX application,
versioned releases, localization, or interactive React components. It preserves
Markdown/MDX and provides table-of-contents and heading links, but it is a
heavier JavaScript application and does not provide a native backlink graph.

Hugo is an excellent fast, Go-based static generator with taxonomies, related
content, cross references, and diagram support. It is a strong publishing
engine, but backlinks and graph views are template work rather than a default
documentation experience.

Jekyll is the lowest-friction GitHub Pages option, but its GitHub-hosted build
environment and plugin constraints make it the least attractive for the
backlink/graph requirements.

The current `docs/index.html` is deliberately framework-neutral. When we choose
Quartz, the existing Markdown can be moved or mirrored into `docs/content/`
without converting the substantive pages to another format. JSON payloads and
schemas should remain outside the published content tree unless a generated
catalog page is explicitly desired.

References: [Quartz features](https://quartz.jzhao.xyz/features), [Material for
MkDocs search](https://squidfunk.github.io/mkdocs-material/plugins/search/),
[Docusaurus Markdown](https://docusaurus.io/docs/markdown-features), and
[Hugo taxonomies and diagrams](https://gohugo.io/content-management/taxonomies/).
