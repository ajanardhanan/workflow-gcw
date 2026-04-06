#!/bin/bash

set -e

echo "🚀 Google Cloud Workflows - Execute Workflow"
echo "============================================"
echo ""

# Configuration
WORKFLOW_NAME="ticket-lifecycle"
REGION="${REGION:-us-central1}"
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project ID if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

# Parse command line arguments
TITLE="${1:-Sample Ticket from GCW}"
DESCRIPTION="${2:-This ticket was created via Google Cloud Workflows}"
PRIORITY="${3:-MEDIUM}"
AGENT_ID="${4}"
RATING="${5:-5}"

# Check if agent ID is provided
if [ -z "$AGENT_ID" ]; then
    echo -e "${YELLOW}⚠️  No agent ID provided${NC}"
    echo ""
    echo "Fetching available agents from ticket-api-server..."

    AGENTS=$(curl -s https://ticket-api-server-421581751516.us-central1.run.app/api/agents)

    echo ""
    echo "Available agents:"
    echo "$AGENTS" | jq -r '.[] | "  - ID: \(.id) | Name: \(.name) | Email: \(.email)"'
    echo ""

    # Get first agent ID
    AGENT_ID=$(echo "$AGENTS" | jq -r '.[0].id')
    echo -e "${GREEN}Using first agent: ${AGENT_ID}${NC}"
    echo ""
fi

# Build input JSON
INPUT_JSON=$(cat <<EOF
{
  "title": "${TITLE}",
  "description": "${DESCRIPTION}",
  "priority": "${PRIORITY}",
  "agentId": "${AGENT_ID}",
  "rating": ${RATING}
}
EOF
)

echo "Workflow: ${WORKFLOW_NAME}"
echo "Region: ${REGION}"
echo "Project: ${PROJECT_ID}"
echo ""
echo "Input:"
echo "$INPUT_JSON" | jq '.'
echo ""

# Execute workflow
echo "Executing workflow..."
echo ""

EXECUTION_OUTPUT=$(gcloud workflows execute $WORKFLOW_NAME \
    --data="$INPUT_JSON" \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format=json)

EXECUTION_NAME=$(echo "$EXECUTION_OUTPUT" | jq -r '.name')
EXECUTION_ID=$(basename "$EXECUTION_NAME")

echo -e "${GREEN}✅ Workflow execution started${NC}"
echo "   Execution ID: ${EXECUTION_ID}"
echo ""

# Wait for completion
echo "Waiting for workflow to complete..."
echo ""

gcloud workflows executions wait $EXECUTION_ID \
    --workflow=$WORKFLOW_NAME \
    --location=$REGION \
    --project=$PROJECT_ID

# Get result
echo ""
echo "Fetching execution result..."
echo ""

RESULT=$(gcloud workflows executions describe $EXECUTION_ID \
    --workflow=$WORKFLOW_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format=json)

STATE=$(echo "$RESULT" | jq -r '.state')
DURATION=$(echo "$RESULT" | jq -r '.duration')

if [ "$STATE" == "SUCCEEDED" ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 Workflow completed successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Duration: ${DURATION}"
    echo ""
    echo "Result:"
    echo "$RESULT" | jq -r '.result'
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "View execution in Cloud Console:"
    echo "https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}/execution/${EXECUTION_ID}?project=${PROJECT_ID}"
    echo ""
    echo "View logs:"
    echo "gcloud logging read \"labels.execution_id=${EXECUTION_ID}\" --limit 50 --format json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ Workflow execution failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "State: ${STATE}"
    echo "Duration: ${DURATION}"
    echo ""
    echo "Error:"
    echo "$RESULT" | jq -r '.error'
    echo ""
    echo "View execution in Cloud Console:"
    echo "https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}/execution/${EXECUTION_ID}?project=${PROJECT_ID}"
    exit 1
fi
