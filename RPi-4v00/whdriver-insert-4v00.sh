#!/bin/bash

echo "Inserting the whdriver-4v00.ko WinterHill device driver module into the kernel"
echo "ls /dev   will show the device"
sudo insmod whdriver-4v00.ko
ls -l /dev/whdriver-4v00
sleep 5s
