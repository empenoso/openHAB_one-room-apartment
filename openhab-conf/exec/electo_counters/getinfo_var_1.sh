#!/bin/sh
#
# Data read from electric meter through dd
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


 BASE_DIR="$(dirname "$0")/"
 #. ${BASE_DIR}lib_funct.sh

 cm=${1}
 lenc=${2}

trap_x()
{
  case "$1" in
    0) ;; #echo_ex "Normal end ${BASE_NAME}." ;;
    2) ;; #echo "Abort(Ctrl+C) ${BASE_NAME}!"  ;;
    *) ;; #echo "Trap code(${1}) unknown ${BASE_NAME}!" ;;
  esac

  if kill -0 ${outport} 2>/dev/null; then
      #echo "Need Kill $outport" >&2
      kill $outport
      wait ${outport} >/dev/null 2>&1
  fi

  if kill -0 ${inport} 2>/dev/null; then
      kill $inport
      wait ${inport} >/dev/null 2>&1
  fi

  return 10
}

trap "trap_x 0" 0
trap "trap_x 2" 2



 [ $DEBUG -gt 1 ] && echo "METHOD_COMMUNITY=DD len=$lenc" >&2

 inport=0
 outport=0

# [ "${ECHOCOMMAND}" = "YES" ] && {
#     cm_len=`expr ${#cm} \/ 5`
#     lenc=`expr $cm_len + $cm_len`
# }

 len_block=$lenc
 #len_block=`echo $len | rev | cut -d"," -f1 | rev`

 HexToChar "${cm}" > ${DEVICE} &
 [ -z "$!" ] || inport=$!
 ( dd if=${DEVICE} of="${TMPFL}" count=$len_block obs=1 ibs=1 > /dev/null 2>&1 ) &
 [ -z "$!" ] || outport=$!

 [ "${DEV_EMULATOR}" = "YES" ] && Dev_Enulator "${cm}" "${TMPFL}"

 ii=0
 while kill -0 ${outport} 2>/dev/null
 do
   ii=`expr $ii + 1`
   [ $ii -gt ${WAITTICK} ] && break
   SleepEx ${WAIT_TIME}
   # sleep .050 > /dev/null 2>&1
   # [ $? -eq 0 ] || ping -c2 -i.050 127.0.0.1 >/dev/null 2>&1
 done



