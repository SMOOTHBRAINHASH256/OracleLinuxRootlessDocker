# OracleLinuxRootlessDocker

Script to setup a rootless install of Docker Oracle Linux 

Administrator will need to run this under an admin account.

This script has 6 phases and will do the following in each phase:

# PHASE 01: UPDATE PACKAGES AND UNINSTALL POTENTIAL CONFLICTS
# PHASE 02: INSTALL DOCKER
# PHASE 03: SETUP DOCKER USER
# PHASE 04: PREP FOR ROOTLESS CONFIG
# PHASE 05: CONFIGURE ROOTLESS SCRIPT AND SYSTEMD SERVICE
# PHASE 06: REBOOT HOST
# PHASE 07: RUN SYSTEMD SERVICE AND INSTALL ROOTLESS DOCKER


Custom configure the script by making sure you update the DOCKER_ADMIN_USER, DOCKER_ADMIN_PASSWORD and TARGET_SCRIPT variables

DOCKER_ADMIN_USER: The user you want to run rootless as

DOCKER_ADMIN_PASSWORD: The password for the $DOCKER_ADMIN_USER account

TARGET_SCRIPT: The script thas is run post-reboot that runs the rootless.service from systemd. Default location is /usr/local/sbin/installRootless.sh


You should run the script as follows:

sudo bash /<scriptDirectory/DockerRootlessInstall.sh | tee -a <logFileName>.log



After the reboot you should login to the shell as $DOCKER_ADMIN_USER and run "ls $HOME" to see the name of the log file for the rootless install script.

This log file should be named "/home/$DOCKER_ADMIN_USER/rootlessLog.log"



HAPPY CONTAINERIZATION!

SBH256 - SMOOTHBRAINHASH256@GMAIL.COM
