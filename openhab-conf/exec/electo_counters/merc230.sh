#!/bin/sh
#
# Data read from electric meter
# Merciry 230
#
# 2015-07-07 version 1
# 2016-05-15 version 2
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


RETRY_QUERY=1
MIN_BLOCK_SIZE=4
MAX_BLOCK_SIZE=255
START_BLOCK_DATA=1

#T2_CORRECT=5578487
#T3_CORRECT=1501430
#           - 21400
#           -  6640 20170814 06:50
#                   20171130 23:25
# T2_CORRECT=5321236
  T2_CORRECT=5315641
# T3_CORRECT=1412463
  T3_CORRECT=1414737


# T3 2015-10-05 08:20:00 2885216 - 1228915 = 1656301
# T2 2015-10-05 08:20:00 7425400 - 1480530 = 5944970
# miliWATT !!
#WATT_HOUR_CORRECTION_T2=5200
WATT_HOUR_CORRECTION_T2=0.0100
#WATT_HOUR_CORRECTION_T3=4100
WATT_HOUR_CORRECTION_T3=-0.0055

PASS_R=`StrToHex "${PASS_READ}"`
PASS_W=`StrToHex "${PASS_WRITE}"`

# modes list
MODES='all_time	0
curr_year	1
prior_year	2
month	3
today	4
yesterday	5
all_time_phase	6'

# tarifs list
ZONES='T_ALL	00
T1	01
T2	02
T3	03
T4	04
LOST	05
T_NEW	06'

#
POWERS='P	0
Q	1
S	2'

#PHAZA
PHAZAS='all	0
1	1
2	2
3	3'


# commands list
# alias	command	size answer	parser format	description
COMMANDS='test	`form_com x${CSN}x00`	4		Тестирование связи
openread	`form_com x${CSN}x01x01${PASS_R}`	4		Открытие соединения на чтение
openwrite	`form_com x${CSN}x01x02${PASS_W}`	4		Открытие соединения на запись
close	`form_com x${CSN}x02`	4		Завершение сеанса
kwatthour	`form_com x${CSN}x05x${mode}${month}x${zona}`	${com_size}		Опрос накопленной энергии params: mode[]:zona[]
amper	`form_com x${CSN}x08x16x2${phaza}`	${com_size}		Сила тока A (А) по фазам params: phaza[]
coefw	`form_com x${CSN}x08x16x30`	15		Коэффициент мощности (С) по фазам
freq	`form_com x${CSN}x08x16x40`	6		Частота Гц
freq2	`form_com x${CSN}x08x16x40`	6	"1,3,2#d#Aprintf(\"%0.2f\",^b0/100)#"	Частота Гц
coin	`form_com x${CSN}x08x16x5${phaza}`	${com_size}		Угол между фазами params: phaza[]
power	`form_com x${CSN}x08x16x0${mode}`	${com_size}		Мощность P (Вт) по фазам params: POWERS[]:phaza[]
volt	`form_com x${CSN}x08x16x1${phaza}`	${com_size}		Напряжение U (В) params: phaza[]
null	`form_com x${CSN}${mode}`	${MAX_BLOCK_SIZE}	"${OutParser}"	Произвольная команда
serialnum	`form_com x${CSN}x08x00`	${MAX_BLOCK_SIZE}	"d1,02d2,02d3,02d4#Sn\\0=\\0\\t|02d5,02d6#Date\\0\\t#0#02d7#20\\t"	Серийный номер счетчика и даты выпуска
version	`form_com x${CSN}x08x03`	${MAX_BLOCK_SIZE}	"d1#version\\0\\t.#0#d2#\\t.#0#d3"	Версия ПО
datetime	`form_com x${CSN}x04x00`	${MAX_BLOCK_SIZE}	"3#0#2#_\\t_#0#1#0#4#\\0\\t\\0#0#5#\\t.#0#6#\\t.#0#7#\\t\\0#0#8"	Дата время по счетчику
kwatthour_t2	`form_com x${CSN}x05x00x02`	19		Учетный счетчик, Т2
kwatthour_t3	`form_com x${CSN}x05x00x03`	19		Учетный счетчик, Т3
kwatthour_af	`form_com x${CSN}x05x${mode}${month}x${zona}`	${com_size}		Внутренний счетчик params: mode[]:month[]:zona[]
kwatthour_phaza	`form_com x${CSN}x05x60x${zona}`	${com_size}	"$((${phaza} * 4 - 2)),$((${phaza} * 4 - 3)),$((${phaza} * 4)),$((${phaza} * 4 - 1))#d"	Накопленная энергия по указанной фазе params: zona[]:phaza[]
power_phaza	`form_com x${CSN}x08x16x00`	15	"$((3 + ${phaza} * 3 - 2)),$((3 + ${phaza} * 3)),$((3 + ${phaza} * 3 - 1))#d#a3fffff"	Мощность P (Вт) по указанной фазе params: phaza[]'





