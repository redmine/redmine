#!/bin/bash


if [ -z "$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" ]; then
    echo "Error: AWS_CONTAINER_CREDENTIALS_RELATIVE_URI is not set."
    echo "Make sure your Fargate task has an IAM role assigned to it."
    exit 1
fi

if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3_BUCKET is not set."
    exit 1
fi

cat > /usr/src/redmine/config/s3.yml << EOF
production:
  bucket: "${S3_BUCKET}"
  folder: ""
EOF

exec /docker-entrypoint.sh "$@"
