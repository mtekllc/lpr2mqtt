CC = gcc
CFLAGS = -Wall -O2
LDFLAGS = -lmosquitto
SRC = mqtt-ppd.c
OUT = mqtt-ppd

# default target
all: $(OUT)

# compile the C program
$(OUT): $(SRC)
	$(CC) $(SRC) -o $(OUT) $(LDFLAGS) $(CFLAGS)

# clean up compiled files
clean:
	rm -f $(OUT)

# install target (optional, requires superuser)
install: $(OUT)
	install -D -m 755 $(OUT) /usr/bin/

.PHONY: all clean install
