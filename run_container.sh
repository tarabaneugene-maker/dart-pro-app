#!/bin/bash
sudo docker rm -f dart-pro-server 2>/dev/null
JWT=$(openssl rand -hex 32)
sudo docker run -d --name dart-pro-server --restart unless-stopped -p 127.0.0.1:8080:8080 -v /opt/dart-pro-data:/app/data -e PORT=8080 -e JWT_SECRET=$JWT dart-pro-server
