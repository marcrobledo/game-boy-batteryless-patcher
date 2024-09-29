# Makefile specific
.PHONY: clean all patches_batteryless
.SECONDEXPANSION:

ifneq ($(wildcard rgbds/.*),)
RGBDS = rgbds/
endif

RGBDS ?=
RGBASM  ?= $(RGBDS)rgbasm
RGBFIX  ?= $(RGBDS)rgbfix
RGBGFX  ?= $(RGBDS)rgbgfx
RGBLINK ?= $(RGBDS)rgblink

# get targets - every roms/* subdir with a input.gbc present
targets = $(patsubst %/, %, $(subst roms/, , $(dir $(wildcard roms/*/input.gbc))))

roms_batteryless = $(foreach targetdir, ${targets}, \
$(shell grep -o "^IF DEF(_BATTERYLESS)" roms/${targetdir}/settings.asm >/dev/null && echo "roms/${targetdir}/${targetdir}_batteryless.gbc"))

roms = $(roms_batteryless)

all: patches_batteryless

patches_batteryless: $(roms_batteryless:.gbc=.bps)


# Create a sym/map for debug purposes if `make` run with `DEBUG=1`
ifeq ($(DEBUG),1)
RGBLINKFLAGS += -n $(@:.gbc=.sym) -m $(@:.gbc=.map)
RGBASMFLAGS = -E
endif


$(roms_batteryless:.gbc=.o): RGBASMFLAGS += -D_BATTERYLESS


$(roms:.gbc=.bps): $$(patsubst %.bps,%.gbc,$$@)
	flips --create --bps $(@D)/input.gbc $< $@

$(roms): $$(patsubst %.gbc,%.o,$$@)
	$(RGBLINK) $(RGBLINKFLAGS) -O $(@D)/input.gbc -o $@ $<
	$(RGBFIX) -p0 -v $@
	$(RM) $<

$(roms:.gbc=.o): $$(@D)/settings.asm src/main.asm
	$(RGBASM) $(RGBASMFLAGS) -o $@ --preinclude $< src/main.asm


clean:
	$(RM) $(roms) \
	$(roms:.gbc=.bps) \
	$(roms:.gbc=.sym) \
	$(roms:.gbc=.map) \
	$(roms:.gbc=.o)

