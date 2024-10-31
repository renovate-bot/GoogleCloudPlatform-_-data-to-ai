# BigQuery multimodal capabilities demo

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=GITHUB_URL)

This repo contains a fully functional demo to show how BigQuery can do complex processing of images
using multimodal GenAI capabilities of Google Cloud.

## Features

* Ability to automatically make images uploaded to Cloud Storage available for processing via
  BigQuery's SQL
* Ability to extract complex image attributes without the need to train custom models
* Full text search on the automatically generated description of the images
* Vector search for images with similar attributes

## Use Case

The code in this repo processes images of bus stops captured either from buses or taken by
passengers.
The images are automatically analysed and if the bus stop is found to be dirty - an incident is
automatically created. The incident is considered to be resolved if a new image show the bus stop
in acceptable condition.

[//]: # (TODO: add architecture diagram)

## Getting Started

### Prerequisites

You need to have access to a Google Cloud project with an active billing account.

### Creating infrastructure

1. Clone this repo and switch to the checked out directory
2. Designate or create a project to create all the artifacts and
   create `infrastructure/terraform/terraform.tfvars` file with
   the following content:

```text
project_id = "<your project id>"
```

There are additional variables that can be provided in that file to further customize the
deployment.
Please check [infrastructure/terraform/variables.tf](infrastructure/terraform/variables.tf) for
detail.

3. Create infrastructure to run the demo:

```shell
cd infrastructure/terraform
terraform init
terraform apply
```

There is a chance you will get an error when creating a Cloud Run function the first time you run
the script. Wait for a couple of minutes and try again.

## Testing image processing

Once the infrastructure is created, the images which are uploaded to the Cloud Storage bucket will
be
automatically processed (by [default](infrastructure/terraform/variables.tf), the process runs every
3 minutes).
You can manually control the scheduler (pausing or resuming) by changing its status
in [Cloud Console](https://console.cloud.google.com/cloudscheduler).

### Upload the test files

There are several test image files in the [data](data) directory. For example, use

```shell
./copy-image.sh data/bus-stop-1-dirty.jpeg bus-stop-1-dirty.jpeg stop-1
```

to simulate capturing of a dirty bus stop. `copy-image.sh` takes three parameters - source file (
must be a JPEG image), destination object name and the id fo the bus stop.

## Analysis
### Vector search analysis
#### Finding recent images with broken glass

#### Identifying a bus stop based on a customer uploaded image

### Full text search

## Cleanup

```shell
terraform -chdir infrastucture/terraform destroy 
```

## Contributing

Contributions to this library are always welcome and highly encouraged.

See [CONTRIBUTING](CONTRIBUTING.md) for more information how to get started.

Please note that this project is released with a Contributor Code of Conduct. By participating in
this project you agree to abide by its terms. See [Code of Conduct](CODE_OF_CONDUCT.md) for more
information.

## License

Apache 2.0 - See [LICENSE](LICENSE) for more information.