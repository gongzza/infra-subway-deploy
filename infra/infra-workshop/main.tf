variable "region" {
  default     = "ap-northeast-3"
  description = "AWS region"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "InfraWorkshop"
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

data "aws_availability_zones" "available" {}

locals {
  subnet = {
    ssh = ["10.0.0.0/27"]
    db = ["10.0.0.32/27"]
    web = ["10.0.0.64/26", "10.0.0.128/26"]
  }
}

resource "aws_subnet" "ssh" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "${local.subnet.ssh[0]}"
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "InfraWorkshopBastionSubnet"
  }
}

resource "aws_subnet" "web" {
  count = length(local.subnet.web)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block = "${local.subnet.web[count.index]}"
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "InfraWorkshopPublicSubnet${count.index}"
  }
}

resource "aws_subnet" "db" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "${local.subnet.db[0]}"
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "InfraWorkshopPrivateSubnet"
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "ssh" {
  name = "InfraWorkshopSshSecurityGroup"
  description = "InfraWorkshopSshSecurityGroup"
  vpc_id = aws_vpc.main.id

  ingress {
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    "Name" = "InfraWorkshopSshSecurityGroup"
  }
}

resource "aws_security_group" "db" {
  name = "InfraWorkshopDbSecurityGroup"
  description = "InfraWorkshopDbSecurityGroup"
  vpc_id = aws_vpc.main.id

  ingress {
    cidr_blocks = aws_subnet.web.*.cidr_block
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [aws_subnet.ssh.cidr_block]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    "Name" = "InfraWorkshopDbSecurityGroup"
  }
}

resource "aws_security_group" "web" {
  name = "InfraWorkshopWebSecurityGroup"
  description = "InfraWorkshopWebSecurityGroup"
  vpc_id = aws_vpc.main.id

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [aws_subnet.ssh.cidr_block]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    "Name" = "InfraWorkshopWebSecurityGroup"
  }
}

resource "aws_instance" "db" {
  instance_type = "t3.micro"
  ami = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.db.id
  security_groups = [aws_security_group.db.id]
  key_name = "test-EC2-key"
  tags = {
    "Name" = "InfraWorkshopDatabaseMachine"
  }
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "InfraWorkshopGateway"
  }
}

resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "web" {
  count = length(aws_subnet.web)
  subnet_id = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.igw.id
}

resource "aws_route_table_association" "ssh" {
  subnet_id = aws_subnet.ssh.id
  route_table_id = aws_route_table.igw.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.ssh.id

  tags = {
    "Name" = "InfraWorkshoptNatGateway"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

output "nat_gateway_ip" {
  value = aws_eip.nat.public_ip
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "db" {
  subnet_id = aws_subnet.db.id
  route_table_id = aws_route_table.db.id
}

resource "aws_instance" "web" {
  instance_type = "t2.micro"
  ami = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.web[0].id
  security_groups = [aws_security_group.ssh.id]
  associate_public_ip_address = true
  key_name = "test-EC2-key"
  tags = {
    "Name" = "InfraWorkshopWebMachine"
  }
}

output "web_public_ip" {
  value = aws_instance.web.public_ip
}

resource "aws_instance" "bastion" {
  instance_type = "t2.micro"
  ami = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.ssh.id
  security_groups = [aws_security_group.ssh.id]
  associate_public_ip_address = true
  key_name = "test-EC2-key"
  tags = {
    "Name" = "InfraWorkshopBastionMachine"
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}