# SetUp

Kindly clone the code into your favourite IDE. 

```bash
giit clone << repo name >>
```

The solution is deployed as one terraform config. The Root HCL config file (main.tf) dictates the flow and all the submodules are bundled under thiss repo in individual folders (for ex /sqs for the sqs module). The /src folder has all the Lambda code associated with it. 


Deployment

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
terraform apply --auto-approve
```

In some cases, you may want to override variables such as AWS Region. You *will* need to change the target S3 bucket supporting AWS Lambda deployments. This can be done in the appropriate `variables.tf` file, or as part of your [terraform commands](https://developer.hashicorp.com/terraform/language/values/variables#variables-on-the-command-line).

Note that per Terraform docs, you can only override variables from the CLI command in the root module.

To deploy to a non-default region, override the `region` variable:

```bash
terraform plan -var="region=us-east-2" -var="root_bucket_name=real-time-posting-poc-bk"
terraform apply -var="region=us-east-2" -var="root_bucket_name=real-time-posting-poc-rajdban"
```
Validating Deployment

1. Log in to your AWS Account Console
2. Sanity check if all resources are created
3. Under DynamDB, insert a row in table 'visa' with test values
4. if the transaction is successful you should see a sucesssfull CW log event under log group '/aws/lambda/payments-posting'
5. if the traansaction is not succeessful, you can follow the architecture guide and track the transaction and see where it has stopped processing.
6. We have also created a mock lambda whch can insert a mock message into the 'visa' DynamoDB table. You can siimply invoke the 'payments-visa-mock' lambda from the console to achive the same effect.