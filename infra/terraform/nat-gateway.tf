resource "aws_internal_gateway" "nat" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gw NAT"
  }
}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internal_gateway.nat.id
  }

  tags = {
    "Name" = "infra-workshop-nat-gateway-route-table"
  }

  depends_on = [
    aws_nat_gateway.main
  ]
}

resource "aws_route_table_association" "nat" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.nat.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.private.id

  tags = {
    "Name" = "infra-workshop-nat-gateway"
  }
}

output "nat_gateway_ip" {
  value = aws_eip.nat.public_ip
}

resource "aws_route_table" "internal" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.internal.id
}