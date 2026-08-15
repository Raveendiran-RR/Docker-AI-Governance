# Hardened by Default : Docker Hardened Images and AI Governance

🙏 Welcome to the demo/lab session :  **Hardened By Default** where we will learn how to get started with **Docker harnedened Images and AI Governance**

## Docker Hardened Images — why they matter
Docker Hardened Images are secure, minimal, production-ready images with near-zero CVEs and an enterprise-grade SLA for rapid remediation. They follow a distroless philosophy, removing unnecessary components to significantly reduce the attack surface:

- Near-zero exploitable CVEs — continuously updated and published with signed attestations to eliminate patch fatigue and false positives
- Seamless migration — drop-in replacements for popular base images, with -dev variants for multi-stage builds
- Up to 95% smaller attack surface — no shells, no package managers, no OS noise
- Built-in supply chain security — signed SBOMs, VEX documents, and SLSA provenance for audit-ready pipelines

## Docker AI Governance

AI agents such as Claude, Copilot, Cursor, custom MCP servers run with the same blast radius as the developer running them. That means access to your filesystem, your secrets, your network, your everything.

This is fine when the agent does what you expect. It's a disaster when:

- A prompt-injected agent uploads SSH keys to paste.ee
- A misconfigured MCP server exfiltrates source code to an unknown destination
- An agent acting on hallucinated instructions pushes a malicious commit to main
- A coding agent reads your .env and posts it to the model API alongside your code

Today's demo we would show how Docker AI Governance helps your mitigate this issue

let's begin !!

## Docker AI Governance Demo

> **First: set your Docker org name below. Every command in this demo updates automatically.**
::variableDefinition[org]{promt="what is your org"}
---

## What we'll cover

| # | Section | What you'll see |
|---|---------|-----------------|
| 01 | **DHI — Product Catalog** | Scout CVEs on community vs hardened Node.js. SBOM, FIPS/STIG, VEX. CI fails then passes. |
| 02 | **Sandbox & AI Governance** | Claude Code in an isolated microVM. Network, filesystem, MCP policies. Claude fixes the product item code bug. |
| 03 | **Org Policies & DHI MCP** | Org context, policy diff, DHI MCP server. Claude resolves the Scout failure automatically. |

---

## Step 1 — Authenticate

```bash
docker login --username $$org$$
```

---

## Step 2 — Configure Scout org

```bash
docker scout config organization $$org$$
```

---

## Step 3 — Review the Scout policy set

```bash
docker scout policy --org $$org$$
```

> **Policies enforced throughout this demo:**
> - No fixable critical CVEs
> - SBOM attestation must be present
> - SLSA provenance attestation must be present
> - Image must be signed (cosign)
> - Container must run as a non-root user