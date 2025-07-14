#main.tf
provider "aws" {
  region = "us-west-2"
}
# -----------------------------
# Dynamo DB table to store chat 
# -----------------------------

resource "aws_dynamodb_table" "chat_logs" {
  name           = "chat_logs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "timestamp"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# -----------------------------
# IAM Role for Lambda function
# -----------------------------

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# -----------------------------
# Policy for IAM Role (Lambda Logging Permission)
# -----------------------------

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -----------------------------
# Policy for IAM Role (DynamoDB specific Permission)
# -----------------------------

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem"
        ],
        Resource = aws_dynamodb_table.chat_logs.arn
      }
    ]
  })
}

# -----------------------------
# Creates Lambda function - For Post
# -----------------------------

resource "aws_lambda_function" "chat_post_handler" {
  function_name = "chatPostHandler"
  filename      = "${path.module}/../lambda/chat_post_handler.zip"
  handler       = "chat_post_handler.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda/chat_post_handler.zip")
  environment {
    variables = {
        OPENAI_API_KEY = var.openai_api_key
    }
  }
}
# -----------------------------
# Creates Lambda function - For Get
# -----------------------------

resource "aws_lambda_function" "chat_get_handler" {
  function_name = "chatGetHandler"
  filename      = "${path.module}/../lambda/chat_get_handler.zip"
  handler       = "chat_get_handler.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda/chat_get_handler.zip")
}

# -----------------------------
# Creates API Gateway
# -----------------------------

resource "aws_apigatewayv2_api" "chat_api" {
  name          = "chat-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]   # Or ["http://localhost:5173"] for stricter security
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
  }
}

# -----------------------------
# Setup API Gateway integration with Lambda - For Post
# -----------------------------

resource "aws_apigatewayv2_integration" "lambda_post_integration" {
  api_id             = aws_apigatewayv2_api.chat_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.chat_post_handler.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# -----------------------------
# Setup API Gateway integration with Lambda - For Get
# -----------------------------

resource "aws_apigatewayv2_integration" "lambda_get_integration" {
  api_id             = aws_apigatewayv2_api.chat_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.chat_get_handler.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# -----------------------------
# Creates API gateway route to invoke lambda function when triggered.
# -----------------------------

resource "aws_apigatewayv2_route" "chat_post_route" {
  api_id    = aws_apigatewayv2_api.chat_api.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_post_integration.id}"
}
resource "aws_apigatewayv2_route" "chat_get_route" {
  api_id    = aws_apigatewayv2_api.chat_api.id
  route_key = "GET /chat-history"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_get_integration.id}"
}


# -----------------------------
# Creates Deployment Stage
# -----------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.chat_api.id
  name        = "$default"
  auto_deploy = true
}

# -----------------------------
# Permission to allow Gateway API to invoke lambda function
# -----------------------------

resource "aws_lambda_permission" "allow_apigw_invoke_post" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_post_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_invoke_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_get_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat_api.execution_arn}/*/*"
}


# -----------------------------
# Cognito User Pool
# -----------------------------
resource "aws_cognito_user_pool" "chatbot_user_pool" {
  name = "chatbot-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

# -----------------------------
# App Client
# -----------------------------
resource "aws_cognito_user_pool_client" "chatbot_app_client" {
  name         = "chatbot-app-client"
  user_pool_id = aws_cognito_user_pool.chatbot_user_pool.id
  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["email", "openid", "profile"]
  callback_urls = ["http://localhost:3000", "http://localhost:5173", "https://d3pb94cafp68vt.cloudfront.net"]
  logout_urls   = ["http://localhost:3000", "https://your-domain.com", "https://d3pb94cafp68vt.cloudfront.net"]
  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "chatbot_domain" {
  domain       = "chatbot-${random_id.rand.hex}"
  user_pool_id = aws_cognito_user_pool.chatbot_user_pool.id
}

resource "random_id" "rand" {
  byte_length = 4
}

# -----------------------------
# Create S3 Bucket for Hosting Frontend
# -----------------------------
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "cloud-chatbot-frontend-${random_id.rand.hex}"
}

resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# -----------------------------
# Create Policy for S3 Bucket for Hosting Frontend
# -----------------------------

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = "*",
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
    }]
  })
}

# -----------------------------
# Create CloudFront Distribution - CloudFront serves your static frontend over HTTPS globally.
# -----------------------------

resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "frontendS3Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontendS3Origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# -----------------------------
#Chat Clear API - new lambda function, new Gateway API created, new Route to connect these 2, and permissions.
# -----------------------------
resource "aws_lambda_function" "chat_clear_handler" {
  function_name = "chatClearHandler"
  filename      = "${path.module}/../lambda/chat_clear_handler.zip"
  handler       = "chat_clear_handler.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda/chat_clear_handler.zip")
}

resource "aws_apigatewayv2_integration" "lambda_clear_integration" {
  api_id             = aws_apigatewayv2_api.chat_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.chat_clear_handler.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "clear_chat_route" {
  api_id    = aws_apigatewayv2_api.chat_api.id
  route_key = "POST /clear-chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_clear_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_clear_invoke" {
  statement_id  = "AllowAPIGatewayClearInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_clear_handler.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat_api.execution_arn}/*/*"
}