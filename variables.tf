variable "aws_region" {
  default = "ap-south-1"
}

variable "iam_user_name" {
  default = "example-iam-user"
}

variable "bucket_name" {
  default = "example-terraform-s3-bucket-12345"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  description = "Static AMI id (avoids a live data.aws_ami lookup at plan time)"
  default     = "ami-0c55b159cbfafe1f0"
}

variable "key_name" {
  description = "EC2 key pair name"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "my_ip" {
  description = "Your public IP for SSH access (x.x.x.x/32)"
}
