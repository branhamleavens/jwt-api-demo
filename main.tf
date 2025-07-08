terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# Upload the PEM files to SSM
data "local_file" "public_key_pem" {
  filename = "${path.module}/public.pem"
}

data "local_file" "private_key_pem" {
  filename = "${path.module}/private.pem"
}

resource "aws_ssm_parameter" "private_key" {
  name  = "/jwt/private_key"
  type  = "SecureString"
  value = data.local_file.private_key_pem.content
}

resource "aws_ssm_parameter" "public_key" {
  name  = "/jwt/public_key"
  type  = "SecureString"
  value = data.local_file.public_key_pem.content
}

# Lambda IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "jwt_lambda_execution_role"

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

# Attach basic logging permissions
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach permission to read from SSM
resource "aws_iam_policy" "lambda_ssm_access" {
  name = "lambda-ssm-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = [
          aws_ssm_parameter.private_key.arn,
          aws_ssm_parameter.public_key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_ssm_access.arn
}

# Lambda Function (ZIP deployment)
resource "aws_lambda_function" "jwt_lambda" {
  function_name    = "jwt-auth-lambda"
  filename         = "deployment.zip"
  source_code_hash = filebase64sha256("deployment.zip")
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 10
  layers = [aws_lambda_layer_version.jwt_dependencies.arn]

}


# Create an API Gateway HTTP API
resource "aws_apigatewayv2_api" "jwt_api" {
  name          = "jwt-api"
  protocol_type = "HTTP"
}

# Lambda integration for API Gateway
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.jwt_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.jwt_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Define a default route that maps all paths/methods to Lambda
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.jwt_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Deploy the API
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.jwt_api.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowInvokeFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.jwt_api.execution_arn}/*/*"
}

# Output the API endpoint
output "api_endpoint" {
  value = aws_apigatewayv2_api.jwt_api.api_endpoint
  description = "Public endpoint of the JWT API"
}

# Create the Lambda Layer
resource "aws_lambda_layer_version" "jwt_dependencies" {
  filename          = "layer.zip"
  layer_name        = "jwt_dependencies"
  compatible_runtimes = ["python3.11"]
  source_code_hash  = filebase64sha256("layer.zip")
}