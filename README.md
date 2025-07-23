# Cloud-Native ChatBot SaaS Platform

![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform)
![AWS Lambda](https://img.shields.io/badge/Compute-AWS%20Lambda-F29111?logo=aws-lambda)
![API Gateway](https://img.shields.io/badge/API-AWS%20Gateway-FF4F00?logo=amazon-aws)
![DynamoDB](https://img.shields.io/badge/DB-DynamoDB-4053D6?logo=amazon-dynamodb)
![Cognito](https://img.shields.io/badge/Auth-Cognito-ED3B54?logo=amazon-aws) 
![OpenAI](https://img.shields.io/badge/LLM-GPT--4o-blue?logo=openai)
![React](https://img.shields.io/badge/Frontend-React%20%7C%20TypeScript-61DAFB?logo=react)
![CloudFront](https://img.shields.io/badge/CDN-CloudFront-FF9900?logo=amazon-aws)
![S3](https://img.shields.io/badge/Hosting-S3-569A31?logo=amazon-s3)

A cloud-native ChatBot platform powered by GPT-4o and deployed entirely on AWS using a secure, serverless architecture.

## Why I Built This

I wanted to go beyond basic demos and build a **production-grade project** that simulates a Chatbot SaaS startup product - the kind of project I’d want to use myself.
This project gave me the opportunity to:

- Learn how companies use **AWS tools to build Serverless Application**
- Practice **secure OAuth2 login**, token validation, and API protection
- Integrate **LLMs like GPT-4o** into a real-time application
- Gain hands-on experience with **Terraform**, **IAM roles**, and **modular Lambda design**

This also gave me a chance to get hands-on with AWS services like Cognito, Lambda, and DynamoDB. The result is a fully deployed chatbot app, live on the internet, with scalable infrastructure and secure authentication.

## What I Learned

- How to manage OAuth 2.0 flows with Cognito + securely exchange tokens
- Validating and decoding JWTs using JOSE in AWS Lambda
- Using Terraform to manage multi-service AWS deployments
- Integrating API Gateway securely with Lambda functions and Cognito-authenticated routes
- Writing clean modular Lambda functions for GET, POST, CLEAR
- Secure S3 hosting with CloudFront and custom bucket policies

## Features

- **Secure Cognito Login** – Hosted UI, OAuth 2.0 flow, code exchange for JWT
- **GPT-4o Integration** – Smart replies using OpenAI's cheapest and fastest model
- **User-specific Chat History** – Stored securely in DynamoDB with preload on login
- **Token Validation in Lambda** – Using public key + jose for decoding JWTs
- **Clear History + Logout** – Per-session memory management via button
- **Modular Lambda Functions** – POST, GET, CLEAR split for maintainability
- **Frontend in TypeScript** – Built with React + TailwindCSS
- **Deployed on AWS** – Static frontend hosted via S3 + CloudFront CDN
- **Terraform Infrastructure** – IaC for full reproducibility
- **IAM Role/Policy** – Secure access from Lambda to DynamoDB

## Tech Stack

| Layer        | Tech Used |
|--------------|-----------|
| Frontend     | React (TypeScript), TailwindCSS, Vite |
| Auth         | Amazon Cognito (OAuth 2.0, Hosted UI, JWT) |
| Backend      | AWS Lambda (Python), API Gateway (HTTP), IAM Roles |
| Database     | Amazon DynamoDB (pay-per-request) |
| Infra-as-Code| Terraform |
| Hosting      | AWS S3 (static site), CloudFront (CDN) |
| AI Model     | OpenAI GPT-4o-mini |

## Live Demo - This is hosted on free-tier resources and may be paused occasionally

[Launch the App](https://d3pb94cafp68vt.cloudfront.net)

Log in with your email to test it live. Chat history is remembered, and responses are powered by GPT-4o.

## Developer Experience

- Token-based authentication using JWT, validated server-side in Lambda
- Chat history automatically fetched on login using secure API calls
- Chat context is maintained per session and stored in DynamoDB
- Users can clear chat history and log out with a single click
- Clean code structure: TypeScript frontend, modular Python Lambdas, declarative Terraform
- Project structure organized into `/frontend`, `/lambda`, and `/terraform` for clarity
- Future-ready: easy to integrate CI/CD or swap LLMs (OpenAI → custom)

## Project Structure

- /frontend - React app with login, chat, memory
- /lambda - Python Lambda functions (chat_post, chat_get, clear_chat)
- /terraform - Terraform stack for entire AWS infra

## Roadmap – Coming Next

- CI/CD pipeline with **GitHub Actions** (auto deploy frontend on push)
- Swap GPT-4o with **my own LLM built from scratch**
- Admin dashboard with usage stats and logs
- Vector store integration (e.g., Pinecone) for semantic memory

---
