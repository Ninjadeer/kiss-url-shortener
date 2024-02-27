locals {
  s3_origin_id = "shortner"
}

resource "aws_route53_record" "shortner" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.shortner.domain_name
    zone_id                = aws_cloudfront_distribution.shortner.hosted_zone_id
  }
}


resource "aws_s3_bucket_policy" "allow_s3_read" {
  bucket = aws_s3_bucket.shortner.bucket
  policy = data.aws_iam_policy_document.allow_s3_read.json
}

# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html#private-content-oac-permission-to-access-s3
# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html#private-content-oac-permission-to-access-s3
data "aws_iam_policy_document" "allow_s3_read" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type        = ""
    }
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.shortner.arn}/*",
    ]

    condition {
      test   = "StringEquals"
      values = [
        aws_cloudfront_distribution.shortner.arn
      ]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_object" "rick_roll" {
  bucket           = aws_s3_bucket.shortner.bucket
  key              = "bar"
  website_redirect = "https://youtu.be/xvFZjo5PgG0?si=8AEsSM8XFqJBgUpE"
}

resource "aws_s3_object" "error_page" {
  bucket = aws_s3_bucket.shortner.bucket
  key    = "error.html"
  source = "${path.module}/files/error.html"
  etag   = filemd5("${path.module}/files/error.html")
}

resource "aws_s3_bucket_ownership_controls" "shortner" {
  bucket = aws_s3_bucket.shortner.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket" "shortner" {
  bucket = var.domain
}

resource "aws_s3_bucket_acl" "shortner" {
  depends_on = [aws_s3_bucket_ownership_controls.shortner]
  bucket     = aws_s3_bucket.shortner.bucket
  acl        = "private"
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.shortner.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}


resource "aws_cloudfront_origin_access_control" "shortner" {
  name                              = "shortner"
  description                       = "Example Shortner Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

output "website_domain" {
  value = aws_s3_bucket.shortner.bucket_domain_name
}

resource "aws_cloudfront_distribution" "shortner" {

  origin {
    origin_id   = local.s3_origin_id
    domain_name = aws_s3_bucket_website_configuration.this.website_endpoint
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }
  enabled         = true
  is_ipv6_enabled = true
  comment         = "URL Shortner example"

  #  logging_config {
  #    include_cookies = false
  #    bucket          = "mylogs.s3.amazonaws.com"
  #    prefix          = "myprefix"
  #  }

  aliases = [
    var.domain
  ]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }


  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
  }
}

