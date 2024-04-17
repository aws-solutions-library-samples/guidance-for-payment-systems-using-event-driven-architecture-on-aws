# Guidance for building cross-platform event-driven payment systems on AWS


Customers who build payment systems must ensure that customer transactions and activities are persistently stored and idempotently processed to ensure integrity of data in their systems of record.

In order to solve for these requirements, architects within the financial services industry often leverage relational databases with transactional capabilities for their ACID (atomicity, consistency, isolation, durability) approaches to data persistence. The applications often persist data to these databases systems with synchronous requests, blocking until the transaction has been committed to the database.

## Table of Contents

### Required

1. [Overview](#overview)
    - [Cost](#cost)
2. [Prerequisites](#prerequisites)
    - [Operating System](#operating-system)
3. [Deployment Steps](#deployment-steps)
4. [Deployment Validation](#deployment-validation)
5. [Running the Guidance](#running-the-guidance-required)
6. [Next Steps](#next-steps-required)
7. [Cleanup](#cleanup-required)

***Optional***

8. [FAQ, known issues, additional considerations, and limitations](#faq-known-issues-additional-considerations-and-limitations-optional)
9. [Revisions](#revisions-optional)
10. [Notices](#notices-optional)
11. [Authors](#authors-optional)
12. [Requirements](#requirements)
     - [Functional Requirements](#functional-requirements)
     - [Non-Functional Requirements](#non-functional-requirements)
13. [Decision Register](#decision-register)

## Overview

This guidance focuses on the part of payments processing systems that post payments to recieving accounts. In this phase, inbound transactions are evaluated, have accounting rules applied to them, then are posted into customer accounts. 

Inbound transactions are assumed to have been authorized by an upstream process.

In traditional architectures, the upstream system writes transactions to a log. The log is periodically picked up by a batch-based processing system system, then eventually posted to customer accounts. Transactions (and customers!) must wait for the next batch iteration before being processed, which can take multiple days.

This sample architecture uses event-driven patterns to post transactions in near real-time rather than in batches. In this system, customers get a more fine-grained account balance, they can dispute transactions much sooner, and processing load is offloaded from batch systems during critical hours.

### Architecture and Message Flow

![Architecture Diagram](./assets/images/architecture-annotated.png)

1. A user initiates a payment which the authorization application approves and persists to an Amazon DynamoDB table.

2. An Amazon EventBridge Pipe reads approved authorization records from the DynamoDB table stream and publishes events to an EventBridge custom bus. 

3. Duplicate-checking logic can be added to the EventBridge Pipe through a deduplication AWS Lambda function.

4. An EventBridge rule invokes an enrichment Lambda function for events that match to add context like account type and bank details.

5. The Lambda function queries metadata and publishes a new event back to the EventBridge custom bus with extra info.

6. An EventBridge rule watching for enriched events invokes an AWS Step Functions workflow to apply business rules to the event as part of a rules engine. In this case the Step Function workflow is representative of any rules engine, such as [Drools](https://www.drools.org/) or similar.

7. When an event passes all business rules, the Step Functions workflow publishes a new event back to the EventBridge bus.

8. An EventBridge rule enqueues a message in an Amazon Simple Queue Service (SQS) queue as a buffer to avoid overrunning the downstream posting subsystem.

9. A Lambda function reads from the SQS queue and invokes the downstream posting subsystem to post the transaction.

10. The Lambda function publishes a final event back to the EventBridge bus.

### Cost

You are responsible for the cost of the AWS services used while running this Guidance. As of April 2024, the cost for running this Guidance with the default settings in the US East (N. Virginia) Region is approximately **\$1 per month**, assuming 3,000 transactions.

This Guidance uses [Serverless services](https://aws.amazon.com/serverless/), which use a pay-for-value billing model. Costs are incurred with usage of the deployed resources. Refer to the [Sample cost table](#sample-cost-table) for a service-by-service cost breakdown.

We recommend creating a [budget](https://alpha-docs-aws.amazon.com/awsaccountbilling/latest/aboutv2/budgets-create.html){:target="_blank"} through [AWS Cost Explorer](http://aws.amazon.com/aws-cost-management/aws-cost-explorer/){:target="_blank"} to help manage costs. Prices are subject to change. For full details, refer to the pricing webpage for each AWS service used in this Guidance.

#### Sample cost table

The following table provides a sample cost breakdown for deploying this Guidance with the default parameters in the US East (N. Virginia) Region for one month.

| **AWS service**  | Dimensions | Cost \[USD\] |
|-----------|------------|
| [Amazon DynamoDB](https://aws.amazon.com/dynamodb/pricing/) | 1 GB Data Storage,1 KB avg item size,3000 DynamoDB Streams per month  | \$ 0.25 |
| [AWS Lambda](https://aws.amazon.com/lambda/pricing/) | 3,000 requests per month with 200 ms avg duration, 128 MB memory,512 MB ephemeral storage | \$ 0.00 |
| [Amazon SQS](https://aws.amazon.com/sqs/pricing/) | 0.03 million requests per month | \$ 0.00 |
| [AWS Step Functions](https://aws.amazon.com/step-functions/pricing/) | 3,000 workflow requests per month with 3 state transitions per workflow | \$ 0.13 |
| [Amazon SNS](https://aws.amazon.com/sns/pricing/)| 3,000 requests users nd 3000 Email notifications per month | \$ 0.04 |
| [Amazon EventBridge](https://aws.amazon.com/eventbridge/pricing/) | 3,000 custom events per month with 3000 events replay and 3000 requests in the pipes | \$ 0.00 |

## Prerequisites

### Operating System

These deployment instructions are optimized to work on Amazon Linux 2 or Mac OSX.

This solution builds AWS Lambda functions using Python. The build process currently supports Linux and MacOS. It was tested with Python `3.11`. You will need [Python and Pip](https://www.python.org/) to build and deploy.

### Third-party tools

This solution uses [Terraform](https://www.terraform.io/) as an Infrastructure-as-Code provider. You will need Terraform installed to deploy. These instructions were tested with Terraform version 1.7.1.

You can install Terraform on Linux (such as a CodeBuild build agent) with commands like this:

```bash
curl -o terraform_1.7.1_linux_amd64.zip https://releases.hashicorp.com/terraform/1.7.1/terraform_1.7.1_linux_amd64.zip
unzip -o terraform_1.7.1_linux_amd64.zip && mv terraform /usr/bin
```

### AWS account requirements

These instructions require AWS credentials configured according to the [Terraform AWS Provider documentation](https://registry.terraform.io/providers/-/aws/latest/docs#authentication-and-configuration).

The credentials must have IAM permission to create and update resources in the target account. 

Services include:

* Amazon EventBridge Custom Event Bus, Pipes, Rules
* AWS Lambda functions
* Amazon Simple Queue Services (SQS) queues
* Amazon DynamoDB tables and streams
* AWS Step Function workflows
* Amazon Simple Notification Service (SNS) topics

### Service limits

Experimental workloads should fit within default service quotas for the involved services.

### Supported Regions

This Guidance is best suited for regions that support these services:

* Amazon EventBridge Custom Event Bus, Pipes, Rules
* AWS Lambda functions
* Amazon Simple Queue Services (SQS) queues
* Amazon DynamoDB tables and streams
* AWS Step Function workflows
* Amazon Simple Notification Service (SNS) topics

You can find services available by region in the [Global Infrastructure documentation](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/).

## Deployment Steps (required)

1. Clone the code repository using command:
 ```bash
 git clone https://github.com/aws-solutions-library-samples/guidance-for-building-cross-platform-event-driven-payment-systems-on-aws
 ```
2. Change directory to the source folder inside the repository: 
```bash
cd guidance-for-building-cross-platform-event-driven-payment-systems-on-aws/source
```
3. Initialize Terraform using the following command
 ```bash
 terraform init
 ```
4. To see the resources that will be deployed, run command:
 ```bash
 terraform plan
 ```
 - this will not deploy anything to your environment
5. To actually deploy the guidance sample code, run the following command:
 ```bash
 terraform apply -var="region=<your target region>" -var="root_bucket_name=<unique S3 bucket name>"
 ```
 Terraform will generate a plan, then prompt you to confirm that you want to deploy the listed resources. Type `yes` if you want to deploy

## Deployment Validation  (required)

When successful, Terraform Outputs the ARN for the DynamoDB input table's stream. It should look something like this: 

```bash
Apply complete! Resources: 5 added, 7 changed, 5 destroyed.

Outputs:

stream_arn = "arn:aws:dynamodb:us-east-2:111111111111:table/visa/stream/2024-01-04T21:55:22.954"
```

Confirm your resources were created by logging into the AWS Management console. Make sure you are in the region you specified in the `terraform apply` command. Check for your resources.

* Open the EventBridge console and verify a `payments` Custom Event Bus exists
* Open the DynamoDB console and verify a `visa` table exists
* **TODO** WHAT ELSE NEEDS TO BE CHECKED?

**Examples:**

* Open CloudFormation console and verify the status of the template with the name starting with xxxxxx.
* If deployment is successful, you should see an active database instance with the name starting with <xxxxx> in        the RDS console.
*  Run the following CLI command to validate the deployment: ```aws cloudformation describe xxxxxxxxxxxxx```

## Running the Guidance (required)

**TODO**

<Provide instructions to run the Guidance with the sample data or input provided, and interpret the output received.> 

This section should include:

* Guidance inputs
* Commands to run
* Expected output (provide screenshot if possible)
* Output description



## Next Steps (required)

**TODO**

Provide suggestions and recommendations about how customers can modify the parameters and the components of the Guidance to further enhance it according to their requirements.


## Cleanup (required)

**TODO**

- Include detailed instructions, commands, and console actions to delete the deployed Guidance.
- If the Guidance requires manual deletion of resources, such as the content of an S3 bucket, please specify.



## FAQ, known issues, additional considerations, and limitations (optional)


**TODO**

**Known issues (optional)**

<If there are common known issues, or errors that can occur during the Guidance deployment, describe the issue and resolution steps here>


**Additional considerations (if applicable)**

<Include considerations the customer must know while using the Guidance, such as anti-patterns, or billing considerations.>

**Examples:**

- “This Guidance creates a public AWS bucket required for the use-case.”
- “This Guidance created an Amazon SageMaker notebook that is billed per hour irrespective of usage.”
- “This Guidance creates unauthenticated public API endpoints.”


Provide a link to the *GitHub issues page* for users to provide feedback.


**Example:** *“For any feedback, questions, or suggestions, please use the issues tab under this repo.”*

## Revisions (optional)

Document all notable changes to this project.

Consider formatting this section based on Keep a Changelog, and adhering to Semantic Versioning.

## Notices (optional)

Include a legal disclaimer

*Customers are responsible for making their own independent assessment of the information in this Guidance. This Guidance: (a) is for informational purposes only, (b) represents AWS current product offerings and practices, which are subject to change without notice, and (c) does not create any commitments or assurances from AWS and its affiliates, suppliers or licensors. AWS products or services are provided “as is” without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and liabilities to its customers are controlled by AWS agreements, and this Guidance is not part of, nor does it modify, any agreement between AWS and its customers.*


## Authors (optional)

**TODO**

Name of code contributors

## Requirements

### Functional Requirements

Req-1:
Given a successful authorization has completed,  when the request and matching response has been logged in the authorization log/file/table then a single post auth event should be created with the details of the authorization req/response in the payload.

Req-2:
Given a post-auth event is received from the event source when the event has the correct payload then the event must be searched for duplicate

Req-3:
Given a post-auth event is run through duplicate checks when the search indicates that the event is a duplicate then the event must be parked in a separate bucket and the event must not be processed further

Req-4:
Given a post-auth event is run through duplicate checks when the search indicates that the event is not a duplicate then a new event should be sent to the event system and the new event must have the authorization req/response as its payload

Req-5:
Given the event engine receives a de-dup event from them event source, when the payload has the necessary details then the payload must be standardized into ISO20022 format and a new event written in the standardized format. 

Req-6:
Given the event engine receives a standard event from the event source, when the payload conforms to the new format then the payload must be enriched with Account, Branch /Sort-Code, Account Holder Information, Bank Product Type, Transaction Description, Merchant Information, Currency Conversion and a new enriched event gets created with this payload.

Req-7:
Given the event engine receives the enriched event from the event source, when the enriched event payload has all the details required then the event must be passed on to the Account Interface and the Account Interface must produce the related events conforming to the posting event and each event must have a connecting indicator to indicate they are from the same posting sequence

Req-8:
Given the posting engine receives the posting events from the event source, when the event sequence is complete then the sequence events must be enessembled and the final payload should match to the issuing banks posting input which it process as BAU

Req-9:
Given events sources create new events within the new flow, when the events are processed by their respective subscribers / destinations then the events must be idempotent. 

Req-10:
Given events sources create new events within the new flow, when the events are processed by their respective subscribers / destinations then the events must be reconciled and any mismatches should be auto patched.

Req-11:
Given the various event sources which can generate events within the new flow, when the events are ready to be created then suitable configuration should be available for the customer and the configurations must ensure events can be batched, real-time and near-realtime.

### Non-Functional Requirements

Req-1:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to process a million posting events in 15 minutes.

Req-2:
Given the events being generated by the various event sources when the events are being processed in batches, then the biggest batch should not take more than 15 minutes to process.

Req-3:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to fail gracefully and have inbuilt mechanisms for retires and replays

Req-4:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to process a single event in less than a milli second

Req-5:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to withstand network or infrastructure outages and maintain data integrity

Req-6:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to process the events in a secure manner and PCI-DSS fields completely tokenized.

Req-7:
Given the events being generated by the various event sources when the events are being processed then the platform should be able to process the events and have sufficient logging to log the important messages from the platform and have sufficient monitoring & alerting in place to invoke the SRE teams in the event of a failure.

## Decision Register

### To what extent does event ordering matter for this system? 

This system is designed to not be sensitive to event ordering.

1. This is downstream from transaction settlement, so we can assume the customer is in good financial standing for the transaction.
2. Event consumers must not assume previous events have happened or have been processed in a certain way. Instead they must stay within the boundary of their source event.
3. Event consumers must process idempotently within their time window. To put this another way, they must accept replay of transactions and not re-perform work against those transactions within the time window.
4. Events are scoped to not be dependent on each other.

Accepting event ordering as a requirement would likely force us off of EventBridge, or at least require complex ordering checks with event rejection/replay. Queues would need to be FIFO which would have lower throughput limits.

### Should we be using a stream-based system at the core, or an event router? 

This is a question of tradeoff for responsibility. In this iteration we use an event router. This gives us flexible dynamic routing via expressive rules, sufficient throughput and latency, and simple onboarding/offboarding of consumers. We can also enforce decoupling of event consumers more easily. Consumers do not need to manage checkpointing.

The major drawback is that the responsibility of event durability/buffering is offloaded consumers. Events are pushed through the router at a single point in time (replay/retry notwithstanding) and consumers must be online and ready to receive at that time. Consumers are therefore recommended to implement buffering (e.g. a queue) as needed in their own domain. We see this in the sample architecture in the “External Consumer Pattern”.

We do have a fallback to an archive in place and can replay that if needed, though at a non-trivial cost (assumed, not calculated).

We also avoid ordering requirements, which would push us towards a stream-based solution that provide ordering-per-shard.

### Should this be a step function instead?

This may be a legit consideration. However, doing so would fail our goal to decouple consumers. In this case we have a single consumer per event type (plus logging), but a stated tenant is that we are able to support multiple as needed, and can on/offboard them easily, without disruption to others. If they were coupled via an orchestrator like a step function workflow, a deployment to the workflow would be required to add/remove consumers. This could be non-trivial to coordinate with the inbound event flow. Also, though the ceiling is soft and high, we could face an overall max of transaction throughput against Step Function quotas.

### Where is the boundary for inbound events? 

We do not make any assumptions about producer architecture. The boundary of this system starts at a PutEvents call to EventBridge.

We do provide suggested producer patterns across stream, API, and batch systems. Producers may choose to use alternate architectures as their needs dictate.

### Do we need a transaction “state” table? 

We have one in place at this time, but are only using it for duplicate checks for inbound events. We are not updating a “state” throughout the flow. Ideally this will not be required. We do not have a known use case for it at this time.

### How is auditing/logging implemented? 

At this time, we assume that cloudwatch+cloudtrail is sufficient for logging/auditing purposes, unless requirements change.

### How is this PCI- (etc.) compliant? 

We assume all inbound records are pre-tokenized. This will be described in our event schemas. All included services are in scope for PCI/etc. Customer-managed keys will be for encryption wherever possible.

### Should we use a QLDB for reconciliation? 

Not yet discussed.

### What is the defined blast radius for cloud provider impact? 

The architecture as designed is single region, multi-AZ due to inherited multi-AZ characteristics of the chosen services.

### What language should we write in? 

We see financial services customers using mostly Java and Python. For simplicity/readability we will use Python.

### What IaC framework should we use? 

We see financial services customers using primarily Terraform, therefore we will match.
