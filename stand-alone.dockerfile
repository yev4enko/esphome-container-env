FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV VIRTUAL_ENV=/opt/esphome-venv
ENV PATH="/opt/esphome-venv/bin:${PATH}"

# зависимости 
RUN apt-get update && apt-get install -y \
    ca-certificates curl gnupg \
    python3 python3-venv python3-pip \
    supervisor mosquitto \
    && install -d /etc/apt/keyrings \
    && curl -fsSL https://apt.grafana.com/gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
      > /etc/apt/sources.list.d/grafana.list \
    && curl -fsSL https://repos.influxdata.com/influxdata-archive.key \
      | gpg --dearmor -o /etc/apt/keyrings/influxdata.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/influxdata.gpg] https://repos.influxdata.com/ubuntu noble stable" \
      > /etc/apt/sources.list.d/influxdata.list \
    && apt-get update \
    && apt-get install -y grafana influxdb2 \
    && python3 -m venv "$VIRTUAL_ENV" \
    && "$VIRTUAL_ENV/bin/pip" install --no-cache-dir esphome \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
   
RUN mkdir -p \
    /config/esphome \
    /var/lib/grafana \
    /var/lib/influxdb2 \
    /var/lib/mosquitto \
    /var/log/mosquitto \
    /run/mosquitto \
    /etc/supervisor/conf.d
# mqtt
RUN printf '%s\n' \
    'listener 1883 0.0.0.0' \
    'allow_anonymous true' \
    'persistence true' \
    'persistence_location /var/lib/mosquitto/' \
    > /etc/mosquitto/conf.d/iot.conf

RUN printf '%s\n' \
    '[supervisord]' \
    'nodaemon=true' \
    'logfile=/dev/null' \
    'pidfile=/run/supervisord.pid' \
    '' \
    '[program:mosquitto]' \
    'command=/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf -v' \
    'autorestart=true' \
    'priority=10' \
    '' \
    '[program:influxdb]' \
    'command=/usr/bin/influxd' \
    'autorestart=true' \
    'priority=20' \
    '' \
    '[program:grafana]' \
    'command=/usr/sbin/grafana-server --homepath=/usr/share/grafana --config=/etc/grafana/grafana.ini' \
    'environment=GF_PATHS_DATA="/var/lib/grafana",GF_SECURITY_ADMIN_PASSWORD="ChangeThisPassword"' \
    'autorestart=true' \
    'priority=30' \
    '' \
    '[program:esphome]' \
    'command=/opt/esphome-venv/bin/esphome dashboard /config/esphome --address 0.0.0.0 --port 6052' \
    'autorestart=true' \
    'priority=40' \
    > /etc/supervisor/conf.d/iot.conf

# or replace those 2 printf configuration files by removing comments on 2 fucntions down below.
# COPY mosquitto/iot.conf /etc/mosquitto/conf.d/iot.conf
# COPY supervisor/supervisor-iot.conf /etc/supervisor/conf.d/iot.conf 
EXPOSE 3000 8086 1883 6052
VOLUME ["/var/lib/grafana", "/var/lib/influxdb2", "/var/lib/mosquitto", "/config/esphome"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
