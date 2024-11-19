import boto3
import base64
import json

cached_credentials = None

def initialize_secrets(secret_id):
    global cached_credentials
    if cached_credentials:
        return cached_credentials

    client = boto3.client("secretsmanager", region_name="ap-northeast-1")
    try:
        response = client.get_secret_value(SecretId=secret_id)
        if "SecretString" in response:
            cached_credentials = json.loads(response["SecretString"])
        else:
            cached_credentials = json.loads(base64.b64decode(response["SecretBinary"]))
        print("Secrets successfully loaded and cached")
        return cached_credentials
    except Exception as e:
        print(f"Error retrieving secrets: {e}")
        raise

def lambda_handler(event, context):
    # 必要に応じて書き換える
    secret_id = "your-secrets"
    credentials = initialize_secrets(secret_id)

    auth_user = credentials["username"]
    auth_pass = credentials["password"]

    # Authorizationヘッダーの確認
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    auth_string = f"Basic {base64.b64encode(f'{auth_user}:{auth_pass}'.encode()).decode()}"

    if (
        "authorization" not in headers
        or headers["authorization"][0]["value"] != auth_string
    ):
        return {
            "status": "401",
            "statusDescription": "Unauthorized",
            "headers": {
                "www-authenticate": [{"key": "WWW-Authenticate", "value": "Basic"}],
            },
            "body": "Unauthorized",
        }

    return request
