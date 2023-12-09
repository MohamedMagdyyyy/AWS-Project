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

Ingestion Pipeline

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


Then when a Kinesis stream recieves an event another lambda is invoked to load the data in DynamoDB and the JSON S3 Bucket

The code for the lambda function kinesis-trigger is as following

```python
import base64
import boto3
import json
from datetime import datetime

print('Loading function')


def lambda_handler(event, context):
    client = boto3.client('dynamodb')
    bucket = boto3.client('s3')
    records = []
    
    for record in event['Records']:
        # Kinesis data is base64 encoded so decode here
        json_data = base64.b64decode(record['kinesis']['data']).decode('utf-8')
        records.append(json_data)
        dict_data = json.loads(json_data)
        
        
        keys = ['Country', 'InvoiceDate']
        dict_data_to_be_loaded = {k: v for k, v in dict_data.items() if k in keys}
        json_data_to_be_loaded = json.dumps(dict_data_to_be_loaded)
        
        # updating customer table
        respone1 = client.update_item(
            TableName = 'customer',
            Key = {
                'CustomerID': {'N': str(dict_data['CustomerID'])} 
            },
            AttributeUpdates = {
                str(dict_data['InvoiceNo']) : {
                    "Value": {"S": json_data_to_be_loaded},
                    "Action": "PUT"
                }
            })
        print('customer table updated')
        
        # updating invoice table
        keys = ['Quantity', 'Description', 'UnitPrice']
        dict_data_to_be_loaded = {k: v for k, v in dict_data.items() if k in keys}
        json_data_to_be_loaded = json.dumps(dict_data_to_be_loaded)
        respone = client.update_item(
            TableName = 'invoice',
            Key = {
                'InvoiceNo': {'S': str(dict_data['InvoiceNo'])} 
            },
            AttributeUpdates = {
                str(dict_data['StockCode']) : {
                    "Value": {"S": json_data_to_be_loaded},
                    "Action": "PUT"
                }
            })
        print('invoice table updated')
    time = datetime.now().strftime("%d-%m-%Y_%H:%M:%S")
    output = '[' + ','.join(records) + ']'
    
    # loading raw jsons in S3 Bucket
    bucket.put_object(Body = output, Bucket = 'batch-process-ecom', Key = 'output'+time+'.json')
    print('object added to bucket successfully')
        
    return 'Successfully processed {} records.'.format(len(event['Records']))

```

#Data Processing Layer

In the data processing layer, to automate the loading of customer events in Redshift, I was facing a challenge where AWS Glue was unable to corretly learn the JSON schema however, it could successfully learn the schema from a CSV file, thus to load the data in Redshift I preformed the ETL job locally on my machine (can be automated using cronjob) using a Bash Script where the Bash Script automates the downloading of raw data, transformation, uploading of transformed data in CSV S3 Bucket and finally to run the Glue Job to load the Data from CSV S3 Bucket to Redshift

The code for the bash script transform-script.sh is as following:
```python
# getting all JSON from S3 bucket to local
aws s3 sync s3://batch-process-ecom ./batch-process-ecom 

# deleting all JSON from S3 bucket
aws s3 rm s3://batch-process-ecom --recursive

for filename in ./batch-process-ecom/*; do
  TIMESTAMP=`date +%Y-%m-%d_%H:%M:%S:%N`
  echo $filename
  dasel -r json -w csv < $filename > ./staging-bucket-ecom/$TIMESTAMP.csv
done

# uploading the files to the staging S3 Bucket 
aws s3 sync ./staging-bucket-ecom s3://staging-bucket-ecom

# deleting all local files after transformations
rm -rf ./batch-process-ecom/*
rm -rf ./staging-bucket-ecom/*
aws glue start-job-run --job-name batch-etl-job
```




#Data Storage & Visualization Layer

The end users of the AWS data platform are customers who are using the E-Commerce website/application, and data analytics team who are performing analytics to extract insights and drive business growth. The DynamoDB was mainly used for it's fast write and read operations to support customer Queries in the E-Commerce front end such as

Listing all invoices
Searching for specific invoice number
Furthermore, for data analytics operations Redshift datawarehouse was used and connected to Tableau as following

First we obtain our Redshift cluster end point and add it to Tableau as following

![68747470733a2f2f692e706f7374696d672e63632f52684657773253312f53637265656e73686f742d323032322d30372d30312d3132323733392e706e67](https://github.com/MohamedMagdyyyy/AWS-Project/assets/153362625/20872181-2860-415e-8792-4d39f2701efb)

Then analysis can be preformed (i.e Checking which items had the most purchases)
![68747470733a2f2f692e706f7374696d672e63632f4b594362305644722f746573742e706e67](https://github.com/MohamedMagdyyyy/AWS-Project/assets/153362625/88f9486b-9407-4ac2-aa6b-92ad686af4f7)

