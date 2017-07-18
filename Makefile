MIX 	:= mix
CFLAGS 	:= -g -O3 -ansi -pedantic -Wall -Wextra

ERLANG_PATH := $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS 		+= -I$(ERLANG_PATH)

SRC	:= c_src/xattr.c c_src/xattr_impl.h c_src/util.c c_src/impl/linux.c
OBJ	:= $(SRC:.c=.o)

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

.PHONY: all clean

all:
	$(MIX) compile

priv/elixir_xattr.so: $(OBJ)
	mkdir -p priv/
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

clean:
	$(MIX) clean
	$(RM) -rf priv/
	$(RM) c_src/*.o
	$(RM) c_src/**/*.o
