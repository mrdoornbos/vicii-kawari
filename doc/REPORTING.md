# Testing Firmware?

For those testing firmware (Thank you!), here are some some guidelines to avoid false positives:

1. Many games and demos are made for PAL systems only.  They will either not run at all on NTSC or show graphical glitches.  This is normal and happens on genuine VIC-II's as well. Since the Kawari can operate in either mode, you may lose track of which video standard you are running (especially over DVI where they look similar). If you find a glitch, please confirm the issue does not also occur using a genuine VIC-II in the same mode. If the issue happens using only the Kawari, then please report it.

2. GAL PLA replacement modules that use Lattice 25ns GALs are known to lock up the system on some games even with a real VIC-II (i.e. Ghostbusters, Fix it Felix Jr).  If you are using a PLA replacement, please try a genuine PLA if possible in the same machine to confirm it is not the PLA.  If the issue also happens with a genuine PLA, please report it.

3. A quick way to confirm whether a glitch is expected or not is to simply run the same game/demo on VICE emulator using x64sc.  You can start x64sc with -ntsc or -pal command line flags to match the system the game/demo is expecting.  If you see the same glitch, it is likely normal/expected.

4. Different KERNAL revisions clear the screen differently and this can make some games/demos appear to glitch on one system while run fine on another. An example is Higher Level (1992) by Lower Level. Another example is Galencia with a trainer screen that asks you to answer 4 Y/N questions.  On the earliest KERNAL revision, it appears the game has crashed because you get a black screen.  However, the trainer is just waiting for you to answer questions that are not visible. This is why comparing behavior with/without the Kawari on the same machine can be important.

5. Cartridges that use pin 6 (dot clock) of the cartridge port will often not work unless you use the motherboard clock setting. Keep that in mind when testing with specialty cartridges.

6. If you are using a KungFuFlash cartridge, make sure you are using a recent firmware build.  Older KFF firmwares did not handle NTSC timing very well and caused many glitches.  If you have been using a PAL system for a long time with a KFF and are now running NTSC mode, you should update the firmware to avoid issues.