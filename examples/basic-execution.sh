#!/bin/bash

# Basic Execution Example for Google Cloud Workflows
# This script shows how to execute the ticket-lifecycle workflow

echo "Basic Execution Example"
echo "======================="
echo ""

# Configuration
WORKFLOW_NAME="ticket-lifecycle"
REGION="us-central1"

# Get first available agent
echo "Fetching available agents..."
AGENT_ID=$(curl -s https://ticket-api-server-421581751516.us-central1.run.app/api/agents | jq -r '.[0].id')
echo "Using agent: $AGENT_ID"
echo ""

# Execute workflow
echo "Executing workflow..."
gcloud workflows execute $WORKFLOW_NAME \
  --data="{
    \"title\": \"Sample Ticket\",
    \"description\": \"This is a test ticket created via Cloud Workflows\",
    \"priority\": \"MEDIUM\",
    \"agentId\": \"$AGENT_ID\",
    \"rating\": 5
  }" \
  --location=$REGION

echo ""
echo "Workflow execution started!"
echo ""
echo "View executions:"
echo "https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}/executions"
