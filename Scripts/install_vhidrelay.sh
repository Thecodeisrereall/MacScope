#!/bin/bash
set -e
make -C ../Source/cli/macs-vhid
sudo install -m755 ../Source/cli/macs-vhid/relay /usr/local/libexec/macscope-vhid-relay
sudo install -m755 ../Source/cli/macs-vhid/macscope-vhid /usr/local/bin/macscope-vhid
