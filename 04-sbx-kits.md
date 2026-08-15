# Section 5 — SBX Kits

## What is an SBX Kit?

An **SBX Kit** is a pre-packaged sandbox blueprint that pins four things in one artifact:

| Layer | What it fixes |
|---|---|
| **Base image** | FIPS-validated, STIG-hardened DHI image — 0 critical CVEs at kit creation time |
| **Tool set** | Pre-installed CLIs, runtimes, MCP servers — no ad-hoc `apt install` during sessions |
| **Policy profile** | Network allowlist, filesystem rules, MCP gateway config — identical enforcement for everyone |
| **Workspace seed** | Starter files, `.env` scaffold, `CLAUDE.md` agent instructions |

A kit is published once by an admin and consumed by the team. Every developer who runs `sbx kit start ai-coding-standard` gets an identical, policy-correct environment — no drift, no manual setup.

```text no-run-button
Admin publishes kit
        │
        ▼
   Docker Hub Org
   (kit registry)
        │
   ┌────┴────────────────────┐
   ▼                         ▼
Developer A              Developer B
sbx kit start            sbx kit start
ai-coding-standard       ai-coding-standard
        │                         │
   identical sandbox         identical sandbox
   identical policy           identical policy
   identical tools            identical tools
```

---

## Why Kits Matter for AI Governance

Without kits, sandbox drift is inevitable:

- Developer A has `github.com` allowed; Developer B forgot and added `*` (all domains)
- MCP server allowlists vary per machine
- Tool versions differ, causing reproducibility failures
- No standard audit baseline across the team

With kits:

- **One kit tag = one policy config** — network rules, MCP allowlists, and filesystem restrictions are locked in the kit's `sbx-kit.yaml`
- **Kit updates propagate** — pull a new version tag to enforce updated policies org-wide
- **Admins can lock kits** — `kit.policy.locked: true` in the kit manifest prevents any per-session overrides

---

## Step 1: List available kits

```bash terminal-id=host
sbx kit ls
```

Docker provides built-in kits. Your org can also publish its own.

| Kit | Base | Key tools | Policy profile |
|---|---|---|---|
| `ai-coding-standard` | `dhi.io/ubuntu:22.04-hardened` | claude-code, git, docker-scout, gh | org-default |
| `node-24-fips` | `dhi.io/node:24-alpine` | node 24, npm, docker | fips-strict |
| `python-3.12-hardened` | `dhi.io/python:3.12-slim` | python 3.12, pip, uv | org-default |
| `java-21-graalvm` | `dhi.io/eclipse-temurin:21` | java 21, maven, gradle | org-default |

---

## Step 2: Inspect a kit before pulling

Before downloading, inspect a kit to see exactly what's inside:

```bash terminal-id=host
sbx kit inspect ai-coding-standard
```

The inspect output shows:

- **Base image** with CVE posture (0 critical for any DHI-based kit)
- **Pre-installed tools** and their versions — reproducible across every session
- **Policy profile** — the exact network/filesystem/MCP rules that will be enforced
- **Workspace seed** — files pre-seeded into `/home/agent/workspace`

> The policy profile is what governs Claude Code's actions. Admins can customize this — for example, adding `pypi.org` to the network allowlist for Python-focused kits, or restricting the MCP gateway to a subset of approved servers.

---

## Step 3: Pull the kit

```bash terminal-id=host
sbx kit pull ai-coding-standard
```

The kit image is pulled from Docker Hub, verified against its SBOM and SLSA provenance attestation, and cached locally. The base image (`dhi.io/ubuntu:22.04-hardened`) is validated for FIPS compliance at pull time.

> Kits are signed with the publisher's cosign key. `sbx kit pull` verifies the signature before caching — a tampered kit is rejected before it ever starts.

---

## Step 4: Start a sandbox from the kit

```bash terminal-id=host
sbx kit start ai-coding-standard
```

Compare this to a plain `sbx start`:

| `sbx start` | `sbx kit start ai-coding-standard` |
|---|---|
| Bare microVM | Bare microVM **+ pre-installed tools** |
| You configure policies | **Kit's policy profile auto-applied** |
| Empty workspace | **Workspace seed pre-loaded** |
| You install claude, git, docker | **Already present and versioned** |

The sandbox is ready for `claude` immediately — no setup steps, no tool installation, no policy configuration.

---

## Step 5: Create a kit from your current sandbox

After customizing a sandbox (installing tools, tuning policies, seeding workspace files), you can snapshot it as a kit:

```bash terminal-id=host
sbx kit create ai-coding-standard
```

The kit capture process:

1. Snapshots the current tool set and versions
2. Captures the active policy profile (network rules, filesystem rules, MCP allowlist)
3. Packages the workspace template (stripping secrets and ephemeral state)
4. Attaches an SBOM + provenance attestation

> **Workspace seeding tip**: Put reusable files in `/home/agent/workspace/` before creating the kit. A `CLAUDE.md` with project-specific instructions is especially useful — Claude Code reads it automatically at startup.

---

## Step 6: Push the kit to your org

Share the kit with your team:

```bash terminal-id=host
sbx kit push $$org$$/ai-coding-standard:v1
```

Once pushed:

- All members of `$$org$$` can `sbx kit pull $$org$$/ai-coding-standard:v1`
- The kit appears in `sbx kit ls` under the org section
- Audit trail: kit creation, push, and every `sbx kit start` are logged to the org audit stream

> **Versioning**: tag kits semantically (`v1`, `v1.1`, `v2`). When you update a policy (e.g. to add a new MCP server to the allowlist), push a new tag. The old tag remains available for rollback.

---

## Kit governance in the org

```text no-run-button
                    Docker Hub Org
                    ┌────────────────────────────────────┐
                    │  Kit Registry                      │
                    │                                    │
                    │  $$org$$/ai-coding-standard:v1  ←──────── admin pushes
                    │  $$org$$/ai-coding-standard:v2  ←──────── policy update
                    │  $$org$$/node-24-fips:v1        ←──────── custom tooling
                    │                                    │
                    └────────┬───────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         Dev sandbox    Dev sandbox    CI sandbox
         (kit pull)     (kit pull)     (kit pull)
         identical      identical      identical
         policy         policy         policy
```

Admins manage kits at:  
**Hub → `$$org$$` → Docker Scout → Sandboxes → Kits**

---

## Summary

| Capability | Command |
|---|---|
| List available kits | `sbx kit ls` |
| Inspect a kit | `sbx kit inspect <name>` |
| Pull a kit | `sbx kit pull <name>` |
| Start a sandbox from a kit | `sbx kit start <name>` |
| Create a kit from current sandbox | `sbx kit create <name>` |
| Push a kit to your org | `sbx kit push $org$/<name>:v1` |

---

> **At any point, type `demo reset` in either terminal to restore the lab to its initial state — all section progress is cleared and you can start fresh from Section 2.**
