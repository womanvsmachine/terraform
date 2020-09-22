# terraform {
#     backend "s3" {
#         bucket          = "alucero-tf-test-workspace-isolation"
#         key             = "workspace-example/terrform.tfstate"
#         region          = "us-west-1"
#         dynamodb_table  = "tf-test-workspace-isolation"
#         encrypt         = true
#     }
# }

resource "aws_instance" "tf-workspace-isolation-example" {
    ami             = "ami-09eaae91d6359eaee" # Ubuntu 18.04 2020-09-21
    # Conditionally sets instance type depending on the value of the terraform workspace
    instance_type   = terraform.workspace == "default" ? "t2.medium" : "t2.micro" # If default then t2.medium, else t2.micro
    subnet_id 	    = var.single_subnet 
}

resource "aws_s3_bucket" "tf-test-workspace-isolation" {
    bucket = "alucero-tf-test-workspace-isolation"
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

resource "aws_dynamodb_table" "tf-test-workspace-isolation" {
    name            = "tf-test-workspace-isolation"
    billing_mode    = "PAY_PER_REQUEST"
    hash_key        = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}