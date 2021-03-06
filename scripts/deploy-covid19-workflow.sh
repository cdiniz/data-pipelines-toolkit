#!/bin/bash

# eval minikube docker env to make the local docker images available inside k8s cluster
eval $(minikube docker-env)

cd ../connectors/covid19-uk-ingestions 

# create jar for db-migrations
make create_uberjar

cd ../../

# create ingestion and transformation docker images
docker build -f data-pipelines/covid19-uk/Dockerfile.ingestion -t covid19ukingestions:latest .
docker build -f data-pipelines/covid19-uk/Dockerfile.transformation -t covid19dbt:latest .

# cleanup old argo template
argo -n argo template delete covid19-uk

# generate workflow using helm templating engine
helm template covid19-uk data-pipelines/covid19-uk --set environment=dev --set name=covid19-uk --output-dir outputs

# create workflow template on argo
argo -n argo template create outputs/covid19-uk/templates/workflow-template.yaml

# deleting old cron workflow 
kubectl -n argo delete cwf covid19-uk

# create workflow template on argo
argo -n argo cron create outputs/covid19-uk/templates/cron-workflow.yaml

# trigger workflow template on argo
argo submit --from workflowtemplate/covid19-uk -n argo -p start-date="" -p end-date=""