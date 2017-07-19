MIX 	:= mix
CFLAGS 	:= -g -O3 -ansi -pedantic -Wall -Wextra

ERLANG_PATH := $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS 		+= -I$(ERLANG_PATH)

SRC	:= c_src/xattr.c \
	   c_src/util.c \
	   c_src/impl_xattr.c

OBJ	:= $(patsubst c_src/%.c,priv/%.o,$(SRC))

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

.PHONY: all clean re

all: priv/elixir_xattr.so

priv/elixir_xattr.so: $(OBJ)
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

priv/%.o: c_src/%.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

clean:
	$(MIX) clean
	$(RM) priv/elixir_xattr.so $(OBJ)

re: clean all
