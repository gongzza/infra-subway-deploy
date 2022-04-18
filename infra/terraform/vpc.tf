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
    bastion = ["10.0.0.0/27"]
    private = ["10.0.0.32/27"]
    public = ["10.0.0.64/26", "10.0.0.128/26"]
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

  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  
  tags = {
    Name = "main_subnet_private"
  }
}

resource "aws_subnet" "main_subnet_bastion" {
  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.bastion[0]}"

  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  
  tags = {
    Name = "main_subnet_bastion"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "main"
  }
}

resource "aws_security_group" "sg_main_external" {
  name = "sg_main_external"
  description = "sg_main_external"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 8080
    to_port = 8080
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }

  ingress {
    from_port = 22
    to_port = 22
    cidr_blocks = [aws_subnet.main_subnet_bastion.cidr_block]
    protocol = "tcp"
  }
}

resource "aws_security_group" "sg_main_internal" {
  name = "sg_main_internal"
  description = "sg_main_internal"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port = 3306
    cidr_blocks = aws_subnet.main_subnet_public.*.cidr_block
    protocol = "tcp"
  }

  ingress {
    from_port = 22
    to_port = 22
    cidr_blocks = [aws_subnet.main_subnet_bastion.cidr_block]
    protocol = "tcp"
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "sg_main_bastion" {
  name = "sg_main_bastion"
  description = "sg_main_bastion"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.main_subnet_public[0].id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.sg_main_external.id
  ]

  tags = {
    "Name" = "ec2-web"
  }
}

resource "aws_instance" "db" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.main_subnet_private.id

  vpc_security_group_ids = [
    aws_security_group.sg_main_internal.id
  ]

  tags = {
    "Name" = "ec2-db"
  }
}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.main_subnet_bastion.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.sg_main_bastion.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    sudo amazon-linux-extras install nginx1.12 -y
    sudo nginx
  EOF


  tags = {
    "Name" = "ec2-bastion"
  }
}