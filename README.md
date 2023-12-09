# AWS-Project
# Introduction

This is a data engineering project using AWS services, the used infrastructure automates extraction, transformation and loading of customer events in a Redshift Datawarehouse for OLAP operations and DynamoDB Database for OLTP operations.

Tech Stack: AWS API Gateway, Kinesis, Lambda, S3, DynamoDB, Glue, Redshift and Tableau.

Here is the used Architecture

![68747470733a2f2f692e706f7374696d672e63632f634a3152486b71572f42444d2d5765656b2d312d4d696e642d4d61702d312e706e67](https://github.com/MohamedMagdyyyy/AWS-Project/assets/153362625/f26c6e45-beca-486e-bade-1c3b90ad35bb)

# Goals

The objective of this AWS data infrastructure is to have a scalable platform that is able to process data (customer events) in real time and store the data in a datawarehouse (redshift) for analysis and data mining. DynamoDB is used to store the data in realtime so that customers can query their invoices, items, etc.. in real time. Furthermore, the data goes into another path where the raw data (json) obtained by the API Gateway is stored in a S3 Bucket and a Bash script extracts the data from the raw S3 Bucket, transforms in into CSV and loads the data in a CSV S3 bucket then a glue crawler learns the schema of the data stored in the CSV S3 Bucket and learns the schema of the Redshift table and then an scheduled ETL job simply loads the data from the CSV S3 Bucket to Amazon Redshift and Finally Tableau is connected to Amazon Redshift for Data Analysis operations.

#The Data Set
The dataset is a real world dataset generated by an e-commerce business in the U.K, the dataset was obtained from kaggle using the following link https://www.kaggle.com/datasets/carrie1/ecommerce-data

The dataset is relatively large consisting of 8 columns and 542k observations

The attributes of the dataset is as following
![68747470733a2f2f692e706f7374696d672e63632f634a3152486b71572f42444d2d5765656b2d312d4d696e642d4d61702d312e706e67](https://github.com/MohamedMagdyyyy/AWS-Project/assets/153362625/4f9a2fff-2c92-47d5-9743-f737d6b9376b)


# Data Ingestion Layer
#Ingestion Pipeline
AWS API-Gateway is setup an created to support a POST request where customer events are POSTed to the API-Gateway automatically.

A event-streaming.py python script is created to simulate customer events where every line of the dataset is transformed to json and POSTed to the API-Gateway.

The code for the event-streaming.py is as following:

```python
import pandas as pd
import requests

data = pd.read_csv('data/sample-data.csv')
BASE_URL = 'https://f7e5ce921k.execute-api.us-east-1.amazonaws.com/test/events'

if __name__ == '__main__':
    for i in data.index:
        event = data.loc[i].to_json()
        response = requests.post(BASE_URL, event)
        print(response)
```

Then a Lambda is invoked whenever an event is POSTed to the API-Gateway, the Lambda Function takes the event and produces it to a kinesis stream for buffering to avoid any stalling of the DynamoDB database due to high load and to allow for a scalable messaging queue service.

The code for the lambda function data-ingestion is as following
```python
import json
import boto3

def lambda_handler(event, context):
    # TODO implement
    method = event['context']['http-method']
    json_data = event['body-json']
    
    if method == 'POST':
        client = boto3.client('kinesis')
        response = client.put_record(
                StreamName ='event-ingest',
                Data = json.dumps(json_data),
                PartitionKey ='string')
        print(f"proccessed the record successfully {response}")
    
    return {
        'statusCode': 200,
        'event': json_data
    }
```
        
