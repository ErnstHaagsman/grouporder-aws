variable "key" {
  type = "string"
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "grouporder_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}"
}

resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}"
}

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}",
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public_table" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = "${aws_egress_only_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "public_table_association" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public_table.id}"
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = ["aws_internet_gateway.main"]
}

resource "aws_nat_gateway" "nat" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  allocation_id = "${aws_eip.nat.id}"

  depends_on = ["aws_internet_gateway.main"]
}

resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}",
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = false
}


resource "aws_route_table" "private_table" {
  vpc_id = "${aws_vpc.grouporder_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = "${aws_egress_only_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "private_table_association" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.private_table.id}"
}

resource "aws_security_group" "management_host" {
  name        = "management_host"
  description = "Allow inbound SSH traffic"
  vpc_id      = "${aws_vpc.grouporder_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "database"
  description = "Allow internal DB and SSH traffic"
  vpc_id      = "${aws_vpc.grouporder_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.management_host.id}"
    ]
    description = "Inbound SSH traffic"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.management_host.id}"
    ]
    description = "PostgreSQL"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "management" {
  ami = "ami-df8406b0" # Ubuntu 16.04
  instance_type = "t2.micro"

  key_name = "${var.key}"

  subnet_id = "${aws_subnet.public_subnet.id}"

  security_groups = [
    "${aws_security_group.management_host.id}"
  ]
}

resource "aws_instance" "database" {
  ami = "ami-df8406b0" # Ubuntu 16.04
  instance_type = "t2.micro"

  key_name = "${var.key}"

  subnet_id = "${aws_subnet.private_subnet.id}"

  security_groups = [
    "${aws_security_group.db.id}"
  ]
}