SetCounterSN()
{
 COUNTER_SN=${COUNTER_SN:='00000000'}
 CSN=`echo "${COUNTER_SN}" | awk '{printf "%02x", substr($0,length($0)-1,2)}'`
}

Dev_Enulator()
{
  #echo "EMU com=${1}" >&2
  local command="`echo "${1}" | cut -d"x" -f3 | cut -c1-2`"
  local command2="`echo "${1}" | cut -d"x" -f4 | cut -c1-2`"
  local command3="`echo "${1}" | cut -d"x" -f5 | cut -c1-2`"
  local answer=""

  case $command in
    # Тестирование связи
    # 11 00 |0D E0
    # 11 00 |0D E0 - ответ : Ok
    '00') answer="`form_com x${CSN}x00`" ;;
    '08') {
            case $command2 in
             '16') {
                    case $command3 in
                       # power
                       # query 11 08 16 00 |8A BA
                       # answer 11 40 37 9A 40 82 0D 00 00 00 40 B5 8C |EF B7
                      '00') answer="`form_com x${CSN}x40x37x9Ax40x82x0Dx00x00x00x40xB5x8C`" ;;
                       # Частота Гц
                       # 11 08 16 40 |8B 4A
                       # 11 00 8C 13 |20 15 - ответ : 50,04
                      '40') answer="`form_com x${CSN}x00x8Cx13`" ;;
                       # amper
                       # query 11 08 16 21 |4A A2
                       # answer 11 00 DA 00 00 00 00 00 A8 06 |52 B6
                      '21') answer="`form_com x${CSN}x00xDAx00x00x00x00x00xA8x06`" ;;
                       # volt
                       # query 11 08 16 11 |4A B6
                       # answer 11 00 4E 57 00 4C 57 00 55 57 |FC 3A
                      '11') answer="`form_com x${CSN}x00x4Ex57x00x4Cx57x00x55x57`" ;;
                       # coefw
                       # query 11 08 16 30 |8A AE
                       # answer 11 40 79 03 40 10 03 00 00 00 40 AF 03 |75 7D
                      '30') answer="`form_com x${CSN}x40x79x03x40x10x03x00x00x00x40xAFx03`" ;;
                    esac
                    } ;;
             # Серийный номер счетчика и даты выпуска
             # 11 08 00 |26 05
             # 11 09 1B 4C 11 02 08 0B |E9 15 - ответ : 9277617 02082011
             '00') answer="`form_com x${CSN}x09x1Bx4Cx11x02x08x0B`" ;;
             # Версия ПО
             # 11 08 03 |66 04
             # 11 02 03 01 |65 E8 - ответ : 2.3.1
             '03') answer="`form_com x${CSN}x02x03x01`" ;;
            esac
          } ;;

     # kwatthour
     # query 11 05 00 00 |15 19
     # answer 11 04 02 4A E2 FF FF FF FF 08 00 1C 92 FF FF FF FF |31 F8
     '05') answer="`form_com x${CSN}x04x02x4AxE2xFFxFFxFFxFFx08x00x1Cx92xFFxFFxFFxFF`" ;;

     # Дата время по счетчику
     # 11 04 00 |23 05
     # 11 13 58 13 02 17 05 16 00 |32 CA - ответ : 13_58_13 02 17.05.16 00
     '04') answer="`form_com x${CSN}x13x58x13x02x17x05x16x00`" ;;

     *) :> "${2}"
  esac

  #echo "EMU answer=${answer}" >&2
  if [ "${ECHOCOMMAND}" = "YES" ]; then
      HexToChar ${1}${answer} > "${2}"
  else
      HexToChar ${answer} > "${2}"
  fi
}


