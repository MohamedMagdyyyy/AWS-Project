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
