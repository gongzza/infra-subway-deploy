
locals {
  subnet = {
    bastion = ["10.0.0.0/27"]
    private = ["10.0.0.32/27"]
    public = ["10.0.0.64/26", "10.0.0.128/26"]
  }
}

resource "aws_subnet" "public" {
  count = length(local.subnet.public)

  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.public[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name = "infra-workshop-public${count.index}"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.private[0]}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "private"
  }
}

resource "aws_subnet" "bastion" {
  vpc_id = aws_vpc.main.id
  cidr_block = "${local.subnet.bastion[0]}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "bastion"
  }
}
