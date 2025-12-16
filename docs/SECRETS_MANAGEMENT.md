# Secrets Management Guide

This guide covers best practices for managing secrets and sensitive data in your Terraform project.

## What Are Secrets?

Secrets include:
- AWS Access Keys
- Secret Access Keys
- API Tokens
- Database Passwords
- SSH Private Keys
- Any sensitive configuration

## Current Protection

### ✅ Already Protected

Your project already protects secrets:

1. **`.gitignore`** excludes:
   - `*.tfvars` (variable files)
   - `dontcommit.txt` (local secrets)
   - `*.csv` (credential files)
   - `*.pdf` (may contain secrets)

2. **S3 Backend Encryption**: State files encrypted at rest

3. **GitHub Secrets**: For CI/CD (see GITHUB_ACTIONS_SETUP.md)

## Secret Management Methods

### Method 1: terraform.tfvars (Local Development)

**Best For**: Local development, learning

**Setup**:
```bash
# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Example**:
```hcl
# terraform.tfvars (NOT committed to git)
project_name = "my-project"
aws_region = "us-east-1"
key_pair_name = "my-secret-key-name"
```

**Security**:
- ✅ Not committed to git (in `.gitignore`)
- ⚠️ Stored in plain text locally
- ⚠️ Not suitable for teams

### Method 2: Environment Variables

**Best For**: CI/CD, automated deployments

**Setup**:
```bash
# Set variables
export TF_VAR_project_name="my-project"
export TF_VAR_aws_region="us-east-1"

# Terraform automatically picks them up
terraform apply
```

**In GitHub Actions**:
```yaml
env:
  TF_VAR_project_name: ${{ secrets.PROJECT_NAME }}
  TF_VAR_aws_region: us-east-1
```

**Security**:
- ✅ Not in code
- ✅ Can use secret management systems
- ⚠️ Need to manage environment

### Method 3: AWS Secrets Manager

**Best For**: Production, sensitive data

**Setup**:

1. **Store secret in AWS Secrets Manager:**
   ```bash
   aws secretsmanager create-secret \
     --name terraform/db-password \
     --secret-string "my-secret-password"
   ```

2. **Retrieve in Terraform:**
   ```hcl
   data "aws_secretsmanager_secret_version" "db_password" {
     secret_id = "terraform/db-password"
   }
   
   # Use in configuration
   resource "aws_instance" "example" {
     # Use: data.aws_secretsmanager_secret_version.db_password.secret_string
   }
   ```

**Security**:
- ✅ Encrypted at rest
- ✅ Access controlled via IAM
- ✅ Audit trail
- ✅ Automatic rotation support

### Method 4: AWS Systems Manager Parameter Store

**Best For**: Configuration values, less sensitive secrets

**Setup**:

1. **Store parameter:**
   ```bash
   aws ssm put-parameter \
     --name /terraform/project-name \
     --value "my-project" \
     --type String
   ```

2. **Retrieve in Terraform:**
   ```hcl
   data "aws_ssm_parameter" "project_name" {
     name = "/terraform/project-name"
   }
   
   # Use
   project_name = data.aws_ssm_parameter.project_name.value
   ```

**Security**:
- ✅ Encrypted (if using SecureString type)
- ✅ Access controlled via IAM
- ✅ Version history
- ✅ Free tier available

### Method 5: Terraform Cloud Variables

**Best For**: Teams using Terraform Cloud

**Setup**:
1. Go to Terraform Cloud workspace
2. Variables → Add variable
3. Mark as "Sensitive"
4. Terraform automatically uses it

**Security**:
- ✅ Encrypted
- ✅ Access controlled
- ✅ Audit trail

## Best Practices

### 1. Never Commit Secrets

**❌ Bad:**
```hcl
# main.tf
variable "aws_secret_key" {
  default = "AKIAIOSFODNN7EXAMPLE"  # DON'T DO THIS!
}
```

**✅ Good:**
```hcl
# terraform.tfvars (in .gitignore)
aws_secret_key = "AKIAIOSFODNN7EXAMPLE"
```

### 2. Use .gitignore

Your `.gitignore` already includes:
```
*.tfvars
dontcommit.txt
*.csv
```

**Verify it's working:**
```bash
git status
# Should NOT show terraform.tfvars
```

### 3. Rotate Credentials Regularly

**AWS Access Keys:**
```bash
# Create new key
aws iam create-access-key --user-name my-user

