# Deployment

Uses terraform. 

Log into your AWS account on your CLI/shell through your perferred auth provider.

Init the solution:

Backend configuration is stored under `./env/`

```bash
terraform init -backend-config="path-to-backend-file.hcl"
```

Plan the deployment:
```bash
terraform plan
```

Apply the deployment:
```bash
terraform apply
```

In some cases, you may want to override variables such as AWS Region. You *will* need to change the target S3 bucket supporting AWS Lambda deployments. This can be done in the appropriate `variables.tf` file, or as part of your [terraform commands](https://developer.hashicorp.com/terraform/language/values/variables#variables-on-the-command-line).

Note that per Terraform docs, you can only override variables from the CLI command in the root module.

To deploy to a non-default region, override the `region` variable:

```bash
terraform plan -var="region=us-east-2" -var="root_bucket_name=real-time-posting-poc-bk"
terraform apply -var="region=us-east-2" -var="root_bucket_name=real-time-posting-poc-rajdban"
```

## Lambda Functions

Some of the lambda functions use Python. You may want to use a Python Virtual Environment to help manage the related Python dependencies.

Create the virtual environment. One time only.
```bash
python3 -m venv .venv
```

Activate the virtual environment. Every time you start a new terminal session.
```bash
source .venv/bin/activate
```
