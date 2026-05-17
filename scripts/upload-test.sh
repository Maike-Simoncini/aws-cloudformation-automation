#!/bin/bash

ENDPOINT="http://localhost:4566"
REGION="us-east-1"
BUCKET_NAME="bucket-automacao-dio-dev"
TABLE_NAME="RegistroProcessamento-dev"
TEST_FILE="arquivo_teste_producao.txt"

echo "=== 1. Criando arquivo de teste temporário ==="
echo "Log de eventos de segurança gerado em $(date)." > $TEST_FILE

echo "=== 2. Enviando arquivo para o Bucket S3 (Gatilhando a Lambda) ==="
aws --endpoint-url=$ENDPOINT s3 cp $TEST_FILE s3://$BUCKET_NAME/$TEST_FILE

echo "=== 3. Aguardando processamento assíncrono (3 segundos) ==="
sleep 3

echo "=== 4. Verificando persistência de dados no DynamoDB ==="
aws --endpoint-url=$ENDPOINT --region=$REGION dynamodb scan --table-name $TABLE_NAME

echo "=== 5. Limpando artefato de teste local ==="
rm -f $TEST_FILE

echo "=== Teste de fluxo Serverless finalizado! ==="
