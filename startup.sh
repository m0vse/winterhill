#!/bin/bash

# Used to check the PICS are programmed and set the startup behaviour on boot

#### PIC Programming ####

# Check whether programmed and, if not, program them

cd /home/pi/winterhill/whsource-4v00/whpicprog-4v00
sudo ./whpicprog-4v00 --check >/dev/null 2>/dev/null
PIC_RETURN=$?
if [ "$PIC_RETURN" != 34 ] && [ "$PIC_RETURN" != 18 ]; then       # Not programmed correctly
  echo Attempting to Program both PICs
  sudo ./whpicprog-4v00 whpic-4v00.hex
  echo Complete, starting WinterHill
  echo
  sleep 1
fi

cd /home/pi

#### Now Start WinterHill as set in the winterhill.ini file ####

#### Root needs to be granted access for xdotool to work under su
xhost +si:localuser:root

grep -q 'BOOT = local' winterhill/winterhill.ini
if [ $? == 0 ]; then
  lxterminal -t "whlaunch-local-4v00.sh" --working-directory=/home/pi/winterhill/RPi-4v00/ -e ./whlaunch-local-4v00.sh
else
  grep -q 'BOOT = anyhub' winterhill/winterhill.ini
  if [ $? == 0 ]; then
    lxterminal -t "whlaunch-anyhub-4v00.sh" --working-directory=/home/pi/winterhill/RPi-4v00/ -e ./whlaunch-anyhub-4v00.sh
  else
    grep -q 'BOOT = anywhere' winterhill/winterhill.ini
    if [ $? == 0 ]; then
      lxterminal -t "whlaunch-anywhere-4v00.sh" --working-directory=/home/pi/winterhill/RPi-4v00/ -e ./whlaunch-anywhere-4v00.sh
    else
      grep -q 'BOOT = multihub' winterhill/winterhill.ini
      if [ $? == 0 ]; then
        lxterminal -t "whlaunch-multihub-4v00.sh" --working-directory=/home/pi/winterhill/RPi-4v00/ -e ./whlaunch-multihub-4v00.sh
      else
        grep -q 'BOOT = fixed' winterhill/winterhill.ini
        if [ $? == 0 ]; then
          lxterminal -t "whlaunch-fixed-4v00.sh" --working-directory=/home/pi/winterhill/RPi-4v00/ -e ./whlaunch-fixed-4v00.sh
        fi
      fi
    fi
  fi
fi

exit

