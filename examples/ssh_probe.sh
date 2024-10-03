#!/bin/sh

if ssh -i /root/.ssh/id_rsa root@ssh-server-service -o StrictHostKeyChecking=no "echo probe_success"; then
  echo "ssh_connection_success 1"
else
  echo "ssh_connection_success 0"
fi
