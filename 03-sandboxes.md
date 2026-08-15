# Section 4 — Sandboxes and AI Governance

## Archietecture
![SBX](./sbx-security.png)

## What is a Docker Sandbox?

> Isolated microVM environments that let AI coding agents build, run, and iterate — without touching the host system.

**In 20 words:** Docker Sandboxes give AI agents a fully isolated microVM with its own Docker daemon, filesystem, network, and org-level policy enforcement.

### Five reasons to run AI agents in a sandbox

1. **Filesystem isolation** — the agent cannot read `/etc/passwd`, your SSH keys, or any path outside its workspace, regardless of what it tries.
2. **Network governance** — outbound traffic is blocked by default; admins define an allowlist of domains the agent may reach per org.
3. **MCP control** — only MCP servers explicitly approved in your Docker Hub org are available inside the sandbox; rogue tool servers can't be injected.
4. **Credential proxy** — Docker Hub and GitHub tokens are injected transparently at the network layer; the agent never sees raw credentials.
5. **Audit log** — every tool call, file read, network attempt, and MCP invocation is logged to your org's audit stream in real time.

---

## Security architecture

Key layers of sandbox isolation (outer → inner):

```text no-run-button
Host machine
  └── sbx daemon (manages microVMs)
        └── microVM (Apple VZ / KVM)
              ├── Docker daemon (full, isolated)
              ├── Filesystem (isolated, org policy applied)
              ├── Network (default-deny, org allowlist)
              ├── MCP gateway (org-approved servers only)
              └── Credential proxy (token injection, no raw secrets)
```

---

## Step 1: Install and log in to the sandbox CLI

On macOS, first trust the Docker Homebrew tap, then install `sbx`:

```bash terminal-id=host
brew trust docker/tap
```

```bash terminal-id=host
brew install docker/tap/sbx
```

