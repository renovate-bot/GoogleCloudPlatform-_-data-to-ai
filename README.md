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

You might also get a transient error "Error creating Routine: googleapi: Error 404: Not found: Model ..."  then
a BigQuery model creation failed (due to a transient error related to a service account's permissions).
Run this script to force re-running the SQL statements which create the models:

```shell
./force-rerunning-model-creation-scripts.sh 
terraform apply
```

## Created infrastructure artifacts

After the Terraform scripts successfully complete, the following artifacts are created in your
project:

* `<project-id>_-bus-stop-images` Cloud Storage bucket
* `bus_stop_image_processing` BigQuery dataset containing:
    * `images` object table, pointing to the Cloud Storage bucket
    * `reports` table, containing the results of the image analysis
    * `incidents` table, containing the automatically detected bus stops requiring attention
    * `text_embeddings` table with the embeddings of the descriptions of the images
    * `multimodal_embeddings` table with the embeddings of the images themselves
    * several tables with `_watermark` at the name suffix, which are used to track processing state
    * `process_images` stored procedure
    * `update_incidents` stored procedure
    * `semantic_text_search` table valued function
    * `semantic_multimodal_search` table valued function
    * `default_model`, `pro_model`, `multimodal_embedding_model` and `text_embedding_model`, which
      refer to different Vertex AI foundational models
* `image-processing-invoker` Cloud Run function to run both `process_images` and `update_incidents`
  stored procedures
* `run_bus_stop_image_processing` Cloud Schedule to run the invoker function
* `data-processor-sa` service account as the principal used by the invoker function

## Processing images using multimodal LLMs
There are two stored procedures which contain the logic of processing images.

[`process_images`](/infrastructure/terraform/bigquery-routines/process-images.sql.tftpl) processes
new images uploaded since the last time this procedure was run. It extracts several attributes 
from the image (e.g., cleanliness level, number of people) and the generic image description 
using a Vertex AI multimodal LLM. The result of processing is stored in the `reports` table. 
The description's text embedding is generated using a Vertex AI's text embedding LLM and stored 
in the `text_embeddings` table. The procedure expects all the files to contain "stop_id" metadata 
attribute.

[`update_incidents`](/infrastructure/terraform/bigquery-routines/update-incidents-procedure.sql.tftpl)
looks for newly processed images and creates new records in `incidents` tables in case the bus stop
cleanliness level is low and there is no active incident. If the bus stop appears clean, it updates
the current incident to automatically "close" it.

You can run each procedure independent of each other.

### Enabling automatic processing

The invoker Cloud Function is scheduled to run every 3 minutes using Cloud Scheduler. It runs
`process_images` and `update_incidents` in succession. This function simulates end-to-end processing
of uploaded files.

By default, the schedule is disabled. To process new images automatically, navigate
to [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler).
in Google Cloud Console and enable `run_bus_stop_image_processing` schedule.

Notice, that if you re-run `terraform apply` it will disable the schedule again. You can permanently
enable the scheduler by changing the Terraform variable `pause_scheduler` to `false`.

### Uploading test files

`process_images` procedure looks for the files in the `images` "folder" of the bucket. A shell 
script [`copy-image.sh`](/copy-image.sh) in the root directory can be used to copy images to that 
folder. The script takes three parameters - source file (must be a JPEG image), destination object 
name and the id of the bus stop. You can try to take a picture of a bus stop yourself and upload it 
to the bucket to see how the Gemini model is able to analyze it.

There is a test image file generated by Imagen 3 in the [data](data) directory. To simulate
capturing an image of a dirty bus stop, run 

```shell
./copy-image.sh data/bus-stop-1-dirty.jpeg bus-stop-1-dirty.jpeg stop-1
```

There are also several staged real and somewhat altered images of bus stops in various degrees of 
cleanliness. Run:

```shell
./upload-batch.sh data/batch-1.txt 
```

to simulate transmission of bus stop images from several buses. 

You can run `process_images` manually after you uploaded images, or you can let the automated 
processing take care of this. You can the see the progress by examining the contents of `reports` table.
If you run `update_incidents`, the `incidents` table should also be updated if there are bus stops
which need attention.

## Searching and analyzing images
There are multiple ways to search images using BigQuery's SQL. 

### Using extracted attributes
The primary purpose of extracting the attributes like `cleanliness_level` and `is_bus_stop` is to
enable the downstream processing to use very simple and efficient queries to analyze the state of
bus stops. Once extracted, you can easily answer questions like "what is the current number and 
percentage of stops which require attention" or create Looker dashboards to show historic trends
and allow complex filtering and aggregation.

As the number of use cases grows, the prompt that extracts the attributes can be adjusted to extract
additional attributes to be stored in the `reports` table.

There could be a need ad-hoc analysis on the attributes which are not currently extracted. 
The following sections offer different options on how this analysis can be done.

### Full text search

The Terraform scripts created a full text search index on the `description` field of the `reports`
table. This field can be searched directly using
BigQuery's [SEARCH](https://cloud.google.com/bigquery/docs/reference/standard-sql/search_functions#search)
function:

```sql
SELECT *
    FROM `bus_stop_image_processing.reports`
    WHERE SEARCH(description, "broken glass")
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
from `reports` table). It also includes the `distance` column, which should be used to gauge how
semantically close the matches are.

### Semantic search using multimodal embeddings

[Multimodal embeddings and search](https://cloud.google.com/bigquery/docs/generate-multimodal-embeddings)
is very similar to creating text embeddings and searching them.
The primary difference is a different model used to generate the embeddings.

```sql
SELECT *
    FROM `bus_stop_image_processing.semantic_vector_search`("a bus stop with broken glass")
    ORDER BY distance
```

The majority of the bus stop image embeddings are very similar to each other when default
embedding model is used. Vector searches can return a number of images with very similar distance.

### Hybrid search

You can use multiple ways to search the images and combine them by assigning weights to each type of
search.
For example, this query will attempt to find bus stops with broken glass:

```sql
DECLARE
    multimodal_coefficent DEFAULT 5.;
DECLARE
    text_coefficient DEFAULT 7.;
DECLARE
    full_text_weight DEFAULT 10.;

WITH 
semantic_multimodal_search AS (
    SELECT uri, distance
        FROM `bus_stop_image_processing.semantic_multimodal_search`("a bus stop with broken glass")),
semantic_text_search AS (
    SELECT uri, distance
        FROM `bus_stop_image_processing.semantic_text_search`("a bus stop with broken glass")),
full_text_search AS (
    SELECT uri
        FROM `bus_stop_image_processing.reports`
        WHERE SEARCH(description, "broken glass")),
combined_results AS (
    SELECT uri, multimodal_coefficent/distance  AS weight FROM semantic_multimodal_search
        UNION ALL
    SELECT uri, text_coefficient/distance AS weight FROM semantic_text_search
        UNION ALL
    SELECT uri, full_text_weight AS weight FROM full_text_search)
SELECT uri, SUM(weight) AS total_weight
    FROM combined_results
    GROUP BY uri
    ORDER BY total_weight DESC LIMIT 10
```

The exact coefficients and weights used in the query above would need to be adjusted based on
testing of somewhat realistic set of images. The search terms used for each type of search can be
improved based on testing.

Notice that we divided (rather than multiplied) the coefficients by the distances from both text and multimodal semantic 
searches. This is because the smaller the distance the more relevant the result of the vector search. 
The minimum and maximum values of the distances depend on the distance type used by the vector search.
For additional details refer to [VECTOR_SEARCH](https://cloud.google.com/bigquery/docs/reference/standard-sql/search_functions#vector_search)
documentation.

### Analyzing the object table directly
If none of the approaches above give good answers, the source object table can be analyzed using
various prompts. 

This approach can be also used when upgrading to the new versions of various models used here. It is
important that the responses produced by the new models will be correctly processed by the SQL 
statements in the [`process_images`](/infrastructure/terraform/bigquery-routines/process-images.sql.tftpl) 
stored procedure.

### Note on using vector indexes
This repo doesn't create [vector indexes](https://cloud.google.com/bigquery/docs/vector-index) automatically. 
Vector indexes can be created only if the table to be indexed contains at least 5,000 records. 
It's highly recommended to add the indexes in production environment to optimize vector search performance.

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