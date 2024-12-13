# Jitsi on AWS Fargate

A full Terraform demo stack deploying Jitsi in AWS Fargate.

# Required ecosystem

An AWS Route53 Hosted Zone with the domain you want for your Jitsi instance is required.

# Required parameters

| Parameter              | Description                                                               |
| ---------------------- | ------------------------------------------------------------------------- |
| aws_region             | The AWS region name where you wan to deploy Jitsi                         |
| aws_availability_zones | The list of avialability zones where Jitsi will be deployed               |
| allowed_account_ids    | Your AWS account identifier                                               |
| domain_name            | The domain name you want for Jitsi instance                               |
| hosted_zone_id         | The Hosted Zone identifier where records will be written for Jisti domain |


# How to deploy this software

Create a `terraform.tfvars` file with the required parameters:

```
aws_region             = ""
aws_availability_zones = []
allowed_account_ids    = []

domain_name    = ""
hosted_zone_id = ""
```

On an AWS account you own, run:

```
terraform apply
```

# Limitation

This is a demo Terraform stack. Consequently, it has the following limitations:

- There is no security hardening
- There is no scaling configuration
- There is no customization of the installation
