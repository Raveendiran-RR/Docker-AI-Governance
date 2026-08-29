# Section 3 — DHI: Product Catalog

### Architecture

![Architecture ](./product_catalog.png)
![dev- working](./dev-environment-architecture.png)

## Step 1: Clone the product catalog

We'll use [`dockersamples/catalog-service-node`](https://github.com/dockersamples/catalog-service-node) — a real Docker sample app (Node.js + PostgreSQL + Kafka + S3) used across several Docker demos.

```bash
git clone https://github.com/dockersamples/catalog-service-node
```

Browse the project structure:

```bash
ls catalog-service-node/
```

Open the Dockerfile to see the base image choice:

```bash
cat catalog-service-node/Dockerfile
```

Notice the base image is `node:22-slim` — the community image from Docker Hub. It's already a well-built multi-stage Dockerfile (non-root user, minimal final stage) — but the base image itself still carries CVEs, as we'll see in a moment.

---

## Step 2: Explore the application source

The API lives under `src/`:

```bash
ls catalog-service-node/src/
```

```bash
ls catalog-service-node/src/services/
```

`ProductService.js` is where product data is read from Postgres and merged with live inventory:

```bash
cat catalog-service-node/src/services/ProductService.js
```

Notice `getProductById` computes a `final_price` from `price` and `discount_rate` — keep this in mind, we'll come back to it once the app is running.

---

## Step 3: Build the image

```bash
docker build -t catalog-service-node:latest ./catalog-service-node
```

Build succeeds. At the end of the output, Docker Build suggests running `docker scout quickview` — that's your first hint that something may need attention.

---

## Step 4: Start the dependencies and run the app

This repo's `compose.yaml` doesn't run the API itself — it brings up everything the API depends on (Postgres, Kafka, LocalStack S3, a mocked inventory service, plus pgAdmin and Kafka UI for visualizing them):

```bash
cat catalog-service-node/compose.yaml
```

```bash
docker compose up
```

7 services come up. Note what's *not* in that list: the API itself. The image you built in Step 3 isn't run here either — it's set aside for the Docker Scout scanning steps later (5–9). To actually serve the API and reproduce the bug, follow the repo's own README and run it natively:

```bash
npm install
```

```bash
npm run dev
```

The API is now listening on `:3000`. Let's query it:

```bash
curl http://localhost:3000/api/products
```

The list looks fine — 12 products with prices and discount rates. Now inspect a single product:

```bash
curl http://localhost:3000/api/products/1
```

> **Notice something?** Widget Pro costs `$99.99` with a `20%` discount.  
> The correct final price is `$79.99` — but the API returns `$20.00`.  
> The `final_price` field is wrong: `price × discount_rate` instead of `price × (1 − discount_rate)` — exactly the line we saw in `ProductService.js` in Step 2.

We'll fix this bug in Section 4 using Claude Code inside a Docker Sandbox.

---

## Step 5: Scan for CVEs with Docker Scout

Get a quick overview of the image's vulnerability posture:

```bash
docker scout quickview catalog-service-node:latest
```

Then run the full CVE report:

```bash
docker scout cves catalog-service-node:latest
```

The output shows **3 CRITICAL** and **11 HIGH** vulnerabilities in the `node:22-slim` base image:

| Package | CVE | Severity | CVSS |
|---|---|---|---|
| openssl | CVE-2024-0727 | CRITICAL | 9.1 |
| libssl3 | CVE-2023-5363 | CRITICAL | 9.1 |
| glibc | CVE-2023-4911 | CRITICAL | 9.8 |
| curl | CVE-2023-38545 | HIGH | 8.1 |
| nghttp2 | CVE-2023-44487 | HIGH | 7.5 |
| node | CVE-2024-22019 | HIGH | 7.5 |

All three critical CVEs have fixes available — they'd be eliminated by upgrading to a current base image.

---

## Step 6: Check policy compliance

Run Docker Scout's policy evaluation against your organization's rules:

```bash
docker scout policy catalog-service-node:latest
```

**Result: 1 / 5 policies satisfied.** Only one passes — this Dockerfile already runs as a non-root user (`USER appuser`), so that policy is already fine. Everything tied to the base image itself still fails:

| Policy | Reason |
|---|---|
| No critical/high CVEs | 3 critical, 11 high found |
| Supply chain attestations | No SBOM or provenance attached |
| No fixable vulnerabilities | 35 fixable CVEs |
| Approved base images | `node:22-slim` not in org allowlist |
| Default non-root user | ✓ already satisfied — `USER appuser` |

---

## Step 7: See how the CI pipeline blocks this image

The product catalog CI uses the `docker/scout-action` to gate on policy. Look at the workflow file:

:filelink[.github/workflows/ci.yml]{path="catalog-service-node/.github/workflows/ci.yml"}

Push to trigger the CI pipeline and watch it fail in the **CI Pipeline** tab:

```bash terminal-id=host
git push
```

The pipeline fails at **"Docker Scout — CVE scan"** — 3 critical, 11 high CVEs cause an exit code 1, and the **policy gate** and **push** steps are skipped entirely. The image never reaches the registry.

> **This is the enforcement point.** No matter how fast a team moves, the image cannot ship until it satisfies all org policies.
> 
> Switch to the **CI Pipeline** tab on the right to see the full step-by-step run. The **Re-run** button re-evaluates from the current state — it will go green once the image is patched in Section 4.

---

## Step 8: Scan the DHI Node image

DHI images are hosted on their own registry, so authenticate to it first:

```bash
docker login dhi.io
```

Now compare with the DHI-provided equivalent — a Debian-based tag, matching this repo's `node:22-slim`:

```bash
docker scout cves dhi.io/node:24-debian13
```

**Result: 0 CRITICAL, 0 HIGH, 0 fixable CVEs.**

The two MEDIUM findings are suppressed by VEX statements from the Docker security team — they reviewed those CVEs and confirmed they're not reachable in this build context. The image is also annotated with:

- ✓ **FIPS 140-2** validated cryptographic modules
- ✓ **STIG-hardened** (DISA STIG Node.js v2R2 — 47/47 controls pass)
- ✓ **SBOM** and **SLSA provenance** attestations pre-attached

---

## Step 9: Inspect the SBOM and attestations

Fetch the full Software Bill of Materials:

```bash
docker scout sbom catalog-service-node:latest
```

The SBOM is in CycloneDX 1.4 format — 77 components listed with their package URLs (`purl`). This can be ingested by any SCA tool, fed to a VEX workflow, or stored in an artifact store for compliance.

View the attestations for the DHI image:

```bash
docker scout attestation list dhi.io/node:24-debian13
```

Three attestation types are present:

| Attestation | What it proves |
|---|---|
| **SBOM (CycloneDX)** | Every package in the image, machine-readable |
| **SLSA Provenance v0.2** | Built from a specific commit, by a specific GitHub Actions workflow, reproducibly |
| **VEX** | Which CVEs are present but not exploitable in this context |

The FIPS and STIG compliance metadata are embedded in the image annotations and verified at pull time by Docker Scout.

> **FIPS**: Federal Information Processing Standard — required for US government and defense workloads.  
> **STIG**: Security Technical Implementation Guide — DISA hardening baseline for DoD environments.

---

> [Continue to Section 4 → Sandboxes and AI Governance](#/4-sandboxes-and-ai-governance) to fix the pricing bug with Claude Code in a governed sandbox.
