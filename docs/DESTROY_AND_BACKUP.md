# Destroy and Backup Guide

This guide explains what happens when you destroy infrastructure and how to backup important data.

## Understanding Terraform Destroy

### What Gets Destroyed

When you run `terraform destroy`, Terraform will destroy **all resources** managed by your configuration:

- ✅ EC2 Instance
- ✅ Security Groups (created by this project)
- ✅ CloudWatch Alarms
- ✅ IAM Roles/Profiles (if created)
- ✅ EBS Volumes (attached to instances)

### What Does NOT Get Destroyed

These resources persist:

- ❌ S3 Backend Bucket (state storage)
- ❌ DynamoDB Lock Table
- ❌ Resources created outside Terraform
- ❌ EBS Snapshots (if you created them)
- ❌ AMIs (if you created custom AMIs)

## Before Destroying

### 1. Backup Important Data

**Option A: Manual Backup via SSH**

```bash
# SSH into instance
ssh -i key.pem ubuntu@<PUBLIC_IP>

# Backup web content
sudo tar -czf /tmp/backup.tar.gz /var/www/html

# Download backup
exit
scp -i key.pem ubuntu@<PUBLIC_IP>:/tmp/backup.tar.gz ./
```

**Option B: EBS Snapshot**

```bash
# Get volume ID
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId'

# Create snapshot
aws ec2 create-snapshot \
  --volume-id <VOLUME_ID> \
  --description "Pre-destroy backup $(date +%Y-%m-%d)"
```

**Option C: S3 Backup**

```bash
# Sync web content to S3
aws s3 sync /var/www/html s3://my-backup-bucket/web-content/
```

### 2. Export Important Information

```bash
# Save outputs
terraform output > outputs-backup.txt

# Save instance details
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  > instance-details.json
```

### 3. Verify What Will Be Destroyed

```bash
# Review destroy plan
terraform plan -destroy

# Save plan to file
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan > destroy-plan.txt
```

## Destroying Infrastructure

### Standard Destroy

```bash
# Destroy all resources
terraform destroy

# Type 'yes' when prompted
```

### Destroy with Auto-Approval

```bash
# Destroy without confirmation (use with caution!)
terraform destroy -auto-approve
```

### Destroy Specific Resources

```bash
# Remove specific resource from state first
terraform state rm module.ec2.aws_instance.web_server

# Then destroy (if you want to keep other resources)
# Or just delete the resource from code and apply
```

### Destroy via GitHub Actions

1. Go to **Actions** tab
2. Select **Terraform CI/CD Pipeline**
3. Click **Run workflow**
4. Select **destroy** action
5. Click **Run workflow**

## After Destroying

### Verify Destruction

```bash
# Check state is empty
terraform state list
# Should show: No resources found

# Verify in AWS Console
# EC2 → Instances (should be empty)
# CloudWatch → Alarms (should be empty)
```

### Clean Up State File (Optional)

```bash
# State file still exists in S3
# You can delete it if you want a fresh start:
aws s3 rm s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate
```

**Note**: This removes state history. Only do this if you're sure you won't need it.

## Backup Strategies

### Strategy 1: Regular EBS Snapshots

**Automated Snapshot Script:**

```bash
#!/bin/bash
# backup-instance.sh

INSTANCE_ID=$(terraform output -raw instance_id)
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Automated backup $(date +%Y-%m-%d-%H%M%S)" \
  --query 'SnapshotId' \
  --output text)

echo "Snapshot created: $SNAPSHOT_ID"

# Tag snapshot
aws ec2 create-tags \
  --resources $SNAPSHOT_ID \
  --tags Key=Backup,Value=Automated Key=Date,Value=$(date +%Y-%m-%d)
```

**Schedule with cron:**
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/backup-instance.sh
```

### Strategy 2: State File Backups

**S3 automatically versions** state files, but you can create manual backups:

```bash
#!/bin/bash
# backup-state.sh

BACKUP_DIR="./backups"
mkdir -p $BACKUP_DIR

# Download current state
aws s3 cp \
  s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate \
  $BACKUP_DIR/terraform.tfstate.$(date +%Y%m%d-%H%M%S)

# Keep only last 30 days
find $BACKUP_DIR -name "terraform.tfstate.*" -mtime +30 -delete