SetParams()
{
  # определить имя команды
  com_string=${1}
  [ -z "${com_string}" ] && com_string="kwatthour"
  com_name="`echo ${com_string} | cut -d":" -f1`"
  [ -z "$com_name" ] && com_name=$com_string

  com="${com_name}	`CheckParameter "command" "${com_name}" "${COMMANDS}" "" "Command \"$com_name\" unknown!"`"
  [ $? -ne 0 ] && return 1

  cmd="`echo "${com}" | cut -d"	" -f2`"
  com_size="`echo "${com}" | cut -d"	" -f3`"
  outparser="`$C_ECHO "${com}" | cut -d"	" -f4`"
  name="`echo "${com}" | cut -d"	" -f5`"

  #echo "$com_name $cmd $com_size" >&2

  case $com_name in
    'null') {
         ParseNullCom "${com_string}"

         PARAMS="\"${com_string}\"> mode="${mode}" OutParser="$OutParser
    };;
    'volt'|'amper'|'coin') {
         phaza="`echo ${com_string} | cut -d":" -f2`"
         if [ "$phaza" != "$com_name" ]; then
            [ -z "$phaza" ] && {
               phaza=1
            }
         else
           phaza=1
         fi

         case $phaza in
             1) com_size=12 ;;
             2) com_size=9 ;;
             3) com_size=6 ;;
             *) com_size=12 ;;
         esac

         PARAMS="\"${com_string}\"> phaza="${phaza}
    };;
    'power') {
         typpowerr="`echo ${com_string} | cut -d":" -f2`"
         typpower=0
         phaza=0

         if [ "$typpowerr" != "$com_name" ]; then
            typpower="`echo "${POWERS}" | sed -n 's/^'${typpowerr}'	\(.*\)$/\1/p'`"
            [ -z "${typpower}" ] && {
               echo "Parameter \"$typpowerr\" unknown!" >&2
               typpower=0
            }

            phazar=`echo ${com_string} | sed -n 's/^[^:]*:[^:]*:\(.*\)$/\1/p'`
            phaza="`CheckParameter phaza "${phazar}" "${PHAZAS}" '1'`"
         fi

         mode=`printf "%X" $(expr ${typpower} \* 4 + $phaza)`

         case $phaza in
           '0') com_size=15 ;;
             *) com_size=12 ;;
         esac

         PARAMS="\"${com_string}\"> mode="$mode", typpower="${typpower}", phaza="${phaza}
    };;
    'kwatthour'|'kwatthour_af') {
            params="`echo ${com_string} | sed -n 's~^[^:]*:\(.*\)~\1~p'`"

            #echo "_$params" >&2

            mode='0'
            zona='0'
            month='0'

            moder="`echo $params | cut -d':' -f1`"
            #echo "moder = $moder" >&2

            if [ -n "$moder" ]; then

                month=`echo "${moder}" | sed -n 's/^[^=]*=\(.*\)$/\1/p'`
                if [ -n "${month}" ]; then
                     moder=`echo "${moder}" | cut -d"=" -f1`
                else
                     month='0';
                fi
                #echo "month = $month" >&2

                mode="`CheckParameter mode "${moder}" "${MODES}" '0'`"

                if [ $mode = '3' ]; then
                    #echo $month >&2
                    [ $month -gt 12 -o $month -lt 1 ] && month='1'
                    month=`echo $month | sed 's/0\([1-9]\)/\1/'`
                    #echo "month = $month" >&2
                    # only the BASH
                    #month=`printf "%X" $((10#$month))`
                    month=`printf "%X" $month`
                    #echo "month = $month" >&2
                else
                    month='0'
                fi

                zoner=`echo ${params} | sed -n 's/^[^:]*:\(.*\)$/\1/p'`
                zona="`CheckParameter zona "${zoner}" "${ZONES}" '00'`"

            fi

            zona=`printf "%02X" $zona`
            if [ $zona -lt 6 ]; then
               case $mode in
                 '0'|'1'|'2'|'3'|'4'|'5') com_size=19 ;;
                 '6') com_size=15 ;;
                 *) com_size=19 ;;
               esac
            else
              com_size=$MAX_BLOCK_SIZE
            fi

            PARAMS="\"${com_string}\"> mode="${mode}", zona="${zona}", month="${month}
         };;

    'kwatthour_phaza')
            zoner=`echo ${com_string} | sed -n 's/^[^:]*:\([^:]*\).*$/\1/p'`
            zona="`CheckParameter zona "${zoner}" "${ZONES}" '00'`"

            phazar=`echo ${com_string} | sed -n 's/^[^:]*:[^:]*:\(.*\)$/\1/p'`
            phaza="`CheckParameter phaza "${phazar}" "${PHAZAS}" '1'`"

            com_size=15

            PARAMS="\"${com_string}\"> zona="${zona}", phaza="${phaza}
    ;;

    'power_phaza')
            phazar=`echo ${com_string} | sed -n 's/^[^:]*:\(.*\)$/\1/p'`
            phaza="`CheckParameter phaza "${phazar}" "${PHAZAS}" '1'`"

            PARAMS="\"${com_string}\"> phaza="${phaza}
    ;;
    *) PARAMS="none" ;;
  esac

  eval cmd=$cmd
  eval com_size=$com_size
  eval outparser="$outparser"

  [ $DEBUG -gt 0 ] && echo "COMMAND: $com_name; PARAMS: ${PARAMS}; SIZE: $com_size; OUTPARSER: $outparser; DESCRIBE: ${name}" >&2

  #echo "$com_name	$cmd	$com_size	$outparser	$name" >&2
  return 0
}


