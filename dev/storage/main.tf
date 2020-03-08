provider "aws" {
  region                  = "us-east-2"
  shared_credentials_file = "/Users/G7Kellen/.aws/credentials"
  profile                 = "kellen.anker"
}

terraform {
  backend "s3" {
    bucket  = "kellen-anker-remote-state"
    key     = "dev/storage/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}

# ========== Aurora cluster

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "aurora-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.03.2"
  availability_zones      = [ "us-east-2a", "us-east-2b", "us-east-2c" ]
  database_name           = "example"
  master_username         = "kellen"
  master_password         = var.aurora_db_password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
}