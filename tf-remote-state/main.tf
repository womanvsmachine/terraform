# To store state file remotely:
# 1. Create S3 bucket and DynamoDB table and deploy with local backend
# 2. Add remote backend configuration to use the newly created bucket and table
# 3. Run terraform init to copy your local state to S3

# To reverse:
# 1. Remove or comment out the backend configuration
# 2. Run terraform init to copy state back to local disk
# 3. Run terraform destroy to remove S3 bucket and DynamoDB table (bucket must be empty)

# Variables are not allowed in the backend configuration
# Key value must be unique, otherwise state files will be overwritten
# You could omit these values and pass them in via the -backend-config command line argment when calling terraform init,
# or extract the repeated arguments such as bucket and region into a separate file called backend.hcl
# terraform init -backend-config=backend.hcl

terraform {
    backend "s3" {
        # bucket          = "tf-test-remote-state"      # See backend.hcl
        key               = "global/s3/terraform.tfstate"
        # region          = "us-west-1"                 # See backend.hcl
        # dynamodb_table  = "tf-test-locks"             # See backend.hcl
        # encrypt         = true                        # See backend.hcl
    }
}

provider "aws" {
    region = "us-west-1"
}

resource "aws_s3_bucket" "tf-test-remote-state" {
    bucket = "tf-test-remote-state"
    # Prevent accidental deletion of this S3 bucket
    #lifecycle {
    #    prevent_destroy = true
    #}
    # Enable versioning so we can see the full revision history of state files and revert if needed
    versioning {
        enabled = true
    }
    # Enable server-side encryption by default
    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

resource "aws_dynamodb_table" "tf-test-locks" {
    name            = "tf-test-locks"
    billing_mode    = "PAY_PER_REQUEST"
    hash_key        = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

output "s3_bucket_arn" {
    value       = aws_s3_bucket.tf-test-remote-state.arn
    description = "The ARN of the S3 bucket"
}

output "dynamodb_table_name" {
    value       = aws_dynamodb_table.tf-test-locks.name
    description = "The name of the DynamoDB table"
}