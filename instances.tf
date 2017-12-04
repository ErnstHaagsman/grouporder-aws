variable "key" {
  type = "string"
}

provider "aws" {
  region = "eu-central-1"
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

resource "aws_security_group" "web" {
  name        = "management_host"
  description = "Allow inbound HTTP and HTTPS traffic"
  vpc_id      = "${aws_vpc.grouporder_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.management_host.id}"
    ]
    description = "Inbound SSH traffic from management host only"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Incoming HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Incoming HTTPS traffic"
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
      "${aws_security_group.management_host.id}",
      "${aws_security_group.web.id}"
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

  provisioner "file" {
    content = "${data.template_file.inventory.rendered}"
    destination = "/etc/ansible/inventory"
  }
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

resource "aws_instance" "web" {
  ami = "ami-df8406b0" # Ubuntu 16.04
  instance_type = "t2.micro"

  key_name = "${var.key}"

  subnet_id = "${aws_subnet.public_subnet.id}"

  security_groups = [
    "${aws_security_group.web.id}"
  ]
}