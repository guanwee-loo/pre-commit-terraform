rem This include the talisman version in the file /opt/app-root/bin/tools_versions_info
podman build -t pre-commit-terraform-talisman:0.2 --build-arg INSTALL_ALL=true -f Containerfile_v0.2 .
