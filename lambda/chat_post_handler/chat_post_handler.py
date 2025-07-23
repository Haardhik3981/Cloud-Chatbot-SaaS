import json
import boto3
import datetime
import os
import requests
from jose import jwt
from boto3.dynamodb.conditions import Key

# Environment Variable Setup (Add these in Terraform later)
USER_POOL_ID = "us-west-2_p7H56KCgz"
APP_CLIENT_ID = "7omafgdpaj2lgrb7dj7h8h2b0f"
REGION = "us-west-2"
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('chat_logs')
CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*"
}

# Step 1: Download Cognito's public keys
cognito_keys_url = f"https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json"

_cached_keys = None
def get_cognito_keys():
    global _cached_keys
    if _cached_keys is None:
        print("Fetching Cognito public keys...")
        _cached_keys = requests.get(cognito_keys_url).json()["keys"]
    return _cached_keys

def lambda_handler(event, context):
    try:
        keys = get_cognito_keys()
        # Step 2: Check Authorization header
        print("DEBUG FULL EVENT:", json.dumps(event))

        auth_header = event.get("headers", {}).get("authorization")
        print("DEBUG AUTH HEADER:", auth_header)
        if not auth_header or not auth_header.startswith("Bearer "):
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "Missing or invalid Authorization header"}),
                "headers": CORS_HEADERS
            }

        token = auth_header.split(" ")[1]

        # Step 3: Validate Token using jose
        claims = jwt.decode(
            token,
            keys,
            options={"verify_aud": False},  # Optional: set True if validating against APP_CLIENT_ID
            issuer=f"https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}",
            algorithms=["RS256"]
        )

        # Step 4: Extract user_id securely
        user_id = claims.get("email") or claims.get("sub")
        if not user_id:
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "Invalid token: missing user_id"}),
                "headers": CORS_HEADERS
            }

        # Step 5: Parse message from body
        body = json.loads(event["body"])
        message = body.get("message")
        if not message:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing message"})
            }

        timestamp = datetime.datetime.utcnow().isoformat(timespec='microseconds')

        # Step 6: Write to DynamoDB
        table.put_item(
            Item={
                "user_id": user_id,
                "timestamp": datetime.datetime.utcnow().isoformat(timespec='microseconds'),
                "role": "user",
                "message": message
            }
        )
        # Step 7: Retrieve last 10 messages for context
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id),
            Limit=10,
            ScanIndexForward=False
        )
        chat_history = response.get("Items", [])
        chat_history = sorted(chat_history, key=lambda x: x['timestamp'])

        # Prepare GPT-4 message array
        gpt_messages = [{"role": "user", "content": item["message"]} for item in chat_history]
        gpt_messages.append({"role": "user", "content": message})

        # Step 7: Call GPT-4o-mini
        response = requests.post(
            OPENAI_API_URL,
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "gpt-4o-mini",
                "messages": gpt_messages,
                "max_tokens": 50
            }
        )
        gpt_reply = response.json()["choices"][0]["message"]["content"]
        table.put_item(
            Item={
                "user_id": user_id,
                "timestamp": datetime.datetime.utcnow().isoformat(timespec='microseconds'),
                "role": "bot",
                "message": gpt_reply
            }
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "user_id": user_id,
                "chatbot_reply": gpt_reply
            }),
            "headers": CORS_HEADERS
        }
    except jwt.ExpiredSignatureError:
        return {
            "statusCode": 401,
            "body": json.dumps({"error": "Token expired"}),
            "headers": CORS_HEADERS
        }
    except jwt.JWTError as e:
        return {
            "statusCode": 401,
            "body": json.dumps({"error": f"Invalid token: {str(e)}"}),
            "headers": CORS_HEADERS
        }
    except Exception as e:
        print(f"Lambda Internal Error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
            "headers": CORS_HEADERS
        }