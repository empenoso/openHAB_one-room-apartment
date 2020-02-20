#!/bin/sh
#
# For yuoras, yuoras@meta.ua ICQ: 377599750
# electro_counter230.sh
# 2017-04-26 version 1
# kohan pavel e-mail: hidersoft@gmail.com Skype: kpp77strannik
#
#
# version 1
#

all="`/bin/sh ./electro_counter.sh kwatthour:all_time:T_ALL`"
T1="`sh ./electro_counter.sh kwatthour:all_time:T1`"
T2="`sh ./electro_counter.sh kwatthour:all_time:T2`"
T3="`sh ./electro_counter.sh kwatthour:all_time:T3`"
T4="`sh ./electro_counter.sh kwatthour:all_time:T4`"

n=1
for i in 1 2 3 4
do
  for j in 0 1 2 3 4
  do
    if [ $j -eq 0 ]; then
       sn="SM"
       sm="$all"
    else 
       sn=T$j
       eval sm="\$$sn"
    fi
    echo "$sm" | sed -n $n'{; s/\([AR]\)p/\1+/; s/\([AR]\)o/\1-/; s/\(..\)([^)]*) = \(.*\)/'$sn' \1 = \2/p; }'
  done
  [ $i -eq 4 ] || {
     echo
     n=`expr $n + 1`
  }
done