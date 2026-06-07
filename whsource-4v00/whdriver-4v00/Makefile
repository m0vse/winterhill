# Makefile
obj-m += whdriver-4v00.o
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	dtc -@ -I dts -O dtb -o whdriver-4v00.dtbo whdriver-4v00-overlay.dts

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f whdriver-4v00.dtbo
