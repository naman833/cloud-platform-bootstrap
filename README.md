CLOUD-PLATFORM-BOOTSTRAP


WHAT THIS PROJECT IS

cloud-platform-bootstrap is a complete, production-grade Infrastructure as Code and CI/CD reference implementation built on AWS, Terraform, Kubernetes, and GitHub Actions. It provisions a full cloud environment from scratch — VPC, EKS cluster, bastion host, IAM roles, S3 buckets — and deploys a containerised workload to Kubernetes with automated rollouts, health checks, and rollback capability. Every resource is declared in code. No AWS console clicks are required after the one-time bootstrap.

This project exists as a portfolio demonstration of modern platform engineering practices. It is designed to be forked, extended with a real workload, and adapted to any AWS account by changing a handful of variables. It covers four environments — dev, test, staging, and production — each with its own Terraform state, Kubernetes overlay, and deployment pipeline. The progression from dev to production is gated by GitHub Actions environment protection rules, giving teams a clear promotion path with a mandatory manual approval step before production changes land.


THE ARCHITECTURE

The foundation is a VPC module that creates a logically isolated network with three public and three private subnets spread across three availability zones. Public subnets host the internet gateway, NAT gateways, and the bastion host. Private subnets host the EKS worker nodes, keeping compute off the public internet. In non-production environments a single NAT gateway is used to minimise cost; in production one NAT gateway per AZ is created so that the loss of an AZ does not break outbound connectivity. VPC flow logs are shipped to an encrypted S3 bucket for audit and debugging.

On top of the VPC sits an EKS cluster managed by the EKS module. The cluster runs a managed node group of t3.medium instances (configurable) with the Cluster Autoscaler wired up via IRSA so it can scale the node group without needing static AWS credentials. The AWS Load Balancer Controller is similarly configured with its own IRSA role so that Kubernetes Service objects of type LoadBalancer result in real NLBs being provisioned automatically. OIDC is enabled on the cluster, which is the prerequisite for IRSA.

The bastion host is an EC2 instance in the public subnet that has no inbound security group rules and no SSH key. Access is exclusively through AWS Systems Manager Session Manager, which means operators connect through the AWS API rather than through a network socket. This eliminates the need to manage SSH keys and removes port 22 from the attack surface entirely.

GitHub Actions authenticates to AWS using OpenID Connect federation rather than static access keys. The IAM module creates a GitHub OIDC provider in the account and an IAM role whose trust policy restricts assumption to workflows running from the correct GitHub repository. This means no AWS credentials ever appear in GitHub secrets; the workflow exchanges a short-lived GitHub token for a short-lived AWS session token at runtime.

The Kubernetes manifests follow the GitOps pattern. The base layer under k8s/base defines the Deployment, Service, HPA, PDB, and Namespace with resource quotas. Kustomize overlays in k8s/overlays adjust replica counts and resource limits per environment without duplicating the base manifests. ArgoCD application manifests in k8s/argocd point ArgoCD at the appropriate overlay path, enabling continuous reconciliation so that the cluster always matches what is in the repository.

The HorizontalPodAutoscaler is configured with a minimum of two replicas (one in dev and test) and a maximum of ten, targeting sixty percent CPU and seventy-five percent memory utilisation. The PodDisruptionBudget ensures at least one pod is always available during voluntary disruptions such as node drains. Pod anti-affinity rules spread replicas across nodes so that a single node failure does not take the service down. The Deployment uses a RollingUpdate strategy with maxUnavailable zero, meaning new pods must become ready before old ones are removed.

Rollback is built into the pipeline at two levels. Automatic rollback is triggered when the health check script fails after a Terraform apply or a Kubernetes rollout. The health check script polls the load balancer hostname until it gets an HTTP 200 from the /health endpoint or exhausts its retry budget, at which point it calls the rollback workflow via the GitHub Actions API. Manual rollback is always available through the workflow_dispatch trigger on rollback.yml, which accepts the target environment and rollback type as inputs. A Slack notification is sent on completion regardless of outcome.


PREREQUISITES

You need the following tools installed locally before starting. Terraform 1.7 or later handles all infrastructure provisioning. The AWS CLI v2 is required for the bootstrap script and for updating your kubeconfig. kubectl communicates with the EKS cluster. kustomize builds the layered Kubernetes manifests; use version 5 or later. The ArgoCD CLI is needed if you want to interact with ArgoCD applications from your terminal. The GitHub CLI (gh) is used to create the repository. Docker is required to build the application image locally. GNU make ties all the commands together through the Makefile targets. No AWS console access is needed once the bootstrap step is complete.


FIRST TIME SETUP

1. Fork or clone this repository to your own GitHub account. If you are starting fresh, create the repository with: GH_CONFIG_DIR=~/.config/gh-personal gh repo create naman833/cloud-platform-bootstrap --public --clone

2. Copy .env.example to .env and fill in the values. At minimum you need AWS_REGION, AWS_ACCOUNT_ID, and GITHUB_ORG. Source the file before running any make targets: source .env

3. Run make bootstrap to create the S3 state bucket and DynamoDB lock table in your AWS account. This is the only step that requires pre-existing AWS credentials configured in your terminal. After this step all subsequent AWS interactions go through GitHub Actions OIDC.

4. Configure the GitHub OIDC trust. Apply the following IAM trust policy to the github-actions role that Terraform will create (or create it manually if you want CI running before the first apply). Replace ACCOUNT_ID and ORG/REPO with your values:

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

