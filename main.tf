# -----------------------------
# IAM USER
# -----------------------------
resource "aws_iam_user" "user" {
  name = var.iam_user_name
}

# -----------------------------
# S3 BUCKET
# -----------------------------
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
}

# -----------------------------
# IAM ROLE FOR EC2
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# -----------------------------
# IAM POLICY (S3 ACCESS)
# -----------------------------
resource "aws_iam_policy" "s3_policy" {
  name = "ec2-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# -----------------------------
# INSTANCE PROFILE
# -----------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------
# EC2 INSTANCE
# Static AMI (no data.aws_ami lookup) so plan-only runs need no AWS
# credentials and reliably reach policy evaluation. Plan does not validate
# that the AMI id exists.
# -----------------------------
resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true # deterministic FAIL: ec2-instance-no-public-ip (EC2.9)

  tags = {
    Name = "terraform-ec2"
  }
}

# -----------------------------
# EBS VOLUMES — deterministic pass/fail pair for the OOTB
# `encrypted-volumes` (EC2.3) tfpolicy: one encrypted (PASS), one not (FAIL).
# A single policy therefore reports passed >= 1 AND advisory-failed >= 1.
# -----------------------------
resource "aws_ebs_volume" "compliant" {
  availability_zone = "${var.aws_region}a"
  size              = 8
  encrypted         = true # PASS

  tags = {
    Name = "t32-ebs-compliant"
  }
}

resource "aws_ebs_volume" "noncompliant" {
  availability_zone = "${var.aws_region}a"
  size              = 8
  encrypted         = false # FAIL

  tags = {
    Name = "t32-ebs-noncompliant"
  }
}


# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# -----------------------------
# INTERNET GATEWAY
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# -----------------------------
# PUBLIC SUBNET
# -----------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "public-subnet"
  }
}

# -----------------------------
# ROUTE TABLE
# -----------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}