> **Linux (apt):**
> ```text no-run-button
> curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
> sudo apt-get install docker-sbx
> sudo usermod -aG kvm $USER && newgrp kvm
> ```
> **Windows (winget):**
> ```text no-run-button
> winget install -h Docker.sbx
> ```
> Full install docs: [docs.docker.com/ai/sandboxes](https://docs.docker.com/ai/sandboxes/)

Verify the install:

```bash terminal-id=host
sbx version
```

Log in to connect the CLI to your Docker Hub org — this is what binds org policies to every sandbox you start:

```bash terminal-id=host
sbx login
```

Explore available commands:

```bash terminal-id=host
sbx
```

---

## Step 2: Understand sandbox policies

Before starting a sandbox, review what policies your org enforces. Use the **Settings** toggle (gear icon next to Reset) to switch between **Org** and **Local** policy modes and see how the output changes.

```bash terminal-id=host
sbx policy ls
```

| Mode | Policy | Type | Effect |
|---|---|---|---|
| **Org** | `default-deny-network` | network | All outbound traffic blocked unless explicitly allowed |
| **Org** | `default-deny-filesystem` | filesystem | `/etc`, `/root`, `/proc` are read/write blocked |
| **Org** | `default-allow-mcp-approved` | MCP | Only org-approved MCP servers are available |
| **Org** | `org-audit-logging` | audit | Every agent action is logged to the org stream |
| **Local** | `default-allow-network` | network | All outbound traffic permitted |
| **Local** | `default-deny-filesystem` | filesystem | `/root` only (minimal) |
| **Local** | `default-allow-mcp-all` | MCP | All MCP servers permitted |

### Allow specific network domains

To let the agent reach GitHub (to clone repos and push fixes):

```bash terminal-id=host
sbx policy allow network github.com
```

To allow PyPI (if using Python packages):

```bash terminal-id=host
sbx policy allow network pypi.org
```

### Lock down a filesystem path

```bash terminal-id=host
sbx policy deny filesystem /etc
```

Any read or write attempt to `/etc` will be blocked and logged — even from inside a container that the agent starts.

---

## Step 3: The credential proxy

One of the most important sandbox features is the **credential proxy**. It means:

- The agent **never sees** your Docker Hub token or GitHub PAT in plaintext.
- Credentials are injected at the network level when the agent makes authenticated requests.
- If the sandbox is compromised, the attacker gets no usable credentials — only the proxy-signed request flows.

```text no-run-button
Agent                    Proxy                    Docker Hub
  │                        │                         │
  │── docker push ─────────▶│                         │
  │                        │── inject Bearer token ──▶│
  │                        │◀─ 200 OK ───────────────│
  │◀─ push complete ────────│                         │
```

Set a sandbox secret — this runs on the **host terminal**, not inside the sandbox:

```bash no-run-button
sbx secret set sbx-claude-abc1 github -t "$(gh auth token)"
```

After this, `git push` inside the sandbox works transparently — no token ever appears in the agent's environment variables or logs.

> The sandbox name (`sbx-claude-abc1`) is the value of `$SANDBOX_VM_ID` inside your sandbox — also available via `hostname`. Get it with `sbx ls`.

---

## Step 4: Connect with the org and start the sandbox

Your sandbox is automatically linked to your Docker Hub org when you're logged in. The output below reflects the **Settings** toggle — switch to Local mode to compare the enforcement differences.

```bash terminal-id=host
sbx start
```

The sandbox boots a microVM, initializes a full Docker daemon inside it, applies all org policies (or local-only if toggled), and attaches the credential proxy.

---

## Step 5: Start Claude Code

The **Sandbox** terminal tab on the right now represents the isolated microVM. Switch to it — all commands from this step run inside the sandbox.

```bash terminal-id=sandbox
claude
```

Claude Code is now running inside the isolated microVM. It can read and write files in the workspace, run Docker commands against the sandbox's private daemon, and make network calls — but only to domains your org has allowed, and every action is logged.

---

## Step 6: Find the bug in the product catalog

Ask Claude to investigate the pricing issue we spotted in Section 3. It searches the codebase:

```bash terminal-id=sandbox
grep -rn final_price product-catalog/src/
```

Found it: `product-catalog/src/routes/products.js:29`

Open the file:

```bash terminal-id=sandbox
cat product-catalog/src/routes/products.js
```

The bug is on line 29:

```javascript no-run-button
// BUG: multiplies price BY the discount rate
// $99.99 × 0.20 = $20.00  ← wrong
product.final_price = product.price * product.discount_rate;

// FIX: price × (1 - discount_rate) gives the discounted price
// $99.99 × (1 - 0.20) = $79.99  ← correct
product.final_price = product.price * (1 - product.discount_rate);
```

Claude edits the file to apply the fix. Review the diff:

```bash terminal-id=sandbox
git diff
```

The single-character fix (`* discount_rate` → `* (1 - discount_rate)`) is confirmed. All reads, the file edit, and the diff command are captured in the org's audit log.

---

## Step 7: Fix the CVEs — switch to the DHI image

While Claude has the repo open, it also updates the `Dockerfile` to use the DHI hardened image:

```diff no-run-button
- FROM node:18-alpine
+ FROM dhi.io/node:24-alpine
```

Build the patched image inside the sandbox's Docker daemon:

```bash terminal-id=sandbox
docker build -t product-catalog:dhi -f product-catalog/Dockerfile.dhi ./product-catalog
```

The DHI base image is pulled from `dhi.io/node:24-alpine` — FIPS-validated, STIG-hardened, 0 fixable CVEs.

---

## Step 8: Verify — run the Scout policy gate

Run the same policy check the CI pipeline will run:

```bash terminal-id=sandbox
docker scout policy product-catalog:dhi
```

**Result: 5 / 5 policies satisfied** ✓

Every policy that previously failed now passes:

| Policy | Before | After |
|---|---|---|
| No critical/high CVEs | ✗ 14 found | ✓ 0 found |
| Supply chain attestations | ✗ missing | ✓ present |
| No fixable vulnerabilities | ✗ 35 fixable | ✓ 0 fixable |
| Approved base images | ✗ node:18-alpine | ✓ dhi.io/node:24-alpine |
| Default non-root user | ✗ missing | ✓ USER node |

---

## Step 9: Commit, push, watch CI go green

```bash terminal-id=sandbox
git add product-catalog/
```

```bash terminal-id=sandbox
git commit -m "Fix discount calculation and upgrade to dhi.io/node:24-alpine"
```

```bash terminal-id=sandbox
git push
```

The push triggers the CI pipeline. Switch to the **CI Pipeline** tab to watch it go green — all four steps pass this time:

1. **Build image** → succeeds
2. **Docker Scout — CVE scan** → 0 critical, 0 high → **PASS**
3. **Docker Scout — policy gate** → 5/5 policies → **PASS**
4. **Push to registry** → image pushed ✓

> Compare this with the failure run from Section 3. The **Re-run** button on that earlier run will now also go green, since `image_patched` is true and the `requires` gate passes.

---

## Step 10: Review the audit log

Everything Claude Code did inside the sandbox is captured. Switch back to the **Host** terminal:

```bash terminal-id=host
sbx audit
```

The audit log shows every tool call (Read, Edit, Bash), every network connection, and every blocked attempt — streamed in real time to your Docker Hub org's audit dashboard.

> Audit logs are available at:  
> **Hub → Org → Docker Scout → Sandbox Audit**

---

## Summary

| What we demonstrated | How |
|---|---|
| FIPS + STIG hardened images | `dhi.io/node:24-alpine` via Docker Hub Integration |
| CVE scanning | `docker scout cves` with policy gate |
| SBOM, VEX, attestations | `docker scout sbom` + `docker scout attestation list` |
| CI pipeline enforcement | `docker/scout-action` with `exit-code: true` — CI tab shows fail → fix → pass |
| AI agent isolation | `sbx start` — microVM, network/filesystem policies |
| Org vs local policies | Settings toggle — switch modes to compare enforcement |
| Credential governance | Credential proxy — no raw tokens in agent scope |
| Full auditability | `sbx audit` — every action logged to org stream |
| Bug found + fixed | Claude Code inside sandbox — one-line fix, confirmed by diff |
| CVEs remediated | Base image swap: 14 critical/high → 0, CI green |

Docker Hub Integration, Docker Scout, and Docker Sandboxes form a **continuous governance loop** — from the base image you pull, through the CI policy gate, to every action an AI agent takes in your codebase.

> [Continue to Section 5 → SBX Kits](#/5-sbx-kits) to learn how to package and distribute governed sandbox environments across your team.
