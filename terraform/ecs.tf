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

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read-policy"
  role = aws_iam_role.ecs_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = [aws_ssm_parameter.prometheus_config.arn]
    }]
  })
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
  # Prometheus Server Access
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For testing
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_security_group_rule" "allow_prometheus_internal" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api_sg.id
  source_security_group_id = aws_security_group.api_sg.id
}

# The Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_ssm_parameter" "prometheus_config" {
  name  = "/ecs/prometheus-config"
  type  = "String"
  value = file("${path.cwd}/prometheus.yml")
}

resource "aws_iam_role_policy" "prometheus_ssm_access" {
  name = "prometheus-ssm-access"
  role = aws_iam_role.ecs_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = [aws_ssm_parameter.prometheus_config.arn]
    }]
  })
}


resource "aws_ecs_task_definition" "api_task" {
  family                   = "task-tracker-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn

  volume {
    name = "shared-config"
  }

  container_definitions = jsonencode([

    {
      name      = "config-init"
      image     = "amazon/aws-cli:latest"
      essential = false
      command = [
        "ssm", "get-parameter", "--name", "/ecs/prometheus-config",
        "--with-decryption", "--query", "Parameter.Value",
        "--output", "text", "--region", "us-east-1",
        ">", "/shared/prometheus.yml"
      ]
      mountPoints = [{
        sourceVolume  = "shared-config",
        containerPath = "/shared"
      }]
    },

    {
      name      = "api-container"
      image     = aws_ecr_repository.api_repo.repository_url
      essential = true
      portMappings = [{ containerPort = 8000, hostPort = 8000 }]
    },
    {
      name      = "node-exporter"
      image     = "prom/node-exporter:latest"
      essential = false
      portMappings = [{ containerPort = 9100, hostPort = 9100 }]
    },
    # PROMETHEUS SERVER (UPDATED FOR FARGATE)
{
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true
      portMappings = [{ containerPort = 9090, hostPort = 9090 }]

      # Wait for init container to finish, then start
      dependsOn = [{
        containerName = "config-init",
        condition     = "COMPLETE"
      }]

      mountPoints = [{
        sourceVolume  = "shared-config", # Matches volume name
        containerPath = "/etc/prometheus/"
      }]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ]
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