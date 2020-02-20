#!/bin/sh
#
# Data read from electric meter
# lib_funct.sh Function libriary
# 2015-07-07 v 1
# 2016-04-18 v 2
# 2017-04-26 version 2.1
# 2018-01-29 version 2.2
# kohan pavel e-mail: hidersoft@gmail.com Skype: kpp77strannik
#
#
# version 2.2
#
# DONATE Поблагодарить
# Всем, кто считает проделанную работу полезной,
# есть возможность поддержать автора.
# Карта ПриватБанка: 6762 4626 8013 0082.
# Всем заранее спасибо.
#

SleepEx()
{
  sleep $1 > /dev/null 2>&1
  [ $? -eq 0 ] || ping -c2 -i$1 127.0.0.1 >/dev/null 2>&1
}

GetFileSize()
{
 case $OS in
  'FREEBSD') stat -f%z "${1}" ;;
  *) ls -l "${1}" | awk '{print $5}' ;;
 esac
}

# calculate CRC CRC_Modbus
CRC_Modbus()
{
  local string=$(echo ${1} | sed 's/_0x//g;s/[_x#]//g')
  local mode=${2}
  local mode=${mode:=1}
  local pref=${3}

  #  вычисляем длину string
  cnt=${#string}
  crc=0xFFFF

  all=`expr $cnt - 2`
  if [ $OS = 'FREEBSD' ]; then
     kol=`expr $cnt / 2`
     masD="`jot $kol 0 $all`"
     masB="`jot 8 0 7`"
  else
     masD="`seq 0 2 $all`"
     masB="`seq 0 7`"
  fi

  for i in $masD
  do
     # --- FOR SH BEGIN ----
     cut_i=$(($i + 1))
     koli=$(($cut_i + 1))
     bob="`echo "$string" | cut -c${cut_i}-${koli}`"
     # echo "i=$i cut_i=$cut_i koli=$koli bob=$bob" >&2
     crc=$(( crc ^ $((0x${bob})) ))             # ^ - по-битовое ИСКЛЮЧАЮЩЕЕ ИЛИ (XOR)
     # --- FOR SH END ----

     # --- FOR BASH BEGIN ----
     #crc=$(( crc ^ $((0x${string:$i:2})) ))    # ^ - по-битовое ИСКЛЮЧАЮЩЕЕ ИЛИ (XOR)
     # --- FOR BASH END ----

     for j in $masB
     do
        c=$(( crc & 1 ))                        # & - по-битовое И (AND)
        crc=$(( crc >> 1 ))                     # >> - сдвиг вправо на 1 бит (деление на 2)
        [ $c -eq 1 ] && crc=$(( crc ^ 0xA001 )) # ^ - по-битовое ИСКЛЮЧАЮЩЕЕ ИЛИ (XOR)
     done

     # echo "$i	0x${string:$i:2}	$crc"
  done

  if [ $mode -eq 1 ]; then
      crcc=`printf "%04X" "$crc"`
      # printf "${pref}${pref}" "${crcc:2:2}" "${crcc:0:2}"  FOR BASH
      printf "${pref}${pref}" "`echo ${crcc} | cut -c3-4`" "`echo ${crcc} | cut -c1-2`" #  FOR SH
  else
      printf "${pref}" "$crc"
  fi

  return 0
}


HexToChar()
{
 case $OS in
   'FREEBSD') echo -n "${1}" | awk -F'_' '{for(i=1; i<=NF; i++) {printf "%c", $i}}' ;;
   *) #echo ${1} | sed 's/_0x/\\\x/g' >&2
      # ONLY BASH !
      $C_ECHO -en "`echo ${1} | sed 's/_0x/\\\x/g'`"
    ;;
 esac
}

StrToHex()
{
  echo "${1}" | awk '{len=length($0); for(i=1; i<=len; i++) {printf "x%02x", substr($0,i,1)}}'
}

GetSequence()
{
 case $OS in
   'FREEBSD') jot ${1} ;;
   *) seq 1 ${1} ;;
 esac
}


GetCommandLine()
{
  tempCSN=$CSN
  CSN=$1
  tcom=$2
  #echo "\"$1\" \"$tcom\"" >&2
  tcom=${tcom:='test'}

  tcom="`echo "${COMMANDS}" | grep "^${tcom}	"`"

  _cmd="`echo "${tcom}" | cut -d"	" -f2`"
  _com_size="`echo "${tcom}" | cut -d"	" -f3`"
  eval _cmd=${_cmd}
  eval _com_size=${_com_size}
  CSN=$tempCSN

  echo "${_cmd} ${_com_size}"
}

form_com()
{
  pref=${2}
  pref=${pref:='_0x'}
  pref2=${3}
  pref2=${pref2:='_0x%02s'}

  #echo "$pref" >&2
  cmd=`echo -n ${1} | sed 's/[x#]/'$pref'/g'`
  echo -n ${cmd}`CRC_Modbus ${cmd} 1 "${pref2}"`
}


check_com()
{
  anwo=$(form_com `echo $1 | sed 's/.\{6\}$//'` 'x' 'x%s')
  #echo "$anw $anwo"
  [ "$1" = "$anwo" ] && return 0
  return 1
}


