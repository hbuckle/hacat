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
