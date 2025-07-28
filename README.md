# Terraform Infrastructure

This repository contains Terraform code for managing infrastructure on AWS and GCP.

## Project Structure

The repository is organized by cloud provider, with each provider having its own directory:

- **aws/**: Contains Terraform code for AWS resources.
- **gcp/**: Contains Terraform code for GCP resources.

Within each provider directory, the code is further divided into:

- **modules/**: Reusable Terraform modules for creating specific resources (e.g., an S3 bucket, a GCS bucket).
- **services/**: Configurations that use the modules to deploy services.

## Testing

This project uses the built-in Terraform testing framework. Tests are located in the `tests/` directory, and the structure of the `tests/` directory mirrors the structure of the main provider directories.

To run the tests, navigate to the specific test directory (e.g., `tests/aws/s3`) and run the following command:

```
terraform test
```
