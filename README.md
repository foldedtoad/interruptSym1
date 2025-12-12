# A Simple SYM-1 (6502) IRQ Initialization and Processing Demo

## Overview

Below is a photo an overview of the hardware setup for this demo.  
As can be seen, there is not much to it.
* SYM-1 Board with Monitor V1.1
* 0.1 microfarid capacitor
* 2K resistor
* 2.2K resistor
* Momentary switch (button)
* LED 5v
* Small protoboard

On the SYM-1 **AA-Connector**, the following lines were used  
* CA1 <--> "P"
* PA6 <--> "17"
* PA7 <--> "U"
* Vcc <--> "A"
* Vss <--> "1"
  
<img src="images/simple_hw_setup.jpg" title="simple hw setup"> 

## The Development and Testing Setup
All development and testing is on **Ubuntu 24.04 LTS**, and using the **CC65** toolchain.  
The terminal app, **minicom**, was used on the Ubuntu system to interact with the SYM-1.  
There are many guides and videos on the internet showing how to serially connect to the SYM-1 to a computer, so that won't be detailed here.

### Makefile Build
This project use the standard **make** supported by Ubuntu.  
Review the Makefile file and make adjustments to point to your CC65 installation.
```
#
# Remember to set CC65_HOME in your .bashrc file.
#   example:  export CC65_HOME="~/sym1/cc65"
#
AS = $(CC65_HOME)/bin/ca65
CC = $(CC65_HOME)/bin/cc65
CL = $(CC65_HOME)/bin/cl65
LD = $(CC65_HOME)/bin/ld65
DA = $(CC65_HOME)/bin/da65
```
  

## Example Run
```
.g 200
SYM-1 Interrupts Demo
```


Below is a screenshot of a logic analyzer capture, showing the results of 3 button press/release cycles.
Note that the LED is not toggled on the button press phase, but rather on the button release phase.  

<img src="images/SYM1_IRQ_demo.png" title="logic analyzer capture"> 
