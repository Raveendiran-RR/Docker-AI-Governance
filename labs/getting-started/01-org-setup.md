# Section 2 — Org Setup & Scout Policies

## Your Docker Hub organization

Enter your Docker Hub organization name below. Every command in this section — and throughout the DHI and Sandboxes sections — will be pre-filled with it.

::variableDefinition[org]{prompt="Docker Hub organization name (e.g. mycompany)"}

---

## Step 1: Log in to Docker Hub

Docker Scout policy enforcement is tied to your Docker organization. Log in first:

```bash
docker login
```

You should see `Login Succeeded`. Your credentials are stored in `~/.docker/config.json`.

> **In production**, use a credential helper (e.g. `docker-credential-osxkeychain`) so the token is stored in the OS keychain, not plain-text on disk.  
> Docs: [docs.docker.com/reference/cli/docker/login](https://docs.docker.com/reference/cli/docker/login/)

---

## Step 2: Enroll the organization with Docker Scout

One-time setup — enroll `$$org$$` to activate Scout analysis and policy enforcement for all repositories in the org:

```bash
docker scout enroll $$org$$
```

This enables the vulnerability database sync, SBOM indexing, and the policy engine for every image pushed under `$$org$$`.

> Docs: [docs.docker.com/scout](https://docs.docker.com/scout/)

---

## Step 3: Point Docker Scout at your organization

Docker Scout reads policies from your Docker Hub organization. Set the org context:

```bash
docker scout config organization $$org$$
```

This tells every subsequent `docker scout` command to evaluate images against the policies defined for `$$org$$` — critical/high CVE thresholds, approved base image lists, attestation requirements, and more.

---

## Step 4: Review active policies

List the policies that will govern every image your CI pipeline builds:

```bash
docker scout policy ls
```

You'll see five policies:

| Policy | What it enforces |
|---|---|
| **No critical or high-profile CVEs** | Fails if any CRITICAL or HIGH severity CVE is present |
| **Supply chain attestations** | Requires SBOM + SLSA provenance attached to the image |
| **No fixable vulnerabilities** | Fails if a CVE has a known fix available |
| **Approved base images** | Only `dhi.io/*` images are allowed as base images |
| **Default non-root user** | Dockerfile must include a `USER` directive |

> Manage policies at: **Hub → `$$org$$` → Docker Scout → Policies**  
> Docs: [docs.docker.com/scout/policy](https://docs.docker.com/scout/policy/)

---

## What these policies block

The **Approved base images** policy is the critical one for this lab. It means:

```dockerfile no-run-button
# This will FAIL the policy gate:
FROM node:18-alpine

# This will PASS:
FROM $org$/node:24-alpine
```

DHI (Docker Hub Integration) images at `dhi.io/` are:
- Built and maintained by the Docker security team
- Scanned and remediated on a continuous basis
- FIPS 140-2 validated (cryptographic modules)
- STIG-hardened (DISA STIG / CIS Benchmark)
- Pinned to minimal attack surface (no shell utilities unless needed)

---

> [Continue to Section 3 → DHI Product Catalog](#/3-dhi-product-catalog) to see what happens when a real app image fails these policies.
