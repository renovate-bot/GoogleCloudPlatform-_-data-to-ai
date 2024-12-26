# BigQuery multimodal and semantic search capabilities

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

There are two implementations of the solution. One uses a Vertex AI Notebook to show the
step-by-step
implementation of the solution and use a set of test images to illustrate the actual image
processing. The other implementation is a set of Terraform scripts that automatically creates a
fully functional deployment of the solution.

Currently, the two implementations create two independent BigQuery datasets and Cloud Storage
buckets. This is done to be able to run the implementations independently of each other.

## Getting Started with the Notebook

For a step-by-step walkthrough of the data processing workflow, refer to
the [Multimodal Analysis and Search of Bus Stops](./notebooks/multimodal_analysis_search.ipynb)
notebook. This notebook is self-sufficient and can be run independently without needing any other
components of this repository.

You can run the notebook in a Vertex AI Workbench instance, in Google Colab Enterprise, or directly
in BigQuery Studio. It assumes you have a Google Cloud project with permissions to create a Cloud
Storage bucket, a BigQuery dataset and a BigQuery cloud resource connection, and to grant that
connection's service account the Vertex AI User role in order to interact with Vertex AI models such
as Gemini.

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
the script. Wait for a few minutes and try again.

You might also get a transient error "Resource precondition failed" related to creating BigQuery
models. If the error message indicates that "...error_result is list of object with 1 element" then
the model creation failed (due to a transient error related to a service account's permissions).
Run this script to force re-running the SQL statements which create the models:

```shell
./force-rerunning-model-creation-scripts.sh 
terraform apply
```

If the precondition fails with `"...state is "RUNNING"` message, please wait a few seconds and
re-run
`terraform apply` again.

## Created infrastructure artifacts

After the Terraform scripts successfully complete, the following artifacts are created in your
project:

* `<project-id>_-bus-stop-images` Cloud Storage bucket
* `bus_stop_image_processing` BigQuery dataset containing:
    * `images` object table, pointing to the Cloud Storage bucket
    * `reports` table, containing the results of the image analysis
    * `incidents` table, containing the automatically detected bus stops requiring attention
    * `text_embeddings` table with the embeddings of the descriptions of the images
    * several tables with `_watermark` at the name suffix, which are used to track processing state
    * `process_images` stored procedure
    * `update_incidents` stored procedure
    * `semantic_text_search` table valued function
    * `default_model`, `pro_model` and `text_embedding_model`, which refer to different Vertex AI
      LLMs
* `image-processing-invoker` Cloud Run function to run both `process_images` and `update_incidents`
  stored procedures
* `run_bus_stop_image_processing` Cloud Schedule to run the invoker function
* `data-processor-sa` service account as the principal used by the invoker function

## Image processing

`process_images` [stored procedure](/infrastructure/terraform/bigquery-routines/process-images.sql.tftpl)
extracts several attributes from the image (e.g., cleanliness level, number
of people) and the generic image description using a Vertex AI multimodal LLM. The result of
processing is stored in the `reports` table. The description's text embedding is generated using a
Vertex AI's text embedding LLM and stored in the `text_embeddings` table.

### Automatic processing

The invoker Cloud Function is scheduled to run every 3 minutes using Cloud Scheduler. By default,
the schedule
is disabled. To process new images automatically, navigate
to [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler).
in Google Cloud Console and enable `run_bus_stop_image_processing` schedule.

Notice, that if you re-run `terraform apply` it will disable the schedule again. You can permanently
enable the scheduler by changing the Terraform variable `pause_scheduler` to `false`.

### Upload test files

There is a test image file generated by Imagen 3 in the [data](data) directory. To simulate
capturing an image of a dirty bus stop, run (from the
repository's root directory)

```shell
./copy-image.sh data/bus-stop-1-dirty.jpeg bus-stop-1-dirty.jpeg stop-1
```

`copy-image.sh` takes three parameters - source file (must be a JPEG image), destination object name
and the id of the bus stop. You can try to take a
picture of a bus stop yourself and upload it to the bucket to see how the Gemini model is able to
analyze it.

We staged several real bus stops images and altered some of them to illustrate various degrees of
bus stop cleanliness. Run:

```shell
./upload-batch.sh data/batch-1.txt 
```

to simulate transmission of bus stop images from several buses.

## Searching images

There are multiple ways to search for images using BigQuery's SQL.

### Full text search

The Terraform scripts created a full text search index on the `description` field of the `reports`
table. This field can be searched directly using
BigQuery's [SEARCH](https://cloud.google.com/bigquery/docs/reference/standard-sql/search_functions#search)
function:

```sql
SELECT *
FROM `bus_stop_image_processing.reports`
WHERE SEARCH(description, "broken glass");
```

### Semantic search using text embeddings

Semantic search can find matches even when the exact words don't occur in the description.
Function `semantic_text_search` takes the text to search as parameter to perform
a [VECTOR_SEARCH](https://cloud.google.com/bigquery/docs/reference/standard-sql/search_functions#vector_search)
against the generated text embeddings:

```sql
SELECT *
FROM `bus_stop_image_processing.semantic_text_search`("a bus stop with broken glass")
ORDER BY distance
```

The current implementation of the function is hardcoded to return top 10 closest matches (records
from `reports` table). It also includes the `distance` column, which can be used to gauge how
semantically close the matches are.

### Semantic search using multimodal embeddings

[Multimodal embeddings and search](https://cloud.google.com/bigquery/docs/generate-multimodal-embeddings)
are very similar to creating text embeddings and searching them.
The primary difference is a different model used to generate the embeddings.

The majority of the bus stop image embeddings are very similar to each other when default
embedding model is used. Vector searches can return a number of images with very similar distance.

## Cleanup

```shell
terraform -chdir infrastructure/terraform destroy 
```

## Contributing

Contributions to this library are always welcome and highly encouraged.

See [CONTRIBUTING](CONTRIBUTING.md) for more information how to get started.

Please note that this project is released with a Contributor Code of Conduct. By participating in
this project you agree to abide by its terms. See [Code of Conduct](CODE_OF_CONDUCT.md) for more
information.

## License

Apache 2.0 - See [LICENSE](LICENSE) for more information.