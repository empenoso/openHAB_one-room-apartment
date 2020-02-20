#!/bin/sh
#
# For yuoras, yuoras@meta.ua ICQ: 377599750
# electro_counter200.sh
# 2017-05-15 version 1
# kohan pavel e-mail: hidersoft@gmail.com Skype: kpp77strannik
#
#
# version 1
#

#main_path="/opt/root/200"
main_path="."
c_mysql=/opt/bin/mysql
DB_HOST=192.168.100.15
DB_USER=merk
DB_PASS=
DB_BASE=merkury


#query="insert into mer200(date, t1, t2, t3, t4, summa, volt, power, prim) values (now(), T1, T2, T3, T4, SUMMA, VOLT, POWER, PRIM)"
query="insert into mer200(date, t1, t2, t3, t4, summa, volt, power) values (now(), T1, T2, T3, T4, SUMMA, VOLT, POWER)"

elsum=`sh $main_path/electro_counter.sh kwatt_summ2 | grep -Ei ^[a-z,0-9]{1,8}=[0-9,\.]{1,}$`

eval $elsum

power=`sh $main_path/electro_counter.sh avp | grep -Ei ^[a-z,0-9]{1,8}=[0-9,\.]{1,}$`

eval $power

#Last_on=`$main_path/electro_counter.sh last_on`

#eval $Last_on

#f_sql_scr="`echo $query | sed 's/T1/'$T1'/; s/T2/'$T2'/; s/T3/'$T3'/; s/T4/'$T4'/; s/SUMMA/'$SUM'/; s/VOLT/'$VOLT'/; s/POWER/'$WATT'/; s
f_sql_scr="`echo $query | sed 's/T1/'$T1'/; s/T2/'$T2'/; s/T3/'$T3'/; s/T4/'$T4'/; s/SUMMA/'$SUM'/; s/VOLT/'$VOLT'/; s/POWER/'$WATT'/'`"

$c_mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_BASE -vv -e "${f_sql_scr};"

