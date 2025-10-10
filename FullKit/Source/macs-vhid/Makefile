CXX=clang++
CXXFLAGS=-std=c++17 -O2 -Wall -Wextra
LDFLAGS=
BIN_DIR=/usr/local/bin
LIBEXEC_DIR=/usr/local/libexec

RELAY_SRC=relay.cpp
RELAY_BIN=relay

MACSCOPE_SRC=macscope-vhid.cpp
MACSCOPE_BIN=macscope-vhid

.PHONY: all clean install

all: $(RELAY_BIN) $(MACSCOPE_BIN)

$(RELAY_BIN): $(RELAY_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(MACSCOPE_BIN): $(MACSCOPE_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(RELAY_BIN) $(MACSCOPE_BIN)

install: all
	install -d $(BIN_DIR) $(LIBEXEC_DIR)
	install -m 755 $(RELAY_BIN) $(BIN_DIR)/
	install -m 755 $(MACSCOPE_BIN) $(LIBEXEC_DIR)/
