#!/bin/bash

set -ex


tee /opt/vault/config/vault.hcl <<EOF
ui = true

seal "pkcs11" {
  lib            = "/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label    	 = "hsm_demo"
  hmac_key_label = "hsm_demo_hmac"
  generate_key   = "true"
}

storage "file" {
  path = "/opt/vault/filedata"
}


entropy "seal" {
  mode = "augmentation"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}


EOF


echo "Installing Vault startup script..."
sudo bash -c "cat >/etc/systemd/system/vault.service" << 'VAULTSVC'

[[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/opt/vault/config/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/opt/vault/bin/vault server -config=/opt/vault/config/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target

VAULTSVC

sudo chmod 0644 /etc/systemd/system/vault.service