5. Set the following secrets in your GitHub repository under Settings > Secrets and variables > Actions: AWS_ROLE_ARN (the ARN of the role from step 4), AWS_ACCOUNT_ID, TF_STATE_BUCKET, TF_LOCK_TABLE, ECR_REPOSITORY, and SLACK_WEBHOOK_URL. Set AWS_REGION as a repository variable (not a secret) under the Variables tab.

6. Create the four GitHub Actions environments in Settings > Environments: dev, test, staging, and production. Add a required reviewer to the production environment to enable the manual approval gate.

7. Push to main. The terraform-apply workflow will trigger, apply dev automatically, apply test automatically after dev succeeds, apply staging automatically after test succeeds, and then pause at production waiting for a reviewer to approve.


MANAGING ENVIRONMENTS

The four environments differ in scale and cost. Dev uses a single t3.small node with one NAT gateway and one pod replica, intended for rapid iteration. Test matches dev in scale but uses t3.medium nodes and slightly more generous resource limits, suitable for automated integration tests. Staging mirrors the production topology — t3.medium nodes, two desired replicas, one NAT gateway — but without multi-AZ NAT to keep costs down. Production uses multi-AZ NAT gateways, three desired nodes with a maximum of ten, three pod replicas, and full resource limits.

To promote a change from staging to production, open a pull request against main. The terraform-plan workflow will post plan output for all four environments as a PR comment. Merge the PR after review. The apply pipeline will sequence through dev, test, and staging automatically. When staging completes successfully the workflow pauses at the production job and sends a notification to any required reviewers configured on the production environment. A reviewer clicks Approve in the GitHub Actions UI to allow the production apply to proceed.


SWITCHING AWS ACCOUNTS

All AWS-specific values live in two places: the terraform.tfvars files under terraform/environments/*/terraform.tfvars and the GitHub Actions secrets. To point the project at a different AWS account, update AWS_ACCOUNT_ID in each tfvars file and in the GitHub secret of the same name, update the OIDC trust policy ARN in the new account to reference its own account ID, run make bootstrap with credentials for the new account to create the state bucket and lock table there, and update TF_STATE_BUCKET and TF_LOCK_TABLE in GitHub secrets to match the new bucket and table names. No Terraform module code needs to change.


ROLLING BACK

Automatic rollback fires when the health check script returns a non-zero exit code after a deployment. The script polls the load balancer hostname on the /health path with up to ten retries at fifteen-second intervals. If all retries fail it exits with code 1, and the workflow step that called it is marked failed. A subsequent step with an if condition on the failure calls the GitHub Actions API to dispatch the rollback workflow targeting the affected environment with rollback_type set to k8s. The rollback workflow runs kubectl rollout undo on the deployment, waits for the rollout to complete, and sends a Slack notification.

Manual rollback is always available regardless of pipeline state. Navigate to Actions > Rollback > Run workflow in the GitHub UI. Select the environment and rollback type. Setting rollback_type to k8s runs kubectl rollout undo. Setting it to terraform runs a terraform plan in the affected environment directory so you can review what would change, but does not apply automatically — edit the workflow if you want fully automated terraform rollback. Setting it to both performs both operations in sequence.


COST ESTIMATE

Dev environment running continuously costs approximately 35 to 50 USD per month: EKS control plane at 0.10 USD per hour (72 USD monthly, split across environments if you share a cluster), one t3.small node at roughly 15 USD per month, one NAT gateway at 32 USD per month plus data transfer. Destroy dev when not in use with make destroy ENV=dev to eliminate the NAT gateway and node costs.

Test environment is similar to dev at approximately 40 to 55 USD per month when running.

Staging running continuously costs approximately 60 to 80 USD per month: EKS control plane, two t3.medium nodes at roughly 60 USD per month, one NAT gateway. Destroy staging overnight and weekends to reduce this to roughly 20 to 30 USD per month of actual use.

Production with multi-AZ NAT and three t3.medium nodes costs approximately 200 to 250 USD per month: three NAT gateways at 32 USD each, three t3.medium nodes at 90 USD, EKS control plane, and load balancer costs. This estimate excludes data transfer, which varies by traffic volume.

The single largest cost driver across all environments is the NAT gateway. If you are not routing outbound internet traffic from your nodes, consider replacing the NAT gateways with VPC endpoints for the specific AWS services you use (ECR, S3, EKS API) and removing the NAT gateways entirely.


CONTRIBUTING AND EXTENDING

The most natural next step is replacing the nginx placeholder with a real application. Swap the Dockerfile for your application's build and update the health check path to match your application's health endpoint. Add a real domain name by creating a Route 53 hosted zone and pointing it at the load balancer hostname using an alias record.

Adding an RDS module follows the same pattern as the existing modules: a module directory under terraform/modules/rds with variables for instance class, engine version, and multi-AZ toggle, wired into each environment's main.tf. Use the private subnets for the RDS subnet group and a security group that allows inbound on 5432 only from the EKS node security group.

For secrets management, add HashiCorp Vault deployed on EKS using the Vault Helm chart and the Vault Agent Injector. Use IRSA to allow the Vault pods to authenticate to AWS Secrets Manager as a backend. Inject secrets into pods as environment variables or mounted files using the agent sidecar pattern.

For policy enforcement, add OPA Gatekeeper or Kyverno as a ValidatingWebhookConfiguration. Write policies that reject pods without resource limits, reject images from registries other than your ECR, and require the standard label set on all namespaces.

For observability, deploy the kube-prometheus-stack Helm chart to get Prometheus, Alertmanager, and Grafana in one installation. Add a ServiceMonitor for the application deployment. Export metrics to a managed service such as Amazon Managed Prometheus if you want metrics retained beyond the cluster lifecycle. Add Fluent Bit as a DaemonSet to ship container logs to CloudWatch Logs or OpenSearch.
