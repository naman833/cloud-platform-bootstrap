# ☁️ Cloud Platform Bootstrap

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20VPC%20%7C%20IAM-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-blue?logo=kubernetes)](https://kubernetes.io/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-black?logo=githubactions)](https://github.com/features/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Production-grade Infrastructure as Code and CI/CD reference implementation** built on AWS, Terraform, Kubernetes, and GitHub Actions. Provision a full cloud environment from scratch - no AWS console clicks required.

---

## 📑 Table of Contents

- [What Is This Project?](#what-is-this-project)
- [Key Features](#-key-features)
- [Architecture Overview](#-architecture-overview)
- [Repository Structure](#-repository-structure)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [What You Need to Configure](#-what-you-need-to-configure)
- [Environment Matrix](#-environment-matrix)
- [Make Targets](#-make-targets)
- [Deployment Pipeline](#-deployment-pipeline)
- [Rolling Back](#-rolling-back)
- [Switching AWS Accounts](#-switching-aws-accounts)
- [Cost Estimates](#-cost-estimates)
- [Contributing & Extending](#-contributing--extending)
- [License](#-license)

---

## What Is This Project?

**cloud-platform-bootstrap** is a complete, production-grade Infrastructure as Code (IaC) and CI/CD reference implementation. It provisions a full AWS cloud environment from scratch - VPC, EKS cluster, bastion host, IAM roles, S3 buckets - and deploys a containerised workload to Kubernetes with automated rollouts, health checks, and rollback capability.

**Every resource is declared in code. No AWS console clicks are required after the one-time bootstrap.**

This project is designed to be:

- 🔀 **Forked** - clone it and make it your own
- 🔧 **Extended** - swap the nginx placeholder for your real application
- 🏗️ **Adapted** - point it at any AWS account by changing a handful of variables

It covers **four environments** - `dev`, `test`, `staging`, and `production` - each with its own Terraform state, Kubernetes overlay, and deployment pipeline. The progression from dev → production is gated by GitHub Actions environment protection rules with mandatory manual approval before production changes land.

---

## ✨ Key Features

| Category | What You Get |
|----------|--------------|
| **Infrastructure** | Multi-AZ VPC, EKS with managed node groups, Cluster Autoscaler (IRSA), AWS Load Balancer Controller |
| **Security** | GitHub OIDC (no static AWS keys), SSM-only bastion (no SSH), VPC flow logs, encrypted state |
| **CI/CD** | GitHub Actions pipelines for plan, apply, deploy, and rollback with environment promotion gates |
| **Kubernetes** | Kustomize overlays, HPA, PDB, pod anti-affinity, RollingUpdate with zero downtime |
| **GitOps** | ArgoCD application manifests for continuous reconciliation |
| **Observability** | Health check scripts, Slack notifications, automated rollback on failure |

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Account                                 │
│                                                                     │
│  ┌───────────────────── VPC (3 AZs) ─────────────────────────┐     │
│  │                                                            │     │
│  │  Public Subnets          Private Subnets                   │     │
│  │  ┌──────────────┐       ┌──────────────────────────┐      │     │
│  │  │ NAT Gateway  │       │  EKS Worker Nodes        │      │     │
│  │  │ Bastion Host │──────▶│  (t3.medium, autoscaling)│      │     │
│  │  │ (SSM only)   │       │                          │      │     │
│  │  └──────────────┘       │  ┌────────────────────┐  │      │     │
│  │                          │  │ cloud-platform-app │  │      │     │
│  │                          │  │ (nginx / your app) │  │      │     │
│  │                          │  └────────────────────┘  │      │     │
│  │                          └──────────────────────────┘      │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  S3 (TF State) │ DynamoDB (Lock) │ ECR │ IAM (OIDC)               │
└─────────────────────────────────────────────────────────────────────┘
         ▲
         │  OIDC Federation (no static credentials)
         ▼
┌─────────────────────┐
│   GitHub Actions     │
│   ┌───┐ ┌───┐       │
│   │Plan│ │Apply│     │
│   └───┘ └───┘       │
│   dev → test →       │
│   staging → prod     │
└─────────────────────┘
```

### Component Deep Dive

- **VPC** - 3 public + 3 private subnets, NAT gateways (multi-AZ in prod), VPC flow logs to encrypted S3
- **EKS** - Managed node groups, OIDC enabled, Cluster Autoscaler & LB Controller via IRSA
- **Bastion** - No SSH key, no inbound SG rules - access exclusively via AWS SSM Session Manager
- **GitHub OIDC** - Workflows exchange short-lived GitHub tokens for short-lived AWS sessions; no secrets stored
- **Kubernetes** - Base manifests + Kustomize overlays per environment; ArgoCD for continuous reconciliation
- **Rollback** - Automatic (health check failure triggers rollback) + manual (workflow_dispatch)

---

## 📂 Repository Structure

```
cloud-platform-bootstrap/
├── .github/workflows/
│   ├── terraform-plan.yml        # PR plan output for all environments
│   ├── terraform-apply.yml       # Sequential apply: dev → test → staging → prod
│   ├── k8s-deploy.yml            # Kubernetes deployment pipeline
│   └── rollback.yml              # Manual/automatic rollback workflow
├── terraform/
│   ├── backend.tf                # S3 backend configuration
│   ├── modules/                  # Reusable Terraform modules (VPC, EKS, IAM, etc.)
│   └── environments/             # Per-environment configs (dev, test, staging, prod)
├── k8s/
│   ├── base/                     # Base Kubernetes manifests (Deployment, Service, HPA, PDB)
│   ├── overlays/                 # Kustomize overlays per environment
│   └── argocd/                   # ArgoCD Application manifests
├── scripts/
│   ├── bootstrap.sh              # One-time S3 + DynamoDB setup
│   ├── health-check.sh           # Post-deploy health verification
│   └── destroy.sh                # Tear down environment resources
├── Dockerfile                    # Application container image
├── nginx.conf                    # Default nginx configuration
├── Makefile                      # Developer workflow commands
├── .env.example                  # Template for required environment variables
└── README.md                     # You are here
```

---

## 📋 Prerequisites

Install the following tools before starting:

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://www.terraform.io/downloads) | ≥ 1.7 | Infrastructure provisioning |
| [AWS CLI](https://aws.amazon.com/cli/) | v2 | Bootstrap script, kubeconfig updates |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Latest | Kubernetes cluster communication |
| [Kustomize](https://kustomize.io/) | ≥ 5.0 | Layered K8s manifest builds |
| [Docker](https://www.docker.com/get-started) | Latest | Build application images locally |
| [GNU Make](https://www.gnu.org/software/make/) | Latest | Orchestrate commands via Makefile |
| [GitHub CLI (gh)](https://cli.github.com/) | Latest | Repository creation and management |
| [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | Latest | *(Optional)* Interact with ArgoCD apps |

---

## 🚀 Getting Started

### 1. Fork or Clone

```bash
# Option A: Fork via GitHub UI, then clone
git clone https://github.com/<your-org>/cloud-platform-bootstrap.git
cd cloud-platform-bootstrap

# Option B: Create fresh with GitHub CLI
gh repo create <your-org>/cloud-platform-bootstrap --public --clone
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` and fill in **at minimum**:

```bash
AWS_REGION=us-east-1           # Your preferred AWS region
AWS_ACCOUNT_ID=123456789012    # Your 12-digit AWS account ID
GITHUB_ORG=your-github-org     # Your GitHub username or org
```

Then source it:

```bash
source .env
```

### 3. Bootstrap Remote State

```bash
make bootstrap
```

> ⚠️ This is the **only step** that requires pre-existing AWS credentials in your terminal. It creates the S3 state bucket and DynamoDB lock table. After this, all AWS interactions go through GitHub Actions OIDC.

### 4. Configure GitHub OIDC Trust

Apply this IAM trust policy to the `github-actions` role. Replace `ACCOUNT_ID` and `ORG/REPO` with your values:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
        }
      }
    }
  ]
}
```

### 5. Set GitHub Secrets & Variables

Navigate to **Settings → Secrets and variables → Actions** in your repository:

**Secrets** (sensitive values):

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | ARN of the OIDC role from step 4 |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `TF_STATE_BUCKET` | Name of the S3 bucket created in step 3 |
| `TF_LOCK_TABLE` | Name of the DynamoDB table created in step 3 |
| `ECR_REPOSITORY` | Name of your ECR repository (e.g., `cloud-platform-app`) |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook for notifications |

**Variables** (non-sensitive):

| Variable Name | Value |
|---------------|-------|
| `AWS_REGION` | Your AWS region (e.g., `us-east-1`) |

### 6. Create GitHub Environments

Go to **Settings → Environments** and create:

- `dev`
- `test`
- `staging`
- `production` - **add a required reviewer** to enable the manual approval gate

### 7. Push and Watch

```bash
git push origin main
```

The `terraform-apply` workflow triggers automatically:
1. ✅ `dev` - applies automatically
2. ✅ `test` - applies after dev succeeds
3. ✅ `staging` - applies after test succeeds
4. ⏸️ `production` - **pauses for reviewer approval**

---

## 🔧 What You Need to Configure

Here's a quick checklist of everything you need to provide to make this project work in your AWS account:

- [ ] **AWS Account** with admin access (for initial bootstrap only)
- [ ] **`.env` file** with `AWS_REGION`, `AWS_ACCOUNT_ID`, `GITHUB_ORG`
- [ ] **GitHub repository secrets** (see table above)
- [ ] **GitHub environments** with production protection rules
- [ ] **IAM OIDC trust policy** connecting GitHub Actions to your AWS account
- [ ] *(Optional)* Slack webhook for deployment notifications
- [ ] *(Optional)* Custom domain in Route 53

---

## 🌍 Environment Matrix

| Environment | Nodes | Instance Type | NAT Gateways | Pod Replicas | Use Case |
|-------------|-------|---------------|--------------|--------------|----------|
| `dev` | 1 | t3.small | 1 | 1 | Rapid iteration |
| `test` | 1 | t3.medium | 1 | 1 | Integration tests |
| `staging` | 2 | t3.medium | 1 | 2 | Pre-production validation |
| `production` | 3 | t3.medium | 3 (multi-AZ) | 3 | Live traffic |

To promote a change: open a PR → review plan output → merge → automatic sequential apply with production gate.

---

## 🎯 Make Targets

```bash
make bootstrap          # One-time: create S3 bucket + DynamoDB table
make init    ENV=dev    # Initialize Terraform for an environment
make plan    ENV=dev    # Preview infrastructure changes
make apply   ENV=dev    # Apply infrastructure changes
make deploy  ENV=dev    # Deploy K8s manifests via Kustomize
make rollback ENV=dev   # Rollback K8s deployment (kubectl rollout undo)
make health  ENV=dev    # Run post-deploy health checks
make destroy ENV=dev    # Tear down all resources for an environment
make fmt                # Format all Terraform files
make validate ENV=dev   # Validate Terraform configuration
make clean              # Remove local .terraform dirs and plan files
```

---

## 🔄 Deployment Pipeline

```
Pull Request                    Merge to main
     │                               │
     ▼                               ▼
terraform-plan.yml              terraform-apply.yml
(posts plan for all envs        (sequential apply)
 as PR comment)                      │
                                     ├── dev (auto)
                                     ├── test (auto)
                                     ├── staging (auto)
                                     └── production (manual approval)
                                          │
                                          ▼
                                     k8s-deploy.yml
                                     (rollout + health check)
                                          │
                                     ┌────┴────┐
                                     │ Healthy? │
                                     └────┬────┘
                                    Yes   │   No
                                     ▼         ▼
                                   Done    rollback.yml
                                           (auto rollback + Slack alert)
```

---

## ↩️ Rolling Back

### Automatic Rollback

Triggered when the health check script fails after deployment:
1. Script polls the load balancer `/health` endpoint (10 retries × 15s intervals)
2. On failure, dispatches `rollback.yml` targeting the affected environment
3. Runs `kubectl rollout undo` and sends a Slack notification

### Manual Rollback

Navigate to **Actions → Rollback → Run workflow** in the GitHub UI:

| `rollback_type` | Action |
|-----------------|--------|
| `k8s` | `kubectl rollout undo` on the deployment |
| `terraform` | Runs `terraform plan` for review (does not auto-apply) |
| `both` | Performs both operations in sequence |

---

## 🔀 Switching AWS Accounts

To point the project at a different AWS account:

1. Update `AWS_ACCOUNT_ID` in each `terraform/environments/*/terraform.tfvars`
2. Update the OIDC trust policy ARN in the new account
3. Run `make bootstrap` with credentials for the new account
4. Update GitHub secrets: `AWS_ACCOUNT_ID`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE`

> No Terraform module code needs to change.

---

## 💰 Cost Estimates

| Environment | Monthly Cost | Key Drivers |
|-------------|-------------|-------------|
| **Dev** | ~$35–50 | 1× t3.small ($15), 1× NAT ($32), EKS control plane (shared) |
| **Test** | ~$40–55 | 1× t3.medium ($30), 1× NAT ($32) |
| **Staging** | ~$60–80 | 2× t3.medium ($60), 1× NAT ($32) |
| **Production** | ~$200–250 | 3× t3.medium ($90), 3× NAT ($96), EKS, ALB |

> 💡 **Cost tip:** Destroy non-production environments when not in use: `make destroy ENV=dev`
>
> 💡 **Biggest cost driver:** NAT gateways. If your workloads don't need outbound internet, replace them with VPC endpoints for ECR, S3, and EKS API.

---

## 🤝 Contributing & Extending

### Replace the Placeholder App

Swap the nginx container for your real application:
1. Update the `Dockerfile` with your app's build
2. Update `HEALTH_CHECK_PATH` in `.env` to match your app's health endpoint
3. *(Optional)* Add a Route 53 hosted zone and alias record for a custom domain

### Add a Database (RDS)

Create `terraform/modules/rds/` following the existing module pattern - variables for instance class, engine, and multi-AZ toggle. Use private subnets and restrict inbound to the EKS node security group on port 5432.

### Add Secrets Management

Deploy HashiCorp Vault on EKS via Helm with IRSA for AWS Secrets Manager backend. Use the Vault Agent Injector sidecar to mount secrets into pods.

### Add Policy Enforcement

Install OPA Gatekeeper or Kyverno. Write policies to reject pods without resource limits, images from untrusted registries, and namespaces without required labels.

### Add Observability

Deploy `kube-prometheus-stack` for Prometheus + Grafana + Alertmanager. Add Fluent Bit as a DaemonSet for shipping logs to CloudWatch or OpenSearch.

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
