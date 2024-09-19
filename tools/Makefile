.PHONY: all clean

CC := gcc
CFLAGS := -O3 -flto -std=c11 -Wall -Wextra -pedantic

tools := scan_includes

all: $(tools)
	@:

clean:
	$(RM) $(tools)

scan_includes: common.h

%: %.c
	$(CC) $(CFLAGS) -o $@ $<