echo "State backed up to $BACKUP_DIR"
```

### Strategy 3: Configuration Backups

**Backup Terraform code:**

```bash
# Create archive
tar -czf terraform-backup-$(date +%Y%m%d).tar.gz \
  *.tf \
  modules/ \
  scripts/ \
  terraform.tfvars

# Store in S3
aws s3 cp terraform-backup-*.tar.gz s3://my-backup-bucket/terraform/
```

## Restoring from Backups

### Restore from EBS Snapshot

```bash
# Create volume from snapshot
aws ec2 create-volume \
  --snapshot-id <SNAPSHOT_ID> \
  --availability-zone us-east-1a \
  --volume-type gp3

# Attach to new instance
aws ec2 attach-volume \
  --volume-id <VOLUME_ID> \
  --instance-id <NEW_INSTANCE_ID> \
  --device /dev/sdf
```

### Restore State File

```bash
# List available backups
aws s3api list-object-versions \
  --bucket terraform-state-bucket-386397333158 \
  --prefix ec2/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket terraform-state-bucket-386397333158 \
  --key ec2/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restored

# Upload restored state
aws s3 cp terraform.tfstate.restored \
  s3://terraform-state-bucket-386397333158/ec2/terraform.tfstate
```

### Restore Web Content

```bash
# From manual backup
scp -i key.pem backup.tar.gz ubuntu@<NEW_INSTANCE_IP>:~/
ssh -i key.pem ubuntu@<NEW_INSTANCE_IP>
sudo tar -xzf backup.tar.gz -C /

# From S3
aws s3 sync s3://my-backup-bucket/web-content/ /var/www/html/
```

## Disaster Recovery Plan

### Scenario: Complete Infrastructure Loss

**Recovery Steps:**

1. **Restore State File** (if available)
   ```bash
   # See "Restore State File" above
   ```

2. **Recreate Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Restore Data**
   ```bash
   # From EBS snapshot or S3 backup
   # See restore procedures above
   ```

4. **Verify Everything Works**
   ```bash
   terraform output
   curl http://$(terraform output -raw instance_public_ip)
   ```

## Cost Considerations

### What Costs Money After Destroy

- ❌ **Nothing!** All billable resources are destroyed

### What Still Costs (Minimal)

- ✅ **S3 Backend**: ~$0.023/GB/month (state files are tiny)
- ✅ **DynamoDB**: Free tier covers small tables
- ✅ **EBS Snapshots**: ~$0.05/GB/month (if you created them)

### Clean Up Costs

```bash
# Delete old snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[*].[SnapshotId,StartTime]' \
  --output table

# Delete specific snapshot
aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID>

# Delete old state backups (if using manual backups)
aws s3 rm s3://my-backup-bucket/terraform/ --recursive
```

## Best Practices

### 1. Always Review Before Destroying

```bash
terraform plan -destroy > destroy-plan.txt
cat destroy-plan.txt
# Review carefully before proceeding
```

### 2. Backup Before Major Changes

```bash
# Before any major update or destroy
./backup-state.sh
./backup-instance.sh
```

### 3. Use Tags for Organization

```bash
# Tag resources for easy identification
aws ec2 create-tags \
  --resources <RESOURCE_ID> \
  --tags Key=Environment,Value=Production Key=Backup,Value=Required
```

### 4. Document Your Infrastructure

```bash
# Export current state
terraform show > infrastructure-state.txt

# Document important values
terraform output > outputs.txt
```

### 5. Test Destroy in Non-Production First

- Test destroy process in dev environment
- Verify backups work
- Then apply to production

## Troubleshooting Destroy Issues

### Error: "Instance is being created, cannot be destroyed"

**Solution**: Wait for instance to finish creating, then destroy.

### Error: "Volume is in use"

**Solution**: Instance must be stopped/terminated before volume can be deleted (Terraform handles this automatically).

### Error: "Cannot delete security group in use"

**Solution**: Terraform should handle dependencies. If stuck, manually detach security group first.

### Destroy Hangs

**Solution**:
```bash
# Check what's happening
terraform show

# Check AWS Console for resource status
# Force unlock if needed (see STATE_MANAGEMENT.md)
```

## Related Documentation

- [State Management](STATE_MANAGEMENT.md)
- [Updating Infrastructure](UPDATING_INFRASTRUCTURE.md)
- [Main README](../README.md)

