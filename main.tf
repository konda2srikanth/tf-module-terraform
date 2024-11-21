resource "aws_instance" "main" {
  ami                    = data.aws_ami.main.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]
  tags = {
    Name    = "${var.name}-${var.env}"
    Monitor = "yes"
  }

  # We will soon remove this option and this is a workAround
  lifecycle {
    ignore_changes = [ami]
  }
}

# Creates DNS Record
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.id
  name    = "${var.name}-${var.env}.expense.internal"
  type    = "A"
  ttl     = 10
  records = [aws_instance.main.private_ip]

  lifecycle {
    ignore_changes = [zone_id]
  }
}

resource "null_resource" "app" {
  depends_on = [aws_route53_record.main, aws_instance.main]

  triggers = {
    always_run = timestamp()
  }
  connection { # Enables connection to the remote host
    host     = aws_instance.main.private_ip
    user     = "ec2-user"
    password = var.ssh_pwd
    type     = "ssh"
  }
  provisioner "remote-exec" { # This let's the execution to happen on the remote node
    inline = [
      "pip3.11 install hvac",
      "ansible-pull -U https://github.com/B58-CloudDevOps/ansible.git -e vault_token=${var.vault_token} -e COMPONENT=${var.name} -e ENV=${var.env} expense-pull.yml"
    ]
  }
}

# hvac:  a pre-req package for hashicorp modules
# ref: https://docs.ansible.com/ansible/latest/collections/community/hashi_vault/hashi_vault_lookup.html#ansible-collections-community-hashi-vault-hashi-vault-lookup