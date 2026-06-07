#!/bin/bash

# WinterHill 4v00 install file
# G8GKQ 6 Mar 2021
# Support for Debian Bookworm added by Phil Taylor M0VSE 14th Sep 2025
# Support for Debian Trixie added by Phil Taylor M0VSE 7th Jun 2026

# Winterhill for a 1920 x 1080 screen

whoami | grep -q pi
if [ $? != 0 ]; then
  echo "Install must be performed as user pi"
  exit
fi

# Check which source needs to be loaded
GIT_SRC="m0vse"
GIT_SRC_FILE=".wh_gitsrc"

if [ "$1" == "-d" ]; then
  GIT_SRC="davecrump";  # G8GKQ
  #GIT_SRC="foxcube";    # G4EWJ
  echo
  echo "-------------------------------------------------------"
  echo "----- Installing development version of WinterHill-----"
  echo "-------------------------------------------------------"
elif [ "$1" == "-u" -a ! -z "$2" ]; then
  GIT_SRC="$2"
  echo
  echo "WARNING: Installing ${GIT_SRC} development version, press enter to continue or 'q' to quit."
  read -n1 -r -s key;
  if [[ $key == q ]]; then
    exit 1;
  fi
  echo "ok!";
else
  echo
  echo "------------------------------------------------------------"
  echo "----- Installing BATC Production version of WinterHill -----"
  echo "------------------------------------------------------------"
fi

cd /home/pi

BOOT_CONFIG="/boot/config.txt"
if [ -f "/boot/firmware/config.txt" ]; then
  BOOT_CONFIG="/boot/firmware/config.txt"
fi

append_boot_config() {
  echo -e "$1" | sudo tee -a "$BOOT_CONFIG" >/dev/null
}

set_boot_config() {
  local pattern="$1"
  local replacement="$2"

  if sudo grep -Eq "$pattern" "$BOOT_CONFIG"; then
    sudo sed -i -E "/$pattern/c\\$replacement" "$BOOT_CONFIG"
  else
    append_boot_config "$replacement"
  fi
}

ensure_boot_config() {
  local setting="$1"

  if ! sudo grep -qxF "$setting" "$BOOT_CONFIG"; then
    append_boot_config "$setting"
  fi
}

install_kernel_headers() {
  sudo apt-get -y install raspberrypi-kernel-headers && return 0
  sudo apt-get -y install "linux-headers-$(uname -r)" && {
    sudo apt-get -y install linux-headers-arm64 >/dev/null 2>&1 || true
    return 0
  }
  sudo apt-get -y install linux-headers-arm64
}

echo "--------------------------------------------------------"
echo "----- Disabling the raspberry ssh password warning -----"
echo "--------------------------------------------------------"
echo
sudo mv /etc/xdg/lxsession/LXDE-pi/sshpwd.sh /etc/xdg/lxsession/LXDE-pi/sshpwd.sh.old

echo "------------------------------------"
echo "---- Loading required packages -----"
echo "------------------------------------"
echo
sudo apt-get -y install xdotool xterm lxterminal
install_kernel_headers

echo "--------------------------------------------------------------"
echo "---- Put the Desktop Toolbar at the bottom of the screen -----"
echo "--------------------------------------------------------------"
echo
cd /home/pi/.config/lxpanel/LXDE-pi/panels
sed -i "/^  edge=top/c\  edge=bottom" panel
cd /home/pi

echo "------------------------------------------------"
echo "---- Increasing gpu memory in $BOOT_CONFIG -----"
echo "------------------------------------------------"
echo
append_boot_config "\n##Increase GPU Memory"
append_boot_config "gpu_mem=128\n"

echo "-------------------------------------------------"
echo "---- Set force_turbo for constant spi speed -----"
echo "-------------------------------------------------"
echo
append_boot_config "##Set force_turbo for constant spi speed"
append_boot_config "force_turbo=1\n"

echo "--------------------------------------"
echo "---- Set the spi ports correctly -----"
echo "--------------------------------------"
echo
set_boot_config "^#?dtparam=spi=on" "dtparam=spi=off"
ensure_boot_config "dtoverlay=spi5-1cs"

echo "----------------------------------------------"
echo "---- Setting Framebuffer to 32 bit depth -----"
echo "----------------------------------------------"
echo
set_boot_config "^dtoverlay=vc4-fkms-v3d" "#dtoverlay=vc4-fkms-v3d"

echo "------------------------------------------------------------"
echo "---- Setting GUI to start with or without HDMI display -----"
echo "------------------------------------------------------------"
echo
set_boot_config "^#hdmi_force_hotplug=1" "hdmi_force_hotplug=1"


echo "-------------------------------------------"
echo "---- Download the WinterHill Software -----"
echo "-------------------------------------------"
echo
cd /home/pi
wget https://github.com/${GIT_SRC}/winterhill/archive/main.zip
unzip -o main.zip
mv winterhill-main winterhill
rm main.zip

BUILD_VERSION=$(</home/pi/winterhill/latest_version.txt)
echo INSTALL WinterHill build started version $BUILD_VERSION > /home/pi/winterhill/whlog.txt

