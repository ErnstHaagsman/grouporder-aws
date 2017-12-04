data "template_file" "inventory" {
  template = "${file("inventory.tmpl")}"
  vars = {
    database_host_ip = "${aws_instance.database.private_ip}",
    web_host_ip = "${aws_instance.web.private_ip}"
  }
}

