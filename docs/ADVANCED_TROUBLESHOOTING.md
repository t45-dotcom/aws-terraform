# Advanced Troubleshooting Guide

This guide covers advanced troubleshooting scenarios beyond the basics.

## Table of Contents

- [Provider Errors](#provider-errors)
- [State File Issues](#state-file-issues)
- [Instance Issues](#instance-issues)
- [Network Issues](#network-issues)
- [User Data Script Failures](#user-data-script-failures)
- [CloudWatch Issues](#cloudwatch-issues)
- [Authentication Errors](#authentication-errors)

## Provider Errors

### Error: "Provider source not supported in Terraform v0.12"

**Cause**: Using Terraform version < 1.0

**Solution**:
```bash
# Check version
terraform version

# Upgrade Terraform
# macOS
brew upgrade terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Error: "Custom variable validation is experimental"

**Cause**: Terraform version doesn't support variable validation, or experiments not enabled

**Solution**:
```bash
# Upgrade to Terraform >= 0.13 (validation is built-in)
# Or add to terraform block:
terraform {
  experiments = [variable_validation]
}
```

**Better Solution**: Upgrade to Terraform 1.0+ (validation is standard)

### Error: "Failed to get existing workspaces"

**Cause**: S3 backend not configured or bucket doesn't exist

**Solution**:
```bash
# Check if bucket exists
aws s3 ls s3://terraform-state-bucket-386397333158

# If not, create it
./scripts/setup-backend.sh
```

### Error: "No valid credential sources found"

**Cause**: AWS credentials not configured

**Solution**:
```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1

# Verify
aws sts get-caller-identity
```

## State File Issues

### Error: "Error acquiring the state lock"

**Cause**: Another Terraform operation is running, or previous operation crashed

**Solution**:

1. **Check if operation is actually running:**
   ```bash
   # Check DynamoDB lock table
   aws dynamodb scan \
     --table-name terraform-locks-386397333158 \
     --filter-expression "LockID = :lockid" \
     --expression-attribute-values '{":lockid":{"S":"terraform-state-bucket-386397333158/ec2/terraform.tfstate-md5"}}'
   ```

2. **Wait for operation to complete** (if someone else is running it)

3. **Force unlock** (only if certain no operation is running):
   ```bash
   # Get lock ID from error message
   terraform force-unlock <LOCK_ID>
   ```

### Error: "State file does not match checksum"

**Cause**: State file was modified outside Terraform

**Solution**:
```bash
# Refresh state
terraform refresh

# If that doesn't work, restore from backup
# See STATE_MANAGEMENT.md for backup restoration
```

### Error: "Backend configuration changed"

**Cause**: Backend block in `provider.tf` was modified

**Solution**:
```bash
# Re-initialize with migration
terraform init -migrate-state

# Follow prompts
```

## Instance Issues

### Instance Stuck in "Pending" State

**Symptoms**: Instance shows "pending" for extended time

**Diagnosis**:
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check console output
aws ec2 get-console-output --instance-id <INSTANCE_ID>
```

**Common Causes & Solutions**:

1. **Insufficient Capacity:**
   ```bash
   # Try different availability zone
   # Or use different instance type
   ```

2. **IAM Role Issues:**
   ```bash
   # Check IAM role exists and has correct permissions
   aws iam get-role --role-name <ROLE_NAME>
   ```

3. **Security Group Issues:**
   ```bash
   # Verify security group exists
   aws ec2 describe-security-groups --group-ids <SG_ID>
   ```

### Instance Not Accessible via SSH

**Diagnosis**:
```bash
# Check instance state
aws ec2 describe-instances --instance-ids <INSTANCE_ID>

# Check security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>

# Check your IP
curl https://checkip.amazonaws.com
```

**Solutions**:

1. **Security Group Not Allowing Your IP:**
   ```hcl
   # Update terraform.tfvars
   allowed_ssh_cidr = "YOUR_IP/32"
   terraform apply
   ```

2. **Instance Not Running:**
   ```bash
   # Start instance
   aws ec2 start-instances --instance-ids <INSTANCE_ID>
   ```

3. **Wrong Key Pair:**
   ```bash
   # Verify key pair name
   aws ec2 describe-instances \
     --instance-ids <INSTANCE_ID> \
     --query 'Reservations[0].Instances[0].KeyName'
   ```

### Instance Terminated Unexpectedly

**Diagnosis**:
```bash
# Check termination reason
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].StateTransitionReason'

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix aws-terraform-project
```

**Common Causes**:
- Spot instance interruption
- Failed status checks
- Manual termination
- Cost/billing issues

**Prevention**:
- Use On-Demand instances (not Spot)
- Monitor CloudWatch alarms
- Enable detailed monitoring

## Network Issues

### Cannot Access Web Server

**Diagnosis**:
```bash
# Check instance is running
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check security group allows HTTP
aws ec2 describe-security-groups \
  --group-ids <SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# Test connectivity
curl -I http://<PUBLIC_IP>
```

**Solutions**:

1. **Security Group Missing HTTP Rule:**
   ```hcl
   # Ensure in terraform.tfvars
   allow_http_public = true
   terraform apply
   ```

2. **NGINX Not Running:**
   ```bash
   # SSH into instance
   ssh -i key.pem ubuntu@<IP>
   
   # Check NGINX status
   sudo systemctl status nginx
   
   # Start if stopped
   sudo systemctl start nginx
   ```

3. **Firewall Blocking:**
   ```bash
   # Check UFW status
   sudo ufw status
   
   # Allow HTTP if needed
   sudo ufw allow 80/tcp
   ```

### Public IP Not Assigned

**Cause**: Instance launched without public IP

**Solution**:
```bash
# Check if instance has public IP
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# If null, allocate Elastic IP and associate
aws ec2 allocate-address --domain vpc
aws ec2 associate-address \
  --instance-id <INSTANCE_ID> \
  --allocation-id <ALLOCATION_ID>
```

**Or update Terraform** to include `associate_public_ip_address = true` in EC2 module.

## User Data Script Failures

### User Data Not Executing

**Diagnosis**:
```bash
# Check user data logs
ssh -i key.pem ubuntu@<IP>
sudo cat /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log
```

**Common Causes**:

1. **Script Syntax Error:**
   ```bash
   # Test script locally first
   bash -n scripts/user_data.sh
   ```

2. **Script Too Long:**
   - User data limited to 16KB (base64 encoded)
   - Split into multiple scripts or use external source

3. **Permissions Issue:**
   ```bash
   # Ensure script is executable
   chmod +x scripts/user_data.sh
   ```

### User Data Partially Executing

**Diagnosis**:
```bash
# Check logs for errors
sudo tail -100 /var/log/user-data.log
sudo journalctl -u cloud-init
```

**Solution**:
- Add error handling to script
- Use `set -e` to exit on error
- Add logging throughout script

## CloudWatch Issues

### Alarms Not Triggering

**Diagnosis**:
```bash
# Check alarm configuration
aws cloudwatch describe-alarms \
  --alarm-names aws-terraform-project-high-cpu

# Check metric data
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions**:

1. **Enable Detailed Monitoring:**
   ```hcl
   enable_monitoring = true  # In terraform.tfvars
   terraform apply
   ```

2. **Check Alarm Threshold:**
   - Verify threshold is appropriate
   - Check evaluation periods

3. **Verify SNS Topic (if configured):**
   ```bash
   aws sns list-subscriptions
   ```

### Metrics Not Appearing

**Cause**: Detailed monitoring not enabled

**Solution**:
```hcl
# Enable in terraform.tfvars
enable_monitoring = true
terraform apply
```

**Note**: Detailed monitoring costs extra (~$2/month per instance)

## Authentication Errors

### Error: "Access Denied"

**Cause**: IAM user/role lacks required permissions

**Diagnosis**:
```bash
# Check current identity
aws sts get-caller-identity

# Test specific permission
aws ec2 describe-instances --dry-run
```

**Solution**:
- Add required IAM permissions
- Check policy attachments
- Verify region permissions

### Error: "InvalidClientTokenId"

**Cause**: Invalid AWS access key

**Solution**:
```bash
# Verify credentials
aws configure list

# Test credentials
aws sts get-caller-identity

# Re-configure if needed
aws configure
```

### Error: "SignatureDoesNotMatch"

**Cause**: Secret access key is incorrect

**Solution**:
```bash
# Re-configure with correct secret
aws configure
# Enter correct secret access key
```

## General Debugging Tips

### Enable Verbose Logging

```bash
# Terraform debug
export TF_LOG=DEBUG
terraform apply

# AWS CLI debug
aws --debug ec2 describe-instances
```

### Check Resource Status

```bash
# List all resources
terraform state list

# Show resource details
terraform state show <RESOURCE_ADDRESS>

# Refresh and plan
terraform refresh
terraform plan
```

### Validate Configuration

```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Check for unused variables
terraform validate -check-variables=false
```

## Getting Help

If you're still stuck:

1. **Check Terraform logs**: `TF_LOG=DEBUG terraform apply`
2. **Check AWS CloudTrail**: For API call history
3. **Check instance logs**: Via SSH or console output
4. **Review documentation**: [Terraform Docs](https://www.terraform.io/docs)
5. **GitHub Issues**: Create an issue with error details

## Related Documentation

- [State Management](STATE_MANAGEMENT.md)
- [SSH Access Guide](SSH_ACCESS_GUIDE.md)
- [Updating Infrastructure](UPDATING_INFRASTRUCTURE.md)
- [Main README](../README.md)

