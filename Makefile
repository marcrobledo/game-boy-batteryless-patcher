# Makefile specific
.PHONY: clean all
.SECONDEXPANSION:

ifneq ($(wildcard rgbds/.*),)
RGBDS = rgbds/
endif

RGBDS ?=
RGBASM  ?= $(RGBDS)rgbasm
RGBFIX  ?= $(RGBDS)rgbfix
RGBGFX  ?= $(RGBDS)rgbgfx
RGBLINK ?= $(RGBDS)rgblink

# Build tools when building the rom.
# This has to happen before the rules are processed, since that's when scan_includes is run.
ifeq (,$(filter clean tools,$(MAKECMDGOALS)))
$(info $(shell $(MAKE) -C tools))
endif


# get targets - every roms/* subdir with a input.gbc present
# targets = $(patsubst %/, %, $(subst roms/, , $(dir $(wildcard roms/*/input.gbc))))
# targets = $(shell for dir in roms/*/*/settings.asm; do echo $$dir | cut -d "/" -f 3;done)
targets = $(shell for dir in roms/*/*/settings.asm; do [ -e "$$(dirname $$dir)/$$(echo $$dir | cut -d '/' -f 3).gbc" ] && echo $$(dirname $$dir);done)

roms_batteryless = $(foreach targetdir, ${targets}, \
$(shell grep -o "^IF DEF(_BATTERYLESS)" ${targetdir}/settings.asm >/dev/null && echo "${targetdir}/$(shell echo ${targetdir} | cut -d '/' -f 3 )_batteryless.gbc"))

roms = $(roms_batteryless)

ifeq (,$(shell command -v flips))
all: roms_batteryless
else
all: patches_batteryless
endif

patches_batteryless: $(roms_batteryless:.gbc=.bps)

roms_batteryless: $(roms_batteryless)

tools:
	$(MAKE) -C tools/

# Create a sym/map for debug purposes if `make` run with `DEBUG=1`
ifeq ($(DEBUG),1)
RGBLINKFLAGS += -n $(@:.gbc=.sym) -m $(@:.gbc=.map)
RGBASMFLAGS = -E
endif


$(roms_batteryless:.gbc=.o): RGBASMFLAGS += -D_BATTERYLESS


$(roms:.gbc=.bps): $$(patsubst %.bps,%.gbc,$$@)
	flips --create --bps $(@D)/$(shell echo $(@D) | cut -d '/' -f 3).gbc $< $@

$(roms): $$(patsubst %.gbc,%.o,$$@)
	$(RGBLINK) $(RGBLINKFLAGS) -O $(@D)/$(shell echo $(@D) | cut -d '/' -f 3).gbc -o $@ $<
	$(RGBFIX) -p0 -v $@

$(roms:.gbc=.o): $$(@D)/settings.asm src/main.asm $$(shell tools/scan_includes $$(@D)/settings.asm) $$(shell tools/scan_includes src/main.asm)
	$(RGBASM) $(RGBASMFLAGS) -o $@ --preinclude $< src/main.asm


clean:
	$(RM) $(roms) \
	$(roms:.gbc=.bps) \
	$(roms:.gbc=.sym) \
	$(roms:.gbc=.map) \
	$(roms:.gbc=.o)
	$(MAKE) clean -C tools/

