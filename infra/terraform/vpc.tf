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
    Name = "terraform-101"
  }
}

locals {
  subnet = {
    public = ["10.0.0.0/26", "10.0.0.64/26"]
    private = ["10.0.0.128/27"]
    bastion = ["10.0.0.160/27"]
  }
}

resource "aws_subnet" "main_subnet_public" {
  count = length(local.subnet.public)

  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.public[count.index]}"

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name = "main_subnet_public_${count.index}"
  }
}

resource "aws_subnet" "main_subnet_private" {
  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.private[0]}"

  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  
  tags = {
    Name = "main_subnet_private"
  }
}

resource "aws_subnet" "main_subnet_bastion" {
  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.bastion[0]}"

  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  
  tags = {
    Name = "main_subnet_bastion"
  }
}
