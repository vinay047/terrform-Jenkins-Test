#setup Provider
provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

#VPC
resource "aws_vpc" "vpc_tuto" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "TestVPC"
  }
}

#public subnet
resource "aws_subnet" "public_subnet_us-east-1a" {
  vpc_id                  = "${aws_vpc.vpc_tuto.id}"
  cidr_block              = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
   Name =  "Public Subnet az 1a"
  }
}

#private subnet
resource "aws_subnet" "private_1_subnet_us-east-1a" {
  vpc_id                  = "${aws_vpc.vpc_tuto.id}"
  cidr_block              = "${var.private_subnet_cidr}"
  availability_zone = "us-east-1a"
  tags = {
   Name =  "private Subnet 1 az 1a"
  }
}

#IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc_tuto.id}"
  tags = {
        Name = "InternetGateway"
    }
}

#Route to the internet
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc_tuto.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
  
}

#Create EIP for Internet Gateway
resource "aws_eip" "tuto_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.gw"]
}

#Create NAT GW
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.tuto_eip.id}"
    subnet_id = "${aws_subnet.public_subnet_us-east-1a.id}"
    depends_on = ["aws_internet_gateway.gw"]
    tags = {
        Name = "NAT GW"
    }
}

#allow all traffic from the private subnets to the internet through the NAT Gateway 

resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.vpc_tuto.id}"

    tags = {
        Name = "Private route table"
    }
}

resource "aws_route" "private_route" {
route_table_id  = "${aws_route_table.private_route_table.id}"
destination_cidr_block = "0.0.0.0/0"
nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

# Associate subnet public_subnet_us-east-1a to public route table
resource "aws_route_table_association" "public_subnet_us-east-1a_association" {
    subnet_id = "${aws_subnet.public_subnet_us-east-1a.id}"
    route_table_id = "${aws_vpc.vpc_tuto.main_route_table_id}"
}

# Associate subnet private_1_subnet_us-east-1a to private route table
resource "aws_route_table_association" "pr_1_subnet_us-east-1a_association" {
    subnet_id = "${aws_subnet.private_1_subnet_us-east-1a.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# IAM Role
resource "aws_iam_role" "test_role" {
  name = "test_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
      tag-key = "terraform - IAM Role"
  }
}
resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}
resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

 ### Creating Security Group for Web EC2
resource "aws_security_group" "webinstance" {
  name = "terraform-webinstanceSG"
  description = "Allow incoming HTTP connections."

    ingress {
        from_port = 80
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }
    egress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    vpc_id = "${aws_vpc.vpc_tuto.id}"

    tags = {
        Name = "Terraform-WebServerSG"
    }
}

### Creating Security Group for DB EC2
resource "aws_security_group" "dbinstance" {
    name = "terraform-dbinstanceSG"
    description = "Allow incoming database connections."

    ingress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        security_groups = ["${aws_security_group.webinstance.id}"]
    }
    ingress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["${aws_security_group.webinstance.id}"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.vpc_cidr}"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["${var.vpc_cidr}"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.vpc_tuto.id}"

    tags = {
        Name = "Terraform-DBServerSG"
    }
}


### Creating EC2 Web instance
/*resource "aws_instance" "web" {
  ami               = "${lookup(var.amis,var.aws_region)}"
  count             = "${var.Count}"
  key_name               = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.webinstance.id}"]
  source_dest_check = false
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet_us-east-1a.id}"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
tags = {
    Name = "${format("web-%03d", count.index + 1)}"
  }
}*/

### Creating EC2 DB instance
resource "aws_instance" "db" {
  ami               = "${lookup(var.amis,var.aws_region)}"
  count             = "${var.Count}"
  key_name               = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.dbinstance.id}"]
  source_dest_check = false
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private_1_subnet_us-east-1a.id}"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
tags = {
    Name = "${format("db-%03d", count.index + 1)}"
  }
}


## Creating Launch Configuration
resource "aws_launch_configuration" "example" {
  image_id               = "${lookup(var.amis,var.aws_region)}"
  instance_type          = "t2.micro"
  security_groups        = ["${aws_security_group.webinstance.id}"]
  key_name               = "${var.aws_key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}
## Creating AutoScaling Group
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  #availability_zones   = ["${split(",", var.aws_availability_zones)}"]
  #availability_zones = ["us-east-1a"]
  vpc_zone_identifier = ["${aws_subnet.public_subnet_us-east-1a.id}"] 
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  desired_capacity     = "${var.asg_desired}"
  force_delete         = true
  load_balancers = ["${aws_elb.example.name}"]
  #health_check_type = ["${aws_elb.example.name}"]
  health_check_type = "ELB"
  #subnet_id = "${aws_subnet.private_1_subnet_us-east-1a.id}"
  count             = "${var.Counter}"
  /*tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }*/
  tag {
    key = "Name"
    value = "${format("web-%03d", count.index + 1)}"
    propagate_at_launch = true
  }
  
}
## Security Group for ELB
resource "aws_security_group" "elb" {
  name = "terraform-example-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = "${aws_vpc.vpc_tuto.id}"
  tags = {
        Name = "Terraform ELB SG"
    }
}
### Creating ELB
resource "aws_elb" "example" {
  name = "terraform-asg-example"
  security_groups = ["${aws_security_group.elb.id}"]
  #availability_zones   = ["${split(",", var.aws_availability_zones)}"]
#availability_zones = ["us-east-1a"]
#vpc_zone_identifier = ["${aws_subnet.public_subnet_us-east-1a.id}"]
subnets = ["${aws_subnet.public_subnet_us-east-1a.id}"]
health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }
}

Sensitivity: Internal & Restricted
