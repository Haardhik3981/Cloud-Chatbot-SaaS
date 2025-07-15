variable "aws_region" {
  default = "us-west-2"
}

variable "openai_api_key" {
  description = "OpenAI API key for GPT-4 integration"
  type        = string
  sensitive   = true
}

variable "pinecone_api_key" {
  description = "Pinecone API key for vector embeddings"
  type        = string
  sensitive   = true
}