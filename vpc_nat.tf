provider "aws" {
  region          = "ap-south-1"
  profile         = "testuser"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "pub-sub" {
  vpc_id     = "${aws_vpc.myvpc.id}"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "pub-sub"  
  }
}
resource "aws_subnet" "priv-sub" {
  vpc_id     = "${aws_vpc.myvpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "priv-sub"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.myvpc.id}"
  tags = {
    Name = "igw"
  }  
}

resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
      }
   tags = {
    Name = "route_table"
  }
}

resource "aws_route_table_association" "my-assoc" {
  subnet_id      = aws_subnet.pub-sub.id
  route_table_id = aws_route_table.my-rt.id
}

resource "aws_route" "my-route" {
  route_table_id = aws_route_table.my-rt.id
  destination_cidr_block ="0.0.0.0/0"
  gateway_id     = aws_internet_gateway.igw.id
}






variable "x" {
  type = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDYDiGssqInIpqspHrMlS3kw0itcz51Ve0DP015IWXGvxmOe/4fffIsx0S1+utUDPgNusfa+1tk0vJ5HqGN4/dWG8iYkXCAFJoHmmX8ABfQ+IUsAifPSSsLCTXZHfUgEG6uOmLwmsJaANl0jhwEQ5+CnQetZwzYSFJvuHZWLSfY3Q=="
}

resource "aws_key_pair" "my-kp" {
  key_name   = "keyterra"
  public_key = var.x
}


resource "aws_security_group" "wp-sg" {
  name        = "wp-sg"
  description = "alow 22 and 80 port only"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "ssh"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "http"
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name ="my-sg"
  }
}

resource "aws_security_group" "db-sg" {
  name        = "mysql-sg"
  description = "MYSQL-setup"
  vpc_id      = "${aws_vpc.myvpc.id}"

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 7
    to_port     = 7
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sgroup"
  }
}


resource "aws_eip" "elastic_ip" {
  vpc      = true
}
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.elastic_ip.id}"
  subnet_id     = "${aws_subnet.pub-sub.id}"
  depends_on    = [ aws_eip.elastic_ip ]
}

resource "aws_route_table" "nat-route" {
  vpc_id = "${aws_vpc.myvpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gw.id}"
  }
  tags = {
    Name = "nat-routetable"
  }
}

resource "aws_route_table_association" "nat-b" {
  subnet_id      = aws_subnet.priv-sub.id
  route_table_id = aws_route_table.nat-route.id
}

resource "aws_security_group" "bastion-sg" {
  name        = "bastion-sg"
  description = "SSH to bastion-host"
  vpc_id      = "${aws_vpc.myvpc.id}"
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sgroup"
  }
}

resource "aws_instance" "mywp" {
  ami           = "ami-004a955bfb611bf13"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.pub-sub.id}"
  vpc_security_group_ids = ["${aws_security_group.wp-sg.id}"]
  key_name = "keyterra"
  tags = {
    Name = "mywp"
  }
  
}
resource "aws_instance" "mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.priv-sub.id}"
  vpc_security_group_ids = ["${aws_security_group.db-sg.id}"]
  key_name = "keyterra"
  tags = {
    Name = "mysql"
  }
}
resource "aws_instance" "bastion-host" {
  ami           = "ami-00b494a3f139ba61f"
  instance_type = "t2.micro"
  key_name      = "keyterra"
  subnet_id     = "${aws_subnet.pub-sub.id}"
  vpc_security_group_ids = [ "${aws_security_group.bastion-sg.id}" ]
  tags = {
    Name = "bastion-host"
  }
}
