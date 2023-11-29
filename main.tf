# VPC
resource "aws_vpc" "main" {
  cidr_block          = "10.0.0.0/16"
  enable_dns_support  = true
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count              = 2
  vpc_id             = aws_vpc.main.id
  cidr_block         = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone  = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public_Subnet_${count.index + 1}"
  }
}



# Private Subnets
resource "aws_subnet" "private" {
  count              = 2
  vpc_id             = aws_vpc.main.id
  cidr_block         = element(["10.0.3.0/24", "10.0.4.0/24"], count.index)
  availability_zone  = element(["us-east-1a", "us-east-1b"], count.index)
  tags = {
    Name = "Private_Subnet_${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Route Tables
resource "aws_route_table" "public" {
  count          = 2
  vpc_id         = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "Public_Route_Table_${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private_Route_Table_${count.index + 1}"
  }
}

# Associate subnets with route tables
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private[count.index].id
}

# IAM Role for CloudWatch
resource "aws_iam_role" "cloudwatch_role" {
  name = "CloudWatchRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for CloudWatch
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "CloudWatchPolicy"
  description = "Policy for CloudWatch Logs and Metrics"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
  role       = aws_iam_role.cloudwatch_role.name
}

# CloudWatch Metric Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "MyCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 90

  dimensions = {
    InstanceId = aws_instance.terraform-project.id
  }

  alarm_actions = ["arn:aws:sns:us-east-1:123456789012:terraform-project"]
}



# IAM Instance Profile
resource "aws_iam_instance_profile" "cloudwatch_profile" {
  name = "CloudWatchInstanceProfile"
}


# Ec2 instance
resource "aws_instance" "terraform-project" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.cloudwatch_profile.name
  tags = {
    Name = "Ec2_instance"
  }
}

resource "aws_eip" "ec2_eip" {
  instance = aws_instance.terraform-project.id
}


# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "NAT_Gateway"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  instance = null
}

# Security Group
resource "aws_security_group" "main" {
  name        = "terraform-security-group"
  description = "Allow inbound traffic on port 22 and 80"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
