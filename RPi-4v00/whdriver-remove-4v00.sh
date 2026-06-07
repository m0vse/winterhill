#!/bin/bash

echo "Removing the whdriver-4v00.ko WinterHill device driver module from the kernel"
sudo rmmod whdriver-4v00.ko
sleep 5s
