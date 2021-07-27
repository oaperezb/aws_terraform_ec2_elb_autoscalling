/* output "instance_id" {
  value = "${aws_instance.ec2-challenge.*.id}"
} */

/* output "server_public_ip" {
  value = "${aws_instance.ec2-challenge.*.public_ip}"
} */

/* output "server_private_ip" {
  value = "${aws_instance.ec2-challenge.*.private_ip}"
} */

output "nat_gateway_ip" {
  value = aws_eip.eip_nat_gateway.public_ip
}