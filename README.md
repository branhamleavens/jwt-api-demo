# Lambda JWT API Auth Demo

Deploy a lightweight Python-based JWT authentication API to AWS using Lambda, API Gateway, and Terraform.

![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/Cloud-AWS-232F3E?logo=amazonaws)
![Python](https://img.shields.io/badge/Runtime-Python-3776AB?logo=python)


---

## 📌 Overview

This project demonstrates how to build and deploy a stateless authentication API using JSON Web Tokens (JWT) with the following stack:

- **AWS Lambda** for serverless function hosting
- **API Gateway** to expose HTTP routes
- **SSM Parameter Store** to securely store RSA key pairs
- **PyJWT** to encode/decode tokens
- **Terraform** to manage the infrastructure as code  
- **CloudWatch Logs** for observability

---

## 🧱 Architecture

[Internet]
↓
[API Gateway]
↓
[AWS Lambda Function]
↓
[SSM Parameter Store]
↓
[JWT signing/verification]



---

## 🚀 Features

- ✅ Stateless JWT authentication with RS256 (asymmetric encryption)
- ✅ Keys are securely managed via AWS SSM Parameter Store
- ✅ /login route issues JWTs
- ✅ /protected route verifies tokens
- ✅ Serverless infrastructure powered entirely by AWS
- ✅ Automated packaging & deployment via Makefile

---

## 🛠️ Prerequisites

- [Python 3.11+](https://docs.python.org/3/whatsnew/3.11.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [pip](https://pip.pypa.io/en/stable/)
- An AWS account and a configured credentials file (`~/.aws/credentials`)

---

## 📂 Project Structure

.
├── handler.py            # Lambda function code
├── requirements.txt      # PyJWT + cryptography for local keygen
├── generate_keys.py      # Script to generate RSA key pair
├── main.tf               # Terraform infrastructure (Lambda + SSM)
├── Makefile              # Automates packaging and deployment
├── deployment.zip        # Generated Lambda package (ignored)
└── README.md


---

## 🧪 Setup & Deployment

```bash
# 1. Install required Python packages (PyJWT, cryptography)
pipenv install

# 2. Generate RSA key pair
pipenv run python3 generate_keys.py

# 3. Deploy infrastructure & upload keys to SSM
make deploy
```

## 🔐 JWT Authentication Flow

```POST /login```: Returns a JWT signed with your RSA private key
```GET /protected```: Requires a valid Bearer token.  Verifies with public key.

You can test these routes with curls like:

**Login**: curl -X POST https://{api_id}.execute-api.{region}.amazonaws.com/login -H "Content-Type: application/json" -d '{"username": "test", "password": "test"}'

**Protected Route**: GET https://{api_id}.execute-api.{region}.amazonaws.com/protected -H "Authorization: Bearer {token}"

## 🔧 Customization

- Edit ```handler.py``` to add handle database auth, more routes, claims, or payload logic.
- Update key parameter names in main.tf if needed.
- To change the token algorithm or lifespan, adjust the payload and jwt.encode() call.



## 🪦 Teardown

To clean up all resources 

```bash
terraform destroy
```