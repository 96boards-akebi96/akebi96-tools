MKIMAGE=mkimage
.PHONY: all clean

all: recovery.scr

recovery.scr:	recovery.txt
	$(MKIMAGE) -A arm -O u-boot -T script -C none -n "recovery" -a 0x8d000000 -d $< $@

clean:
	rm -f recovery.scr
