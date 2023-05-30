resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.namespace}-ec2-policy"
  path        = "/"
  description = "Policy to provide permission to EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:List*"
        ],
        "Resource": [
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:GetSeries",
          "aps:QueryMetrics",
          "aps:RemoteWrite"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.namespace}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_policy_role" {
  name       = "${var.namespace}-ec2-attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.namespace}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