# Update terraform.tfvars or secrets
# Test new key
# Delete old key
aws iam delete-access-key --user-name my-user --access-key-id OLD_KEY_ID
```

### 4. Use Least Privilege

**Don't use full admin access:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:RunInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5. Separate Secrets by Environment

**Structure:**
```
terraform.tfvars.dev
terraform.tfvars.staging
terraform.tfvars.prod
```

**Use:**
```bash
terraform apply -var-file=terraform.tfvars.dev
```

### 6. Use Secret Scanning

**GitHub automatically scans** for secrets in commits.

**Manual scan:**
```bash
# Use git-secrets
git secrets --install
git secrets --register-aws

# Scan
git secrets --scan
```

## Current Project Secrets

### What Needs Protection

1. **AWS Credentials** (for local development)
   - Location: `terraform.tfvars` (not committed)
   - Or: Environment variables

2. **GitHub Secrets** (for CI/CD)
   - Location: GitHub Repository Secrets
   - See: [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

3. **EC2 Key Pairs**
   - Location: AWS (managed by AWS)
   - Private keys: Local only (not in repo)

### What's Already Safe

- ✅ `terraform.tfvars` - In `.gitignore`
- ✅ `dontcommit.txt` - In `.gitignore`
- ✅ State files - Encrypted in S3
- ✅ GitHub Secrets - Encrypted by GitHub

## Securing GitHub Actions

### Current Setup

Your workflow uses GitHub Secrets:
```yaml
aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Best Practices

1. **Use OIDC (More Secure):**
   ```yaml
   - name: Configure AWS credentials
     uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole
       aws-region: us-east-1
   ```

2. **Rotate Secrets Regularly:**
   - Every 90 days
   - Or when team member leaves

3. **Use Environment Protection:**
   - Require approvals for production
   - Limit who can access secrets

## Detecting Exposed Secrets

### If You Accidentally Commit Secrets

1. **Immediately Rotate:**
   ```bash
   # Create new credentials
   # Update all systems
   # Delete old credentials
   ```

2. **Remove from Git History:**
   ```bash
   # Use git filter-branch or BFG Repo-Cleaner
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch terraform.tfvars' \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force Push:**
   ```bash
   git push origin --force --all
   ```

**Note**: If secrets were exposed publicly, assume they're compromised and rotate immediately.

## Secret Rotation Checklist

- [ ] Create new secret/credential
- [ ] Update all systems using old secret
- [ ] Test new secret works
- [ ] Update documentation
- [ ] Delete old secret
- [ ] Verify old secret no longer works
- [ ] Monitor for errors

## Tools for Secret Management

### 1. AWS Secrets Manager
- **Cost**: ~$0.40/secret/month
- **Best For**: Production secrets
- **Features**: Rotation, audit trail

### 2. AWS Systems Manager Parameter Store
- **Cost**: Free (Standard), $0.05/parameter/month (Advanced)
- **Best For**: Configuration, less sensitive data
- **Features**: Versioning, encryption

### 3. HashiCorp Vault
- **Cost**: Open source (free)
- **Best For**: Multi-cloud, complex scenarios
- **Features**: Dynamic secrets, rotation

### 4. Terraform Cloud
- **Cost**: Free tier available
- **Best For**: Teams using Terraform Cloud
- **Features**: Integrated with Terraform

## Related Documentation

- [GitHub Actions Setup](GITHUB_ACTIONS_SETUP.md)
- [State Management](STATE_MANAGEMENT.md)
- [Main README](../README.md)

