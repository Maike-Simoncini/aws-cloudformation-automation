#!/bin/bash

# Configurações de ambiente local
ENDPOINT="http://localhost:4566"
REGION="us-east-1"
TABLE_NAME="RegistroProcessamento-dev"
BUCKET_NAME="bucket-automacao-dio-dev"
FUNCTION_NAME="S3Processor-dev"

echo "=== 1. Limpando pacotes antigos ==="
rm -f lambda_deployment.zip

echo "=== 2. Compactando o código-fonte da Lambda ==="
cd ../src
zip -r ../scripts/lambda_deployment.zip lambda_function.py
cd ../scripts

echo "=== 3. Criando Tabela no DynamoDB ==="
aws --endpoint-url=$ENDPOINT --region=$REGION dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

echo "=== 4. Criando IAM Role Fictícia no LocalStack ==="
aws --endpoint-url=$ENDPOINT --region=$REGION iam create-role \
    --role-name LambdaExecutionRoleLocal \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

echo "=== 5. Criando a Função Lambda ==="
aws --endpoint-url=$ENDPOINT --region=$REGION lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.11 \
    --role arn:aws:iam::000000000000:role/LambdaExecutionRoleLocal \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_deployment.zip \
    --environment "Variables={LOCALSTACK_ENDPOINT=$ENDPOINT,DYNAMODB_TABLE=$TABLE_NAME}"

echo "=== 6. Criando o Bucket Amazon S3 ==="
aws --endpoint-url=$ENDPOINT --region=$REGION s3 mb s3://$BUCKET_NAME

echo "=== 7. Vinculando o Gatilho de Eventos do S3 para a Lambda ==="
LAMBDA_ARN="arn:aws:lambda:$REGION:000000000000:function:$FUNCTION_NAME"

NOTIFICATION_CONFIG='{
    "LambdaFunctionConfigurations": [
        {
            "LambdaFunctionArn": "'"$LAMBDA_ARN"'",
            "Events": ["s3:ObjectCreated:*"]
        }
    ]
}'

aws --endpoint-url=$ENDPOINT --region=$REGION s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration "$NOTIFICATION_CONFIG"

echo "=== Ambiente configurado com sucesso no LocalStack! ==="
