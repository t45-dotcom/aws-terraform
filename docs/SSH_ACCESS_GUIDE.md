# SSH Access Guide

This guide explains how to SSH into your EC2 instances created by Terraform.

## Prerequisites

1. **EC2 Key Pair**: You need an EC2 Key Pair configured
2. **Security Group**: SSH access must be allowed from your IP
3. **Instance Running**: The instance must be in "running" state

## Step 1: Create or Use an EC2 Key Pair

### Option A: Create a New Key Pair

1. **Via AWS Console:**
   - Go to EC2 → Key Pairs → Create key pair
   - Name: `my-terraform-key`
   - Key pair type: `RSA`
   - Private key file format: `.pem`
   - Click "Create key pair"
   - **Save the `.pem` file** - you won't be able to download it again!

2. **Via AWS CLI:**
   ```bash
   aws ec2 create-key-pair \
     --key-name my-terraform-key \
     --query 'KeyMaterial' \
     --output text > my-terraform-key.pem
   
   # Set proper permissions
   chmod 400 my-terraform-key.pem
   ```

### Option B: Use Existing Key Pair

If you already have a key pair, note its name for use in `terraform.tfvars`.

## Step 2: Configure Terraform

Add the key pair name to your `terraform.tfvars`:

```hcl
key_pair_name = "my-terraform-key"
```

## Step 3: Get Instance Information

After deployment, get the instance details:

```bash
# Get public IP
terraform output instance_public_ip

# Get SSH command (already formatted)
terraform output ssh_command
```

## Step 4: Connect via SSH

### Basic SSH Connection

```bash
ssh -i /path/to/your-key.pem ubuntu@<PUBLIC_IP>
```

Example:
```bash
ssh -i ~/.ssh/my-terraform-key.pem ubuntu@54.159.47.64
```

### Using the Output Command

Terraform provides a pre-formatted SSH command:

```bash
# Get the command
terraform output ssh_command

# Copy and paste, replacing <your-key.pem> with your actual key path
ssh -i <your-key.pem> ubuntu@54.159.47.64
```

### SSH Configuration (Recommended)

Create `~/.ssh/config` for easier access:

```bash
# Edit SSH config
nano ~/.ssh/config
```

Add:
```
Host terraform-ec2
    HostName <PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/my-terraform-key.pem
    StrictHostKeyChecking no
```

Then connect simply:
```bash
ssh terraform-ec2
```

## Step 5: Verify Connection

Once connected, you should see:

```bash
Welcome to Ubuntu 22.04 LTS
...
ubuntu@ip-172-31-19-30:~$
```

## Troubleshooting

### Error: "Permission denied (publickey)"

**Causes:**
- Wrong key file
- Incorrect permissions on key file
- Wrong username (should be `ubuntu` for Ubuntu AMIs)

**Solutions:**
```bash
# Fix key permissions
chmod 400 /path/to/your-key.pem

# Verify you're using the correct username
# Ubuntu: ubuntu
# Amazon Linux: ec2-user
# CentOS: centos
```

### Error: "Connection timed out"

**Causes:**
- Security group doesn't allow your IP
- Instance not running
- Wrong public IP

**Solutions:**
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>

# Verify your IP is allowed
# Update allowed_ssh_cidr in terraform.tfvars with YOUR_IP/32
```

### Error: "Host key verification failed"

**Solution:**
```bash
# Remove old host key
ssh-keygen -R <PUBLIC_IP>

# Or add to known_hosts
ssh-keyscan -H <PUBLIC_IP> >> ~/.ssh/known_hosts
```

### Error: "WARNING: UNPROTECTED PRIVATE KEY FILE!"

**Solution:**
```bash
# Set correct permissions
chmod 400 /path/to/your-key.pem

# Verify
ls -l /path/to/your-key.pem
# Should show: -r--------
```

### Can't Find Public IP

**Solution:**
```bash
# Get from Terraform
terraform output instance_public_ip

# Or from AWS CLI
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

## Security Best Practices

1. **Restrict SSH Access:**
   ```hcl
   # In terraform.tfvars
   allowed_ssh_cidr = "YOUR_IP/32"  # Not 0.0.0.0/0!
   ```

2. **Use Key Pairs:**
   - Always use EC2 Key Pairs, never passwords
   - Keep private keys secure
   - Don't commit keys to git

3. **Rotate Keys:**
   - Regularly rotate key pairs
   - Remove old keys from instances

4. **Use SSH Agent:**
   ```bash
   # Add key to SSH agent
   ssh-add ~/.ssh/my-terraform-key.pem
   
   # Then connect without -i flag
   ssh ubuntu@<PUBLIC_IP>
   ```

## Common Commands After SSH

```bash
# Check system info
uname -a
df -h
free -m

# Check NGINX status
sudo systemctl status nginx

# View user data logs
sudo cat /var/log/user-data.log

# View NGINX logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Next Steps

- [How to Update Infrastructure](UPDATING_INFRASTRUCTURE.md)
- [Troubleshooting Guide](ADVANCED_TROUBLESHOOTING.md)
- [Main README](../README.md)

