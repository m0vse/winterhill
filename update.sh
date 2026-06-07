#!/bin/bash

# Updated by davecrump 202103080 for WinterHill
# Support for Debian Bookworm added by Phil Taylor M0VSE 14th Sep 2025
# Support for Debian Trixie added by Phil Taylor M0VSE 7th Jun 2026


reset

echo "------------------------------------------------"
echo "------ Commencing WinterHill Update ------------"
echo "------------------------------------------------"
echo

install_kernel_headers() {
  sudo apt-get -y install raspberrypi-kernel-headers && return 0
  sudo apt-get -y install "linux-headers-$(uname -r)" && {
    sudo apt-get -y install linux-headers-arm64 >/dev/null 2>&1 || true
    return 0
  }
  sudo apt-get -y install linux-headers-arm64
}

cd /home/pi

## Check which update to load
GIT_SRC_FILE=".wh_gitsrc"
if [ -e ${GIT_SRC_FILE} ]; then
  GIT_SRC=$(</home/pi/${GIT_SRC_FILE})
else
#  GIT_SRC="BritishAmateurTelevisionClub"
  GIT_SRC="m0vse"
fi

# Define Location of Dev version
GIT_DEV="davecrump"  # G8GKQ
#GIT_DEV="foxcube"     # G4EWJ

## If previous version was Dev, load production by default
if [ "$GIT_SRC" == "$GIT_DEV" ]; then
  GIT_SRC="BritishAmateurTelevisionClub"
fi

if [ "$1" == "-d" ]; then
  echo "Overriding to update to latest development version"
  GIT_SRC=$GIT_DEV
fi

if [ "$GIT_SRC" == "BritishAmateurTelevisionClub" ]; then
  echo "Updating to latest Production WinterHill build";
elif [ "$GIT_SRC" == "$GIT_DEV" ]; then
  echo "Updating to latest development WinterHill build";
else
  echo "Updating to latest ${GIT_SRC} development WinterHill build";
fi

echo
echo "------------------------------------------------"
echo "-- Making Sure that WinterHill is not running --"
echo "------------------------------------------------"
echo

pgrep winterhill
WHRUNS=$?
while [ $WHRUNS = 0 ]
do
  PID=$(pgrep winterhill | head -n 1)
  echo $PID
  sudo kill "$PID"
  sleep 1
  PID=$(pgrep winterhill | head -n 1)
  echo $PID
  sudo kill -9 "$PID"
  pgrep winterhill
  WHRUNS=$?
done

echo "------------------------------------------------"
echo "-- Making a Back-up of the User Configuration --"
echo "------------------------------------------------"
echo

PATHINI="/home/pi/winterhill"
PATHUBACKUP="/home/pi/user_backups"
mkdir "$PATHUBACKUP" >/dev/null 2>/dev/null

# Note previous version number
cp -f -r /home/pi/winterhill/installed_version.txt "$PATHUBACKUP"/prev_installed_version.txt

# Make a safe copy of the user .ini file
cp -f -r "$PATHINI"/winterhill.ini "$PATHUBACKUP"/winterhill.ini

echo
echo "Updating the OS and Installed Packages"
echo

sudo dpkg --configure -a                         # Make sure that all the packages are properly configured
sudo apt-get clean                               # Clean up the old archived packages
sudo apt-get update --allow-releaseinfo-change   # Update the package list
sudo apt-get -y dist-upgrade                     # Upgrade all the installed packages to their latest version
sudo apt-get -y install xdotool xterm lxterminal
install_kernel_headers

# --------- Install new packages as Required ---------

# Add code here to install any new packages required by updates

# --------- Now update WinterHill ---------

echo
echo "Updating the WinterHill Software"
echo

cd /home/pi

# Delete the previous winterhill code
rm -rf winterhill >/dev/null 2>/dev/null

echo "--------------------------------------------------"
echo "---- Downloading the new WinterHill Software -----"
echo "--------------------------------------------------"
echo
cd /home/pi
wget https://github.com/${GIT_SRC}/winterhill/archive/main.zip
unzip -o main.zip
mv winterhill-main winterhill
rm main.zip

BUILD_VERSION=$(</home/pi/winterhill/latest_version.txt)
sudo chown pi /home/pi/winterhill/whlog.txt  # Will be owned by root in some conditions
echo UPDATE WinterHill update started version $BUILD_VERSION >> /home/pi/winterhill/whlog.txt
echo UPDATE from $GIT_SRC repository >> /home/pi/winterhill/whlog.txt

# spi driver may need rebuilding after OS update
echo "--------------------------------------------"
echo "---- Rebuilding spi driver for install -----"
echo "--------------------------------------------"
echo
cd /home/pi/winterhill/whsource-4v00/whdriver-4v00 || exit
make
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "- Failed to build the WinterHill Driver --"
  echo "------------------------------------------"
  echo UPDATE Failed to build the WinterHill Driver >> /home/pi/winterhill/whlog.txt
  exit
