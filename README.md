# BigQuery multimodal capabilities

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

Imagine a large city transportation agency which is trying to improve passenger satisfaction. The
agency would like to be notified if there are issue with cleanliness and safety of the
bus stops. The city decides to install low cost outdoor facing cameras on its bus fleet and
automatically upload pictures of the bus stops to a cloud for automatic issue detection. The city
also provides a customer portal to allow uploading bus stop pictures by passengers.

The images should be automatically analysed and if the bus stop is found to be dirty - an incident
is automatically created. The incident is considered to be resolved if a new image show the bus stop
in acceptable condition.

## Implementation

The code in this repo shows how images uploaded to Google Cloud Storage buckets can be
automatically analysed without the need to build custom AI/ML models. Only simple and
intuitive Gemini prompt and SQL code are needed to create a fully functional, scalable and secure
implementation of a non-trivial image analysis. Additionally, it shows how vector and full text
search capabilities of BigQuery can be used to implement semantic search of images.

The following is a high level architecture diagram of the solution:
![Architecture Diagram](docs/architecture.png)

There are two implementation of the solution. One uses a Vertex AI Notebook to show the step-by-step
implementation of the solution and use a set of test images to illustrate the actual image
processing. The other implementation is a set of Terraform scripts that automatically creates a
fully functional deployment of the solution.

Currently, the two implementations create two independent BigQuery datasets and Cloud Storage
buckets. This is done to be able to run the to implementations independently of each other.

## Getting Started with the Notebook

For a step-by-step walkthrough of the data processing workflow, refer to the [Multimodal Analysis and Search of Bus Stops](./notebooks/multimodal_analysis_search.ipynb) notebook. This notebook is self-sufficient and can be run independently without needing any other components of this repository.

You can run the notebook in a Vertex AI Workbench instance, in Google Colab Enterprise, or directly in BigQuery Studio. It assumes you have a Google Cloud project with permissions to create a Cloud Storage bucket, a BigQuery dataset and a BigQuery cloud resource connection, and to grant that connection's service account the Vertex AI User role in order to interact with Vertex AI models such as Gemini.

## Getting Started with the Terraform

### Prerequisites

You need to have access to a Google Cloud project with an active billing account.

### Creating infrastructure

1. Clone this repo and switch to the checked out directory
2. Designate or create a project to create all the artifacts and
   create `infrastructure/terraform/terraform.tfvars` file with
   the following content:

```text
project_id = "<your project id>"
notification_email = "<your email address for incident alert notifications>"
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

There is a test image files in the [data](data) directory. For example, use

```shell
./copy-image.sh data/bus-stop-1-dirty.jpeg bus-stop-1-dirty.jpeg stop-1
```

to simulate capturing of a dirty bus stop. `copy-image.sh` takes three parameters - source file (
must be a JPEG image), destination object name and the id fo the bus stop. You can try to take a
picture of a bus stop yourself and upload it to the bucket to see how the Gemini model is able to
analyze it.

[//]: # (## Analysis)

[//]: # ()
[//]: # (### Vector search analysis)

[//]: # ()
[//]: # (#### Finding recent images with broken glass)

[//]: # ([//]: # TODO&#40;&#41;)

[//]: # ()
[//]: # (### Full text search)

[//]: # ([//]: # TODO&#40;&#41;)

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