#!/bin/bash



#!!!!!!!!!!!!!!!!!!!!!!EDIT THIS SECTION!!!!!!!!!!!!!!!!!!!!!!!
#
# Non-admin username and password to be set
DOCKER_ADMIN_USER="rootlessuser"
DOCKER_ADMIN_PASSWORD="somepass"
#
# Define the path of the script to run at system startup
TARGET_SCRIPT="/usr/local/sbin/installRootless.sh"
#
#!!!!!!!!!!!!!!!!!!END EDIT THIS SECTION!!!!!!!!!!!!!!!!!!!!!!!




echo "PHASE 01: UPDATE PACKAGES AND UNINSTALL POTENTIAL CONFLICTS"
##################################################

# Update your existing list of packages
sudo yum update -y
# Install required packages
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
#remove potential packages that will cause runc conflicts
sudo yum erase -y podman buildah
# Set up the Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo




echo "PHASE 02: INSTALL DOCKER"
##################################################

# Install Docker CE
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Check if the docker group exists, if not, create it
if ! getent group docker > /dev/null 2>&1; then
    echo "Creating docker group..."
    sudo groupadd docker
fi




echo "PHASE 03: SETUP DOCKER USER"
##################################################

# Create a new user and set the password
echo "Creating user $DOCKER_ADMIN_USER..."
sudo useradd -m -G docker $DOCKER_ADMIN_USER
echo "$DOCKER_ADMIN_USER:$DOCKER_ADMIN_PASSWORD" | sudo chpasswd
# Ensure the user has been added to the docker group
sudo usermod -aG docker $DOCKER_ADMIN_USER
# Output the result
echo "User $DOCKER_ADMIN_USER has been created and added to the docker group."




echo "PHASE 04: PREP FOR ROOTLESS CONFIG"
##################################################

sudo systemctl disable --now docker.service docker.socket
# Apply the system kernel parameters
echo "Applying system kernel parameters..."
# Define the parameter to add for rootless
PARAM="user.max_user_namespaces=28633"
SYSCTL_CONF="/etc/sysctl.conf"
# Check if the parameter already exists
if grep -q "$PARAM" "$SYSCTL_CONF"; then
    echo "Parameter already set in $SYSCTL_CONF"
else
    # Add the parameter to sysctl.conf
    echo "Adding $PARAM to $SYSCTL_CONF"
    echo "$PARAM" | sudo tee -a "$SYSCTL_CONF" > /dev/null
fi
sudo sysctl --system
echo "Performing user checks for good measure"
#checking and prepping for rootless install
sudo -u "$DOCKER_ADMIN_USER" id -u
sudo -u "$DOCKER_ADMIN_USER" whoami
sudo -u "$DOCKER_ADMIN_USER" grep ^$(whoami): /etc/subuid
sudo -u "$DOCKER_ADMIN_USER" grep ^$(whoami): /etc/subgid
echo "Installing fuse-overlayfs and iptables if not already"
sudo dnf install -y fuse-overlayfs
echo "fuse-overlayfs successfully installed"
sudo dnf install -y iptables
echo "iptables successfully installed"




echo "PHASE 05: CONFIGURE ROOTLESS SCRIPT AND SYSTEMD SERVICE"
##################################################

echo "Set Login Control so we can run the rootless script as another user for systemd"
sudo loginctl enable-linger $DOCKER_ADMIN_USER
#Define location and name for log
LOG_NAME="/home/$DOCKER_ADMIN_USER/rootlessLog.log"
#Create systemd service
cat > /etc/systemd/system/rootless.service <<EOF
[Unit]
Description=Rootless Startup commands

[Service]
ExecStart=$TARGET_SCRIPT

[Install]
WantedBy=multi-user.target

EOF
echo "Applying perms and enabling the custom systemd service"
chmod +x /etc/systemd/system/rootless.service
chmod 777 /etc/systemd/system/rootless.service
sudo systemctl daemon-reload
sudo systemctl enable rootless.service
echo "Building the installRootless.sh script"
# Create and write the installRootless.sh script
cat > "$TARGET_SCRIPT" <<EOF
#!/bin/bash

#Create log
sudo touch $LOG_NAME

#Change log ownership
chown dockeradmin:dockeradmin $LOG_NAME

echo "Running rootless startup script" >> $LOG_NAME

echo "setting modprobe and ip_tables" >> $LOG_NAME
echo "modprobe ip_tables" | sudo sh -eux >> $LOG_NAME

echo "running the official rootless script" >> $LOG_NAME
sudo -u $DOCKER_ADMIN_USER dockerd-rootless-setuptool.sh install >> $LOG_NAME

echo "Setting user PATH env variable" >> $LOG_NAME
sudo -u $DOCKER_ADMIN_USER export PATH=/usr/bin:\$PATH >> $LOG_NAME

echo "Setting DOCKER_HOST env variable" >> $LOG_NAME
sudo -u $DOCKER_ADMIN_USER export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock >> $LOG_NAME

echo "Enable reserved ports for rootless mode"
sudo setcap cap_net_bind_service=ep $(which rootlesskit) >> $LOG_NAME

echo "Enabling Docker as rootless service" >> $LOG_NAME
sudo -u $DOCKER_ADMIN_USER systemctl --user enable docker >> $LOG_NAME

echo "Starting rootless docker service" >> $LOG_NAME
sudo -u $DOCKER_ADMIN_USER systemctl --user start docker >> $LOG_NAME

echo "Deleting the startup service and script" >> $LOG_NAME
#crontab -l | grep -v "$TARGET_SCRIPT" | crontab - >> $LOG_NAME
sudo systemctl disable rootless.service >> $LOG_NAME

sudo rm $TARGET_SCRIPT >> $LOG_NAME

echo "All DONE!" >> $LOG_NAME

EOF
# Make the script running at boot executable
chmod +x "$TARGET_SCRIPT"
chmod 777 "$TARGET_SCRIPT"
echo "startup script and service created and will be run after reboot"




echo "PHASE 06: REBOOT HOST"
##################################################

sudo reboot

exit
