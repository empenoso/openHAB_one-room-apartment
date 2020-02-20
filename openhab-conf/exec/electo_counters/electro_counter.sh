#!/bin/sh
#
# Data read from electric meter
# electro_counter.sh main
# 2015-07-07 version 1
# 2016-04-09 - 2016-05-16 version 2
# 2017-04-26 version 2.1
# 2018-01-29 version 2.2
# kohan pavel e-mail: hidersoft@gmail.com Skype: kpp77strannik
#
#
# version 2.2
#
# parameters: COMMAND COUNTER_SN COUNTER_CONFIG_FILE
#    COMMAND
#    COUNTER_SN - counter serial number
#    COUNTER_CONFIG_FILE - counter configuration file
#
# DONATE Поблагодарить
# Всем, кто считает проделанную работу полезной,
# есть возможность поддержать автора.
# Карта ПриватБанка: 6762 4626 8013 0082.
# Всем заранее спасибо.
#

#set -x

canceled=1

# каталог скрипта
BASE_DIR="$(dirname "$0")/"

. ${BASE_DIR}lib_funct.sh
. ${BASE_DIR}electro_counter.conf

# $1 - command
# $2 - COUNTER_SN
# $3 - COUNTER_TYPE

Fatalerror()
{
  [ "$1" != 'bash' ] && exit ${2}
}

SetDeviceParams()
{
  if [ $OS = 'FREEBSD' ]; then
      stty -f ${DEVICE}.init $DEV_BAND $DEV_FLAGS
      return $?
  else
      stty -F ${DEVICE} $DEV_FLAGS_LINUX
      return $?
  fi
}


reciver()
{
  cm=${1}
  lenc=${2}

  len="${MIN_BLOCK_SIZE},$lenc"

  #echo "cm=$cm	lenc=$lenc	len=$len" >&2

  cm_len=0
  [ "${ECHOCOMMAND}" = "YES" ] && {
      cm_len=`expr ${#cm} \/ 5`
      lenc=`expr $cm_len + $lenc`
  }

  case ${METHOD_COMMUNITY} in
   "DD") . ${BASE_DIR}getinfo_var_1.sh "${cm}" ${lenc} ;;
   "CAT"|*) . ${BASE_DIR}getinfo_var_2.sh "${cm}" ${lenc} ;;
  esac
 
  #echo -n "0" >> "${TMPFL}"
  #echo "$anw" > 2
  filesi=`GetFileSize "${TMPFL}"`

  #echo "${tmpfl} $filesi $len" >&2

  if [ $filesi -ne 0 ]; then
       anw="`hexdump -ve '1/1 "x%.2X"' "${TMPFL}"`"
       #anw="`echo "${anw}" | hexdump -ve '1/1 "x%.2X"'`"
       [ $cm_len -gt 0 ] && {
           ech_len=`expr $cm_len \* 3`
           anw_start=`expr $ech_len + 1`
           anw_len=${#anw}
           ech=`echo $anw | cut -c1-${ech_len}`
           anw=`echo $anw | cut -c${anw_start}-${anw_len}`

           filesi=`expr $filesi - $cm_len`
           echo "ech=$ech	anw=$anw	filesi=$filesi	len=$len" >&2
       }
  else
       anw=''
  fi

  echo "$anw	$filesi"

  #echo "anw=$anw	filesi=$filesi	len=$len" >&2

  if [ -n "`echo $len | grep -E '(^|,)'${filesi}'(,|$)'`" ]; then
      return 0
  else
      if [ $filesi -eq 0 ]; then
          return 1
      else
          case `expr $lenc - $filesi` in
            1) return 3 ;;
            2) return 4 ;;
            *) return 2 ;;
          esac
          #return 2
      fi
  fi
}

test_reciver()
{
  good=1
  local answer
  local result
  for i in `GetSequence ${TRY_COUNT_TEST}`
  do
    answer="`reciver ${1} ${2}`"
    result=$?
#    sleep .080 > /dev/null 2>&1
    [ $DEBUG -gt 0 ] && echo "TEST_ANSWER($i) "$answer
    [ $result -eq 0 ] && {
       good=0
       break
    }
    #[ $DEBUG -gt 0 ] && echo $answer
  done

  return $good
}


