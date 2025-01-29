provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-github-actions-builds-qa"
    key     = "sierra-holding-parser-terraform-state"
    region  = "us-east-1"
  }
}

# Upload the zipped app to S3:
resource "aws_s3_object" "uploaded_zip" {
  bucket = "nypl-github-actions-builds-${terraform.workspace}"
  key    = "sierra-holding-parser-${terraform.workspace}-dist.zip"
  acl    = "private"
  source = "../build/build.zip"
  etag = filemd5("../build/build.zip")
}

# Create the lambda:
resource "aws_lambda_function" "lambda_instance" {
  description   = "Listens to recently retrieved holdings records on the SierraHoldingParser stream, enhances them, and passes them to the HoldingPostRequest stream, to be saved in the HoldingService"
  function_name = "SierraHoldingParser-${terraform.workspace}"
  handler       = "app.handle_event"
  memory_size   = 128
  role          = "arn:aws:iam::946183545209:role/lambda-full-access"
  runtime       = "ruby3.3"
  timeout       = 60

  # Location of the zipped code in S3:
  s3_bucket     = aws_s3_object.uploaded_zip.bucket
  s3_key        = aws_s3_object.uploaded_zip.key

  # Trigger pulling code from S3 when the zip has changed:
  source_code_hash = filebase64sha256("../build/build.zip")

  # Load ENV vars from ./config/{environment}.env
  environment {
    variables = { for tuple in regexall("(.*?)=(.*)", file("../config/${terraform.workspace}.env")) : tuple[0] => tuple[1] }
  }
}
