# Frequently Asked Questions (FAQ)

Common questions and answers about this Terraform project.

## General Questions

### Q: What is this project?

**A**: This is an Infrastructure-as-Code (IaC) project that automates the deployment of AWS EC2 instances using Terraform. It includes EC2 instances, security groups, CloudWatch monitoring, and CI/CD integration.

### Q: Do I need to know Terraform to use this?

**A**: Basic knowledge helps, but the documentation is designed to guide beginners. Start with [QUICKSTART.md](QUICKSTART.md) for step-by-step instructions.

### Q: How much does this cost?

**A**: 
- **Free Tier**: t3.micro instances are free for 12 months (750 hours/month)
- **After Free Tier**: ~$10-15/month for t3.micro instance + storage + monitoring
- **S3 Backend**: ~$0.023/GB/month (state files are tiny, essentially free)
- **DynamoDB**: Free tier covers small tables

See [README.md](../README.md#-cost-optimization) for detailed cost breakdown.

### Q: Can I use this for production?

**A**: Yes, but consider:
- Review security settings (SSH access, security groups)
- Enable monitoring
- Set up proper backups
- Use appropriate instance sizes
- Follow best practices in documentation

## Setup Questions

### Q: Do I need an AWS account?

**A**: Yes, you need an AWS account. Sign up at [aws.amazon.com](https://aws.amazon.com). Free tier includes 12 months of free usage for eligible services.

### Q: What AWS permissions do I need?

**A**: You need permissions for:
- EC2 (create/delete instances, security groups)
- VPC (read default VPC)
- CloudWatch (create alarms, metrics)
- S3 (for state backend)
- DynamoDB (for state locking)

See [README.md](../README.md#aws-account-setup) for details.

### Q: Can I use this without S3 backend?

**A**: Yes, for local development. Comment out the backend block in `provider.tf`. However, S3 backend is required for CI/CD and team collaboration.

### Q: How do I find my AWS account ID?

**A**:
```bash
aws sts get-caller-identity --query Account --output text
```

Or check the top-right corner of AWS Console.

## Configuration Questions

### Q: How do I change the instance type?

**A**: Edit `terraform.tfvars`:
```hcl
instance_type = "t3.small"  # Change from t3.micro
```

Then run:
```bash
terraform plan
terraform apply
```

**Note**: This will replace the instance (destroy and recreate).

### Q: How do I change the region?

**A**: Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"  # Change from us-east-1
```

**Note**: You'll need to update the S3 backend region too, or create a new backend in the new region.

### Q: How do I restrict SSH access to my IP only?

**A**: 
1. Find your IP: [whatismyipaddress.com](https://whatismyipaddress.com)
2. Edit `terraform.tfvars`:
   ```hcl
   allowed_ssh_cidr = "YOUR_IP/32"  # Replace YOUR_IP
   ```
3. Apply:
   ```bash
   terraform apply
   ```

### Q: Can I use an existing security group?

**A**: Yes, but you'd need to modify the security group module. The current setup creates a new security group. For existing groups, you'd modify `main.tf` to reference an existing security group ID.

### Q: How do I add more ports to the security group?

**A**: Edit `modules/security-group/main.tf` and add new ingress rules. See [UPDATING_INFRASTRUCTURE.md](UPDATING_INFRASTRUCTURE.md) for details.

## Deployment Questions

### Q: How long does deployment take?

**A**: Typically 2-5 minutes:
- Security group: ~10 seconds
- EC2 instance: ~1-2 minutes
- CloudWatch alarms: ~10 seconds
- User data script: Runs in background after instance starts

### Q: How do I know when deployment is complete?

**A**: 
```bash
# Check outputs
terraform output

# Verify instance is running
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>
```

### Q: Can I deploy multiple instances?

**A**: Yes, you can:
1. Use the module multiple times in `main.tf`
2. Or use `count` or `for_each` in the module
3. See [UPDATING_INFRASTRUCTURE.md](UPDATING_INFRASTRUCTURE.md) for examples

### Q: What happens if deployment fails?

**A**: Terraform will:
- Show error message
- Keep partially created resources
- Allow you to fix and retry

Run `terraform plan` to see what will be created/modified on retry.

## Access Questions

### Q: How do I SSH into the instance?

**A**: See [SSH_ACCESS_GUIDE.md](SSH_ACCESS_GUIDE.md) for detailed instructions.

Quick version:
```bash
# Get SSH command
terraform output ssh_command

# Replace <your-key.pem> with your key path
ssh -i /path/to/key.pem ubuntu@<PUBLIC_IP>
```

### Q: How do I access the web server?

**A**: 
```bash
# Get URL
terraform output instance_url

# Or use public IP
curl http://$(terraform output -raw instance_public_ip)
```

### Q: Why can't I SSH into the instance?

**A**: Common causes:
1. Security group doesn't allow your IP
2. Instance not fully started
3. Wrong key pair
4. Wrong username (should be `ubuntu` for Ubuntu AMIs)

See [SSH_ACCESS_GUIDE.md](SSH_ACCESS_GUIDE.md#troubleshooting) for solutions.

## State Questions

### Q: What is Terraform state?

**A**: State is a file that tracks which real-world resources correspond to your configuration. See [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) for details.

### Q: Can I delete the state file?

**A**: **No!** The state file is critical. Without it, Terraform can't manage your resources. It's stored in S3 and automatically backed up via versioning.

### Q: What if I lose my state file?

**A**: 
1. Check S3 versioning for previous versions
2. Restore from backup (see [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md))
3. Or import existing resources back into state

### Q: Can multiple people work on this?

**A**: Yes! The S3 backend with DynamoDB locking prevents conflicts. Multiple people can work, but only one `terraform apply` can run at a time.

## Destroy Questions

### Q: What happens when I run `terraform destroy`?

**A**: All resources created by Terraform are destroyed:
- EC2 instance
- Security groups
- CloudWatch alarms
- IAM roles (if created)

See [DESTROY_AND_BACKUP.md](DESTROY_AND_BACKUP.md) for details.

### Q: Will destroying remove my S3 backend?

**A**: No. The S3 bucket and DynamoDB table persist. They're not managed by this Terraform configuration.

### Q: How do I backup before destroying?

**A**: See [DESTROY_AND_BACKUP.md](DESTROY_AND_BACKUP.md) for backup procedures.

## CI/CD Questions

### Q: How do I set up GitHub Actions?

**A**: See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for step-by-step instructions.

### Q: Do I need GitHub Actions?

**A**: No, it's optional. You can use Terraform locally. GitHub Actions is for automated deployments.

### Q: How do I run the workflow manually?

**A**: See [HOW_TO_RUN_WORKFLOW.md](../HOW_TO_RUN_WORKFLOW.md) for instructions.

### Q: Can I use other CI/CD systems?

**A**: Yes! The workflow is GitHub Actions-specific, but you can adapt it for:
- GitLab CI
- Jenkins
- CircleCI
- AWS CodePipeline
- etc.

## Troubleshooting Questions

### Q: I get "Provider source not supported" error

**A**: You're using Terraform < 1.0. Upgrade to Terraform 1.0+:
```bash
# Check version
terraform version

# Upgrade (macOS)
brew upgrade terraform

# Or download from hashicorp.com
```

### Q: I get "Custom variable validation is experimental" error

**A**: Upgrade to Terraform 1.0+ (variable validation is built-in).

### Q: Instance is stuck in "pending" state

**A**: 
- Wait a few minutes (can take 2-5 minutes)
- Check AWS Console for errors
- Check instance console output
- See [ADVANCED_TROUBLESHOOTING.md](ADVANCED_TROUBLESHOOTING.md)

### Q: I can't access the web server

**A**: 
- Check security group allows HTTP (port 80)
- Check instance is running
- Check NGINX is running (SSH in and check)
- See [ADVANCED_TROUBLESHOOTING.md](ADVANCED_TROUBLESHOOTING.md)

### Q: Terraform says resource doesn't exist, but I see it in AWS

**A**: State file is out of sync. Run:
```bash
terraform refresh
terraform plan
```

## Security Questions

### Q: Is it safe to commit my terraform.tfvars?

**A**: **No!** Never commit `terraform.tfvars` - it may contain secrets. It's already in `.gitignore`.

### Q: Where should I store my AWS credentials?

**A**: 
- Local: `terraform.tfvars` (not committed) or environment variables
- CI/CD: GitHub Secrets
- Production: AWS Secrets Manager or SSM Parameter Store

See [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) for details.

### Q: How do I rotate my AWS credentials?

**A**: 
1. Create new credentials
2. Update `terraform.tfvars` or GitHub Secrets
3. Test new credentials
4. Delete old credentials

See [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) for details.

## Still Have Questions?

- Check the [Main README](../README.md)
- Review specific guides in `docs/` folder
- Check [Troubleshooting Guide](ADVANCED_TROUBLESHOOTING.md)
- Create an issue on GitHub
- Check [Terraform Documentation](https://www.terraform.io/docs)

