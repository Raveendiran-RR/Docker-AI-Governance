# My Simspace labs

Interactive, fully in-browser labs built on
[Simspace](https://github.com/dockersamples/simspace). Everything in the terminal
is simulated — no real Docker, backend, or network — so it runs the same for
everyone, with nothing to install.

You edit content under [`labs/`](labs/) — each entry in its own `labs/<id>/`
directory. The app that runs them is a prebuilt image, and content is loaded at
runtime, so there's no build step. With one entry the app opens it directly; with
several it shows a landing page to choose from.

An entry is either a **lab** (instructions plus a simulated terminal) or a **slide
deck** (`kind: slides` — presentation slides that can embed a live demo terminal).
A workshop is usually both: slides to introduce it, a lab to work through, two
cards on the landing page, one deploy.

## Author locally

You only need Docker.

```bash
docker compose up dev              # live preview at http://localhost:5173
docker compose run --rm validate   # validate every lab (fails on errors)
```

Edit the files under `labs/<id>/` and refresh the browser to see changes:

- `labspace.yaml` — title, catalog card, terminals, seed files, sections, variables
  (plus `kind: slides`, `theme:`, and `brand:` for a deck)
- `simulator.yaml` — what each command does (scenarios). Optional for a deck; point
  it at a sibling lab's spec to reuse it.
- `*.md` — one file per section of instructions, or per chapter of slides

The `labs.json` catalog is **generated** from each entry's `labspace.yaml` (by the
preview server and by `validate`), so you never write or edit it. Add a lab or a
deck by adding a `labs/<new-id>/` directory and running `validate`.

Working with Claude Code? See [Authoring with an AI agent](#authoring-with-an-ai-agent)
below — one command gets you an agent that already knows the format.

Pin the toolchain to a released version for reproducibility:

```bash
export SIMSPACE_AUTHORING_IMAGE=dockersamples/simspace-authoring:1
```

## Deploy

**GitHub Pages (default):** enable Pages (Settings → Pages → Source: "GitHub
Actions"), then push to `main`. The workflow in
[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) validates the labs,
generates the catalog, and publishes. Pin `runtime-tag` there to a released
version for a stable site. Pull requests are validated first by
[`.github/workflows/validate.yml`](.github/workflows/validate.yml).

**As a container:** the [`Dockerfile`](Dockerfile) bases on the runtime image,
generates the catalog, and swaps in your labs.

```bash
docker build -t my-lab .
docker run --rm -p 8080:80 my-lab    # http://localhost:8080
```

## Authoring with an AI agent

[`.sbxenv.yaml`](.sbxenv.yaml) describes a [Docker
Sandbox](https://docs.docker.com/ai/sandboxes/) for authoring this repo. One
command:

```bash
sbx env run
```

You get Claude Code with the **authoring-lab**, **authoring-slidedeck** and
**importing-slidedeck** skills already installed, Docker inside the sandbox so
`docker compose up dev` works, and ports 5173 and 8888 published to your own
browser. Needs `sbx` 0.39.0 or later.

The skills come from the
[`simspace-authoring-kit`](https://hub.docker.com/r/dockersamples/simspace-authoring-kit) sandbox
kit, which is resolved fresh on every `sbx env run` — so this repo authors
against the *current* Simspace format however long ago you generated it. That's
the reason they aren't committed here: vendored skills froze at generation time
and never learned about features added since. Pin to a released version in
`.sbxenv.yaml` if a workshop needs a fixed target.

Either way, `docker compose` and `validate-lab` are pre-allowed (`.claude/`), a
hook auto-validates the labs after every edit under `labs/`, and
[`CLAUDE.md`](CLAUDE.md) loads [`AGENTS.md`](AGENTS.md) automatically.

## Learn more

[`AGENTS.md`](AGENTS.md) orients you in this repo. For the format itself, the
[Simspace specs](https://github.com/dockersamples/simspace/tree/main/spec) are
authoritative: `simulator.yaml`, `labspace.yaml`, the catalog, and slide decks.
