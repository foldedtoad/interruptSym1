#
# Remember to set CC65_HOME in your .bashrc file.
#   example:  export CC65_HOME="~/sym1/cc65"
#
AS = $(CC65_HOME)/bin/ca65
CC = $(CC65_HOME)/bin/cc65
CL = $(CC65_HOME)/bin/cl65
LD = $(CC65_HOME)/bin/ld65
DA = $(CC65_HOME)/bin/da65

NULLDEV = /dev/null
DEL = $(RM)
RMDIR = $(RM) -r

ASM_SOURCES = interrupts.s
ASM_OBJECTS = $(ASM_SOURCES:.s=.o)

OBJECTS = $(ASM_OBJECTS)

LIBS = --lib sym1.lib

TARGET  = interrupts.bin

.PHONY:	all clean flatten

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) -t sym1 --mapfile $(basename $(TARGET)).map $(OBJECTS) -o $@  

%.o: %.c
	$(CC) -t sym1 -O $< 
	$(AS) --cpu 6502 -l $(basename $<).lst $(basename $<).s -o $@ 
	@$(DEL) $(basename $<).s

%.o: %.s	
	$(AS) --cpu 6502 -l $(basename $<).lst $< -o $@ 

clean:
	$(DEL) -rf *.o *.bin *.lst *.out *.map

flatten:
	hexdump -v -e '1/1 "%02x\n"' $(TARGET) > $(basename $(TARGET)).out

