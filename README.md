# Google Cloud Workflows - Ticket Lifecycle

A serverless workflow orchestration system built with **Google Cloud Workflows** that manages the complete lifecycle of support tickets.

## Overview

This project demonstrates workflow orchestration using Google Cloud Workflows (GCW) - a fully managed serverless platform for orchestrating Google Cloud and HTTP-based API services.

### Workflow Steps

The ticket lifecycle workflow executes the following sequence:

```
Create Ticket → Assign to Agent → Update Status → Close Ticket → Rate Ticket
```

**Each step:**
- Calls the [ticket-api-server](https://ticket-api-server-421581751516.us-central1.run.app) (Cloud Run)
- Uses OIDC authentication
- Includes automatic retry with exponential backoff
- Logs execution details
- Sends email notifications (logged to Cloud Logging)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT (gcloud CLI)                      │
│  Execute workflow with ticket details                       │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS API call
                        ↓
┌─────────────────────────────────────────────────────────────┐
│          GOOGLE CLOUD WORKFLOWS SERVICE                     │
│                (Fully Managed)                              │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │ Workflow Engine                                   │     │
│  │ • Parses YAML definition                          │     │
│  │ • Executes steps sequentially                     │     │
│  │ • Handles retries & errors                        │     │
│  │ • Persists state after each step                  │     │
│  └───────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP calls (OIDC auth)
                        ↓
┌─────────────────────────────────────────────────────────────┐
│              TICKET-API-SERVER (Cloud Run)                  │
│  https://ticket-api-server-421581751516.us-central1.run.app│
│                                                             │
│  Endpoints:                                                 │
│  • POST   /api/tickets          - Create ticket            │
│  • PUT    /api/tickets/:id/assign - Assign to agent        │
│  • PUT    /api/tickets/:id      - Update ticket            │
│  • PUT    /api/tickets/:id/close - Close ticket            │
│  • POST   /api/tickets/:id/rate - Rate ticket              │
└─────────────────────────────────────────────────────────────┘
```

## Key Differences from Temporal

| Feature | Temporal | Google Cloud Workflows |
|---------|----------|----------------------|
| **Hosting** | Self-hosted (workers, PostgreSQL) | Fully serverless |
| **Definition** | Code (Go, Python, etc.) | YAML |
| **Workers** | Required (you deploy) | Not needed |
| **Cost (10K wf/month)** | ~$2,100 (infrastructure) | ~$2.25 (pay-per-use) |
| **Duration limit** | Unlimited | 1 year max |
| **Debugging** | Full debugger, replay | Logs only |
| **Vendor lock-in** | Portable | GCP-only |
| **Setup time** | Hours (infrastructure) | Minutes (just YAML) |

## Prerequisites

1. **Google Cloud Platform account**
2. **gcloud CLI installed**
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Or download from: https://cloud.google.com/sdk/docs/install
   ```

3. **Authentication**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

4. **Required APIs** (automatically enabled by deploy script)
   - Cloud Workflows API
   - Cloud Workflows Executions API

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/ajanardhanan/workflow-gcw.git
cd workflow-gcw
```

### 2. Deploy the workflow

```bash
chmod +x deploy.sh execute.sh
./deploy.sh
```

This will:
- ✅ Enable required Google Cloud APIs
- ✅ Deploy the workflow to Cloud Workflows
- ✅ Set call logging to LOG_ALL_CALLS

### 3. Execute the workflow

**Option A: Using the execute script (recommended)**

```bash
# Uses default values and auto-selects first available agent
./execute.sh

# With custom values
./execute.sh "Bug in login" "User can't login" "HIGH" "agent-123" 5
```

**Option B: Using gcloud directly**

```bash
# Get an agent ID first
curl -s https://ticket-api-server-421581751516.us-central1.run.app/api/agents | jq -r '.[0].id'

# Execute workflow
gcloud workflows execute ticket-lifecycle \
  --data='{"title":"Test Ticket","description":"Testing GCW","priority":"HIGH","agentId":"YOUR_AGENT_ID","rating":5}' \
  --location=us-central1
```

### 4. View execution results

**Cloud Console UI:**
```
https://console.cloud.google.com/workflows/workflow/us-central1/ticket-lifecycle/executions
```

**gcloud CLI:**
```bash
# List recent executions
gcloud workflows executions list ticket-lifecycle --location=us-central1

# Describe specific execution
gcloud workflows executions describe EXECUTION_ID \
  --workflow=ticket-lifecycle \
  --location=us-central1
```

**View logs:**
```bash
# All workflow logs
gcloud logging read 'resource.type="workflows.googleapis.com/Workflow"' \
  --limit 50 \
  --format json

# Specific execution
gcloud logging read 'labels.execution_id="EXECUTION_ID"' \
  --limit 50 \
  --format json
```

## Project Structure

```
workflow-gcw/
├── ticket-lifecycle.yaml    # Main workflow definition (YAML)
├── deploy.sh               # Deployment script
├── execute.sh              # Execution script with agent auto-select
├── README.md               # This file
├── .gitignore              # Git ignore patterns
└── examples/
    ├── basic-execution.sh      # Simple execution example
    ├── error-handling.yaml     # Error handling patterns
    └── parallel-steps.yaml     # Parallel execution example
```

## Workflow Definition Explained

### Input Parameters

```yaml
params: [input]
```

Required fields:
- `title` (string) - Ticket title
- `description` (string) - Ticket description
- `priority` (string) - LOW, MEDIUM, HIGH, URGENT
- `agentId` (string) - Agent ID to assign ticket to
- `rating` (integer) - Rating score (1-5)

### Step Pattern

Each step follows this pattern:

```yaml
- stepName:
    try:
      call: http.post  # or http.put, http.get
      args:
        url: ${api_base_url + "/endpoint"}
        auth:
          type: OIDC  # Auto authentication for Cloud Run
        headers:
          Content-Type: "application/json"
        body:
          key: ${input.value}
        timeout: 30
      result: responseVariable
    retry:
      predicate: ${http.default_retry}  # Retries 5xx, network errors
      max_retries: 3
      backoff:
        initial_delay: 1
        max_delay: 10
        multiplier: 2  # Exponential backoff
```

### Return Value

```yaml
- returnResult:
    return:
      ticketId: ${ticketId}
      status: ${closeTicketResponse.body.status}
      agentId: ${assignTicketResponse.body.assignedAgentId}
      rating: ${rateTicketResponse.body.score}
      ratingId: ${rateTicketResponse.body.id}
      workflowStep: "RATED"
```

## Monitoring & Observability

### Cloud Console

**Workflow Overview:**
```
https://console.cloud.google.com/workflows
```

**Execution Details:**
- Status (ACTIVE, SUCCEEDED, FAILED)
- Duration
- Input/output
- Step-by-step timeline
- Variables at each step

### Cloud Logging

**Query execution logs:**
```sql
resource.type="workflows.googleapis.com/Workflow"
resource.labels.workflow_id="ticket-lifecycle"
```

**Filter by state:**
```sql
resource.type="workflows.googleapis.com/Workflow"
jsonPayload.state="FAILED"
```

**Find slow executions:**
```sql
resource.type="workflows.googleapis.com/Workflow"
jsonPayload.duration > "10s"
```

### Cloud Monitoring

**Pre-built metrics:**
- `workflows.googleapis.com/execution/execution_count` - Total executions by state
- `workflows.googleapis.com/execution/duration` - Execution duration (p50, p95, p99)
- `workflows.googleapis.com/step/step_count` - Steps executed
- `workflows.googleapis.com/execution/retry_count` - Retry attempts

**Create alerts:**
```bash
# Alert on high failure rate
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Workflow Failures" \
  --condition-display-name="High failure rate" \
  --condition-threshold-value=10 \
  --condition-threshold-duration=300s
```

## Cost Estimation

**Pricing:**
- Internal steps: $0.01 per 1,000 steps
- External HTTP calls: $0.025 per 1,000 calls

**Example (ticket-lifecycle workflow):**
- Internal steps per execution: ~10
- HTTP calls per execution: 5

**Cost for different volumes:**

| Executions/Month | Internal Steps Cost | HTTP Calls Cost | Total |
|-----------------|---------------------|-----------------|-------|
| 1,000 | $0.10 | $0.13 | $0.23 |
| 10,000 | $1.00 | $1.25 | $2.25 |
| 100,000 | $10.00 | $12.50 | $22.50 |
| 1,000,000 | $100.00 | $125.00 | $225.00 |

**Free tier:** First 5,000 internal steps and 2,000 external steps per month are free.

## Advanced Features

### Parallel Execution

```yaml
- parallelNotifications:
    parallel:
      branches:
        - sendEmail:
            call: http.post
            args:
              url: ${email_api_url}
        - sendSlack:
            call: http.post
            args:
              url: ${slack_webhook_url}
        - sendSMS:
            call: http.post
            args:
              url: ${sms_api_url}
```

### Conditional Logic

```yaml
- checkPriority:
    switch:
      - condition: ${ticket.priority == "URGENT"}
        next: escalateToManager
      - condition: ${ticket.priority == "HIGH"}
        next: assignToSenior
      - condition: true
        next: assignToJunior
```

### Loops

```yaml
- processItems:
    for:
      value: item
      in: ${input.items}
      steps:
        - processItem:
            call: http.post
            args:
              url: ${api_url}
              body: ${item}
```

### Subworkflows

```yaml
- callSubworkflow:
    call: subworkflow_name
    args:
      param1: ${value1}
    result: subworkflow_result
```

## Troubleshooting

### Common Issues

**1. Permission Denied**
```
Error: User does not have permission to access workflow
```

**Solution:**
```bash
# Grant yourself Workflows Admin role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/workflows.admin"
```

**2. OIDC Authentication Failed**
```
Error: 403 Forbidden when calling Cloud Run
```

**Solution:**
```bash
# Grant Workflows service account permission to invoke Cloud Run
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)")
gcloud run services add-iam-policy-binding ticket-api-server \
  --region=us-central1 \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/run.invoker"
