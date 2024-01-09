[defaults]
inventory=./ansible/inventory.ini
roles_path=./ansible/roles
private_key_file=${private_key_file}
remote_user=${remote_user}
host_key_checking=False
use_persistent_connections=True
forks=48

[connection]
pipelining=True

[persistent_connection]
control_path_dir={{ ANSIBLE_HOME ~ "/pc" }}

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
retries = 10
pipelining = True
