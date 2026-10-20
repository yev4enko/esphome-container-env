# Docker IoT — README

This README explains how to install Docker and run the configurations from **Section 4** and **Section 5** of the project report. Keep configuration files separate from terminal commands!

## 1. Docker installation guide on Ubuntu

*see the [official Docker Engine installation guide for Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

### 1.1 Update Ubuntu and install prerequisites

Run in a terminal:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install ca-certificates curl -y
```

### 1.2 Add Docker's official signing key and repository

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add the Docker repository:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

### 1.3 Install Docker Engine and Compose

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

### 1.4 Start and verify Docker

```bash
sudo systemctl status docker
```

If Docker is not running, enable and start it:

```bash
sudo systemctl enable --now docker
```

Verify the installation and run a test container:

```bash
sudo docker --version
sudo docker compose version
sudo docker info
sudo docker run hello-world
```

The `hello-world` test should print a message beginning with `Hello from Docker!`. Continue only after Docker can successfully run this test container.


## 2. Section 4 — Build and run the stand-alone image

This configuration builds "STAND-ALONE" containing Grafana, InfluxDB, Mosquitto, and ESPHome in the same container.

### Commands

Build the image:

```bash
sudo docker build -t iot-standalone:1.0
```

Start the container:

```bash
sudo docker run -d \
  --name iot-standalone \
  --restart unless-stopped \
  -p 3000:3000 \
  -p 8086:8086 \
  -p 1883:1883 \
  -p 6052:6052 \
  -v grafana-data:/var/lib/grafana \
  -v influxdb-data:/var/lib/influxdb2 \
  -v mosquitto-data:/var/lib/mosquitto \
  -v esphome-config:/config/esphome \
  iot-standalone:1.0
```

### Check and manage the container

```bash
sudo docker ps
sudo docker logs iot-standalone
```

Stop or start it:

```bash
sudo docker stop iot-standalone
sudo docker start iot-standalone
```

To remove the container (named volumes remain):

```bash
sudo docker rm -f iot-standalone
```

### Open the services

- Grafana: http://localhost:3000
- InfluxDB: http://localhost:8086
- ESPHome dashboard: http://localhost:6052
- Mosquitto: MQTT clients connect to `localhost:1883`

**Important:** This is a prototype configuration. The Dockerfile enables anonymous MQTT access for local testing. Do not expose it to an untrusted network. Change default credentials and configure authentication before broader use. Starting the services does not complete the data pipeline automatically; InfluxDB, Grafana, ESPHome, and MQTT integration still need application-level configuration.

## 3. Section 5.1 — Run two instances with Docker Compose

This configuration runs **two instances of the same custom image**. Build the image using the exact tag expected by the Compose file.

```bash
sudo docker build -t my-iot-stack:latest .
sudo docker compose -f docker-compose-two-instances.yml up -d
```

Check their status and logs:

```bash
sudo docker compose -f docker-compose-two-instances.yml ps
sudo docker compose -f docker-compose-two-instances.yml logs
```

Stop and remove the containers (named volumes remain):

```bash
sudo docker compose -f docker-compose-two-instances.yml down
```

### Ports

- Instance 1: Grafana `3000`, InfluxDB `8086`, MQTT `1883`, ESPHome `6052`
- Instance 2: Grafana `3001`, InfluxDB `8087`, MQTT `1884`, ESPHome `6053`

**Important limitation from the report:** Two instances cannot publish the same host port simultaneously, so the second instance uses different host ports. The Compose file currently mounts a generic `/data` volume, but the Dockerfile stores application data under paths such as `/var/lib/grafana`, `/var/lib/influxdb2`, `/var/lib/mosquitto`, and `/config/esphome`. The `/data` volume therefore does not by itself persist those application directories. For actual persistence, mount each application's data/configuration path separately for each instance.

Because all four applications share one container lifecycle, a failure can be harder to isolate than in the four-service setup.

## 4. Section 5.2 — Run four separate services with Docker Compose

This configuration runs Grafana, InfluxDB, Mosquitto, and ESPHome in **four separate containers**.

### Prepare configuration files and directories

Create the required directories:

```bash
mkdir -p mosquitto/config esphome
```

Create `mosquitto/config/mosquitto.conf` with this minimal local-lab configuration:

```conf
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
```

This allows anonymous MQTT access and is intended only for an isolated test environment. Configure authentication and network restrictions before using it on a shared or exposed network. Put ESPHome device YAML configuration files in the `esphome/` directory.

### Start, inspect, and stop the services

```bash
sudo docker compose -f docker-compose-four-services.yml up -d
sudo docker compose -f docker-compose-four-services.yml ps
sudo docker compose -f docker-compose-four-services.yml logs
```

View logs for one service at a time:

```bash
sudo docker compose -f docker-compose-four-services.yml logs grafana
sudo docker compose -f docker-compose-four-services.yml logs influxdb
sudo docker compose -f docker-compose-four-services.yml logs mosquitto
sudo docker compose -f docker-compose-four-services.yml logs esphome
```

Stop and remove the containers (named volumes remain):

```bash
sudo docker compose -f docker-compose-four-services.yml down
```

### Open the services

- Grafana: http://localhost:3000
- InfluxDB: http://localhost:8086
- ESPHome dashboard: http://localhost:6052
- Mosquitto: MQTT clients connect to `localhost:1883`

In the supplied Compose file, Grafana and InfluxDB are published only on `127.0.0.1`, so they are accessible from the Ubuntu host itself by default. Mosquitto and ESPHome ports are published without that loopback restriction.

**Important:** Compose starts and connects the containers, but does not automatically configure the full IoT data flow. Set up InfluxDB, configure Grafana's InfluxDB data source, configure ESPHome devices, and add any required MQTT-to-InfluxDB integration separately.

## 5. Troubleshooting and error handling

The original report highlights two key points: successful execution depends on correct image configuration, startup, networking, and storage; and separating the four applications makes troubleshooting easier because each service has its own logs and can be restarted independently.

### Docker installation or daemon problems

**Error: `Cannot connect to the Docker daemon` or Docker commands cannot connect.**

Check the service and start it if needed:

```bash
sudo systemctl status docker
sudo systemctl enable --now docker
sudo docker info
```

**Error: `docker: command not found` or `docker compose` is unavailable.**

Confirm the packages were installed and check versions:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker --version
sudo docker compose version
```

If installation fails, compare the repository configuration with the [official Ubuntu installation guide](https://docs.docker.com/engine/install/ubuntu/).

**Error: permission denied when accessing Docker.**

Use `sudo` with the command, as in this README. For non-root access, read the security implications in Docker's [post-installation guide](https://docs.docker.com/engine/install/linux-postinstall/).

### Build or Compose problems

**Error: Docker cannot find the Dockerfile or Compose file.**

Run `pwd` and `ls` to confirm the terminal is in the project folder and the filenames match this README. Build the custom image from the directory containing `Dockerfile`:

```bash
sudo docker build -t iot-standalone:1.0 .
```

**Error: image not found for the two-instance configuration.**

Build the tag expected in `docker-compose-two-instances.yml` before starting Compose:

```bash
sudo docker build -t my-iot-stack:latest .
sudo docker compose -f docker-compose-two-instances.yml up -d
```

**Error: `port is already allocated` or a service cannot bind to a port.**

Another process or container is using the host port. Check running containers and listening ports; stop the conflicting container or change the host-side port mapping in the Compose file:

```bash
sudo docker ps
sudo ss -ltnp
```

The report's two-instance configuration intentionally uses different host ports for the second instance.

**A container exits or a service does not start.**

Check the container state and logs first:

```bash
sudo docker ps -a
sudo docker logs iot-standalone
```

For Compose, inspect all service logs or narrow the output to the failing service:

```bash
sudo docker compose -f docker-compose-four-services.yml ps
sudo docker compose -f docker-compose-four-services.yml logs <service-name>
```

Replace `<service-name>` with `grafana`, `influxdb`, `mosquitto`, or `esphome`. If using Section 4 or 5.1, all four applications share one container, so the logs may include messages from multiple applications and diagnosis can be more difficult. Section 5.2 is easier to troubleshoot because each service can be inspected and restarted separately.

**Mosquitto fails to start in Section 5.2.**

Check that `mosquitto/config/mosquitto.conf` exists and contains valid configuration. Then inspect its logs:

```bash
sudo docker compose -f docker-compose-four-services.yml logs mosquitto
```

**The dashboards open, but no measurements appear.**

Starting the containers does not create the complete data pipeline. Check that InfluxDB has been initialized, Grafana's data source points to the correct InfluxDB instance, ESPHome device configuration is present, and the selected MQTT-to-InfluxDB integration is configured. Inspect the logs for the relevant service.

**Data disappears after recreating containers.**

Check that application directories are mounted to persistent named volumes. `docker compose down` normally preserves named volumes, but `docker compose down -v` deletes them. For Section 5.1, the generic `/data` mount does not persist the application paths used by the Dockerfile; see the limitation in Section 4 above.

## Official Documentation links

- [Docker Engine installation on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) — install Docker Engine from the official APT repository.
- [Docker post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/) — non-root access and daemon setup considerations.
- [Docker Compose documentation](https://docs.docker.com/compose/) — Compose files, commands, and service management.
- [Grafana documentation](https://grafana.com/docs/grafana/latest/) — configuring dashboards and data sources.
- [InfluxDB documentation](https://docs.influxdata.com/influxdb/v2/) — initial setup, buckets, and data ingestion.
- [Eclipse Mosquitto documentation](https://mosquitto.org/documentation/) — broker configuration and security.
- [ESPHome documentation](https://esphome.io/) — device configuration and dashboard usage.