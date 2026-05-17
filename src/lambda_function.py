import json
import urllib.parse
import boto3
import os
from datetime import datetime

# Inicializa os clientes da AWS fora do handler para otimizar a performance (Warm Start)
# Se as variáveis de ambiente locais não existirem, ele assume o padrão da AWS
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or os.environ.get("LOCALSTACK_ENDPOINT")

if ENDPOINT_URL:
    # Configuração voltada para testes locais com LocalStack
    s3_client = boto3.client("s3", endpoint_url=ENDPOINT_URL)
    dynamodb = boto3.resource("dynamodb", endpoint_url=ENDPOINT_URL)
else:
    # Configuração padrão quando rodando diretamente na infraestrutura AWS produtiva
    s3_client = boto3.client("s3")
    dynamodb = boto3.resource("dynamodb")

# Define o nome da tabela do DynamoDB via variável de ambiente (boa prática de IaC)
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "RegistroProcessamento")
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Função Lambda principal disparada por eventos do Amazon S3.
    Lê os dados do objeto carregado e persiste os metadados no DynamoDB.
    """
    print("Evento recebido do S3:", json.dumps(event, indent=2))
    
    try:
        # Percorre todos os registros do evento (o S3 pode enviar múltiplos registros em lote)
        for record in event.get('Records', []):
            # Extrai o nome do bucket e a chave (nome/caminho) do arquivo
            bucket_name = record['s3']['bucket']['name']
            file_key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
            
            print(file_index_info := f"Processando o arquivo '{file_key}' do bucket '{bucket_name}'.")
            
            # Busca metadados adicionais diretamente no S3 (como o tamanho exato do arquivo)
            response = s3_client.head_object(Bucket=bucket_name, Key=file_key)
            file_size = response.get('ContentLength', 0)
            content_type = response.get('ContentType', 'unknown')
            
            # Estrutura o item que será persistido no DynamoDB
            item_log = {
                'id': f"{bucket_name}/{file_key}",  # Chave primária (Partition Key) única
                'bucket_name': bucket_name,
                'file_name': file_key,
                'file_size_bytes': file_size,
                'content_type': content_type,
                'processed_at': datetime.utcnow().isoformat() + 'Z',
                'status': 'PROCESSADO_COM_SUCESSO'
            }
            
            # Grava o registro no banco NoSQL
            print(f"Persistindo metadados no DynamoDB (Tabela: {TABLE_NAME})...")
            table.put_item(Item=item_log)
            print(f"Arquivo '{file_key}' registrado com sucesso no DynamoDB.")
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Processamento concluído com sucesso!'})
        }
        
    except Exception as e:
        print(f"Erro crítico durante o processamento: {str(e)}")
        # Em cenários reais, aqui você poderia enviar o erro para uma fila de Dead Letter Queue (DLQ)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Falha no processamento: {str(e)}'})
        }
