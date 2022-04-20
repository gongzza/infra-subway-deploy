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
  instance_type = "t2.micro"
  ami = "${data.aws_ami.ubuntu.id}"
  subnet_id = aws_subnet.public[0].id
  key_name = "test-EC2-key"

  vpc_security_group_ids = [
    aws_security_group.external.id
  ]

  tags = {
    "Name" = "ec2-web"
  }
}

resource "aws_eip" "web" {
  instance = aws_instance.web.id
  vpc = true
}

output "web_ip" {
  value = aws_eip.web.public_ip
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}

resource "aws_instance" "db" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  key_name = "test-EC2-key"
  subnet_id = aws_subnet.main_subnet_private.id


  vpc_security_group_ids = [
    aws_security_group.internal.id
  ]

  tags = {
    "Name" = "ec2-db"
  }
}

output "db_ip" {
  value = aws_eip.db.private_ip
}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.main_subnet_bastion.id
  associate_public_ip_address = true

  key_name = "test-EC2-key"

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    HISTTIMEFORMAT="%F %T -- "    ## history 명령 결과에 시간값 추가
    export HISTTIMEFORMAT
    export TMOUT=600              ## 세션 타임아웃 설정 
  EOF

  tags = {
    "Name" = "ec2-bastion"
  }
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  vpc = true
}

output "bastion_ip" {
  value = aws_eip.bastion.public_ip
}
