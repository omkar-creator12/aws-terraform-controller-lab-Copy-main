# AWS EC2 Terraform Controller & Nested Infrastructure

## Project Overview

This project demonstrates automated AWS infrastructure provisioning using Terraform. It includes an outer Terraform configuration for creating a controller EC2 instance and a nested Terraform configuration for provisioning an Amazon S3 bucket.

## Technologies Used

- Amazon Web Services (AWS)
- Amazon EC2
- AWS IAM and Instance Profiles
- Amazon S3
- Terraform
- Ubuntu Linux
- AWS CLI
- Git and GitHub
- MobaXterm

## Project Structure

```text
aws-terraform-controller-lab-Copy/
├── main.tf
├── README.md
├── .gitignore
├── .terraform.lock.hcl
├── terraform-ec2-controller/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── secondary-infra/
    └── main.tf
```

The nested configuration is maintained in the `secondary-infra` directory in the working environment. The repository structure should be kept synchronized with the actual files committed to GitHub.

## Stage 1: Outer Terraform Configuration

The outer configuration defines the infrastructure required for a Terraform controller:

- Ubuntu 24.04 LTS EC2 instance
- IAM role and instance profile
- IAM policy attachment
- SSH key pair
- Security group with restricted SSH access
- Automated Terraform installation using EC2 user data

The configuration is located in `terraform-ec2-controller/`.

## Stage 2: Nested Terraform Deployment

The nested Terraform configuration provisions an Amazon S3 bucket using the AWS provider and a generated random suffix.

Resources:

- `random_id.bucket_suffix`
- `aws_s3_bucket.test_bucket`

The EC2 instance uses its attached IAM role for AWS authentication.

## Deployment and Verification Commands

Initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Review the proposed changes:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

Verify the AWS identity:

```bash
aws sts get-caller-identity
```

Verify the S3 bucket:

```bash
aws s3api head-bucket --bucket YOUR_BUCKET_NAME --region us-east-1
```

Display Terraform outputs:

```bash
terraform output
```

## Security Considerations

- Do not commit private SSH keys, credentials, or Terraform state files.
- Restrict SSH access to trusted IP addresses.
- Use IAM roles instead of hardcoded AWS access keys.
- Apply least-privilege IAM permissions whenever possible.
- Remove lab resources when they are no longer needed.

## Cleanup

Run `terraform destroy` in the relevant Terraform workspace to remove resources managed by that workspace. Verify the planned deletions before confirming. Resources created by a different Terraform state must be cleaned up separately.

## Deployment Notes

The initial controller was created manually, and an additional controller was provisioned through the outer Terraform configuration. The nested S3 deployment was verified successfully. The final report should document these implementation details accurately.
