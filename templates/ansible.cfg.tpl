[defaults]
inventory=./ansible/inventory.ini
roles_path=./ansible/roles
private_key_file=${private_key_file}
remote_user=${remote_user}
host_key_checking=False
use_persistent_connections=True
forks=48
hash_behaviour=merge

[connection]
pipelining=True

[persistent_connection]
control_path_dir={{ ANSIBLE_HOME ~ "/pc" }}

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ForwardAgent=yes
retries = 10
pipelining = True

[privilege_escalation]
become_flags = -H -S -n
become_method = sudo

[sudo_become_plugin]
flags = -H -S -n --preserve-env=SSH_AUTH_SOCK