fi
if [ ! -f whdriver-4v00.ko ]; then
  echo "------------------------------------------"
  echo "- WinterHill Driver module was not built -"
  echo "------------------------------------------"
  echo UPDATE whdriver-4v00.ko was not found in the driver directory >> /home/pi/winterhill/whlog.txt
  exit
fi

# Remove any old drivers, and the current one  
# Add current driver to this list after a driver update
sudo rmmod whdriver-2v22.ko >/dev/null 2>/dev/null
sudo rmmod whdriver-3v20.ko >/dev/null 2>/dev/null
sudo rmmod whdriver-4v00.ko >/dev/null 2>/dev/null

# Load the new driver
sudo insmod whdriver-4v00.ko
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "--- Failed to load WinterHill Driver -----"
  echo "------------------------------------------"
  echo UPDATE Failed to load the WinterHill Driver >> /home/pi/winterhill/whlog.txt
  exit
fi

cat /proc/modules | grep -q 'whdriver_4v00'
if [ $? != 0 ]; then
  echo "-----------------------------------------------------"
  echo "--- Failed to find new loaded WinterHill Driver -----"
  echo "-----------------------------------------------------"
  echo UPDATE Failed to find the new loaded WinterHill Driver >> /home/pi/winterhill/whlog.txt
  exit
else
  echo
  echo "------------------------------------------------"
  echo "--- Successfully loaded  WinterHill Driver -----"
  echo "------------------------------------------------"
  echo UPDATE Successfully loaded  WinterHill Driver >> /home/pi/winterhill/whlog.txt
  echo
fi
cd /home/pi

echo "----------------------------------------------------"
echo "---- Set up to load the new spi driver at boot -----"
echo "----------------------------------------------------"
echo

if [ -f "/etc/rc.local" ]; then
  sudo sed -i "/^exit 0/c\cd /home/pi/winterhill/whsource-4v00/whdriver-4v00 || exit 1\nmake clean >/dev/null 2>&1\nmake\n[ -f whdriver-4v00.ko ] || exit 1\ninsmod whdriver-4v00.ko\nexit 0" /etc/rc.local
else
  sudo tee /etc/rc.local > /dev/null  << EOL
#!/bin/sh -e
cd /home/pi/winterhill/whsource-4v00/whdriver-4v00 || exit 1
make clean >/dev/null 2>&1
make
[ -f whdriver-4v00.ko ] || exit 1
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
  echo UPDATE Failed to build the WinterHill Application >> /home/pi/winterhill/whlog.txt
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
  echo UPDATE Failed to build the PIC Programmer >> /home/pi/winterhill/whlog.txt
  exit
fi
cp whpicprog-4v00 /home/pi/winterhill/PIC-4v00/whpicprog-4v00
cd /home/pi

# Any desktop shortcuts needing replacement will need deleting here

# rm /home/pi/Desktop/WH_Local
# rm /home/pi/Desktop/WH_Anyhub
# rm /home/pi/Desktop/WH_Anywhere
# rm /home/pi/Desktop/WH_Multihub
# rm /home/pi/Desktop/PIC_Prog

#echo "------------------------------------------------"
#echo "---- Copy the new shortcuts to the desktop -----"
#echo "------------------------------------------------"
#echo

#cp /home/pi/winterhill/configs/WH_Local     /home/pi/Desktop/WH_Local
#cp /home/pi/winterhill/configs/WH_Anyhub    /home/pi/Desktop/WH_Anyhub
#cp /home/pi/winterhill/configs/WH_Anywhere  /home/pi/Desktop/WH_Anywhere
#cp /home/pi/winterhill/configs/WH_Multihub  /home/pi/Desktop/WH_Multihub
#cp /home/pi/winterhill/configs/PIC_Prog     /home/pi/Desktop/PIC_Prog

# Note previous version number
cp -f -r "$PATHUBACKUP"/prev_installed_version.txt /home/pi/winterhill//prev_installed_version.txt 

# Restore the user .ini file
cp -f -r "$PATHUBACKUP"/winterhill.ini "$PATHINI"/winterhill.ini

# Update the version number
cp -f -r /home/pi/winterhill/latest_version.txt /home/pi/winterhill/installed_version.txt

# Save (overwrite) the git source used
echo "${GIT_SRC}" > /home/pi/${GIT_SRC_FILE}

echo "--------------------"
echo "---- Rebooting -----"
echo "--------------------"
echo UPDATE Reached the end of the update script >> /home/pi/winterhill/whlog.txt

sleep 1
# Turn off swap to prevent reboot hang
sudo swapoff -a
sudo shutdown -r now  # Seems to be more reliable than reboot

exit