trap_x()
{
  case "$1" in
    0) ;; #echo_ex "Normal end ${BASE_NAME}." ;;
    2) echo "Abort(Ctrl+C) ${BASE_NAME}!"  ;;
    *) echo "Trap code(${1}) unknown ${BASE_NAME}!" ;;
  esac

  if [ $canceled -eq 0 ] && [ -f "${PID_DIR}/${PID_NAME}.pid" ]; then
      rm -f "${PID_DIR}/${PID_NAME}.pid"
  fi
  rm "${TMPPID}"

  case "$1" in
    0) ;;
    2) exit 254 ;;
    *) exit 253 ;;
  esac
}


trap "trap_x 0" 0
trap "trap_x 2" 2


 # define COUNTER_CONFIG_FILE
 [ -n "${3}" ] && {
    COUNTER_CONFIG_FILE="${3}"
    if [ -r "${COUNTER_CONFIG_FILE}" ]; then
         . "${COUNTER_CONFIG_FILE}"
    else
       echo "Error! Not exists configuration file  \"${COUNTER_CONFIG_FILE}\"!"
       Fatalerror "$0" 1
       #return 1
    fi
 }


 # define COUNTER_TYPE
 #[ -n "${3}" ] && COUNTER_TYPE=${3}
 [ -z "${COUNTER_TYPE}" ] && {
    echo "Error! Not defind COUNTER TYPE!"
    Fatalerror "$0" 1
    return 1
 }
 if [ -r "${BASE_DIR}${COUNTER_TYPE}" ]; then
    . ${BASE_DIR}${COUNTER_TYPE}
 else
    echo "Error! Not found file for COUNTER TYPE \"${COUNTER_TYPE}\"!"
    Fatalerror "$0" 2
    return 2
 fi
 [ -z "${DEVICE}" ] && {
    echo "Error! Not define device!"
    Fatalerror "$0" 3
    return 3
 }
 [ -r "${DEVICE}" ] || {
    echo "Error! Not exists device \"${DEVICE}\"!"
    Fatalerror "$0" 4
    return 4
 }


 # define OS if auto
 [ "${OS}" = "FREEBSD" -o "${OS}" = "LINUX" ] || OS=`uname | tr "[a-z]" "[A-Z]"`


 # исключить одновременную работу двух и более копий скрипта для одного и того же порта(DEVICE)
 PID_NAME="${PID_NAME}`echo "${DEVICE}" | tr -s "/" "-"`"
 #echo ${PID_NAME} >&2
 #
 # PID_TIMEOUT
 # PID_DIR
 # PID_NAME
 # PID_TIMEWAIT
 TMPPID="${PID_DIR}/${PID_NAME}.$$"
 echo $$ > "${TMPPID}"
 timeout=0
 while [ $timeout -lt ${PID_TIMEOUT} ]
 do
    ln -s "${TMPPID}" "${PID_DIR}/${PID_NAME}.pid" 2> /dev/null
    [ $? -eq 0 ] && {
       canceled=0
       break
    }
    PID="`cat "${PID_DIR}/${PID_NAME}.pid"`"
    if ! kill -0 $PID 2>/dev/null; then
        rm -f "${PID_DIR}/${PID_NAME}.pid"
    fi
    timeout=$((timeout + ${PID_TIMEWAIT}))
    sleep ${PID_TIMEWAIT}
 done
 [ $canceled -ne 0 ] && {
    echo "Timeout ${PID_TIMEOUT} sec has expired."
    exit 1
 }


 # define COUNTER_SN
 [ -n "${2}" ] && COUNTER_SN=${2}
 SetCounterSN


 [ $DEBUG -gt 0 ] && echo "OS: ${OS}; DEVICE: ${DEVICE}; COUNTER_SN: ${COUNTER_SN}($CSN); COUNTER_TYPE: ${COUNTER_TYPE}; ECHOCOMMAND: ${ECHOCOMMAND}; TEST_COMMUNITY: ${TEST_COMMUNITY}; DEV_EMULATOR: ${DEV_EMULATOR}; METHOD_COMMUNITY: ${METHOD_COMMUNITY}; FUZZY_MATCHING_CRC: ${FUZZY_MATCHING_CRC}"


 # define COMMAND
