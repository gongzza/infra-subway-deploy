
resource "aws_security_group" "external" {
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
    cidr_blocks = [
      aws_subnet.bastion.cidr_block,
      # "0.0.0.0/0"
    ]
    protocol = "tcp"
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_main_internal" {
  name = "sg_main_internal"
  description = "sg_main_internal"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port = 3306
    cidr_blocks = aws_subnet.public.*.cidr_block
    protocol = "tcp"
  }

  ingress {
    from_port = 22
    to_port = 22
    cidr_blocks = [aws_subnet.bastion.cidr_block]
    protocol = "tcp"
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "bastion" {
  name = "sg_main_bastion"
  description = "sg_main_bastion"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "${chomp(data.http.myip.body)}/32"
    ]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}