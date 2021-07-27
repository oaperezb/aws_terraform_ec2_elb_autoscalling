resource "aws_vpc" "vpc-challenge" {
  provider             = aws
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-challenge"
  }
}

resource "aws_subnet" "subnet-private-challenge" {
  provider   = aws
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.vpc-challenge.id
  tags = {
    Name = "subnet-private-challenge"
  }
}

resource "aws_subnet" "subnet-public-challenge" {
  provider                = aws
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.vpc-challenge.id
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-challenge"
  }
}

resource "aws_internet_gateway" "igw-challenge" {
  provider = aws
  vpc_id   = aws_vpc.vpc-challenge.id
  tags = {
    Name = "igw-challenge"
  }
}

resource "aws_route_table" "rt-challenge" {
  provider = aws
  vpc_id   = aws_vpc.vpc-challenge.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-challenge.id
  }
  tags = {
    Name = "rt-challenge"
  }
}

resource "aws_route_table_association" "rt-association-challenge" {
  provider       = aws
  route_table_id = aws_route_table.rt-challenge.id
  subnet_id      = aws_subnet.subnet-public-challenge.id
}

resource "aws_eip" "eip_nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip_nat_gateway.id
  subnet_id = aws_subnet.subnet-public-challenge.id
  tags = {
    "Name" = "nat_gateway"
  }
}

resource "aws_route_table" "art_nat_gateway" {
  vpc_id = aws_vpc.vpc-challenge.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "arta_subnet_private" {
  subnet_id = aws_subnet.subnet-private-challenge.id
  route_table_id = aws_route_table.art_nat_gateway.id
}

variable "ingress-rules" {
  default = {
    "http-ingress" = {
      description = "For HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    "https-ingress" = {
      description = "For HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    "ssh-ingress" = {
      description = "For SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "egress-rules" {
  default = {
    "all-egress" = {
      description = "All"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

resource "aws_security_group" "sgp-challenge" {
  provider    = aws
  name        = "allow_http_https_and_ssh"
  description = "Allow HTTP, HTTPS and SSH traffic"
  vpc_id      = aws_vpc.vpc-challenge.id

  dynamic "ingress" {
    for_each = var.ingress-rules
    content {
      description = lookup(ingress.value, "description", null)
      from_port   = lookup(ingress.value, "from_port", null)
      to_port     = lookup(ingress.value, "to_port", null)
      protocol    = lookup(ingress.value, "protocol", null)
      cidr_blocks = lookup(ingress.value, "cidr_blocks", null)
    }
  }

  dynamic "egress" {
    for_each = var.egress-rules
    content {
      description = lookup(egress.value, "description", null)
      from_port   = lookup(egress.value, "from_port", null)
      to_port     = lookup(egress.value, "to_port", null)
      protocol    = lookup(egress.value, "protocol", null)
      cidr_blocks = lookup(egress.value, "cidr_blocks", null)
    }
  }

  tags = {
    Name = "sgp-challenge"
  }
}

data "template_file" "init" {
  template = file("install.tpl")
}

resource "aws_key_pair" "challenge-deployer" {
key_name = "challenge-user-key"
public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCUVLojzlYNync7EODaeJPrGAyHRQyoZ72yiEO0xMJpvy7149w+UdEl2ik/dzN7iN1XTWZtB4BgzQjl8UMUmHXQMXM/S/b8/qexiLg1nKHY33j2WGE3FoYnXro7AkQp/JDga6V68SIdiqhgNR0GH1i1Uo2hrvTNNG1pUzdnAAr006lW9WoOzAkTN0wCxxGmFWDLlLr4V4jj3oWSLTU8ag7FZKVnVv/zo81DdtxhmVoH31fmc3Z/ObVwH0nEJkkuXaFXp4OfkLX7xTZEKTbu3kKuJsrFKM2HLoY6I2M9bcM7tsGloD/8Yg2LkG2rMs0xh1VtyT7wBAePmk5FncFgqiJx challenge-user-key"
}

/* resource "aws_instance" "ec2-challenge" {
  ami             = "ami-0233c2d874b811deb"
  instance_type   = "t2.micro"
  count           = 2
  subnet_id       = aws_subnet.subnet-private-challenge.id
  security_groups = [aws_security_group.sgp-challenge.id]
  user_data       = data.template_file.init.rendered
  key_name        = aws_key_pair.challenge-deployer.key_name
  tags = {
    Name      = "ec2-challenge${count.index + 1}"
    ManagedBy = "Terraform"
  }
} */

resource "aws_lb_target_group" "target-group-challenge" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "tg-challenge"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc-challenge.id
}

resource "aws_lb" "aws-alb-challenge" {
  name     = "alb-challenge"
  internal = false

  security_groups = ["${aws_security_group.sgp-challenge.id}", ]

  subnets = [aws_subnet.subnet-private-challenge.id, aws_subnet.subnet-public-challenge.id ]

  tags = {
    Name = "alb-challenge"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "alb-listner-challenge" {
  load_balancer_arn = "${aws_lb.aws-alb-challenge.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target-group-challenge.arn}"
  }
}

resource "aws_launch_configuration" "lac-challenge" {
  name_prefix = "ec2-challenge-"
  image_id        = "ami-0233c2d874b811deb"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sgp-challenge.id]
  key_name        = aws_key_pair.challenge-deployer.key_name
  user_data       = data.template_file.init.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg-challenge" {
  launch_configuration = "${aws_launch_configuration.lac-challenge.name}"
  vpc_zone_identifier  = [aws_subnet.subnet-private-challenge.id]
  target_group_arns    = [aws_lb_target_group.target-group-challenge.arn]
  health_check_type    = "ELB"

  min_size = 2
  max_size = 4

  tag {
    key                 = "Name"
    value               = "asg-challenge"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "asp-up-challenge" {
  name = "asp-up-challenge"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.asg-challenge.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-utilization-up-challenge" {
  alarm_name          = "cpu-utilization-up-challenge"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = ["${aws_autoscaling_policy.asp-up-challenge.arn}"]

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.asg-challenge.name}"
  }
}

resource "aws_autoscaling_policy" "asp-down-challenge" {
  name = "asp-down-challenge"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.asg-challenge.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-utilization-down-challenge" {
  alarm_name          = "cpu-utilization-down-challenge"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = ["${aws_autoscaling_policy.asp-down-challenge.arn}"]

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.asg-challenge.name}"
  }
}