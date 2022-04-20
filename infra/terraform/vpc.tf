variable "region" {
  default     = "ap-northeast-3"
  description = "AWS region"
}

data "aws_availability_zones" "available" {
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "infra-workshrp"
  }
}
