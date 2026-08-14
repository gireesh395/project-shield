# 🏛️ System Architecture & DevSecOps Design

> **Project Shield:** Enterprise Cloud Infrastructure, Container Security, and Continuous Runtime Defense Model.

---

## 📋 Table of Contents
- [1. High-Level Network Topology](#1-high-level-network-topology)
- [2. AWS Infrastructure & IAM Security Model](#2-aws-infrastructure--iam-security-model)
- [3. CI/CD Pipeline Architecture (4 Security Rings)](#3-cicd-pipeline-architecture-4-security-rings)
- [4. Container & Pod Security Standards](#4-container--pod-security-standards)
- [5. Runtime Defense (eBPF Kernel Probes)](#5-runtime-defense-ebpf-kernel-probes)

---

## 1. High-Level Network Topology

Project Shield is deployed within a multi-Availability Zone (AZ) Amazon VPC engineered according to the AWS Well-Architected Framework:

```text
                               AWS CLOUD (us-east-1)
┌──────────────────────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                                           │
│                                                                              │
│  ┌──────────────────────────────┐          ┌──────────────────────────────┐  │
│  │ Public Subnet A (10.0.1.0/24)│          │ Public Subnet B (10.0.2.0/24)│  │
│  │  - Internet Gateway (IGW)    │          │  - NAT Gateway (AZ-2)        │  │
│  │  - Application Load Balancer │          │                              │  │
│  └──────────────┬───────────────┘          └──────────────┬───────────────┘  │
│                 │                                         │                  │
│  ┌──────────────▼───────────────┐          ┌──────────────▼───────────────┐  │
│  │ Private Subnet A (10.0.10.0/24)          │ Private Subnet B (10.0.20.0/24) │
│  │                              │          │                              │  │
│  │  AWS EKS Node 1 (Worker)     │          │  AWS EKS Node 2 (Worker)     │  │
│  │  ├─ App Pod (Flask)          │          │  ├─ App Pod (Flask)          │  │
│  │  └─ Falco Agent (DaemonSet)  │          │  └─ Falco Agent (DaemonSet)  │  │
│  └──────────────────────────────┘          └──────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Key Network Isolation Controls:
* **Network Segregation:** EKS Managed Worker Nodes reside strictly in **Private Subnet IP blocks** with no public IP allocation.
* **Egress Control:** Outbound traffic from private worker nodes (e.g., pulling base images, security database updates) routes through managed **NAT Gateways**.
* **Ingress Filtering:** Security Groups strictly limit HTTP/HTTPS inbound traffic to ALB endpoints, dropping unauthorized port access.

---

## 2. AWS Infrastructure & IAM Security Model

All infrastructure is declaratively defined using **Terraform (HCL)** to eliminate manual configuration drift.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        IAM & AUTHENTICATION MODEL                       │
├──────────────────┬─────────────────────────────────────────────────────┤
│ Component        │ Access Strategy & Least Privilege Enforcement       │
├──────────────────┼─────────────────────────────────────────────────────┤
│ GitHub Actions   │ AWS OIDC OpenID Connect (Keyless Authentication)    │
│ EKS Control Plane│ KMS Envelope Encryption for Kubernetes Secrets      │
│ EKS Pods (IRSA)  │ IAM Roles for Service Accounts (Isolated Pod Roles) │
└──────────────────┴─────────────────────────────────────────────────────┘
```

### Infrastructure Components:
1. **Amazon EKS (Elastic Kubernetes Service):** Version 1.29+ running managed Linux node groups.
2. **KMS Encryption:** AWS Key Management Service (KMS) manages envelope encryption for all Kubernetes Secrets stored in `etcd`.
3. **IRSA (IAM Roles for Service Accounts):** Pods obtain short-lived AWS STS tokens instead of relying on worker node IAM permissions.

---

## 3. CI/CD Pipeline Architecture (4 Security Rings)

The pipeline uses **GitHub Actions** to enforce a "Shift-Left" security strategy. Code must pass sequential security checks prior to deployment.

```text
[ Developer Push ]
       │
       ▼
┌─────────────────┐     FAIL
│ RING 1: SECRETS ├──────────────► [ Halts Pipeline ] (Gitleaks)
└────────┬────────┘
         │ PASS
         ▼
┌─────────────────┐     FAIL
│ RING 2: SCA     ├──────────────► [ Halts Pipeline ] (Trivy CVE Scan)
└────────┬────────┘
         │ PASS
         ▼
┌─────────────────┐     FAIL
│ RING 3: IAC/K8S ├──────────────► [ Halts Pipeline ] (Checkov Policies)
└────────┬────────┘
         │ PASS
         ▼
┌─────────────────┐
│ RING 4: DEPLOY  ├──────────────► [ Rolling Update to AWS EKS ]
└─────────────────┘
```

---

## 4. Container & Pod Security Standards

Containers are built using multi-stage Dockerfiles and hardened against Pod Security Standards (PSS) **Restricted Level**:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 10001
  capabilities:
    drop:
      - ALL
```

---

## 5. Runtime Defense (eBPF Kernel Probes)

Static checks cannot catch zero-day exploits or runtime logic compromises. **Falco** operates as a Kubernetes `DaemonSet` on every EKS node, attaching **eBPF (Extended Berkeley Packet Filter)** probes directly to the Linux kernel.

```text
┌─────────────────────────────────────────────────────────────┐
│                 EKS WORKER NODE (LINUX KERNEL)              │
├─────────────────────────────────────────────────────────────┤
│  User Space:                                                │
│    [ Application Pod ] ──► (Spawns /bin/sh)               │
│                                   │                         │
│  Kernel Space:                    │ (Intercepted)           │
│    [ System Call: execve ] ───────▼                         │
│    [ eBPF Probe ] ──────────────► [ Falco Engine ]          │
│                                         │                   │
│                                         ▼                   │
│                                  🚨 REAL-TIME ALERT         │
└─────────────────────────────────────────────────────────────┘
```

### Tracked Syscall Patterns:
* `execve` (Unauthorized process executions like `/bin/sh` or `/bin/bash`).
* `openat` / `read` (Accessing sensitive ServiceAccount tokens or `/etc/shadow`).
* `socket` / `connect` (Unexpected outbound connection attempts from container pods).