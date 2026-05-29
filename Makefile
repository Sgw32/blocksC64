TARGET = c64
OUT = minecraft_c64.prg
SRC = src/main.c

CC = cl65
CFLAGS = -t $(TARGET) -Oirs --static-locals

all: $(OUT)

$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $(OUT) $(SRC)

run: $(OUT)
	x64sc $(OUT)

clean:
	del $(OUT)
