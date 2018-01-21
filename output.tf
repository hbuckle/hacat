output "output" {
  value = "The cat lives at http://${aws_elb.elb.dns_name}"
}
