# Terraform State Management Guide

This guide covers everything you need to know about managing Terraform state files.

## What is Terraform State?

Terraform state is a file that tracks the resources Terraform manages. It maps your configuration to real-world resources.

## State File Locations

### Local State (Default for Development)

- **Location**: `terraform.tfstate` in your project directory
- **Use Case**: Local development, learning
- **Limitations**: Not shared, no locking, lost if deleted

### Remote State (S3 Backend)

- **Location**: S3 bucket (configured in `provider.tf`)
- **Use Case**: Team collaboration, CI/CD, production
- **Benefits**: Shared state, locking, versioning

## Current Configuration

This project uses **S3 backend** for remote state:

```hcl
backend "s3" {
  bucket         = "terraform-state-bucket-386397333158"
  key            = "ec2/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks-386397333158"
  encrypt        = true
}
```

## State Operations

### View State

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show module.ec2.aws_instance.web_server

# Show all outputs
terraform state show
```

### Refresh State

Sync state with actual infrastructure:

```bash
terraform refresh
```

### Move Resources in State

If you rename a resource in code:

```bash
# Move resource to new address
terraform state mv \
  'module.ec2.aws_instance.web_server' \
  'module.ec2.aws_instance.new_name'
```

### Remove Resources from State

Remove resource from state (doesn't destroy it):

```bash
terraform state rm module.ec2.aws_instance.web_server
```

**Warning**: This only removes from state, the resource still exists in AWS!

## State Locking

### What is State Locking?

Prevents multiple people from modifying infrastructure simultaneously.

### How It Works

- Uses DynamoDB table for locking
- Automatically locks during `terraform apply` or `terraform destroy`
- Releases lock when operation completes

### Check Lock Status

```bash
# View current lock
aws dynamodb get-item \
  --table-name terraform-locks-386397333158 \
  --key '{"LockID":{"S":"terraform-state-bucket-386397333158/ec2/terraform.tfstate-md5"}}'
```

### Force Unlock (Use with Caution!)

If a lock is stuck:

```bash
# Get lock ID from error message
terraform force-unlock <LOCK_ID>
```

**Only do this if you're certain no other operation is running!**

## State File Conflicts

### Scenario: Multiple People Working

**Problem**: Two people run `terraform apply` simultaneously.

**Solution**: State locking prevents this automatically.

### Scenario: State Drift

**Problem**: Someone manually changed AWS resources.

**Solution**:
```bash
# Refresh state to detect drift
terraform refresh

# Review changes
terraform plan

# Apply to sync
terraform apply
```

## Importing Existing Resources

If you have resources created outside Terraform:

### Step 1: Add Resource to Configuration

Add the resource block to your `.tf` files.

### Step 2: Import

```bash
terraform import module.ec2.aws_instance.web_server i-1234567890abcdef0
```

### Step 3: Verify

```bash
terraform plan
# Should show no changes if import was successful
```

## Moving State Between Backends

### From Local to S3

1. **Configure S3 backend** in `provider.tf`
2. **Initialize:**
   ```bash
   terraform init
   ```
3. **Migrate state:**
   ```bash
   # Terraform will ask to migrate
   # Type: yes
   ```

### From S3 to Local

1. **Comment out backend block** in `provider.tf`
2. **Initialize:**
   ```bash
   terraform init -migrate-state
   ```

## State File Backup

### Automatic Backups (S3 Backend)

S3 backend automatically:
- Versions state files
- Keeps history of changes
- Can restore previous versions

### Manual Backup

```bash
# Download state file
aws s3 cp \
  s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate \
  terraform.tfstate.backup
```

### Restore from Backup

```bash
# Upload backup
aws s3 cp \
  terraform.tfstate.backup \
  s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate
```

## State File Corruption

### Symptoms

- `Error: state file is corrupted`
- `Error: state file does not match checksum`

### Recovery Steps

1. **Check S3 versioning:**
   ```bash
   aws s3api list-object-versions \
     --bucket terraform-state-bucket-386397333158 \
     --prefix ec2/terraform.tfstate
   ```

2. **Restore previous version:**
   ```bash
   aws s3api get-object \
     --bucket terraform-state-bucket-386397333158 \
     --key ec2/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate.restored
   ```

3. **Upload restored version:**
   ```bash
   aws s3 cp \
     terraform.tfstate.restored \
     s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate
   ```

## State File Security

### Encryption

State files contain sensitive data. Our S3 backend has encryption enabled:

```hcl
encrypt = true  # Encrypts state file in S3
```

### Access Control

- **S3 Bucket Policy**: Restrict access to state bucket
- **IAM Policies**: Limit who can read/write state
- **DynamoDB Access**: Control who can create locks

### Best Practices

1. **Never commit state files** to git (already in `.gitignore`)
2. **Enable versioning** on S3 bucket (already enabled)
3. **Enable encryption** (already enabled)
4. **Use least privilege** IAM policies
5. **Regular backups** (automatic with versioning)

## Troubleshooting State Issues

### Error: "Failed to get existing workspaces"

**Cause**: S3 bucket or DynamoDB table doesn't exist.

**Solution**:
```bash
# Run setup script
./scripts/setup-backend.sh

# Or create manually (see SETUP_S3_BACKEND.md)
```

### Error: "Error acquiring the state lock"

**Cause**: Another operation is running or lock is stuck.

**Solution**:
```bash
# Wait for other operation to finish
# Or force unlock if stuck (see above)
```

### Error: "State file does not match checksum"

**Cause**: State file was modified outside Terraform.

**Solution**:
```bash
# Refresh state
terraform refresh

# Or restore from backup
```

### Error: "Backend configuration changed"

**Cause**: Backend configuration in `provider.tf` was modified.

**Solution**:
```bash
# Re-initialize with migration
terraform init -migrate-state
```

## State File Best Practices

1. **Use Remote State**: Always use S3 backend for production
2. **Enable Versioning**: Automatic with S3 backend
3. **Enable Encryption**: Already configured
4. **Regular Backups**: Automatic with S3 versioning
5. **Monitor State Size**: Large state files can be slow
6. **Use Workspaces**: For multiple environments (see MULTI_ENVIRONMENT.md)

## Related Documentation

- [S3 Backend Setup](SETUP_S3_BACKEND.md)
- [Multi-Environment Guide](MULTI_ENVIRONMENT.md)
- [Troubleshooting Guide](ADVANCED_TROUBLESHOOTING.md)
- [Main README](../README.md)

