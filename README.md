# 🚀 FastAPI Task Tracker with DevOps Observability

A production-ready FastAPI application deployed on **AWS ECS Fargate** using **Terraform**, featuring a full monitoring stack with **Prometheus** and **Grafana**.

## 🏗 Architecture Overview

The application is deployed using a **Sidecar Pattern**. All monitoring components live within the same ECS Task, sharing the same network namespace for high-performance data scraping and simplified connectivity.

### System Diagram
```text
                                  AWS CLOUD (Default VPC)
+---------------------------------------------------------------------------------------+
|                                                                                       |
|   +-------------------------------------------------------------------------------+   |
|   |                          ECS FARGATE TASK (Shared Network)                    |   |
|   |                                                                               |   |
|   |  +-------------------+        +--------------------+        +------------------+  |
|   |  |   API CONTAINER   |        |   NODE EXPORTER    |        | PROMETHEUS SRV   |  |
|   |  |   (FastAPI)       |        |   (Metrics Agent)  |        | (Time-Series DB) |  |
|   |  |   Port: 8000      |        |   Port: 9100       |        | Port: 9090       |  |
|   |  +---------+---------+        +----------+---------+        +---------+--------+  |
|   |            ^                             ^                            |           |
|   |            |                             |                            |           |
|   |            +----------- SCRAPE ----------+----------- SCRAPE ---------+           |
|   |                      (via localhost)               (via localhost)                |
|   |                                                                       |           |
|   +-----------------------------------------------------------------------|-----------+
|                                                                           |           |
|   +--------------------------+                                            |           |
|   |     GRAFANA SERVICE      | <-------------- QUERY ---------------------+           |
|   |     (Visualization)      |           (via Public IP)                      |
|   |     Port: 3000           |                                                        |
|   +------------+-------------+                                                        |
+----------------|----------------------------------------------------------------------+

**Tech Stack**
Backend: FastAPI (Python 3.12+)

Infrastructure: Terraform (Infrastructure as Code)

Cloud Platform: AWS (ECS Fargate, ECR, IAM, VPC, SSM)

Observability: Prometheus (Time-series data) & Grafana (Visualization)

CI/CD: GitHub Actions (Automated Deployment)

📊 Monitoring Features
Application Metrics: Real-time tracking of Request per Second (RPS), Latency (P95/P99), and HTTP error rates (4xx/5xx).

Infrastructure Metrics: CPU and Memory utilization for Fargate containers via Node Exporter.

Visualizations: Seamless integration with Grafana using pre-built community dashboards

**Getting Started**
**Prerequisites**

AWS CLI configured with appropriate permissions.
Terraform installed locally.(i have used terraform file inside the github actions)
Docker for local image testing.(this is required for testing the image locally)

## 📂 Project Structure

```text
.
├── .github/                # GitHub Actions CI/CD workflows
│   └── workflows/
│       └── deploy.yml
├── app/                    # FastAPI Application source code
│   ├── main.py             # Entry point with Prometheus instrumentation
│   ├── models              # Pydantic and database models
│   ├── database.py         # databse session
│   └── requirements.txt    # Python dependencies
├── terraform/              # Infrastructure as Code
│   ├── main.tf             # Core AWS provider
│   ├── ecs.tf              # ECS Task, Service, VPC and Security Groups
│   ├── variables.tf        # Input variables for customization
│   ├── outputs.tf          # Outputs like the Load Balancer DNS
│   └── prometheus.yml      # Configuration for Prometheus sidecar
├── .gitignore              # Files to exclude from Git (e.g., .terraform/)
├── Dockerfile              # Container definition for the FastAPI app
└── README.md               # Project documentation

**Deployment Steps**

Clone the Repository:

git clone [https://github.com/your-username/FastAPIProject.git](https://github.com/your-username/FastAPIProject.git)
cd FastAPIProject

Deploy Infrastructure:

Once the code commit is made, terraform will create the resource and deploy it in ECS (change the aws cedentials as per your own)

Access the Stack:

FastAPI Docs: http://<PUBLIC_IP>:8000/docs

Prometheus UI: http://<TASK_PUBLIC_IP>:9090

Grafana Dashboard: http://<GRAFANA_IP>:3000 (Default: admin/admin)

Once all tested and validated, i have created new githubaction to delete the resoruce (destroy.yaml)

**Infrastructure Details**
Prometheus Configuration
The Prometheus server is injected with a configuration stored in AWS Systems Manager (SSM). It scrapes metrics from the API and Node Exporter using localhost to ensure low-latency internal communication.

Terraform Resources
VPC & Security Groups: Configured with specific ingress rules for ports 8000, 9090, 9100, and 3000.

ECS Task Definition: Orchestrates three containers (API, Node Exporter, Prometheus) within a single task.

IAM Roles: Task Execution roles providing necessary access to ECR and SSM Parameter Store.