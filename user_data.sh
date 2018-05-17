#!/usr/bin/env bash

if type -P yum >/dev/null; then
  groupadd -g 1000 ubuntu
  useradd -u 1000 -g ubuntu -d /home/ubuntu -m -s /bin/bash -p '*' ubuntu

  install -d -m 0700 -o ubuntu -g ubuntu ~ubuntu/.ssh
  install -m 0600 -o ubuntu -g ubuntu ~ec2-user/.ssh/authorized_keys ~ubuntu/.ssh/authorized_keys

  echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
  echo "Defaults !requiretty" >> /etc/sudoers

  if [[ ! -f "/etc/machine-id" ]]; then
    cat /sys/class/dmi/id/product_uuid > /etc/machine-id
  fi
fi
