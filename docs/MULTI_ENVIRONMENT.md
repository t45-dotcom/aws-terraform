# Multi-Environment Guide

This guide explains how to manage multiple environments (dev, staging, production) with Terraform.

## Approaches

There are several ways to manage multiple environments:

1. **Terraform Workspaces** (Recommended for this project)
2. **Separate Directories**
3. **Separate State Files**
4. **Environment-Specific Variable Files**

## Method 1: Terraform Workspaces (Recommended)

### What Are Workspaces?

Workspaces allow you to manage multiple environments with the same configuration but separate state files.

### Setup Workspaces

```bash
# List workspaces
terraform workspace list

# Create dev workspace
terraform workspace new dev

# Create staging workspace
terraform workspace new staging

# Create production workspace
terraform workspace new prod

# Switch between workspaces
terraform workspace select dev
terraform workspace select staging
terraform workspace select prod

# Show current workspace
terraform workspace show
```

### Workspace-Specific Configuration

**Option A: Use Workspace in Variables**

```hcl
# variables.tf
variable "environment" {
  description = "Environment name"
  default     = terraform.workspace
}

variable "instance_type" {
  description = "Instance type"
  type        = map(string)
  default = {
    dev       = "t3.micro"
    staging   = "t3.small"
    prod      = "t3.medium"
  }
}

# main.tf
module "ec2" {
  instance_type = var.instance_type[terraform.workspace]
  # ...
}
```

**Option B: Workspace-Specific Variable Files**

```bash
# Create environment-specific files
terraform.tfvars.dev
terraform.tfvars.staging
terraform.tfvars.prod
```

```hcl
# terraform.tfvars.dev
instance_type = "t3.micro"
enable_monitoring = false

# terraform.tfvars.staging
instance_type = "t3.small"
enable_monitoring = true

# terraform.tfvars.prod
instance_type = "t3.medium"
enable_monitoring = true
```

**Apply with workspace:**
```bash
terraform workspace select dev
terraform apply -var-file=terraform.tfvars.dev
```

### Backend Configuration for Workspaces

Your S3 backend automatically handles workspaces:

```hcl
# provider.tf
backend "s3" {
  bucket         = "terraform-state-bucket-386397333158"
  key            = "ec2/${terraform.workspace}/terraform.tfstate"
  # Each workspace gets its own state file
}
```

### Workflow Example

```bash
# Deploy to dev
terraform workspace select dev
terraform apply -var-file=terraform.tfvars.dev

# Deploy to staging
terraform workspace select staging
terraform apply -var-file=terraform.tfvars.staging

# Deploy to production
terraform workspace select prod
terraform apply -var-file=terraform.tfvars.prod
```

## Method 2: Separate Directories

### Structure

```
aws-terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
└── modules/
    └── ...
```

### Setup

**1. Create Environment Directory:**
```bash
mkdir -p environments/dev
cd environments/dev
```

**2. Create Backend Configuration:**
```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-386397333158"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-386397333158"
    encrypt        = true
  }
}
```

**3. Reference Modules:**
```hcl
# environments/dev/main.tf
module "ec2" {
  source = "../../modules/ec2"
  
  project_name = "my-project-dev"
  instance_type = "t3.micro"
  # ...
}
```

**4. Deploy:**
```bash
cd environments/dev
terraform init
terraform apply
```

## Method 3: Environment-Specific Variable Files

### Structure

```
aws-terraform/
├── terraform.tfvars.dev
├── terraform.tfvars.staging
├── terraform.tfvars.prod
└── terraform.tfvars.example
```

### Usage

```bash
# Deploy to dev
terraform apply -var-file=terraform.tfvars.dev

# Deploy to staging
terraform apply -var-file=terraform.tfvars.staging

# Deploy to production
terraform apply -var-file=terraform.tfvars.prod
```

### Example Files

**terraform.tfvars.dev:**
```hcl
project_name = "my-project-dev"
environment = "dev"
instance_type = "t3.micro"
enable_monitoring = false
allowed_ssh_cidr = "0.0.0.0/0"  # Less restrictive for dev
```

**terraform.tfvars.prod:**
```hcl
project_name = "my-project-prod"
environment = "prod"
instance_type = "t3.medium"
enable_monitoring = true
allowed_ssh_cidr = "203.0.113.0/32"  # Restrictive for prod
```

## Recommended Approach for This Project

