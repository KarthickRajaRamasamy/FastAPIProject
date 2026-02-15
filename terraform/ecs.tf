# Find the default VPC in your account
data "aws_vpc" "default" {
  default = true
}

# Find all subnets inside that default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_iam_role" "ecs_exec_role" {
  name = "${var.project_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Attach the standard AWS policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "api_sg" {
  name        = "${var.project_name}-api-sg"
  description = "Allow inbound traffic to Task Tracker API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8000 # Change this to match your app port (FastAPI usually 8000)
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Node Exporter Access (Prometheus Scrape)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #  (Grafana)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# The Task Definition (Blueprint)
resource "aws_ecs_task_definition" "api_task" {
  family                   = "task-tracker-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512" #  vCPU
  memory                   = "1024" #  GB
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-container"
      image     = aws_ecr_repository.api_repo.repository_url # Link to your ecr.tf resource
      essential = true
      portMappings = [{ containerPort = 8000, hostPort      = 8000 }]
    },
    # The Prometheus Node Exporter Sidecar
    {
      name      = "node-exporter"
      image     = "prom/node-exporter:latest"
      essential = false # If monitoring fails, the app stays up
      portMappings = [{ containerPort = 9100, hostPort = 9100 }]
      # Optional: Add command to disable collectors that need root (Fargate doesn't allow)
      command = ["--path.procfs=/host/proc", "--path.sysfs=/host/sys"]
    }
  ])
}

# The Service (Manager)
resource "aws_ecs_service" "api_service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.api_sg.id]
  }
}

resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([{
    name  = "grafana"
    image = "grafana/grafana:latest"
    portMappings = [{ containerPort = 3000, hostPort = 3000 }]
  }])
}

resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.api_sg.id] # Sharing the same SG for now
  }
}