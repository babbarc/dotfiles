function joy-console --wraps='ssh -t HOSTNAME \'cd /tmp && sudo -u USERNAME podman exec -it -u USERNAME USERNAME /bin/bash -c "export HOME=/opt/data/home && source ~/.bashrc && USERNAME"\'' --description 'alias joy-console ssh -t HOSTNAME \'cd /tmp && sudo -u USERNAME podman exec -it -u USERNAME USERNAME /bin/bash -c "export HOME=/opt/data/home && source ~/.bashrc && USERNAME"\''
    ssh -t HOSTNAME 'cd /tmp && sudo -u USERNAME podman exec -it -u USERNAME USERNAME /bin/bash -c "export HOME=/opt/data/home && source ~/.bashrc && USERNAME"' $argv
end