### Using Workspaces + Variable Files

**1. Create Variable Files:**
```bash
# Create environment-specific files
cp terraform.tfvars.example terraform.tfvars.dev
cp terraform.tfvars.example terraform.tfvars.staging
cp terraform.tfvars.example terraform.tfvars.prod
```

**2. Update Backend Key:**
```hcl
# provider.tf
backend "s3" {
  key = "ec2/${terraform.workspace}/terraform.tfstate"
  # ...
}
```

**3. Update Variables:**
```hcl
# variables.tf
variable "instance_type" {
  type = map(string)
  default = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
}

# main.tf or modules
instance_type = var.instance_type[terraform.workspace]
```

**4. Deploy:**
```bash
# Dev
terraform workspace select dev
terraform apply -var-file=terraform.tfvars.dev

# Staging
terraform workspace select staging
terraform apply -var-file=terraform.tfvars.staging

# Production
terraform workspace select prod
terraform apply -var-file=terraform.tfvars.prod
```

## Environment-Specific Best Practices

### 1. Different Resource Sizes

```hcl
# Dev: Small, cheap
instance_type = "t3.micro"
volume_size = 20

# Staging: Medium
instance_type = "t3.small"
volume_size = 30

# Production: Larger
instance_type = "t3.medium"
volume_size = 50
```

### 2. Different Security Settings

```hcl
# Dev: More permissive
allowed_ssh_cidr = "0.0.0.0/0"
enable_monitoring = false

# Production: Restrictive
allowed_ssh_cidr = "YOUR_IP/32"
enable_monitoring = true
```

### 3. Different Tags

```hcl
# Automatically set via provider.tf
default_tags {
  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
```

### 4. Different Regions (Optional)

```hcl
# terraform.tfvars.dev
aws_region = "us-east-1"

# terraform.tfvars.prod
aws_region = "us-west-2"  # Different region for DR
```

## CI/CD with Multiple Environments

### GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Select workspace
        run: terraform workspace select dev
      - name: Apply
        run: terraform apply -var-file=terraform.tfvars.dev -auto-approve

  deploy-prod:
    if: github.ref == 'refs/heads/main'
    environment: production  # Requires approval
    steps:
      - name: Select workspace
        run: terraform workspace select prod
      - name: Apply
        run: terraform apply -var-file=terraform.tfvars.prod -auto-approve
```

## Managing State Across Environments

### View State for Specific Environment

```bash
# Switch workspace
terraform workspace select dev

# List resources
terraform state list

# Show resource
terraform state show module.ec2.aws_instance.web_server
```

### State File Locations

With workspaces, state files are stored as:
- `ec2/dev/terraform.tfstate`
- `ec2/staging/terraform.tfstate`
- `ec2/prod/terraform.tfstate`

### Backup State for Each Environment

```bash
# Backup dev state
terraform workspace select dev
aws s3 cp \
  s3://terraform-state-bucket-386397333158/ec2/dev/terraform.tfstate \
  terraform.tfstate.dev.backup
```

## Promotion Workflow

### Dev → Staging → Production

```bash
# 1. Test in dev
terraform workspace select dev
terraform apply -var-file=terraform.tfvars.dev

# 2. Promote to staging
terraform workspace select staging
terraform apply -var-file=terraform.tfvars.staging

# 3. Promote to production (after testing)
terraform workspace select prod
terraform apply -var-file=terraform.tfvars.prod
```

## Cost Management

### Environment-Specific Costs

```bash
# View costs by environment tag
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=Environment
```

### Cost Optimization

- **Dev**: Use smallest instances, auto-shutdown
- **Staging**: Medium instances, can be stopped when not testing
- **Production**: Right-sized instances, always running

## Troubleshooting

### Wrong Workspace Selected

```bash
# Check current workspace
terraform workspace show

# Switch to correct workspace
terraform workspace select <workspace-name>
```

### State File Conflicts

Each workspace has its own state, so no conflicts between environments.

### Resources in Wrong Environment

```bash
# Check which workspace created resource
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].Tags[?Key==`Environment`].Value'

# Move resource (if needed)
terraform state mv <OLD_ADDRESS> <NEW_ADDRESS>
```

## Related Documentation

- [State Management](STATE_MANAGEMENT.md)
- [Updating Infrastructure](UPDATING_INFRASTRUCTURE.md)
- [Main README](../README.md)

