ERL_ROOT = /usr/lib/erlang
CFLAGS=-pthread -I$(ERL_ROOT)/include -Ic_src
LDFLAGS=-L$(ERL_ROOT)/lib
LDLIBS=-lerl_interface -lei

SOURCE_FILES = c_src/roomba_port.c c_src/serial.c
OBJECT_FILES = $(SOURCE_FILES:.c=.o)

priv_dir/roomba_port: clean priv_dir $(OBJECT_FILES)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJECT_FILES) $(LDLIBS)

priv_dir:
	mkdir -p priv_dir

clean:
	rm -f priv_dir/roomba_port $(OBJECT_FILES) $(BEAM_FILES)
