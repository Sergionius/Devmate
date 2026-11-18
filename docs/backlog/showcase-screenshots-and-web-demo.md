---
worth: yes
priority: p1
where: README.md:1
added: 2026-11-18
---
# showcase screenshots and a deployed web demo

Before opening the repository publicly: add README screenshots of the core
flows (home, topic, practice flow, AI chat) and deploy the web build to
GitHub Pages so a reviewer can try the app without cloning it. Both agents
in the 2026-11-18 architecture review (Pi + Claude) ranked this as the single
highest-impact change for a resume showcase.

Preconditions agreed with the owner on 2026-11-18 — verify before doing:
- Pages can actually be enabled for this repo (Settings → Pages → Source:
  "GitHub Actions"; `gh` is authenticated as the owner, so it may also be
  enabled via API — confirm the owner is OK with that first).
- Decide the screenshot method (headless-Chrome captures of the local web
  build vs owner-provided captures) and the theme (default is dark).
- Proposed shape: `deploy-pages.yml` building `flutter build web
  --base-href /Devmate/` on push to main; PNGs in `docs/screenshots/`;
  skip GIFs on the first pass.