# SetParams "${1}" > /dev/null
# [ "$?" -ne 0 ] && {
#   echo "Error SetParams"
#   Fatalerror "$0" 7
#   return 7
# }


 # тестирование связи, настройка параметров порта при необходимости
 # COMMAND TEST
 [ ${TEST_COMMUNITY} = "YES" ] && {
     CheckParameter "command" "${TEST_COMMAND}" "${COMMANDS}" "" "Command \"${TEST_COMMAND}\" not found!" > /dev/null
     CMDTESTEXIST=$?
 }
 [ ${TEST_COMMUNITY} = "YES" -a 0${CMDTESTEXIST} -eq 0 ] && {

   #  comtest="`GetCommandLine ${CSN} ${TEST_COMMAND}`"
 
   SetParams "${TEST_COMMAND}" > /dev/null
   [ "$?" -ne 0 ] && {
       echo "Error SetParams"
       Fatalerror "$0" 7
       return 7
   }

   [ ${DEBUG} -gt 0 ] && echo "TEST_SEND: ${TEST_COMMAND} ${cmd} ${com_size}"

   crc=1
   answ="`test_reciver ${cmd} ${com_size}`"
   #answ="`reciver ${cmd} ${com_size}`"
   result=$?
   [ $DEBUG -gt 0 ] && echo "${answ}"
   [ $result -eq 1 ] && {
      if [ ${DEV_EMULATOR} = "NO" ]; then
         [ $DEBUG -gt 0 ] && echo "Set params device \"${DEVICE}\"..."
         SetDeviceParams
         retset=$?
         [ $DEBUG -gt 0 ] && echo "Set params device \"${DEVICE}\" - $retset."
         if [ $retset -eq 0 ]; then
             answ="`test_reciver ${cmd} ${com_size}`"
             result=$?
             [ $DEBUG -gt 0 ] && echo "$answ"
             [ $result -eq 1 ] && {
                echo "Error! Not answer \"${DEVICE}\"!";
                Fatalerror "$0" 7
                return 7
             }
         else
             echo "Error! Set params device \"${DEVICE}\"!";
             Fatalerror "$0" 6
             return 6
         fi
      else
          echo "Error! Not answer \"${DEVICE}\"!";
          Fatalerror "$0" 7
          return 7
      fi
   }
 }

 # define COMMAND
  SetParams "${1}" > /dev/null
  [ "$?" -ne 0 ] && {
      echo "Error SetParams"
      Fatalerror "$0" 7
      return 7
 }

#set -x
 # COMMAND PROCESSING
 [ $DEBUG -gt 0 ] && echo "SEND: "${cmd}
 crc=1
 for i in `GetSequence ${TRY_COUNT_COMMAND}`
 do
   answer="`reciver ${cmd} ${com_size}`"
   recret=$?
   [ $DEBUG -gt 0 ] && echo "ANSWER($i): "$answer $recret

   ans=`echo "$answer" | cut -d"	" -f1`
   len_ans=`echo "$answer" | cut -d"	" -f2`
   #echo $ans $len_ans

   [ "${FUZZY_MATCHING_CRC}" = "YES" ] && {
       case $recret in
        3) ans1=$(form_com `echo $ans | sed 's/.\{3\}$//'` 'x' 'x%s')
           [ -n "`echo $ans1 | grep '^'${ans}'...$'`" ] && ans=$ans1
           ;;
        4) ans=$(form_com $ans 'x' 'x%s') ;;
      esac
      case $recret in
       3|4) len_ans=$com_size
            recret=0
          ;;
      esac
      [ $DEBUG -gt 0 ] && echo $ans $len_ans $recret
   }

   dyn_mode=0
   [ $recret -ne 1 -a ${com_size} -eq ${MAX_BLOCK_SIZE} ] && dyn_mode=1

   [ $recret -eq 0 -o $dyn_mode -eq 1 ] && {
      check_com $ans
      crc=$?
      [ $crc -eq 0 ] && {
         [ $len_ans -eq $MIN_BLOCK_SIZE ] && {
             need="`Parser_com $com_name $ans $len_ans | sed -n 's/.* Need \(.*\)/\1/p'`"
             [ -n "$need" ] && {
                 answer="`reciver $(GetCommandLine "$CSN" "$need")`"
                 continue
             }
         }
         break
      }
   }
 done
#set +x

 # COMMAND RESULT PARSING
 if [ $recret -eq 0 -o $dyn_mode -eq 1 ]; then
    if [ $crc -eq 0 ]; then
        [ ${DISPLAY_DESCRIPTION} = 'YES' ] && echo "$name"
        Parser_com $com_name $ans $len_ans $outparser
    else
        echo "Error CRC!"
        Fatalerror "$0" 10
    fi
 else
    if [ $recret -eq 1 ]; then
        echo "Error! Counter(${COUNTER_SN}) not answer!"
        Fatalerror "$0" 11
    else
        echo "Error! Size packets(${len_ans}) error!"
        Fatalerror "$0" 12
    fi
 fi


#sleep 5
exit 255
