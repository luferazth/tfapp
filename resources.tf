# We need to provide with the necessary cloud provider
# to get access to the API's we're going to invoke
provider "aws" {
  access_key = XXXX
  secret_key = XXXX
  region = "us-east-1"
}


## we need to get data and metadata about the type of image we're going to need
##


data "aws_ssm_parameter" "ami"{
    name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# As for this moment we're going into the Virtual Private Cloud service in AWS
# we have a lot of choices here
# for example:
# we chose to have a private IPv4 address to assign to the VPC
# with dns_hostnames which allows to assign a dns name to "any" resources created in the VPC
#
resource "aws_vpc" "vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = "true"
}

#After this we're going to attach an internet gateway to the VPC to allow
# internet connections to our resources
# A nice thing to notice is that: after the VPC is created we're gonna reference its id as variable
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# After the VPC is created, we're going to create a simple architecture, VPC with a single public subnet
# one EC2 Instance and a security group to allow access on port 80 since we're hosting a NGINX web server
resource "aws_subnet" "subnet1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
}

resource "aws_route_table" "rtb" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id =  aws_internet_gateway.igw.id
    }
}
resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_instance" "nginx1" {
    ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
    instance_type          = "t2.micro"
    subnet_id              = aws_subnet.subnet1.id
    vpc_security_group_ids = [aws_security_group.nginx-sg.id]

    user_data = <<EOF
#!/bin/bash

sudo amazon-linux-extras install -y nginx1
sudo service nginx start
sudo rm /usr/share/nginx/html/index.html
echo '<html><head><title>TACO TEAM SERVER</title></head></html>' > /var/www/index.html
EOF
}