```

**3. Workflow Execution Timeout**
```
Error: Execution exceeded maximum duration
```

**Solution:**
- Reduce HTTP call timeouts
- Optimize external API performance
- Break into smaller workflows

**4. Variable Size Exceeded**
```
Error: Variable size exceeds 256 KB limit
```

**Solution:**
- Store large data in Cloud Storage
- Pass only references/IDs between steps
- Use subworkflows to reset variable scope

## Comparison with Temporal Implementation

### Same Workflow, Different Approach

**Temporal (Code-first):**
```go
func TicketLifecycleWorkflow(ctx workflow.Context, input TicketInput) error {
    var ticket TicketResponse
    err := workflow.ExecuteActivity(ctx, CreateTicket, input).Get(ctx, &ticket)
    if err != nil {
        return err
    }
    // ... more steps
}
```

**Cloud Workflows (YAML-first):**
```yaml
- createTicket:
    call: http.post
    args:
      url: ${api_base_url + "/tickets"}
      body: ${input}
    result: ticket
```

### When to Use Which

**Choose Temporal if:**
- Need complex business logic (loops, conditionals, custom algorithms)
- Workflow duration > 1 year
- Need to debug with breakpoints
- Want to avoid vendor lock-in
- High volume (>10M workflows/month)
- Team prefers code over configuration

**Choose Cloud Workflows if:**
- Simple API orchestration (5-20 steps)
- Want zero infrastructure management
- Budget-conscious (< $500/month)
- Already on GCP
- Quick time-to-market
- Team comfortable with YAML

## Resources

**Documentation:**
- [Cloud Workflows Documentation](https://cloud.google.com/workflows/docs)
- [YAML Syntax Reference](https://cloud.google.com/workflows/docs/reference/syntax)
- [Standard Library Functions](https://cloud.google.com/workflows/docs/reference/stdlib/overview)

**Related Projects:**
- [workflow-builder (Temporal)](https://github.com/ajanardhanan/workflow-builder) - Same workflow in Temporal
- [ticket-api-server](https://github.com/ajanardhanan/ticket-management) - Backend API

**Pricing:**
- [Cloud Workflows Pricing](https://cloud.google.com/workflows/pricing)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

**Built with ❤️ using Google Cloud Workflows**

For questions or issues, please [open an issue](https://github.com/ajanardhanan/workflow-gcw/issues).
