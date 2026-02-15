resource "aws_ecr_repository" "api_repo" {
  name = "task-tracker-api"
  image_tag_mutability = "MUTABLE"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
}
#provive Neccessary IAM roles
output "ecr_repository_url" {
  value = "aws_ecr_repository.api_repo.repository_url"
}