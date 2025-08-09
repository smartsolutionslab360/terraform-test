provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    lambda = "http://localstack:4566"
    s3     = "http://localstack:4566"
    iam    = "http://localstack:4566"
  }
}

resource "aws_iam_role" "lambda_xmp_exec" {
  name = "lambda_xmp_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_xmp_s3_policy" {
  name = "lambda_xmp_s3_policy"
  role = aws_iam_role.lambda_xmp_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::bucket-de-ejemplo/*"
    }]
  })
}

resource "aws_api_gateway_rest_api" "api_xmp" {
  name        = "xmp-api"
  description = "API Gateway para Lambda XMP"
}

resource "aws_api_gateway_resource" "proxy_xmp" {
  rest_api_id = aws_api_gateway_rest_api.api_xmp.id
  parent_id   = aws_api_gateway_rest_api.api_xmp.root_resource_id
  path_part   = "process-xmp"
}

resource "aws_api_gateway_method" "get_xmp" {
  rest_api_id   = aws_api_gateway_rest_api.api_xmp.id
  resource_id   = aws_api_gateway_resource.proxy_xmp.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_xmp" {
  rest_api_id             = aws_api_gateway_rest_api.api_xmp.id
  resource_id             = aws_api_gateway_resource.proxy_xmp.id
  http_method             = aws_api_gateway_method.get_xmp.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.xmp_processor.invoke_arn
}

resource "aws_lambda_permission" "apigw_xmp" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.xmp_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_xmp.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deploy_xmp" {
  depends_on  = [aws_api_gateway_integration.lambda_xmp]
  rest_api_id = aws_api_gateway_rest_api.api_xmp.id
}

resource "aws_api_gateway_stage" "stage_xmp" {
  rest_api_id   = aws_api_gateway_rest_api.api_xmp.id
  deployment_id = aws_api_gateway_deployment.deploy_xmp.id
  stage_name    = "dev"
}

resource "aws_lambda_layer_version" "ffmpeg_layer" {
  filename         = "${path.module}/ffmpeg-layer.zip"
  layer_name       = "ffmpeg-layer"
  compatible_runtimes = ["python3.9"]
  source_code_hash = filebase64sha256("${path.module}/ffmpeg-layer.zip")
}

resource "aws_lambda_function" "xmp_processor" {
  function_name = "xmp-processor"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_xmp_exec.arn
  filename      = "${path.module}/lambda-xmp.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda-xmp.zip")
  timeout       = 300
  memory_size   = 1024
  
  layers = [aws_lambda_layer_version.ffmpeg_layer.arn]
  
  environment {
    variables = {
      BUCKET_NAME = "bucket-de-ejemplo"
    }
  }
}