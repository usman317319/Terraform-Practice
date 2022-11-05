resource "google_compute_instance" "www1" {
  name = "www1"
  zone = "us-east1-b"
  machine_type = "e2-small"
  tags = ["network-lb-tag"]
  metadata_startup_script = "sudo apt update; sudo apt install apache2 -y; sudo service apache2 restart; sudo echo '<h3>Web Server : www1</h3>' | tee /var/www/html/index.html"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
}


resource "google_compute_instance" "www2" {
  name = "www2"
  zone = "us-east1-b"
  machine_type = "e2-small"
  tags = ["network-lb-tag"]
  metadata_startup_script = "sudo apt update; sudo apt install apache2 -y; sudo service apache2 restart; echo '<h3>Web Server: www2</h3>' | tee /var/www/html/index.html"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
}


resource "google_compute_instance" "www3" {
  name = "www3"
  zone = "us-east1-b"
  machine_type = "e2-small"
  tags = ["network-lb-tag"]
  metadata_startup_script = "sudo apt update; sudo apt install apache2 -y; sudo service apache2 restart; sudo echo '<h3>Web Server: www3</h3>' | tee /var/www/html/index.html"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
}


resource "google_compute_firewall" "www-firewall-network-lb" {
  name = "www-firewall-network-lb"
  network = "default"
  allow {
    ports = ["80"]
    protocol = "tcp"
  }
  priority = 1000
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["network-lb-tag"]
}


resource "google_compute_address" "network-lb-ip-1" {
  name = "network-lb-ip-1"
  region = "us-east1"
}


resource "google_compute_http_health_check" "basic-health" {
  name = "basic-health"
}


resource "google_compute_target_pool" "www-pool" {
  name = "www-pool"
  region = "us-east1"
  instances = [
    "us-east1-b/www1",
    "us-east1-b/www2",
    "us-east1-b/www3",
  ]

  health_checks = [ google_compute_http_health_check.basic-health.id]
}

# Problems in attaching the target pool to back end of the forwarding rule
#resource "google_compute_forwarding_rule" "www-rule" {
#  name = "www-rule"
#  region = "us-central1"
#  ports = ["80"]
#  ip_address = google_compute_address.network-lb-ip-1.id
#}


resource "google_compute_instance_template" "lb-backend-template" {
  name = "lb-backend-template"
  region = "us-east1"
  tags = ["allow-health-check"]
  machine_type = "e2-medium"
  metadata_startup_script = "sudo apt update; sudo apt install apache2 -y; sudo a2ensite default-ssl; sudo a2enmod ssl; sudo vm_hostname='$(curl -H 'Metadata-Flavor:Google' http://169.254.169.254/computeMetadata/v1/instance/name)'; sudo echo 'Page served from: $vm_hostname' | tee /var/www/html/index.html; sudo systemctl restart apache2"

  disk {
    source_image = "debian-cloud/debian-11"
  }

  network_interface {
    network = "default"
    subnetwork = "default"
    access_config{
    }
  }
}

resource "google_compute_instance_group_manager" "lb-backend-group" {
  name = "lb-backend-group"
  
  base_instance_name = "app"
  zone = "us-east1-b"

  version {
    instance_template = google_compute_instance_template.lb-backend-template.id
  }

  named_port {
    name = "http"
    port = 80
  }

  target_size= 3
}


resource "google_compute_firewall" "fw-allow-health-check" {
  name = "fw-allow-health-check"
  network = "default"
  allow {
    ports = ["80"]
    protocol = "tcp"
  }
  direction = "INGRESS"
  priority = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = ["allow-health-check"]
}
  

resource "google_compute_global_address" "lb-ipv4-1" {
  name = "lb-ipv4-1"
}

resource "google_compute_health_check" "http-basic-check" {
  name = "http-basic-check"
  tcp_health_check {
    port = "80"
  }
}



resource "google_compute_backend_service" "web-backend-service" {
  name = "web-backend-service"
  port_name = "http"
  health_checks = [google_compute_health_check.http-basic-check.id]
  backend {
    group = google_compute_instance_group_manager.lb-backend-group.instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }
}


resource "google_compute_url_map" "web-map-http" {
  name = web-map-http"
  default_service = google_compute_backend_service.web-backend-service.id
}


resource "google_compute_target_http_proxy" "http-lb-proxy"{
  name = "http-lb-proxy"
  url_map = "web-map-http"
}


resource "google_compute_global_forwarding_rule" "http-content-rule" {
  name = "http-content-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.lb-ipv4-1.id
  target = google_compute_target_http_proxy.http-lb-proxy.id
  port_range = "80"
}
