terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------- Availability Zones ----------------

data "aws_availability_zones" "available" {}

# ---------------- AMI ----------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------- VPC ----------------

resource "aws_vpc" "main_vpc" {
  cidr_block           = "192.168.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "project-vpc" }
}

# ---------------- Subnets ----------------

# Public Subnet (AZ-1)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "192.168.0.0/26"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = { Name = "public-subnet" }
}

# Private Subnet 1 (AZ-1)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "192.168.0.64/26"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "private-subnet-1" }
}

# Private Subnet 2 (AZ-2)
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "192.168.0.128/26"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = { Name = "private-subnet-2" }
}

# ---------------- Internet Gateway ----------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# ---------------- Route Table ----------------

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route.id
}

# ---------------- Security Groups ----------------

# EC2 Security Group
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "ec2-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # change to your IP in production
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "rds-sg"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- RDS ----------------

resource "aws_db_subnet_group" "db_subnet_group" {
  name = "db-subnet-group"

  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = { Name = "db-subnet-group" }
}

resource "aws_db_instance" "mysql_db" {
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "webshop"
  username                = var.db_username
  password                = var.db_password
  skip_final_snapshot     = true
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
}

# ---------------- EC2 ----------------

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
apt update -y
apt install -y nginx git curl

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
npm install -g pm2

cd /home/ubuntu
git clone https://github.com/Kavin9898/PROJECT-new.git
cd PROJECT-new/backend
npm install

echo "DB_HOST=${aws_db_instance.mysql_db.address}" >> /etc/environment
echo "DB_USER=${var.db_username}" >> /etc/environment
echo "DB_PASSWORD=${var.db_password}" >> /etc/environment

pm2 start server.js
pm2 startup systemd
pm2 save

systemctl restart nginx
EOF

  tags = { Name = "App-Server" }
}
