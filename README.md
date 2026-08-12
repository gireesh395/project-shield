# 🛡️ Project Shield: Enterprise DevSecOps Defense Grid

Most cloud breaches don't happen because of hyper-complex zero-day exploits. They happen when a developer accidentally hardcodes an AWS secret or deploys a container with an outdated, vulnerable base image.

**Project Shield** turns GitHub Actions into an automated, multi-stage gatekeeper. Every commit must survive four sequential security rings before a single line of code reaches production.

---

```
[ Git Push / Pull Request ]
            │
            ▼
┌────────────────────────────────────────────────────────┐
│ Ring 1: Secrets & SAST   (Gitleaks + Semgrep)          │
├────────────────────────────────────────────────────────┤
│ Ring 2: Container Audit  (Aqua Trivy)                  │
├────────────────────────────────────────────────────────┤
│ Ring 3: IaC Compliance   (Checkov)                     │
└────────────────────────────────────────────────────────┘
            │
     🟢 ALL RINGS PASS
            │
            ▼
┌────────────────────────────────────────────────────────┐
│ Ring 4: Cloud Deployment (Docker Hub ➔ AWS EKS Paris)  │
└────────────────────────────────────────────────────────┘
```

---

## ⚡ The Four Defense Rings

### 🔹 Ring 1: Secret Leaks & Code Flaws (Gitleaks + Semgrep)
* **Gitleaks:** Scans the *entire* Git commit history (`fetch-depth: 0`). Deleting a leaked API key in a recent commit won't save you—Gitleaks digs into past commits and blocks the pipeline if a secret was ever exposed.
* **Semgrep:** Analyzes raw Python application code (`app/server.py`) against OWASP Top 10 security standards, catching SQL injections, unencrypted handlers, and broken access controls before image compilation.

### 🔹 Ring 2: Container Supply Chain (Aqua Trivy)
* **Layer Inspection:** Builds a temporary local image and audits base OS packages and Python dependencies (`requirements.txt`) against live global CVE registries.
* **Targeted Scanning:** Filters specifically for `HIGH` and `CRITICAL` vulnerabilities to eliminate minor alert noise and focus on real threats.

### 🔹 Ring 3: Infrastructure Policy (Checkov)
* **Manifest Auditing:** Static inspection across Kubernetes manifests (`k8s-deployment.yaml`), Terraform files (`main.tf`), and Dockerfiles.
* **Misconfiguration Guard:** Blocks risky operational defaults—like running containers with `root` privileges, missing resource limits, or overly permissive security group rules.

### 🔹 Ring 4: Automated Deployment (Docker Hub + AWS EKS)
* **Strict Gatekeeping:** Runs **only** if Rings 1, 2, and 3 pass 100% green on target deployment branches (`master`/`main`).
* **Artifact Push:** Authenticates to Docker Hub via GitHub Secrets and pushes `shield-app:latest`.
* **EKS Handshake:** Authenticates to AWS IAM, fetches the API endpoint and TLS certificates for the Paris cluster (`eu-west-3`) via `aws eks update-kubeconfig`, and applies a zero-downtime rolling deployment.

---

## 🎯 Engine Controls

* **`fetch-depth: 0` (Gitleaks):** Prevents shallow clones so past Git commits can't hide leaked keys.
* **`severity: 'CRITICAL,HIGH'` (Trivy):** Stops builds instantly if severe, unpatched CVEs exist in container packages.
* **`soft_fail: true` (Checkov):** Logs infrastructure drift and compliance warnings while establishing policy baselines.
* **`needs: [ring1, ring2, ring3]` (GitHub Actions):** Enforces hard dependency—Ring 4 physical deployment is impossible if any scanning ring fails.
