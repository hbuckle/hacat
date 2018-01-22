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
