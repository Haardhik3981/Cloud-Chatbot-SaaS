output "api_url" {
  value = "${aws_apigatewayv2_api.chat_api.api_endpoint}/chat"
}

output "user_pool_id" {
  value = aws_cognito_user_pool.chatbot_user_pool.id
}

output "app_client_id" {
  value = aws_cognito_user_pool_client.chatbot_app_client.id
}

output "cognito_login_url" {
  value = "https://${aws_cognito_user_pool_domain.chatbot_domain.domain}.auth.${var.aws_region}.amazoncognito.com/login?response_type=code&client_id=${aws_cognito_user_pool_client.chatbot_app_client.id}&redirect_uri=http://localhost:3000"
}

output "frontend_url" {
  value = aws_cloudfront_distribution.frontend_cdn.domain_name
}