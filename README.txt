Code used on my Proxxon MF70 + MakerBot MK7 CNC-mill based repstrap.

Main areas of interest:

rtl/vp2 - verilog RTL sources for FPGA part of controller. It has embedded
          6502 cpu for control tasks and hardware DDA and acceleration 
	  blocks. SD-card interface and end-stops present too.

soft/vp2_cli - software running on embedded processor. It has commandline 
          interface on serial port and can print .s3g files from SD.

emu/parse.py - host-based g-code interpreter, path planning, synchronized
          acceleration profiles and output to makerbot compatible .s3g files.

Some photos from this project:
  https://picasaweb.google.com/114257244810512271993/3dMf70

New printer using this electronics (in progress):
  https://picasaweb.google.com/114257244810512271993/Monsterap
