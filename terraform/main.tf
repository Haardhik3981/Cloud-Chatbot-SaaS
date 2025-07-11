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
          "dynamodb:Scan"
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
  callback_urls = ["http://localhost:3000", "http://localhost:5173"]
  logout_urls   = ["http://localhost:3000", "https://your-domain.com"]
  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "chatbot_domain" {
  domain       = "chatbot-${random_id.rand.hex}"
  user_pool_id = aws_cognito_user_pool.chatbot_user_pool.id
}

resource "random_id" "rand" {
  byte_length = 4
}