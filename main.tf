provider "oci" {}

variable "patch_id" {type = "string"}
variable "mos_username" {type = "string"}
variable "mos_password" {type = "string"}
variable "display_name" {type = "string"}
variable "ad" {}
variable "compartment_ocid" {}

data "oci_core_images" "linux_images" {
    compartment_id = var.compartment_ocid
    operating_system = "Oracle Autonomous Linux"
    operating_system_version = "7.9"
    shape = var.shape
    sort_by = "TIMECREATED"
    sort_order = "DESC"
}

resource "oci_core_instance" "generated_oci_core_instance" {
  agent_config {
    is_management_disabled = "false"
    is_monitoring_disabled = "false"
    plugins_config {
      desired_state = "DISABLED"
      name = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name = "Oracle Java Management Service"
    }
    plugins_config {
      desired_state = "ENABLED"
      name = "OS Management Service Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name = "Bastion"
    }
  }
  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }
  availability_domain = var.ad
  compartment_id = var.compartment_ocid
  create_vnic_details {
    assign_private_dns_record = "true"
    assign_public_ip = "true"
    subnet_id = "${oci_core_subnet.generated_oci_core_subnet.id}"
  }
  display_name = var.display_name
  instance_options {
    are_legacy_imds_endpoints_disabled = "false"
  }
  metadata = {
    "ssh_authorized_keys" = tls_private_key.public_private_key_pair.public_key_openssh
  }
  shape = "VM.Standard.E4.Flex"
  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    memory_in_gbs = "20"
    ocpus = "2"
  }
  source_details {
        source_id   = data.oci_core_images.linux_images.images[0].id
        source_type = "image"
    }
}

resource "oci_core_vcn" "generated_oci_core_vcn" {
  cidr_block = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name = "Images Demo VCN"
  dns_label = "demo"
}

resource "oci_core_subnet" "generated_oci_core_subnet" {
  cidr_block = "10.0.0.0/24"
  compartment_id = var.compartment_ocid
  display_name = "Images"
  dns_label = "images"
  route_table_id = "${oci_core_vcn.generated_oci_core_vcn.default_route_table_id}"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_internet_gateway" "generated_oci_core_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name = "Internet Gateway For Demo"
  enabled = "true"
  vcn_id = "${oci_core_vcn.generated_oci_core_vcn.id}"
}

resource "oci_core_default_route_table" "generated_oci_core_default_route_table" {
  route_rules {
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.generated_oci_core_internet_gateway.id}"
  }
  manage_default_resource_id = "${oci_core_vcn.generated_oci_core_vcn.default_route_table_id}"
}

# ioco storage drive
resource "tls_private_key" "public_private_key_pair" {
  algorithm   = "RSA"
}

resource "oci_core_volume" "psinstance_storage" {
  availability_domain = oci_core_instance.generated_oci_core_instance.availability_domain
  compartment_id = oci_core_instance.generated_oci_core_instance.compartment_id
  display_name = "PUM Storage"
  size_in_gbs = "150"
  vpus_per_gb = "20"
}

resource "oci_core_volume_attachment" "psinstance_storage_attachment" {
  attachment_type = "iscsi"
  use_chap        = true
  instance_id     = oci_core_instance.generated_oci_core_instance.id
  volume_id       = oci_core_volume.psinstance_storage.id
  connection {
    type        = "ssh"
    host        = oci_core_instance.generated_oci_core_instance.public_ip
    user        = "opc"
    private_key = tls_private_key.public_private_key_pair.private_key_pem
  }
  
  # register and connect the iSCSI block volume
  provisioner "remote-exec" {
    inline = [
      "sudo iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}",
      "sudo iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic",
      "sudo iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -o update -n node.session.auth.authmethod -v CHAP",
      "sudo iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -o update -n node.session.auth.username -v ${self.chap_username}",
      "sudo iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -o update -n node.session.auth.password -v ${self.chap_secret}",
      "sudo iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l",
    ]
  }
}

# resource "null_resource" "psinstance_provision" {
#   depends_on = [oci_core_instance.generated_oci_core_instance, oci_core_volume.psinstance_storage, oci_core_volume_attachment.psinstance_storage_attachment]

#   triggers = {
#     ps_ids = oci_core_instance.generated_oci_core_instance.id
#   }

#   connection {
#     type        = "ssh"
#     host        = oci_core_instance.generated_oci_core_instance.public_ip
#     user        = "opc"
#     private_key = tls_private_key.public_private_key_pair.private_key_pem
#   }

#   provisioner "file" {
#     source      = "${path.module}/provision.sh"
#     destination = "/tmp/provision.sh"
#   }

#   provisioner "remote-exec" {
#     inline = [
#         "chmod +x /tmp/provision.sh;",
#         "sudo /tmp/provision.sh ${var.mos_username} ${var.mos_password} ${var.patch_id} | tee /tmp/provision.log",
#       ]
#   }
# }

output "connection" {
  value = join("", "ssh -i image.key opc@", oci_core_instance.generated_oci_core_instance.public_ip)
}

output "ssh_key" {
  value = tls_private_key.public_private_key_pair.private_key_openssh
}