ParserCommand()
{
  block=$1
  nblock="$2"

 # echo "PC $1 "$nblock" $3" >&2

  if [ 0"$3" -eq 0 ]; then
     # единичное значение

     if [ -n "`echo $nblock | grep "^[0-9][0-9]*$"`" ]; then
        cio="`$C_ECHO -n $1 | awk -Fx -v num=$nblock -v stp=${START_BLOCK_DATA} '{print x$(num+stp)}'`"
     else
        cio=`echo $nblock | sed -n 's~^\(.*[dx]\)\(.*\)~echo "'$1'" | awk -Fx -v stp=${START_BLOCK_DATA} \\\{printf\\\(\\\"%\1\\\",\\\"0x\\\"\\\$\\\(\2+stp\\\)\\\)\\\}~p'`
     fi
  else
     # блочное значение
     cio="`$C_ECHO "$nblock" | sed -n 's/\\\0/ /g; s/\(.*\)\\\t\(.*\)/\1'"$1"'\2/p'`"
     [ -n "$cio" ] && {
        echo "${cio}"
        return 0
     }
     #echo "c0" >&2

     nblock=`echo "$nblock" | sed 's~\^b~\$~g; s~\^0~ ~g'`

     if [ "`echo "${nblock}" | cut -c1`" = "A" ]; then
        nblock="`$C_ECHO $nblock | sed 's~^A\(.*\)~{\1}~'`"
        #echo "1mnog=\"$mnog\" nblock=\"$nblock\" block=$block" >&2

        cio="`$C_ECHO "${block}" | awk ${nblock}`"

        #echo "2mnog=\"$mnog\" nblock=\"$nblock\" block=$block" >&2
     else
        mnog="`$C_ECHO $nblock | sed -n 's/.*\.\(.*\)f.*/\1/p'`"
        #echo "mnog=\"$mnog\" nblock=\"$nblock\" block=$block" >&2

        if [ -n "$mnog" ]; then
            cio=`$C_ECHO $1 | awk '{printf("%'$nblock'", $0 / (10 ** '$mnog'))}'`
        else
            if [ "$nblock" = "$2" ]; then
                cio=`$C_ECHO "$nblock" | sed -n 's/^a\(.*\)/\$(( '$1' \& 0x\1 ))/p'`
                #echo "c0=\"$mnog\" bio=\"$bio\" block=$block" >&2
                [ -z "$cio" ] && cio=`$C_ECHO $nblock | printf "%$nblock" 0x${1}`
            else
                cio=$nblock
            fi
        fi
     fi
  fi
  #echo "cio=$cio" >&2
  #echo cio="$cio" >&2
  eval echo "$cio"
}


CheckParameter()
{
  par_name="${1}"
  par_val="${2}"
  par_list="${3}"
  par_def="${4}"
  par_flag="${5}"

  #echo "par_name \"${par_name}\" par_val=\"${par_val}\" par_list=\"${par_list}\" par_def=\"$par_def\" par_flag=\"$par_flag\"" >&2
  retur=0

  par_cor="${par_def}"
  if [ -n "${par_val}" ]; then
       par_cor="`$C_ECHO "${par_list}" | sed -n 's/^'${par_val}'	[	]*\(.*\)$/\1/p'`"
       #echo $par_cor >&2
       [ -z "${par_cor}" ] && {
           par_cor="$par_def"
           if [ -z "${par_flag}" ]; then
               echo "Parameter value \"${par_name}\"=\"${par_val}\" unknown! Set default \"${par_name}\"=\"${par_cor}\"" >&2
               retur=1
           else
               echo "${par_flag}" >&2
               retur=1
           fi
       }
  fi
  $C_ECHO "${par_cor}"
  return $retur
}


DoOutParser()
{
  outpars="${1}"
  #echo $outpars >&2

  for bl in `$C_ECHO "${outpars}" | tr "|" " "`
  do
     ii=0
     #echo bl=$bl >&2
     for dv in `$C_ECHO "$bl" | tr '#' " "`
     do
        #echo dv="$dv" >&2
        [ $dv = '0' ] && {
            echo -n "$block"
            block=''
            ii=0
            continue
        }
        [ $ii -eq 1 ] && {
             block=`ParserCommand "$block" "$dv" 1`
             #ii=0
             continue
        }
        #      echo "${block}"
        ii=1
        block=''
        for zp in `echo "$dv" | tr "," " "`
        do
            #echo zp=$zp >&2
            block=${block}`ParserCommand "$data" "$zp" 0`
            #echo block=$block >&2
            #echo "$block"
        done
     done
     echo "${block}"
  done
}


ParseNullCom()
{
   local com_string="${1}"
   OutParser=""
   mode="`echo ${com_string} | cut -d":" -f2-`"
   if [ "$mode" != "$com_name" ]; then
        [ -z "$mode" ] && mode="x00"
        #echo mode=$mode Formats=$Formats >&2
        OutParser=`echo "${mode}" | sed -n 's/^[^=]*=\(.*\)$/\1/p'`
        if [ -n "${OutParser}" ]; then
            mode=`echo "${mode}" | cut -d"=" -f1`
        else
            OutParser="";
        fi
   else
        mode="x00"
   fi
}


