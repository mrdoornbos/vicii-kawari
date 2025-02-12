# Spartan6

    Use build.sh in rev_4H or rev_4S dirs.
    Will produce two build .bit files. One for active (multiboot) and another for fallback (golden)
    Set Makefile params at top to build flash image for what you want.

## Large (BETA Spartan6)

golden             | multiboot
-------------------|---------------------
FPGA=spartan6_x16  | FPGA=spartan6_x16
START_ADDRESS=0    | START_ADDRESS=512000
IMAGE_SIZE=512000  | IMAGE_SIZE=512000
TYPE=golden        | TYPE=multiboot
VARIANT=MAIN       | VARIANT=MAIN
PAGE_SIZE=16384    | PAGE_SIZE=16384

## Large (Final Spartan6)

golden             | multiboot
-------------------|---------------------
FPGA=spartan6_x16  | FPGA=spartan6_x16
START_ADDRESS=0    | START_ADDRESS=512000
IMAGE_SIZE=512000  | IMAGE_SIZE=512000
TYPE=golden        | TYPE=multiboot
VARIANT=MAINLD     | VARIANT=MAINLD
PAGE_SIZE=16384    | PAGE_SIZE=16384

# Efinix

    Build multi.hex using programmer's 'combine multiple images' option

## Large (board rev 1.2)

golden             | multiboot
-------------------|---------------------
FPGA=efinix_t20    | FPGA=efinix_t20
START_ADDRESS=0    | START_ADDRESS=659456
IMAGE_SIZE=659465  | IMAGE_SIZE=659456
TYPE=golden        | TYPE=multiboot
VARIANT=MDVILG or MRGBLG | VARIANT=MDVILG or MRGBLG
PAGE_SIZE=4096     | PAGE_SIZE=4096

## Mini (board rev 1.3/rev 1.4)

golden             | multiboot
-------------------|---------------------
FPGA=efinix_t20    | FPGA=efinix_t20
START_ADDRESS=0    | START_ADDRESS=659456
IMAGE_SIZE=659465  | IMAGE_SIZE=659456
TYPE=golden        | TYPE=multiboot
VARIANT=MAINLH or DOTCLH     | VARIANT=MAINLH or DOTCLH
PAGE_SIZE=4096     | PAGE_SIZE=4096

## POV (TBD)

Never produced.

## Direct SPI Programming

This will program both multiboot and golden images directly to the flash via SPI.

    openFPGALoader -b xyloni_spi -c digilent_ad /home/rrossi/multi.hex  --verify

## Making a Flash Disk

For Trion boards, you must first create a multi.hex file using the programmer utilty. Slots 0 and 2 (1st and 3rd) are set to the vicii.hex file.

Before making a flash disk, you must create the bit files using the utility script for efinix devices.

    ./efinix_prep.sh multi.hex golden MAINLH 1.4
    ./efinix_prep.sh multi.hex multiboot MAINLH 1.5

NOTE: In either case of golden/multiboot, use the same .hex file. The Makefile will extract the correct image out of the .bin
