resource "random_string" "random_name" {
  length  = 12
  upper   = false
  number  = false
  special = false
}

resource "aws_s3_bucket" "s3_bucket_logs" {
  bucket        = "${random_string.random_name.result}-logs"
  acl           = "private"
  force_destroy = true

  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${random_string.random_name.result}-logs/AWSLogs/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.elb_service_account.arn}"
        ]
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "s3_bucket_app" {
  bucket        = "${random_string.random_name.result}-app"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "iam_role" {
  name = "${random_string.random_name.result}-iam-s3"

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
}

resource "aws_iam_role_policy" "iam_role_policy" {
  name = "${random_string.random_name.result}-iam-s3"
  role = "${aws_iam_role.iam_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::${random_string.random_name.result}-app"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${random_string.random_name.result}"
  role = "${aws_iam_role.iam_role.name}"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.0.0/16"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = "${aws_subnet.subnet.id}"
  route_table_id = "${aws_route_table.route_table.id}"
}

resource "aws_security_group" "security_group_elb" {
  name   = "${random_string.random_name.result}-elb"
  vpc_id = "${aws_vpc.vpc.id}"

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

  depends_on = ["aws_internet_gateway.internet_gateway"]
}

resource "aws_security_group" "security_group_instance" {
  name   = "${random_string.random_name.result}-instance"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = ["${aws_security_group.security_group_elb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = ["aws_internet_gateway.internet_gateway"]
}

resource "aws_launch_configuration" "launch_configuration" {
  name                 = "${random_string.random_name.result}"
  image_id             = "${data.aws_ami.coreos.id}"
  instance_type        = "t2.micro"
  security_groups      = ["${aws_security_group.security_group_instance.id}"]
  user_data            = "${data.ignition_config.config.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.iam_instance_profile.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "elb" {
  name            = "${random_string.random_name.result}"
  subnets         = ["${aws_subnet.subnet.id}"]
  security_groups = ["${aws_security_group.security_group_elb.id}"]

  access_logs {
    bucket   = "${aws_s3_bucket.s3_bucket_logs.id}"
    interval = 5
  }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:8000/"
    interval            = 10
  }

  depends_on = ["aws_internet_gateway.internet_gateway"]
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = "${random_string.random_name.result}"
  vpc_zone_identifier       = ["${aws_subnet.subnet.id}"]
  min_size                  = 2
  max_size                  = 4
  health_check_grace_period = 300
  health_check_type         = "ELB"
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  launch_configuration      = "${aws_launch_configuration.launch_configuration.name}"
  load_balancers            = ["${aws_elb.elb.name}"]
}

resource "aws_autoscaling_policy" "autoscaling_policy_up" {
  name                   = "${random_string.random_name.result}-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling_group.name}"
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_cpu_up" {
  alarm_name          = "${random_string.random_name.result}-cpu-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling_group.name}"
  }

  alarm_actions = ["${aws_autoscaling_policy.autoscaling_policy_up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_elb" {
  alarm_name          = "${random_string.random_name.result}-elb"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "0"

  dimensions {
    LoadBalancerName = "${aws_elb.elb.name}"
  }

  alarm_actions = ["${aws_sns_topic.sns_topic.arn}"]
}

resource "aws_sns_topic" "sns_topic" {
  name = "${random_string.random_name.result}"
}

resource "aws_sns_topic_subscription" "xxxx_cloudwatch_notifications" {
  topic_arn = "${aws_sns_topic.sns_topic.arn}"
  protocol  = "sms"
  endpoint  = "${var.pager}"
}
