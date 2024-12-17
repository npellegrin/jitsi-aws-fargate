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

Create a `terraform.tfvars` file with the required parameters and replace with your own values:

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

# Networking and associated costs

This project is intended to be as close as possible as a "real" deployment, consequently, the Jitsi services are deployed in private subnets without a NAT gateway.

To make everything work, in particular, the Fargate image pulling, VPC endpoints are configured in the [vpc.tf](vpc.tf) file and deployed over two availability zone each. **This incur additional costs estimated to 60 USD per month** (4 VPC endpoints x 2 ENIs per VPC endpoint x 730 hours in a month x 0,01 USD = 58,40 USD).

In a real-world design, these costs would be mutualized over your projects, switched to NAT costs using a NAT gateway, or completely removed by putting everything into public subnets with public ips.

# Limitation

This is a demo Terraform stack. Consequently, it has the following limitations:

- There is no security hardening
- There is no scaling configuration
- There is no customization of the installation

# Docker Hub mirror

This project creates ECR registries to provide DockerHub mirrors inside AWS. You may, or may not use it, however, pulling DockerHub would require a NAT gateway or public IPs configured over ECS tasks (see [vpc.tf](vpc.tf))

If you use the private ECR registries, you must init registries with images pulled from DockerHub like below.

```shell
AWS_ACCOUNT_ID=...
AWS_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/jitsi-meet-mirror

docker pull jitsi/jicofo:jicofo-1.0-1118-1
docker tag jitsi/jicofo:jicofo-1.0-1118-1 ${AWS_REGISTRY}/jitsi/jicofo:jicofo-1.0-1118-1
docker push ${AWS_REGISTRY}/jitsi/jicofo:jicofo-1.0-1118-1

docker pull jitsi/jvb:jvb-2.3-187-gc7ef8e66-1
docker tag jitsi/jvb:jvb-2.3-187-gc7ef8e66-1 ${AWS_REGISTRY}/jitsi/jvb:jvb-2.3-187-gc7ef8e66-1
docker push ${AWS_REGISTRY}/jitsi/jvb:jvb-2.3-187-gc7ef8e66-1

docker pull jitsi/prosody:prosody-0.12.4
docker tag jitsi/prosody:prosody-0.12.4 ${AWS_REGISTRY}/jitsi/prosody:prosody-0.12.4
docker push ${AWS_REGISTRY}/jitsi/prosody:prosody-0.12.4

docker pull jitsi/web:web-1.0.8310-1
docker tag jitsi/web:web-1.0.8310-1 ${AWS_REGISTRY}/jitsi/web:web-1.0.8310-1
docker push ${AWS_REGISTRY}/jitsi/web:web-1.0.8310-1
```
