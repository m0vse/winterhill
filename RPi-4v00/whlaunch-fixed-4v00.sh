#!/bin/bash

whlaunch-fixed-4v00.sh

# sends the TS to a fixed address
# no VLC windows are started on the RPi
# the final zero is the interface IP address which should be set if the RPi has more than one network interface

cd /home/pi/winterhill/RPi-4v00
./winterhill-fixed-4v00.sh 192.168.77.237 9900 0