# CorrectionCounter $data 2 $T2_CORRECT
CorrectionCounter()
{
  #local data="${1}"
  #case "$2" in
  #  '2') correct_watt="`sh ${BASE_DIR}correction.sh 2 ${WATT_HOUR_CORRECTION_T2} 2>> ${BASE_DIR}error_corr.log`" ;;
  #  '3') correct_watt="`sh ${BASE_DIR}correction.sh 3 ${WATT_HOUR_CORRECTION_T3} 2>> ${BASE_DIR}error_corr.log`" ;;
  #esac
  #[ $? -eq 1 ] && echo "T${2}	`date +%Y%m%d%H%M%S`" >> ${BASE_DIR}merc230_last
  #echo "2=\"$2\" WATT_HOUR_CORRECTION_T2=$WATT_HOUR_CORRECTION_T2 BASE_DIR=$BASE_DIR correct_watt=$correct_watt" >&2

  T_last=0
  T_calc=0
  [ -r "${BASE_DIR}/merc230_last_count$2" ] && {
        TALL=`tail -n 1 ${BASE_DIR}/merc230_last_count$2 | sed -n '/^T'$2'	/{; s/^T'$2'	\([^	]*\)	\([^	]*\)	\([^	]*\)/\2 \3/p;q;}'`

        T_last=`echo "$TALL" | cut -d" " -f1`
        T_calc=`echo "$TALL" | cut -d" " -f2`
  }

  curr=`echo "$1" | awk -Fx -v cors=${3} 'function preob(val)
                 {
                    if(val=="FFFFFFFF")val=0000; val=sprintf("%d", "0x"val); oval=sprintf("%01d", val);
                        return oval;
                 };
                 {
                   ovalA=preob($3$2$5$4);
                   #ovalR=preob($11$10$13$12);
                   printf("%01d\n", ovalA - cors);
                 }'`

  eval percent=\$WATT_HOUR_CORRECTION_T$2

  if [ 0$T_last -eq 0 ]; then
      curr_calc=$curr
      dif_calc=0
  else
      dif_calc=`echo $curr | awk -v cors=$T_last -v ca=$T_calc -v pc=$percent '{ printf("%01d", ($1 - cors) * pc + ca) }'`
      curr_calc=`echo $curr | awk -v cors=$T_last -v ca=$dif_calc '{ printf("%01d", $1 + ca) }'`
  fi

  if [ 0$T_last -ne $curr ] || [ ! -r "${BASE_DIR}/merc230_last_count$2" ]; then
      echo "T${2}	`date +%Y%m%d%H%M%S`	$curr	$dif_calc" >> ${BASE_DIR}/merc230_last_count$2
  fi

  echo $curr_calc
}


