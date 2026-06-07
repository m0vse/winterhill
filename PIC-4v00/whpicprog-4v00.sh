#!/bin/bash

cd /home/pi/winterhill/whsource-4v00/whpicprog-4v00

sudo ./whpicprog-4v00 --check
PIC_RETURN=$?

if [ "$PIC_RETURN" == 34 ]; then
  echo Both PICs Programmed with software 4v00
  echo No Action Required
  echo
  read -n 1 -s -r -p "Press any key to continue"
  exit
fi

if [ "$PIC_RETURN" == 18 ]; then
  echo PIC A Programmed with software 4v00
  echo PIC B not fitted
  echo No Action Required
  echo
  read -n 1 -s -r -p "Press any key to continue"
  exit
fi

echo Attempting to Program both PICs

sudo ./whpicprog-4v00 whpic-4v00.hex

echo Complete
echo
read -n 1 -s -r -p "Press any key to continue"
exit

