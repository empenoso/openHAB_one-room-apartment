#!/bin/sh
#
# Data read from electric meter through cat
# 2016-04-18
# kohan pavel e-mail: hidersoft@gmail.com Skype: kpp77strannik
#
#
# version 1
#
# DONATE Поблагодарить
# Всем, кто считает проделанную работу полезной,
# есть возможность поддержать автора.
# Карта ПриватБанка: 6762 4626 8013 0082.
# Всем заранее спасибо.
#



# каталог скрипта
BASE_DIR="$(dirname "$0")/"
BASE_NAME="$(basename "$0")"

#. ${BASE_DIR}lib_funct.sh

trap_x()
{
  case "$1" in
      0) ;; #echo_ex "Normal end ${BASE_NAME}." ;;
      2) ;; #echo "Abort(Ctrl+C) ${BASE_NAME}!"  ;;
      *) ;; #echo "Trap code(${1}) unknown ${BASE_NAME}!" ;;
  esac

  if kill -0 ${outport} 2>/dev/null; then
    kill ${outport}
    wait ${outport} >/dev/null 2>&1
  fi
  return 10
}

trap "trap_x 0" 0
trap "trap_x 2" 2

 cm=${1}
 lenc=${2}

# [ "${ECHOCOMMAND}" = "YES" ] && {
#     cm_len=`expr ${#cm} \/ 5`
#     lenc=`expr $cm_len + $cm_len`
# }

 [ $DEBUG -gt 1 ] && echo "METHOD_COMMUNITY=CAT len=$lenc" >&2

 cat ${DEVICE} > "${TMPFL}" &
 [ -z "$!" ] || outport=$!

 HexToChar "${cm}" > ${DEVICE}

 #HexToChar "${cm}" > tesst

 [ "${DEV_EMULATOR}" = "YES" ] && Dev_Enulator "${cm}" "${TMPFL}"

 #set -x
 ii=0
 while [ `GetFileSize "${TMPFL}"` -lt $lenc ]
 do
   ii=$(($ii + 1))
   [ $ii -gt ${WAITTICK} ] && break
   SleepEx ${WAIT_TIME}
   # sleep .050 > /dev/null 2>&1
   # [ $? -eq 0 ] || ping -c2 -i.050 127.0.0.1 >/dev/null 2>&1
 done
 #set +x

