# Updating Infrastructure Guide

This guide explains how to safely modify and update your Terraform-managed infrastructure.

## Before Making Changes

### 1. Review Current State

```bash
# List all resources
terraform state list

# Show current configuration
terraform show

# Check for drift
terraform plan
```

### 2. Backup State (Recommended)

```bash
# Download current state
aws s3 cp \
  s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate \
  terraform.tfstate.backup-$(date +%Y%m%d)
```

## Common Update Scenarios

### Changing Instance Type

**Example**: Upgrade from `t3.micro` to `t3.small`

1. **Update `terraform.tfvars`:**
   ```hcl
   instance_type = "t3.small"
   ```

2. **Review changes:**
   ```bash
   terraform plan
   ```

3. **Apply:**
   ```bash
   terraform apply
   ```

**Note**: This will **replace** the instance (destroy and recreate). Data on the instance will be lost unless you have backups.

### Updating Security Group Rules

**Example**: Add a new port or change allowed IPs

1. **Update variables:**
   ```hcl
   # In terraform.tfvars
   allowed_ssh_cidr = "203.0.113.0/32"  # Your new IP
   ```

2. **Or modify security group module:**
   ```hcl
   # In modules/security-group/main.tf
   # Add new ingress rule
   ingress {
     from_port   = 8080
     to_port     = 8080
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ```

3. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

**Note**: Security group changes are **non-destructive** - they update in-place.

### Modifying User Data Script

**Example**: Install additional software

1. **Edit `scripts/user_data.sh`:**
   ```bash
   # Add your changes
   apt-get install -y docker.io
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

**Note**: User data only runs on **first boot**. To apply changes:
- Option 1: Replace instance (destructive)
- Option 2: Manually run commands via SSH

### Changing Volume Size

**Example**: Increase EBS volume from 30GB to 50GB

1. **Update `terraform.tfvars`:**
   ```hcl
   volume_size = 50
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

**Note**: Volume size can be increased **non-destructively**. Decreases require replacement.

### Adding New Resources

**Example**: Add a second EC2 instance

1. **Create new module instance in `main.tf`:**
   ```hcl
   module "ec2_backup" {
     source = "./modules/ec2"
     
     project_name         = var.project_name
     ami_id               = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
     instance_type        = var.instance_type
     # ... other variables
   }
   ```

2. **Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

### Removing Resources

**Example**: Remove CloudWatch alarms

1. **Comment out or delete** the resource/module in `.tf` files

2. **Review destruction plan:**
   ```bash
   terraform plan
   # Review what will be destroyed
   ```

3. **Apply:**
   ```bash
   terraform apply
   ```

## Update Workflow

### Standard Update Process

```bash
# 1. Pull latest changes (if using git)
git pull

# 2. Review current state
terraform show

# 3. Make configuration changes
# Edit .tf files or terraform.tfvars

# 4. Validate syntax
terraform validate

# 5. Format code
terraform fmt

# 6. Review planned changes
terraform plan

# 7. Apply changes
terraform apply

# 8. Verify changes
terraform output
```

### Using Terraform Plan Files

For safer updates, save and review plans:

```bash
# Create plan
terraform plan -out=update.tfplan

# Review plan (human-readable)
terraform show update.tfplan

# Apply plan
terraform apply update.tfplan
```

## Destructive vs Non-Destructive Changes

### Non-Destructive (In-Place Updates)

These changes update resources without replacement:

- ✅ Security group rules
- ✅ Tags
- ✅ Volume size (increase only)
- ✅ Monitoring settings
- ✅ IAM roles/policies

### Destructive (Replacement Required)

These changes require destroying and recreating resources:

- ⚠️ Instance type change
- ⚠️ AMI change
- ⚠️ Volume size decrease
- ⚠️ User data changes (on existing instances)
- ⚠️ Subnet/VPC changes

**Warning**: Destructive changes will cause **data loss** unless you have backups!

## Handling Data During Updates

### Before Destructive Changes

1. **Backup important data:**
   ```bash
   # SSH into instance
   ssh -i key.pem ubuntu@<IP>
   
   # Backup data
   sudo tar -czf /tmp/backup.tar.gz /var/www/html
   
   # Download backup
   scp -i key.pem ubuntu@<IP>:/tmp/backup.tar.gz ./
   ```

2. **Or use EBS snapshots:**
   ```bash
   # Create snapshot
   aws ec2 create-snapshot \
     --volume-id <VOLUME_ID> \
     --description "Pre-update backup"
   ```

### After Destructive Changes

1. **Restore data:**
   ```bash
   # Upload backup
   scp -i key.pem backup.tar.gz ubuntu@<NEW_IP>:~/
   
   # SSH and restore
   ssh -i key.pem ubuntu@<NEW_IP>
   sudo tar -xzf backup.tar.gz -C /
   ```

## Rollback Procedures

### Rollback Configuration Changes

1. **Revert code changes:**
   ```bash
   git checkout HEAD -- main.tf
   ```

2. **Apply previous configuration:**
   ```bash
   terraform plan
   terraform apply
   ```

### Rollback State File

If state file is corrupted or incorrect:

1. **Restore from S3 version:**
   ```bash
   # List versions
   aws s3api list-object-versions \
     --bucket terraform-state-bucket-386397333158 \
     --prefix ec2/terraform.tfstate
   
   # Restore specific version
   aws s3api get-object \
     --bucket terraform-state-bucket-386397333158 \
     --key ec2/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate
   
   # Upload restored state
   aws s3 cp terraform.tfstate \
     s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate
   ```

## Best Practices

### 1. Always Plan First

```bash
terraform plan > plan.txt
# Review plan.txt before applying
```

### 2. Use Version Control

```bash
# Commit changes before applying
git add .
git commit -m "Update instance type to t3.small"
git push

# Then apply
terraform apply
```

### 3. Test in Non-Production First

- Test changes in dev environment
- Verify everything works
- Then apply to production

### 4. Use Workspaces for Environments

See [Multi-Environment Guide](MULTI_ENVIRONMENT.md)

### 5. Monitor Changes

```bash
# After applying, verify
terraform output
aws ec2 describe-instances --instance-ids <INSTANCE_ID>
```

### 6. Document Changes

Keep a changelog of infrastructure changes:

```markdown
## 2025-12-16
- Upgraded instance type from t3.micro to t3.small
- Added port 8080 to security group
- Increased volume size to 50GB
```

## Troubleshooting Updates

### Error: "Instance is being created, cannot be modified"

**Solution**: Wait for instance to be fully running, then retry.

### Error: "Cannot modify instance type while instance is running"

**Solution**: Terraform will stop, modify, and start the instance automatically.

### Error: "Volume size cannot be decreased"

**Solution**: You cannot decrease volume size. If needed, create new instance with smaller volume.

### Changes Not Applied

**Possible Causes**:
- State file out of sync
- Resource was modified outside Terraform

**Solution**:
```bash
# Refresh state
terraform refresh

# Review changes
terraform plan

# Apply
terraform apply
```

## Related Documentation

- [State Management](STATE_MANAGEMENT.md)
- [SSH Access Guide](SSH_ACCESS_GUIDE.md)
- [Troubleshooting Guide](ADVANCED_TROUBLESHOOTING.md)
- [Main README](../README.md)

