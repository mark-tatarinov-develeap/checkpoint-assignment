# checkpoint-assignment
## Project Guide

1. Terraform folder includes all infrastructure for the main workflow
2. Grafana contains terraform code specifically for Grafana + a dashboard folder with the json file exported for the dashboard.
3. The jenkins folder contains CI and CD folders, each contains a Jenkinsfile for CI and CD - seperatly
4. The Producer the Consumer folders contain the code for these microservices + a Dockerfile and requirements 
5. The Version.json file contains the minor and major versions for the producer and the consumer - used by the CI job

## Terraform And Infrastructure walkthrough

Terraform version used: v1.14.0

The Terraform code creates:

1. A VPC, subnets, security groups and a NAT Gateway - should be used only to pull the Grafana image in this case
2. VPC Endpoints - much cheaper than using a NAT Gateway for microservice communication with AWS services.
3. S3 and SQS Queue - our serverless infra
4. IAM roles, policies, trust policies and attachments
5. ECS Cluster, ECS services (including task and container definitions - for the producer (the validator) and the consumer), Capacity provider and related ASG + LT.
6. Cloudwatch log groups for our microservices and Grafana (in the Grafana terraform code)
7. ECS service for Grafana (including the whole package same as number 5)

Terraform uses a remote s3 bucket to manage the state, it has 2 different state files, one for the main infra and another for Grafana specifically, locks are managed in the s3 bucket, dynamoDB lock managment is deprecated.




