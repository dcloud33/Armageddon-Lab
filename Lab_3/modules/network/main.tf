data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip"
  })
}

resource "aws_subnet" "subnet_public_1" {
  count                     = length(var.public_subnet_cidrs)
  vpc_id                    = aws_vpc.vpc.id
  cidr_block                = var.public_subnet_cidrs[count.index]
  availability_zone         = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
  })
}

resource "aws_subnet" "subnet_private_1" {
  count               = length(var.private_subnet_cidrs)
  vpc_id              = aws_vpc.vpc.id
  cidr_block          = var.private_subnet_cidrs[count.index]
  availability_zone   = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "my_nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_public_1[0].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_default_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "route_table_association" {
  count          = length(aws_subnet.subnet_public_1)
  subnet_id      = aws_subnet.subnet_public_1[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "my_private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route" "private_default_route" {
  route_table_id         = aws_route_table.my_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat.id
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(aws_subnet.subnet_private_1)
  subnet_id      = aws_subnet.subnet_private_1[count.index].id
  route_table_id = aws_route_table.my_private_route_table.id
}