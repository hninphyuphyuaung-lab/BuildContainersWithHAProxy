resource "docker_network" "private_network" {
  name = var.docker_network_name
}

#Define 3 web containers
resource "docker_container" "web1" {
  name  = "web1"
  image = var.web_image_name
  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 8080
    external = 8080
  }

  command = [
    "-text=hello from web1",
    "-listen=:8080"
  ]
}

resource "docker_container" "web2" {
  name  = "web2"
  image = var.web_image_name
  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 8080
    external = 8081
  }

  command = [
    "-text=hello from web2",
    "-listen=:8080"
  ]
}

resource "docker_container" "web3" {
  name  = "web3"
  image = var.web_image_name
  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 8080
    external = 8082
  }

  command = [
    "-text=hello from web3",
    "-listen=:8080"
  ]
}

#Define SSL Certificate for https
resource "tls_private_key" "my_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
  }

resource "tls_self_signed_cert" "my_private_key" {
    subject {
    common_name  = "localhost"
    organization = "HelloCloud"
  }

  private_key_pem = tls_private_key.my_private_key.private_key_pem
  is_ca_certificate = false

  # Certificate expires after 12 hours.
  validity_period_hours = 12

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

 dns_names = ["localhost"]
 ip_addresses = ["127.0.0.1"]
}

# Write the certificate and private key to a .pem file for HAProxy
resource "local_file" "haproxy_cert" {
  content  = "${tls_self_signed_cert.my_private_key.cert_pem}\n${tls_private_key.my_private_key.private_key_pem}"
  filename = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.pem"
}

#Define HA Proxy container 1
resource "docker_container" "haproxy1" {
  name  = "haproxy1"
  image = var.haproxy_image_name

  networks_advanced {
    name = docker_network.private_network.name
  }
  
 #Map ports
  ports {
    internal = 443
    external = 443
  }

  ports {
    internal = 8404
    external = 8404
  }

#Volume mount HAProxy config file
  volumes {
    host_path = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.cfg"
    container_path = "/usr/local/etc/haproxy/haproxy.cfg"
  }

  volumes {
    host_path      = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.pem"
    container_path = "/usr/local/etc/haproxy/haproxy.pem"
  }
}


#Define HA Proxy container 2
resource "docker_container" "haproxy2" {
  name  = "haproxy2"
  image = var.haproxy_image_name

  networks_advanced {
    name = docker_network.private_network.name
  }

 #Map ports
  ports {
    internal = 443
    external = 444
  }

  ports {
    internal = 8404
    external = 8405
  }

#Volume mount HAProxy config file
  volumes {
    host_path = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.cfg"
    container_path = "/usr/local/etc/haproxy/haproxy.cfg"
  }

    volumes {
    host_path      = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.pem"
    container_path = "/usr/local/etc/haproxy/haproxy.pem"
  }
}

# HAProxy configuration
resource "local_file" "haproxy_config" {
  content = <<EOF
global
  stats socket /var/run/api.sock user haproxy group haproxy mode 660 level admin expose-fd listeners
  log stdout format raw local0 info

defaults
  mode http
  timeout client 10s
  timeout connect 5s
  timeout server 10s
  timeout http-request 10s
  log global

frontend stats
  bind *:8404
  stats enable
  stats uri /
  stats refresh 10s

frontend myfrontend
  bind *:443 ssl crt /usr/local/etc/haproxy/haproxy.pem
  default_backend webservers

backend webservers
  server s1 web1:8080 check
  server s2 web2:8080 check
  server s3 web3:8080 check
EOF
  filename = "/Users/hninphyuphyuaung/HelloCloud/Terraform/Assignment5_HAProxy/BuildContainersWithHAProxy/haproxy.cfg"
}