Some important points I want to address:
* Tasks are using the awsvpc networking mode, this creates an ENI for each task and attaches it on the corresponding EC2 instance, this is the recommended way to run tasks right now (Tasks are treated as nodes, get their own private IPs, SGs, ENIs, no more port conflicts, and maximum isolation with out of the box service discovery), this is the reason desired instances on the ASG is set to 3, t2.micro instance only supports 1 ENI, each task gets it's own instance automatically and attaches and ENI.
* Continuing my previous point, in this task the better thing to do was to use a bridge networking mode, but I tried to stay as loyal to real-life environments as possible.
* t2.micro instances are super-small, so the CD bugs when we update a task revision, we need to stop the task that is running (the old one) and only then the new one can run without being stuck on pending.
* The Terraform code runs as part of the CD - since the CD is responsible to update the container definition, this is not good and shouldn't happen, what should be happening in real environments is that the terraform code is completly decoupled from the devs repo (sits in it's own repo), has it's own pipeline, and the only thing that might reside here is only the "container definition" submodule, for updating the image version. - this is happening only because I wanted to make everything as compact and centered as possible for the home assignment.
* Grafana terraform code is manually deployed, not as part of the CD like the main infra.
* The state bucket and SSM parameters were created manually outside of Terraform, reason is I was not intrested in managing the state bucket itself in terraform (although it's possible and valid) to prevent mistakes, and SSM stores secrets, I don't want to expose them in my code.
* ECRs were also created manually - I wouldn't want it as part of the CD, ideally they should be created using terraform
* ALB listens on port 80, aka without TLS encryption, in a "real project" I would create an ACM certificate using IaC and attach it to a 443 listener created for the ALB, then redirect the traffic to port 80/8080 after TLS termination.
* I had no permission to block public access to the S3 bucket, de-attach ENI and maybe more stuff I probably forgot, which causes destroy operations to not fully be executed, using my access and secret keys.
* Ideally SQS should also have a DLQ attached to it, here it's pointless but in more complex workloads it's a best practice.

## CI/CD - What We Have And What We Should have

The CI here adheres the assignment requirements, it builds and pushes the docker image, It also computes the tag.
Regarding versioning: here is not the ideal way to version imo, I also think the CI should create a tag on the Git repo for each new version, since it was not required I didn't do that to save time for other things, here my versioning mechanism goes by using the version.json file for minor and major versions and for the patch version it uses the Jenkins build number, this is just to demonstrate versioning and can be much better and complex given real life situations and more time.

The stuff CI is missing: 
* Unit Tests
* Component (integration) Tests with a temporary env - much easier done on EKS, ECS is not ideal for this at all in my opinion
* Security Scans with tools like Trivy, CheckMarx, Snyk, etc
* In case we use an EKS I would also add packaging and pushing an Helm chart
* Real semantic and/or semi-semantic versioning, take into considaration release, feature and hotfix branches.

The CD is relatively simple here, takes image tags as parameters, then runs a validation and a terraform plan, then waits for user input to apply (or abort).

The CD is missing:
* Security scan validations.
* In case of EKS - deployment of helm charts
* Can also add auto promotion for higher ENVs
* Again, Should not deploy infra!

To execute the CD, make sure you have the image tags in the ECR repo, as of now, 1.0.11 and 1.0.12 are valid tags for both services.

### Jenkins Requirements:

I used 2 important plugins to build the CI/CD proccesses optimally:
* Credentials Plugin
* AWS Credentials Plugin

The 1st one is installed with the Jenkins recommended plugin installation (together with some more essentials), the AWS one has to be installed manually.

Regarding Credentials:

A credential called aws-creds should be created, with the AWS Credentials type, insert Access and Secret Keys in the required fields.
A credentials called git-creds should be created of Username and Password type, with the git username and a PAT for the password field, the repo was private during development, now it will turn public, but not having this will still fail the pipeline.

Jenkins Agent should have docker installed with permissions to access the socket.

To setup the pipelines simply create a new pipeline kind item, input the https url of the repo, pick creds (although if the repo is public I don't think this will be nessecary) and don't forget to provide the path to the corresponding Jenkinsfile


## Grafana

Grafana Terraform code is dependent on existing infrastructure, you need to make sure CD has deployed all the main infra, and only then deploy the Grafana Terraform code, it uses the same ECS cluster, ALB, VPC and subnets.

Grafana UI is accessible on this endpoint (notice it runs on port 3000): http://checkpoint-exam-alb-1386994032.us-west-2.elb.amazonaws.com:3000/

Admin username and password for Grafana are stored as ecrypted SSM parameters at these paths: /devops-exam/grafana/admin_pass and 
/devops-exam/grafana/admin_user, I am not sure if I should expose them here since the repo is going public, but you can decrypt these params to login.

Inside there is a dashboard which monitors the infrastructure of the workflow.

Missing things:
* Container Insights is not enabled, if it was we could also visualize pending and desired task counts (and much more info)
* Application logs
* Prometheus Metrics - this would be heavy and time consuming to install on t2.micro cluster, I would definetly use Prometheus + Alert Manager as well in real life (not a fan of Grafana alerts)
* Alerts

Another point: An older, already destroyed ALB, might appear in the ALB variable of Grafana, if you see no data on the ALB graphs, try choosing the other one, this one worked.


## The Microservices And How To Use Them

### Producer (validator)

This service will validate the token against the token stored as an encrypted ssm parameter, if the tokens are equal, it will also validate the data, if everything is OK it will pass the data part of the payload as json message to the SQS queue.

SQS_QUEUE_URL and TOKEN_PARAM_NAME (path of the token in ssm) are required env variables which are passed at the container definition.

It prints a status (with an error if something is wrong) if the message is accepted or declined.

To execute the workflow, we begin with sending a POST request to the producer service, this is an example curl:

```bash
curl -X POST "http://checkpoint-exam-alb-1386994032.us-west-2.elb.amazonaws.com/process" -H 'Content-Type: application/json' --data @payload.json
```

While the payload.json file looks like this:

```json
{
  "data": {
    "email_subject" : "Happy new year!",
    "email_sender" : "John Doe",
    "email_timestream": "1693561101",
    "email_content": "Just want to say... Happy new year!!!"
  },
  "token" : "{TOKEN AS DESCRIBED IN ASSIGNMENT PDF}"
}
```

if we see:
```json
{"status":"accepted"}
```
Then it worked, anything else is an error and description will appear instead of this.

### Consumer (processor)

POLL_INTERVAL_SECONDS env variable defaults to 10 seconds, if not set in the container definition, currently it is set to 60, meaning every minute the service will poll the SQS and pull messages.

OUTPUT_BUCKET and SQS_QUEUE_URL are also required and are set by terraform.

Once the consumer has recieved a message, it will simply upload it into an S3 bucket as a json file under the emails folder.
To view the file:
```bash
aws s3 ls s3://checkpoint-exam-messages/emails/
```

This service is completly private and you can't access it from the outside, it uses a Gateway Endpoint to talk to the S3 service.


## IMPORTANT NOTICE
If we destroy and redeploy terraform, ALB DNS might change so the endpoints themselves might change too, this only affects access to Grafana and the POST request endpoint.


## Much TODO

Following the docs, there are things I mentioned that should work diffrently, it's important for me to clarify that the 2 reasons it's written here rather than applied, is to save money, and save time, IRL things should not look like here, this is only a partial demonstration.

If there are any questions, feel free to contact me.
