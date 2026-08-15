# Project Shield: Enterprise DevSecOps CI/CD Pipeline

![Build Status](https://img.shields.io/github/actions/workflow/status/gireesh395/project-shield/secret-guard.yml?branch=master&style=for-the-badge&logo=githubactions)
![Security Scanners](https://img.shields.io/badge/Security-Gitleaks%20%7C%20Semgrep%20%7C%20Trivy%20%7C%20Checkov-blue?style=for-the-badge&logo=shield)
![Infrastructure](https://img.shields.io/badge/AWS-EKS%20%7C%20Terraform-orange?style=for-the-badge&logo=amazon-aws)
![Container](https://img.shields.io/badge/Docker-Hub-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

> *"Shift-Left Security: Enforcing multi-ring static code analysis, secret leak protection, container vulnerability auditing, and infrastructure policy compliance before artifacts touch production."*

---

## Table of Contents
- [Architectural Overview](#architectural-overview)
- [Detailed Feature / Security Breakdown](#detailed-feature--security-breakdown)
- [OWASP / Compliance Matrix](#owasp--compliance-matrix)
- [Proof of Work / Negative Testing Table](#proof-of-work--negative-testing-table)
- [Repository Structure](#repository-structure)
- [Deployment & Setup Guide](#deployment--setup-guide)
- [FinOps / Teardown](#finops--teardown)

---

## Architectural Overview

```text
  +-----------------------------------------------------------------------------------+
  |                                 DEVELOPER WORKFLOW                                |
  |   git push origin feature/**  ==>  Pull Request  ==>  git merge origin/master    |
  +-----------------------------------------+-----------------------------------------+
                                            |
                                            v
  +-----------------------------------------------------------------------------------+
  |                       PROJECT SHIELD CI/CD PIPELINE (GitHub Actions)               |
  |                                                                                   |
  |  +-----------------------------------------------------------------------------+  |
  |  | RING 1: Secret & Code Audit (Gitleaks + Semgrep)                           |  |
  |  | - SCM Deep Graph Scan (fetch-depth: 0)                                       |  |
  |  | - High-Entropy Secret Detection & OWASP Top 10 SAST                         |  |
  |  +--------------------------------------+--------------------------------------+  |
  |                                         | (Pass)                                  |
  |                                         v                                         |
  |  +-----------------------------------------------------------------------------+  |
  |  | RING 2: Container Security Audit (Aqua Trivy)                               |  |
  |  | - Local Layer Build & CVE Extraction                                        |  |
  |  | - Base OS & Library Scanning (vuln-type: os,library)                        |  |
  |  | - Gate Enforcement (severity: CRITICAL,HIGH | exit-code: 1)                     |  |
  |  +--------------------------------------+--------------------------------------+  |
  |                                         | (Pass)                                  |
  |                                         v                                         |
  |  +-----------------------------------------------------------------------------+  |
  |  | RING 3: Infrastructure as Code Audit (Bridgecrew Checkov)                  |  |
  |  | - K8s Manifest & Terraform Best Practices Scan                              |  |
  |  | - CIS Benchmark Compliance Audit                                            |  |
  |  +--------------------------------------+--------------------------------------+  |
  |                                         | (Pass & Branch == master)               |
  |                                         v                                         |
  |  +-----------------------------------------------------------------------------+  |
  |  | RING 4: Automated EKS Deployment                                            |  |
  |  | - Docker Hub Image Compilation & Registry Push                              |  |
  |  | - AWS IAM Auth & EKS Kubeconfig Injection (eu-west-3)                      |  |
  |  | - Zero-Downtime Rolling Update (kubectl apply & rollout status)             |  |
  |  +-----------------------------------------------------------------------------+  |
  +-----------------------------------------+-----------------------------------------+
                                            |
                                            v
  +-----------------------------------------------------------------------------------+
  |                            AWS EKS PRODUCTION CLUSTER                             |
  |  [ Worker Node Subnet ]  <-->  [ Managed Pods ]  <-->  [ LoadBalancer Service ]    |
  +-----------------------------------------------------------------------------------+
```

---

## Detailed Feature / Security Breakdown

### Ring 1: Secret Leak Protection & SAST Audit
* **Gitleaks Secret Scanner:** Scans full Source Control Management (SCM) commit graphs (`fetch-depth: 0`) to detect hardcoded AWS keys, private tokens, API secrets, and high-entropy strings using Shannon entropy calculations and regex matching.
* **Semgrep SAST Engine:** Conducts static application security testing against Python source files (`app/server.py`), auditing code patterns for OWASP Top 10 vulnerabilities including injection flaws, unsafe deserialization, and misconfigured headers.

### Ring 2: Container Security Audit (Aqua Trivy)
* **Dual-Layer Scanning Scope (`os,library`):** Inspects compiled container layer images (`shield-app:local`), analyzing both OS package manager databases (`dpkg`/`apk`) and application language dependencies (`requirements.txt`).
* **CVSS Gate Enforcement:** Configured with `exit-code: '1'` and `severity: 'CRITICAL,HIGH'` to immediately break build jobs whenever unmitigated high-risk vulnerabilities are detected in production binaries.

### Ring 3: Infrastructure as Code (IaC) Policy Audit (Bridgecrew Checkov)
* **Static Compliance Checkov Scanner:** Audits Kubernetes manifests (`k8s-deployment.yaml`) and Terraform files (`terraform/main.tf`) against CIS Benchmarks, ensuring pods do not run as root, possess resource limits, and enforce network isolation policies.

### Ring 4: Automated Container Build & AWS EKS Deployment
* **Secure Registry Publishing:** Builds verified Docker images via `docker/build-push-action@v4` and publishes tagged release artifacts to Docker Hub using encrypted repository secrets.
* **AWS EKS Integration:** Authenticates via `aws-actions/configure-aws-credentials@v2` targeting region `eu-west-3` (Paris), updates cluster context via `aws eks update-kubeconfig`, and executes `kubectl rollout status` to ensure zero-downtime application updates.

---

## OWASP / Compliance Matrix

| Security Feature / Gate | OWASP Top 10 Mapping | CIS Benchmark Target | Mitigation Mechanism |
| :--- | :--- | :--- | :--- |
| **Ring 1: Gitleaks Scan** | A07:2021 – Identification & Authentication Failures | CIS Git Controls 1.1 | Traverses full commit graph to flag exposed credentials before repository push. |
| **Ring 1: Semgrep SAST** | A03:2021 – Injection / A01:2021 – Broken Access Control | CIS Software Development 2.3 | Validates source code against OWASP rulesets prior to container packaging. |
| **Ring 2: Aqua Trivy** | A06:2021 – Vulnerable & Outdated Components | CIS Docker Benchmark 4.3 | Scans base OS images and runtime dependencies; halts builds on HIGH/CRITICAL CVEs. |
| **Ring 3: Checkov IaC** | A05:2021 – Security Misconfiguration | CIS Kubernetes Benchmark 5.2 | Validates container security contexts, root access limits, and resource allocations. |
| **Ring 4: Branch Lock** | A04:2021 – Insecure Design | CIS Controls 16.4 | Restricts automated infrastructure deployment steps exclusively to verified branches. |

---

## Proof of Work / Negative Testing Table

| Test ID | Injected Threat / Configuration Flaw | Target Ring | Pipeline Status | Root Cause & Resolution Log Snippet |
| :--- | :--- | :--- | :--- | :--- |
| **TST-01** | Malformed base image tag (`python:3.7 stretch`) | Ring 2 | ❌ FAILED | `invalid reference format: repository name must be lowercase`. Replaced space with hyphen (`python:3.7-stretch`). |
| **TST-02** | End-of-Life base image (`python:3.7-stretch`) | Ring 2 | ❌ FAILED | `Debian stretch repository release files expired / 404`. Upgraded base image to `python:3.8-slim-buster`. |
| **TST-03** | Vulnerable package in manifest (`requests==2.20.0`) | Ring 2 | 🟢 PASSED | `trivy` default scope evaluated OS packages only. Added `vuln-type: 'os,library'` to enforce application-level CVE checking. |
| **TST-04** | Misplaced step inside workflow `on:` trigger | Ring 1–4 | ❌ FAILED | `yaml: line 18: did not find expected key`. Relocated Trivy action block under `jobs.ring2-trivy-scan.steps`. |
| **TST-05** | Scanner exit code set to advisory mode (`exit-code: '0'`) | Ring 2 | 🟢 PASSED | Scan flagged critical CVEs but returned status 0. Updated workflow parameter to `exit-code: '1'` to enforce blocking gates. |
| **TST-06** | Unstaged local edits during git commit execution | Ring 1–4 | 🟢 PASSED | Terminal executed `git commit` without staging changes (`no changes added to commit`). Used `git commit -am` to stage edits. |

---

## Repository Structure

```text
project-shield/
├── .github/
│   └── workflows/
│       └── secret-guard.yml      # Multi-Ring DevSecOps GitHub Actions Pipeline
├── app/
│   ├── server.py                 # Core Python Flask Application
│   └── requirements.txt          # Python Language Dependencies
├── aws/                          # AWS CLI Configuration Helper Scripts
├── docs/                         # Architectural Specs & Compliance Documentation
├── terraform/                    # Infrastructure as Code Provisioning
│   ├── main.tf                   # EKS Cluster, VPC Subnets, & Security Groups
│   ├── providers.tf              # AWS Terraform Provider Definitions
│   └── variables.tf              # Region and Cluster Sizing Variables
├── .gitignore                    # Local Exclusion Artifact Rules
├── .trivyignore                  # Approved Vulnerability Exception Rules
├── docker-shield                 # Production Multi-Stage Dockerfile
├── k8s-deployment.yaml           # Kubernetes Deployment & Service Manifests
└── README.md                     # Project Shield Documentation
```

---

## Deployment & Setup Guide

### 1. Prerequisites
Ensure the following CLI tools are installed on your workstation:
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with active credentials (`aws configure`).
* [Terraform v1.5+](https://developer.hashicorp.com/terraform/downloads) for cloud provisioning.
* [kubectl](https://kubernetes.io/docs/tasks/tools/) for Kubernetes cluster interactions.
* [Docker Desktop / Engine](https://docs.docker.com/get-docker/) for local container builds.

Configure the following **Secrets** in your GitHub Repository (`Settings > Secrets and variables > Actions`):
* `DOCKERHUB_USERNAME`: Your Docker Hub registry username.
* `DOCKERHUB_TOKEN`: Personal Access Token for Docker Hub.
* `AWS_ACCESS_KEY_ID`: AWS IAM access key with EKS provisioning rights.
* `AWS_SECRET_ACCESS_KEY`: AWS IAM secret key.

### 2. Infrastructure Provisioning (AWS EKS)
Provision the live Amazon EKS cluster and networking VPC using Terraform:

```bash
# Navigate to terraform infrastructure directory
cd terraform

# Initialize Terraform modules and AWS provider plugins
terraform init

# Validate configuration syntax and plan deployment
terraform plan

# Apply infrastructure blueprint to provision VPC & EKS cluster in eu-west-3
terraform apply -auto-approve
```

### 3. Local Verification & Pipeline Trigger
Verify local build context and trigger the pipeline on a feature branch:

```bash
# Verify local container build execution
docker build -t shield-app:local -f docker-shield .

# Create and checkout a test feature branch
git checkout -b feature/test-ring2-fresh

# Make pipeline modifications, stage, and commit
git commit -am "ci: enforce strict trivy exit-code 1 scanning"

# Push branch to remote repository to execute Rings 1-3
git push origin feature/test-ring2-fresh
```

To trigger **Ring 4 (EKS Deployment)**, merge your feature branch into `master` via Pull Request or push directly to `master`.

---

## FinOps / Teardown

To avoid incurring cloud infrastructure charges on AWS when testing is complete, destroy all provisioned EKS resources and cluster services using the following teardown workflow:

```bash
# 1. Remove active Kubernetes deployments and load balancer services
kubectl delete -f k8s-deployment.yaml

# 2. Tear down AWS EKS cluster, worker nodes, VPC subnets, and IAM roles
cd terraform
terraform destroy -auto-approve

# 3. Clean local Docker build caches and temporary container images
docker system prune -af --volumes
```