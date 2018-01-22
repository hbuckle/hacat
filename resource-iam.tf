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
