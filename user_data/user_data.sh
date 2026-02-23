#!/bin/bash
set -euo pipefail

# --- Packages ---
dnf update -y
dnf install -y python3-pip amazon-cloudwatch-agent
pip3 install flask pymysql boto3

# --- CloudWatch Agent: logs ---
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWC'
{
  "logs": {
    "force_flush_interval": 15,
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
            "log_group_name": "/aws/ec2/lab-rds-app",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/my-app.log",
            "log_group_name": "MyLogGroup/AppLogs",
            "log_stream_name": "app-{instance_id}",
            "timezone": "LOCAL"
          }
        ]
      }
    }
  }
}
CWC

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

# --- App code ---
mkdir -p /opt/rdsapp
mkdir -p /opt/rdsapp/static
echo "hello static" > /opt/rdsapp/static/example.txt



cat >/opt/rdsapp/app.py <<'PY'
import os, json, logging, urllib.request, urllib.error
from logging.handlers import RotatingFileHandler

import boto3
import pymysql
from flask import Flask, request, send_from_directory, jsonify

REGION = os.getenv("AWS_REGION", "us-east-1")
SECRET_ID = os.environ.get("SECRET_ID", "lab3/rds/mysql")

secrets = boto3.client("secretsmanager", region_name=REGION)
cloudwatch = boto3.client("cloudwatch", region_name=REGION)

def get_instance_id():
    base = "http://169.254.169.254/latest"
    try:
        token_req = urllib.request.Request(
            f"{base}/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()

        id_req = urllib.request.Request(
            f"{base}/meta-data/instance-id",
            headers={"X-aws-ec2-metadata-token": token},
        )
        return urllib.request.urlopen(id_req, timeout=2).read().decode()
    except Exception:
        return "unknown"

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

handler = RotatingFileHandler("/var/log/my-app.log", maxBytes=10_000_000, backupCount=3)
logging.basicConfig(level=logging.INFO, handlers=[handler])

def emit_db_conn_error_metric():
    cloudwatch.put_metric_data(
        Namespace="Lab3/RDSApp",
        MetricData=[{
            "MetricName": "DBConnectionErrors",
            "Value": 1,
            "Unit": "Count",
            "Dimensions": [
                {"Name": "InstanceId", "Value": get_instance_id()},
                {"Name": "Service", "Value": "rdsapp"},
                {"Name": "Environment", "Value": "lab"}
            ]
        }]
    )

def get_conn():
    c = get_db_creds()
    try:
        return pymysql.connect(
            host=c["host"],
            user=c["username"],
            password=c["password"],
            port=int(c.get("port", 3306)),
            database=c.get("dbname", "labdb"),
            autocommit=True,
            connect_timeout=3,
        )
    except Exception as e:
        logging.exception("DB connection failed: %s", e)
        emit_db_conn_error_metric()
        raise

app = Flask(__name__)

@app.after_request
def add_api_no_cache_headers(resp):
    if request.path.startswith("/api/"):
        resp.headers["Cache-Control"] = "no-store"
        resp.headers["Pragma"] = "no-cache"
    return resp

@app.route("/api/list")
def api_list():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([{"id": r[0], "note": r[1]} for r in rows])

@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory("/opt/rdsapp/static", filename)


PY

# --- systemd service ---
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=lab3/rds/mysql
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl restart rdsapp