echo "------------------------------------------"
echo "---- Building spi driver for install -----"
echo "------------------------------------------"
echo
cd /home/pi/winterhill/whsource-4v00/whdriver-4v00
sudo make
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "- Failed to build the WinterHill Driver --"
  echo "------------------------------------------"
  echo INSTALL Initial make of driver failed >> /home/pi/winterhill/whlog.txt
  exit
fi

sudo rmmod whdriver-3v20.ko >/dev/null 2>/dev/null
sudo rmmod whdriver-4v00.ko >/dev/null 2>/dev/null

sudo insmod whdriver-4v00.ko
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "--- Failed to load WinterHill Driver -----"
  echo "------------------------------------------"
  echo INSTALL Initial insmod of driver failed >> /home/pi/winterhill/whlog.txt
  exit
fi

cat /proc/modules | grep -q 'whdriver_4v00'
if [ $? != 0 ]; then
  echo "-------------------------------------------------------------"
  echo "--- Failed to find previously loaded  WinterHill Driver -----"
  echo "-------------------------------------------------------------"
  echo INSTALL Initial check of driver failed >> /home/pi/winterhill/whlog.txt
  exit
else
  echo
  echo "------------------------------------------------"
  echo "--- Successfully loaded  WinterHill Driver -----"
  echo "------------------------------------------------"
  echo INSTALL Driver Successfully loaded >> /home/pi/winterhill/whlog.txt
  echo
fi
cd /home/pi

echo "------------------------------------------------"
echo "---- Set up to load the spi driver at boot -----"
echo "------------------------------------------------"
echo
if [ -f "/etc/rc.local" ]; then
  sudo sed -i "/^exit 0/c\cd /home/pi/winterhill/whsource-4v00/whdriver-4v00\nmake clean >/dev/null 2>&1\nmake\ninsmod whdriver-4v00.ko\nexit 0" /etc/rc.local
else
  sudo tee /etc/rc.local > /dev/null  << EOL
#!/bin/sh -e
cd /home/pi/winterhill/whsource-4v00/whdriver-4v00
make clean >/dev/null 2>&1
make
insmod whdriver-4v00.ko
exit 0
EOL

  sudo chmod a+x /etc/rc.local
  sudo systemctl status rc-local.service
fi

echo "---------------------------------------------------"
echo "---- Building the main WinterHill Application -----"
echo "---------------------------------------------------"
echo
cd /home/pi/winterhill/whsource-4v00/whmain-4v00
make
if [ $? != 0 ]; then
  echo "----------------------------------------------"
  echo "- Failed to build the WinterHill Application -"
  echo "----------------------------------------------"
  echo INSTALL make of main application failed >> /home/pi/winterhill/whlog.txt
  exit
fi
cp winterhill-4v00 /home/pi/winterhill/RPi-4v00/winterhill-4v00
cd /home/pi

echo "--------------------------------------"
echo "---- Building the PIC Programmer -----"
echo "--------------------------------------"
echo
cd /home/pi/winterhill/whsource-4v00/whpicprog-4v00
./make.sh
if [ $? != 0 ]; then
  echo "--------------------------------------"
  echo "- Failed to build the PIC Programmer -"
  echo "--------------------------------------"
  echo INSTALL make of PIC Programmer failed >> /home/pi/winterhill/whlog.txt
  exit
fi
cp whpicprog-4v00 /home/pi/winterhill/PIC-4v00/whpicprog-4v00
cd /home/pi

echo "--------------------------------------------"
echo "---- Copy the shortcuts to the desktop -----"
echo "--------------------------------------------"
echo
cp /home/pi/winterhill/configs/Kill_WH           /home/pi/Desktop/Kill_WH
cp /home/pi/winterhill/configs/WH_Local          /home/pi/Desktop/WH_Local
cp /home/pi/winterhill/configs/WH_Anyhub         /home/pi/Desktop/WH_Anyhub
cp /home/pi/winterhill/configs/WH_Anywhere       /home/pi/Desktop/WH_Anywhere
cp /home/pi/winterhill/configs/WH_Multihub       /home/pi/Desktop/WH_Multihub
cp /home/pi/winterhill/configs/WH_Fixed          /home/pi/Desktop/WH_Fixed
cp /home/pi/winterhill/configs/PIC_Prog          /home/pi/Desktop/PIC_Prog
cp /home/pi/winterhill/configs/Show_IP           /home/pi/Desktop/Show_IP
cp /home/pi/winterhill/configs/Shutdown          /home/pi/Desktop/Shutdown
cp /home/pi/winterhill/configs/Check_for_Update  /home/pi/Desktop/Check_for_Update

echo "--------------------------------------------------------------------"
echo "---- Enable Autostart for the selected WinterHill mode at boot -----"
echo "--------------------------------------------------------------------"
echo
mkdir /home/pi/.config/autostart
cp /home/pi/winterhill/configs/startup.desktop /home/pi/.config/autostart/startup.desktop

# Save git source used
echo "${GIT_SRC}" > /home/pi/${GIT_SRC_FILE}

echo
echo "SD Card Serial:"
cat /sys/block/mmcblk0/device/cid

# Reboot
echo
echo "--------------------------------"
echo "----- Complete.  Rebooting -----"
echo "--------------------------------"
echo INSTALL Reached end of install script >> /home/pi/winterhill/whlog.txt

sleep 1

#sudo reboot now
exit
