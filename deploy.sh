#!/bin/bash

set -e

echo "🚀 Google Cloud Workflows - Deployment Script"
echo "=============================================="
echo ""

# Configuration
WORKFLOW_NAME="ticket-lifecycle"
WORKFLOW_FILE="ticket-lifecycle.yaml"
REGION="${REGION:-us-central1}"
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed${NC}"
    echo "   Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo -e "${GREEN}✅ gcloud CLI installed${NC}"

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated with gcloud${NC}"
    echo "   Run: gcloud auth login"
    exit 1
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo -e "${GREEN}✅ Authenticated as: ${ACTIVE_ACCOUNT}${NC}"

# Get project ID if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}❌ No GCP project configured${NC}"
        echo "   Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Project ID: ${PROJECT_ID}${NC}"
echo -e "${GREEN}✅ Region: ${REGION}${NC}"
echo ""

# Check if workflow file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}❌ Workflow file not found: ${WORKFLOW_FILE}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Workflow file found: ${WORKFLOW_FILE}${NC}"
echo ""

# Enable required APIs
echo "📦 Enabling required Google Cloud APIs..."
gcloud services enable workflows.googleapis.com --project=$PROJECT_ID
gcloud services enable workflowexecutions.googleapis.com --project=$PROJECT_ID
echo -e "${GREEN}✅ APIs enabled${NC}"
echo ""

# Deploy workflow
echo "🔧 Deploying workflow: ${WORKFLOW_NAME}"
echo "   Region: ${REGION}"
echo "   Project: ${PROJECT_ID}"
echo ""

gcloud workflows deploy $WORKFLOW_NAME \
    --source=$WORKFLOW_FILE \
    --location=$REGION \
    --project=$PROJECT_ID \
    --call-log-level=LOG_ALL_CALLS

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Next Steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Execute the workflow:"
    echo "   ./execute.sh"
    echo ""
    echo "   Or manually:"
    echo "   gcloud workflows execute $WORKFLOW_NAME \\"
    echo "     --data='{\"title\":\"Test Ticket\",\"description\":\"Testing GCW\",\"priority\":\"HIGH\",\"agentId\":\"YOUR_AGENT_ID\",\"rating\":5}' \\"
    echo "     --location=$REGION"
    echo ""
    echo "2. View workflow in Cloud Console:"
    echo "   https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}?project=${PROJECT_ID}"
    echo ""
    echo "3. View executions:"
    echo "   https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}/executions?project=${PROJECT_ID}"
    echo ""
    echo "4. View logs:"
    echo "   gcloud logging read \"resource.type=workflows.googleapis.com/Workflow\" \\"
    echo "     --limit 50 \\"
    echo "     --format json"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
