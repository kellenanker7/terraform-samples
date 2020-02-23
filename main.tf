provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami           = "ami-0c64dd618a49aeee8"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-example"
  }
}
