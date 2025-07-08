import json
import jwt #Included in Lambda Layer
import boto3 # Boto3 is included in the standard AWS Lambda Python runtime
import base64

ssm = boto3.client('ssm')

# Cache keys after first fetch
PRIVATE_KEY = None
PUBLIC_KEY = None

def get_private_key():
    global PRIVATE_KEY
    if not PRIVATE_KEY:
        resp = ssm.get_parameter(Name="/jwt/private_key", WithDecryption=True)
        value = resp["Parameter"]["Value"]

        # Fix: Decode if value is base64-encoded (not PEM)
        if not value.startswith("-----BEGIN PRIVATE KEY-----"):
            try:
                decoded = base64.b64decode(value).decode("utf-8")
                print("Decoded private key from base64")
                value = decoded
            except Exception as e:
                print(f"Failed to base64-decode private key: {e}")

        PRIVATE_KEY = value
    return PRIVATE_KEY

def get_public_key():
    global PUBLIC_KEY
    if not PUBLIC_KEY:
        resp = ssm.get_parameter(Name="/jwt/public_key", WithDecryption=True)
        value = resp["Parameter"]["Value"]

        # Fix: Decode if value is base64-encoded (not PEM)
        if not value.startswith("-----BEGIN PUBLIC KEY-----"):
            try:
                decoded = base64.b64decode(value).decode("utf-8")
                print("Decoded public key from base64")
                value = decoded
            except Exception as e:
                print(f"Failed to base64-decode public key: {e}")

        PUBLIC_KEY = value
    return PUBLIC_KEY

def lambda_handler(event, context):
    path = event.get("rawPath", "")
    method = event.get("requestContext", {}).get("http", {}).get("method", "")

    if path == "/login" and method == "POST":
        return login_handler(event)
    elif path == "/protected" and method == "GET":
        return protected_handler(event)
    else:
        return {
            "statusCode": 404,
            "body": json.dumps({"error": "Not Found"})
        }

def login_handler(event):
    # In a real implementation, validate user credentials from event["body"]
    private_key = get_private_key()
    token = jwt.encode(
        {"sub": "user_id", "role": "user"},
        private_key,
        algorithm="RS256"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"token": token})
    }

def protected_handler(event):
    headers = event.get("headers", {})
    auth = headers.get("authorization") or headers.get("Authorization", "")
    
    if not auth.startswith("Bearer "):
        return {"statusCode": 401, "body": json.dumps({"error": "Unauthorized"})}
    
    token = auth.split(" ")[1]

    try:
        decoded = jwt.decode(token, get_public_key(), algorithms=["RS256"])
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Access granted!", "user": decoded})
        }
    except jwt.ExpiredSignatureError:
        return {"statusCode": 401, "body": json.dumps({"error": "Token expired"})}
    except jwt.InvalidTokenError:
        return {"statusCode": 401, "body": json.dumps({"error": "Invalid token"})}
