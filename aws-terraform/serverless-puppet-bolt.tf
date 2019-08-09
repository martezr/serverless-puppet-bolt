provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

## Puppet Bolt builder
resource "aws_iam_instance_profile" "serverless-puppet-bolt" {
  name = "serverless-puppet-bolt-instance-profile"
  role = aws_iam_role.serverless-puppet-bolt.name
}

resource "aws_iam_role" "serverless-puppet-bolt" {
  name               = "serverless-puppet-bolt-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "serverless-puppet-bolt" {
  name   = "serverless-puppet-bolt-role-policy"
  role   = aws_iam_role.serverless-puppet-bolt.id
  policy = data.aws_iam_policy_document.serverless-puppet-bolt.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "serverless-puppet-bolt" {
  statement {
    sid    = "LambdaAccess"
    effect = "Allow"
    actions = [
      "lambda:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMAccess"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:PassRole",
      "iam:PutRolePolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:PutBucketNotification",
      "s3:PutBucketPolicy",
      "s3:PutBucketTagging",
      "s3:PutBucketWebsite",
      "s3:PutEncryptionConfiguration",
      "s3:PutObject",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFormationAccess"
    effect = "Allow"
    actions = [
      "cloudformation:CancelUpdateStack",
      "cloudformation:ContinueUpdateRollback",
      "cloudformation:CreateChangeSet",
      "cloudformation:CreateStack",
      "cloudformation:CreateUploadBucket",
      "cloudformation:DeleteStack",
      "cloudformation:Describe*",
      "cloudformation:EstimateTemplateCost",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:Get*",
      "cloudformation:List*",
      "cloudformation:PreviewStackUpdate",
      "cloudformation:UpdateStack",
      "cloudformation:UpdateTerminationProtection",
      "cloudformation:ValidateTemplate",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LogGroupAccess"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
    ]

    resources = ["*"]
  }
}

module "serverless-puppet-bolt" {
  source         = "terraform-aws-modules/ec2-instance/aws"
  instance_count = 1

  name                        = "serverless-puppet-bolt"
  ami                         = data.aws_ami.amazon_linux.id
  associate_public_ip_address = true
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.serverless-puppet-bolt.id
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  user_data                   = file("serverless-puppet-bolt.sh")

  tags = {
    DeployFrom = "terraform"
  }
}

