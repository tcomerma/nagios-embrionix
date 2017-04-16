#!/bin/bash
# FILE: "check_embrionix.sh"
# DESCRIPTION: Check status of embrionix emsfp-2022 devices.
# AUTHOR: Toni Comerma
# DATE: april-2017
#
# Notes:

# Examples
#
#
#

PROGNAME=`basename $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION='Version: 1.0'

source performance_utils.sh

STATE_DIR="$PROGPATH"

CURL=`which curl`
OPTIONS="-s"
API_CALL="/emsfp/node/v1/flows"
OUTFILE="xx.tmp"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

STATE=$STATE_OK

HOST=""
PORT=8080
TIMEOUT=10
NO_SDI=0


function print_help() {
  echo "Usage:"
  echo "  $PROGNAME -H <host> [-p <port>] -t <timeout> "
  echo "  $PROGNAME -h "
        echo ""
        echo "Opcions:"
        echo "  -H IP or hostmame "
        echo "  -p port, defaults to 8080"
        echo "  -t timeout, defaults to 10"
        echo "  -n no warning if no SDI"
        echo "  "
        echo ""
  exit $STATE_UNKNOWN
}

function set_warning {
  if [ $STATE -lt $STATE_WARNING ]
  then
    STATE=$STATE_WARNING
  fi
}

function set_critical {
  if [ $STATE -lt $STATE_CRITICAL ]
  then
    STATE=$STATE_CRITICAL
  fi
}

function write_status {
  case $STATE in
     0) echo "OK: $1"; exit 0 ;;
     1) echo "WARNING: $1"; exit 1 ;;
     2) echo "CRITICAL: $1"; exit 2 ;;
  esac
}

# main program
#
# Parameters processing
while getopts "H:p:t:n" Option
do
        case $Option in
                H ) HOST=$OPTARG;;
                t ) TIMEOUT=$OPTARG;;
                h ) print_help;;
                p ) PORT=$OPTARG;;
                n ) NO_SDI="1";;
                * ) echo "unimplemented option";;
                esac
done

if [ ! "$HOST" ] ; then
        echo " Error - No Address (IP or hostmame) provided "
        echo ""
        print_help
        echo ""
fi


# Read information URL
API_CALL="/emsfp/self/information"
URL="http://${HOST}:${PORT}${API_CALL}"
OUT=`curl $URL $OPTIONS --max-time $TIMEOUT -o - `
CURL_STATUS=$?
# curl return status
if [ $CURL_STATUS -eq 0 ]
then
  # Check device type (Encap o Decap)
  TYPE=`echo "$OUT" | egrep -m 1 -o '"type": "(.)"' | cut -f 2 -d ":" | tr -d '"'`
  if [ "$TYPE" -eq "1" ]
  then
    TYPE="ENCAP"
  else
     if [ "$TYPE" -eq "2" ]
     then
       TYPE="DECAP"
     else
       set_critical
       write_status "ERROR: Unable to determine device model"
     fi
  fi
  # Get HW version
  HW_VERSION=`echo "$OUT" | egrep -o '"hw_version": ".*"' | cut -f 2 -d ":" | tr -d '" ' `
  FPGA_VERSION=`echo "$OUT" | egrep -o '"fpga_version": ".*"' | cut -f 2 -d ":" | tr -d '" ' `
else
  set_critical
  write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"
fi

# Read flows URL
API_CALL="/emsfp/node/v1/flows"
URL="http://${HOST}:${PORT}${API_CALL}"
OUT=`curl $URL $OPTIONS --max-time $TIMEOUT -o - `
CURL_STATUS=$?
# curl return status
if [ $CURL_STATUS -eq 0 ]
then
   # Check number of ports
   PORTS=`echo "$OUT" | egrep -o '"version":' | wc -w`
   if [ -z "$PORTS" ]
   then
     write_status $STATE_CRITICAL  "ERROR: Unable to determine device model"
   fi
   # Loop for ports
   PORT=1
   PERF=""
   STATUS_PORT=""
   while [ $PORT -le $PORTS ]
   do
     STATUS_PORT="$STATUS_PORT (Port=$PORT:"
     # Status and video characteristics
     #
     # format_code_valid
     FORMAT_CODE_VALID=`echo "$OUT" | egrep -o '"format_code_valid": "([0-9])"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
     if [ "$FORMAT_CODE_VALID" == "1" ]
     then
        STATUS_PORT="$STATUS_PORT SDI OK "
        # format_code_p_scan
        FORMAT_CODE_P_SCAN=`echo "$OUT" | egrep -o '"format_code_p_scan": "([0-9])"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
        case "$FORMAT_CODE_P_SCAN" in
          "0") STATUS_PORT="$STATUS_PORT Interlaced"
             ;;
          "4") STATUS_PORT="$STATUS_PORT Progressive"
             ;;
          *)   STATUS_PORT="$STATUS_PORT Unknown format_code_p_scan"
               set_warning
             ;;
        esac
        # format_code_mode
        FORMAT_CODE_MODE=`echo "$OUT" | egrep -o '"format_code_mode": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
        case "$FORMAT_CODE_MODE" in
          "0") STATUS_PORT="$STATUS_PORT HD"
             ;;
          "8") STATUS_PORT="$STATUS_PORT SD"
             ;;
          "16") STATUS_PORT="$STATUS_PORT 3G"
             ;;
          *)   STATUS_PORT="$STATUS_PORT Unknown format_code_mode"
               set_warning
             ;;
        esac
        # format_code_format
        FORMAT_CODE_FORMAT=`echo "$OUT" | egrep -o '"format_code_format": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
        case "$FORMAT_CODE_FORMAT" in
          "0") STATUS_PORT="$STATUS_PORT 1920x1080"
             ;;
          "64") STATUS_PORT="$STATUS_PORT 1280x720"
             ;;
          "512") STATUS_PORT="$STATUS_PORT (525i) 720x483"
             ;;
          "576") STATUS_PORT="$STATUS_PORT (625i) 720x576"
             ;;
          *)   STATUS_PORT="$STATUS_PORT Unknown format_code_format"
               set_warning
             ;;
        esac
        # format_code_rate
        FORMAT_CODE_RATE=`echo "$OUT" | egrep -o '"format_code_rate": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
        case "$FORMAT_CODE_RATE" in
          "5120") STATUS_PORT="$STATUS_PORT 50Hz"
             ;;
          "6144") STATUS_PORT="$STATUS_PORT 59.94Hz"
             ;;
          "7168") STATUS_PORT="$STATUS_PORT 60Hz"
             ;;
          "9216") STATUS_PORT="$STATUS_PORT 50Hz"
             ;;
          "10240") STATUS_PORT="$STATUS_PORT 59.94Hz"
             ;;
          "11264") STATUS_PORT="$STATUS_PORT 60Hz"
             ;;
          *)   STATUS_PORT="$STATUS_PORT Unknown format_code_rate"
               set_warning
             ;;
        esac
        # format_code_sampling
        FORMAT_CODE_SAMPLING=`echo "$OUT" | egrep -o '"format_code_sampling": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
        case "$FORMAT_CODE_SAMPLING" in
          "0") STATUS_PORT="$STATUS_PORT Interlaced"
             ;;
          "8192") STATUS_PORT="$STATUS_PORT Progressive"
             ;;
          *)   STATUS_PORT="$STATUS_PORT Unknown format_code_rate"
               set_warning
             ;;
        esac
     else
        STATUS_PORT="$STATUS_PORT NO SDI "
        if [ "$NO_SDI" == "0" ]
        then
           set_warning
        fi
     fi
     STATUS_PORT="$STATUS_PORT)"
     # Performance
     read_state_file "${HOST}_$PORT.state"
     # Get counters
     if [ "$TYPE" == "ENCAP" ]
     then
       PERF_PKT_CNT_CUR=`echo "$OUT" | egrep -o '"tx_pkt_cnt": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" ' `
     else
       PERF_PKT_CNT_CUR=`echo "$OUT" | egrep -o '"rx_pkt_cnt": "([0-9]*)"' | awk "NR == ${PORT} " | cut -f 2 -d ":" | tr -d '" '`
     fi
     calc_diff
     PERF="$PERF PKT_CNT_${PORT}=$PERF_PKT_CNT_INC,"
     #echo "$STATUS_PORT"
     write_state_file "${HOST}_$PORT.state"
     PORT=$(( PORT+1 ))
   done
   write_status "emSFP $TYPE HWver: $HW_VERSION, FPGAver: $FPGA_VERSION $STATUS_PORT|$PERF"
else
   set_critical
   write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"

fi

# bye