Parser_com()
{
  com=$1
  request=$2
  leng=$3
  outparser="$4"
  #echo $outparser >&2

  lenn=${#request}

  #echo $com $request $leng

  de=`expr ${lenn} - 6`
  sn=`echo $request | cut -c1-3`
  snd=`printf "%d" 0$sn`
  data=`echo $request | cut -c4-$de`
  crc=`echo $request | cut -c$(expr $de + 1)-$lenn`

  #echo sn=$sn data=$data crc=$crc

  if [ $leng -eq $MIN_BLOCK_SIZE ]; then
     case $data in
      # Ok
      x00) {
         echo "$com - Ok [${snd}]"
         return 0
      };;
      # Недопустимая команда или параметр.
      x01) {
         echo "ERROR: Invalid command or parameter [device: ${snd}]."
         return 1
      };;
      # Внутренняя ошибка счетчика.
      x02) {
         echo "ERROR: Internal error counter [device: ${snd}]."
         return 2
      };;
      # Не достаточен уровень доступа для удовлетворения запроса.
      x03) {
         echo "ERROR: Not sufficient level of access to satisfy the request [device: ${snd}]."
         return 3
      };;
      # Внутренние часы счетчика уже корректировались в течение текущих суток
      x04) {
         echo "ERROR: The internal clock counter has been adjusted for the current day [device: ${snd}]."
         return 4
      };;
      # Не открыт канал связи
      x05) {
         echo "ERROR: Do not open the link [device:${snd}]. Need openread"
         return 5
      };;
        *) {
         echo "ERROR: Unknown code \"$data\" [device: ${snd}]."
         return 6
      };;
     esac
  else

     # ParserCommand $data "01D1"
     if [ -n "$outparser" ]; then
          #echo $outparser >&2

          rezout="`DoOutParser $outparser`"
          echo "${rezout}"
          return 255
     fi

   case $com in
    'null') {
           echo $data outparser=$outparser >&2
    };;
    'freq') {
           echo $data | awk -Fx 'function preob(name,val)
                                 {
                                   val=sprintf("%d", "0x"val); val=val / 100; printf("%s = %01.02f\n", name, val);
                                 };
                                 {preob("Freq(Hr)", $2$4$3)}'
    };;
    'amper') {
           echo $data | awk -Fx 'function preob(name,val)
                                 {
                                   val=sprintf("%d", "0x"val); val=val / 1000; printf("%s = %01.03f\n", name, val);
                                 };
                                 {preob("Ph1(A)", $2$4$3);
                                  preob("Ph2(A)", $5$7$6);
                                  preob("Ph3(A)", $8$10$9)}'
    };;
    'volt') {
           echo $data | awk -Fx 'function preob(name,val)
                                 {
                                   val=sprintf("%d", "0x"val); val=val / 100; printf("%s = %01.02f\n", name, val);
                                 };
                                 {preob("Ph1(V)", $2$4$3);
                                  preob("Ph2(V)", $5$7$6);
                                  preob("Ph3(V)", $8$10$9)}'
    };;
    'power') {
           echo $data | awk -Fx 'function preob(name,val)
                                 {
                                   val=sprintf("%d", "0x"val); printf("%s = %01d\n", name, val);
                                 };
                                 {preob("Phs(W)", $2$4$3);
                                  preob("Ph1(W)", $5$7$6);
                                  preob("Ph2(W)", $8$10$9);
                                  preob("Ph3(W)", $11$13$12)}' |\
                                   (while read i1 i2 i3; do
                                      zn=$((i3 & 0x3FFFFF))
                                      dl=${#zn}
                                      if [ $dl -gt 2 ]; then
                                          st=`expr $dl - 2`
                                          zn2=`echo ${zn} | cut -c$((${st} + 1))-$((${st} + 2)) | sed 's/^[0]*//'`
                                      else
                                          st=1
                                          zn2=0
                                      fi
                                      #printf "%s %s %01d.%02d\n" $i1 $i2 ${zn:0:`expr $dl - 2`} ${zn:`expr $dl - 2`:2}; FOR BASH
                                      #zn=123409
                                      zn1=`echo ${zn} | cut -c1-${st}`

                                      #echo "zn=$zn st=$st dl=$dl zn1=$zn1 zn2=$zn2" >&2
                                      printf "%s %s %01d,%02d\n" ${i1} ${i2} $zn1 $zn2 # FOR SH
                                    done)
    };;
    'coefw') {
           echo $data | awk -Fx 'function preob(name,val)
                                 {
                                   val=sprintf("%d", "0x"val); printf("%s = %01d\n", name, val);
                                 };
                                 {preob("Cosf", $2$4$3);
                                  preob("Cosf1", $5$7$6);
                                  preob("Cosf2", $8$10$9);
                                  preob("Cosf3", $11$13$12)}' |\
                                   (while read i1 i2 i3; do
                                      zn=$((i3 & 0x3FFFFF))
                                      # dl=${#zn}
                                      printf "%s %s 0.%03d\n" $i1 $i2 ${zn}
                                      #printf "%s %s %01d\n" $i1 $i2 ${zn}
                                    done)
    };;

    'kwatthour') {
           echo $data | awk -Fx -v lenc=$leng 'function preob(name,val)
                                 {
                                  if(val=="FFFFFFFF")val=0000; val=sprintf("%d", "0x"val); val=val / 1000; printf("%s = %01.03f\n", name, val);
                                 };
                                 {
                                  if (lenc==19) {
                                      preob("Ap(kWh)", $3$2$5$4);
                                      preob("Ao(kWh)", $7$6$9$8);
                                      preob("Rp(kWh)", $11$10$13$12);
                                      preob("Ro(kWh)", $15$14$17$16);
                                  } else {
                                      preob("Ap_F1(kWh)", $3$2$5$4);
                                      preob("Ap_F2(kWh)", $7$6$9$8);
                                      preob("Ap_F3(kWh)", $11$10$13$12);
                                  };
                                 }'
    };;
    'kwatthour_t2') {
          CorrectionCounter $data 2 $T2_CORRECT
    };;
    'kwatthour_t3') {
          CorrectionCounter $data 3 $T3_CORRECT
    };;

    'kwatthour_af') {
          echo $data | awk -Fx -v lenc=$leng 'function preob(val)
                           {
                             if(val=="FFFFFFFF")val=0000; oval=sprintf("%d", "0x"val);
                             return oval;
                           };
                           {
                             if (lenc==19) {
                                  printf("%01d\n%01d\n%01d\n%01d", preob($3$2$5$4), preob($7$6$9$8), preob($11$10$13$12), preob($15$14$17$16))
                             } else {
                                  printf("%01d\n%01d\n%01d", preob($3$2$5$4), preob($7$6$9$8), preob($11$10$13$12))
                             };
                           }'
    };;

   esac
   return 255
 fi
}

