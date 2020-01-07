#!/bin/bash

set -ex

apt-get update
apt-get install -y unzip
apt-get install -y libltdl7

sudo cp /vagrant/vault /usr/local/bin/vault

mkdir -p /etc/vault/

tee /etc/vault/vault.hcl <<EOF
seal "pkcs11" {
  lib            = "/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label      = "hsm_demo_key"
  hmac_key_label = "hsm_demo_hmac_key"
  generate_key   = "true"
}
backend "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}
EOF

tee /etc/vault/vault-secondary.hcl <<EOF
seal "pkcs11" {
  lib            = "/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label      = "hsm_demo_key"
  hmac_key_label = "hsm_demo_hmac_key"
  generate_key   = "true"
}
backend "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address     = "127.0.0.1:8210"
  tls_disable = 1
}
EOF

echo "Installing Vault startup script..."
sudo bash -c "cat >/etc/systemd/system/vault.service" << 'VAULTSVC'
[Unit]
Description=vault agent
Requires=network-online.target
After=network-online.target consul.service
[Service]
EnvironmentFile=-/etc/default/vault
Environment="VAULT_UI=true"
Restart=on-failure
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
[Install]
WantedBy=multi-user.target
VAULTSVC
sudo chmod 0644 /etc/systemd/system/vault.service
