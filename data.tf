data "aws_elb_service_account" "elb_service_account" {}

data "aws_ami" "coreos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CoreOS-stable-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"]
}

data "ignition_systemd_unit" "systemd_unit" {
  name    = "helloworld.service"
  enabled = true
  content = "${file("${path.module}/helloworld.service")}"
}

data "ignition_file" "file" {
  filesystem = "root"
  path       = "/opt/Dockerfile"
  mode       = 0644

  content {
    content = "${file("${path.module}/Dockerfile")}"
  }
}

data "ignition_config" "config" {
  files = [
    "${data.ignition_file.file.id}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.systemd_unit.id}",
  ]
}
