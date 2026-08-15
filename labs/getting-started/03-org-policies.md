# Org Policies & DHI MCP Server

Org-level AI Governance extends local sandbox policies across your entire Docker organisation. Admins define what agents are allowed to do — networks, filesystems, MCP servers — and those rules apply to every sandbox started under that org.

---

## Step 1 — Switch to org context

```bash
docker login --org $$org$$
```

> Once switched, all `sbx` and `docker scout` commands run under `$$org$$` policy.

---

## Step 2 — Compare local vs org policies

```bash
sbx policy diff --local --org $$org$$
```

| Dimension | Local | $$org$$ Org |
|-----------|-------|-------------|
| Network | hub.docker.com, api.anthropic.com | + `dhi.io/mcp` explicitly allowed |
| Filesystem | `/workspace` rw | + deny exec outside `/workspace` |
| MCP | *(none pre-registered)* | + DHI MCP server pre-registered |
| Image policy | *(none)* | + require base `$$org$$/dhi-*` |

---

## Step 3 — View full org policy set

```bash
sbx policy show --org $$org$$
```

The org policy is **more restrictive** than local. The DHI MCP server comes pre-registered — every agent in this org can query the DHI catalog without a manual setup step.

---

## Step 4 — Register the DHI MCP server

The DHI MCP server at `https://dhi.io/mcp` gives Claude real-time access to the Docker Hardened Images catalog — images, SBOMs, CVEs, attestations. No binary to install.

**Reference:** [docs.docker.com/dhi/tools/mcp](https://docs.docker.com/dhi/tools/mcp/)

```bash
claude mcp add dhi --url https://dhi.io/mcp
```

Verify it's connected:

```bash
sbx mcp list
```

> DHI MCP tools available to Claude:
>
> | Tool | What it does |
> |------|--------------|
> | `mcp__dhi__dhi_list_repositories` | Search and filter the DHI catalog |
> | `mcp__dhi__dhi_get_image_cves` | CVEs with severity, CVSS, EPSS, fix version |
> | `mcp__dhi__dhi_get_image_packages` | Full SBOM: packages, versions, purls, licenses |
> | `mcp__dhi__dhi_get_image_attestations` | SBOM, provenance, signature, FIPS, STIG, VEX |

---

## Step 5 — Claude resolves failure messages that scout reported during image analysis

Claude now has the DHI MCP. Ask it to fix the failing CI pipeline from Section 01.

```bash
claude -p "The Scout policy gate is failing because the Dockerfile uses node:22-alpine. Use the DHI catalog to find the right hardened Node.js 22 image and update the Dockerfile. The org is $$org$$."
```

> **Reading the Claude Code output:**
> - `● mcp__dhi__dhi_list_repositories(...)` — Claude calls the DHI MCP tool directly
> - `⎿  {...}` — the MCP server returns live catalog data (simulated)
> - `● Edit(Dockerfile)` — Claude writes the fix
> - The `1 -` / `1 +` diff shows the exact FROM line change
> - `✔ Done` confirms tool count, cost, duration

Claude found that the policies are failing because a DHI image is not used. It corrects that to resolve the scout policy failure messages

---

## Step 6 — Confirm the policy gate now passes

```bash
docker scout policy $$org$$/dhi-node:22 --org $$org$$ --exit-code
```

> **CI pipeline — all stages now pass:**
>
> 📦 Build → 🧪 Test → ✔ Scout Policy → 🚀 Push → 🌐 Deploy

---

## What just happened

Claude, running inside an isolated microVM under **$$org$$** org policy, used the DHI MCP server to:

1. Call `dhi_list_repositories` — searched the DHI catalog for a Node.js 22 image
2. Call `dhi_get_image_cves` — confirmed zero critical/high CVEs, policy passes
3. Edit `Dockerfile` — swapped `node:22-alpine` for `$$org$$/dhi-node:22`
4. All Supply Chain Security policies now pass

It did this entirely within the governance perimeter: network-restricted, filesystem-scoped, MCP-allowlisted, and fully audited.