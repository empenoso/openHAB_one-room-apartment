#!/bin/bash
sh /etc/openhab2/exec/electo_counters/electro_counter.sh amper 2>&1 | sed -n 's#^Amper=:[^0-9]*\([0-9.]*\)$#\1#p';

#bash /etc/openhab2/exec/amper.sh