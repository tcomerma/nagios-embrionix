#!/bin/bash
# FILE: "check_enc_embrionix.sh"
# DESCRIPTION: Check status of embrionix emsfp-2022 devices.
# AUTHOR: Toni Comerma
# DATE: august-2019
#
# Notes:

# Examples
#
#
#

# TODO
# Check is encoder
# help

PROGNAME=`basename $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION='Version: 1.0'

STATE_DIR="$PROGPATH"

CURL=`which curl`
OPTIONS="-s"
GETOPT=`which getopt`

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

STATE=$STATE_OK
STATE_MSG=""
HOST=""
PORT=80
TIMEOUT=4
V1=0
V2=0
M1=""
M2=""


function print_help() {
  echo "Usage:"
  echo "  $PROGNAME -H <host> -t <timeout> --v1 --v2 "
  echo "  $PROGNAME -h "
        echo ""
        echo "Opcions:"
        echo "  -H IP or hostmame "
        echo "  -t timeout, defaults to 4"
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

function read_params {
    # Parameters processing
    # 
    # check if gnu-getopt installed
    out=$(getopt -T)
    # error status != 4 and output is non-empty (ie = '--')
    if (( $? != 4 )) && [[ -n $out ]]; then
        if [ -f /usr/local/opt/gnu-getopt/bin/getopt ]; then
          GETOPT='/usr/local/opt/gnu-getopt/bin/getopt'
        fi
    fi
    options=$($GETOPT -o H:t:h -l "v1,v2,m1:,m2:,host:,timeout:" -- "$@"); set -- "$options"
    [ $? -eq 0 ] || { 
        echo "Incorrect options provided"
        exit 1
    }
    eval set -- "$options"
    while true; do
        case "$1" in
        --host | -H )
            shift;
            HOST=$1
            ;;
        --timeout | -t)
            shift;
            TIMEOUT=$1
            ;;
        --v1)
            V1=1
            ;;
        --v2)
            V2=1
            ;;
        -h)
            print_help
            exit 0
            ;;
        --m1)
            shift;
            M1=$1
            ;;
        --m2)
            shift;
            M2=$1
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
}

function video_format {
    MODE=$1
    P_SCAN=$2
    FORMAT=$3
  
    case "$MODE" in
    0 )
        TEXT_MODE="HD-SDI"
        ;;
    8)
        TEXT_MODE="SD-SDI"
        ;;
    16)
        TEXT_MODE="3G-SDI"
        ;;
    *)  TEXT_MODE=""
        ;;
    esac
    case "$P_SCAN" in
    0 )
        TEXT_P_SCAN="INTERLACED"
        ;;
    4)
        TEXT_P_SCAN="PROGRESSIVE"
        ;;
    *)  TEXT_P_SCAN=""
        ;;
    esac
    case "$FORMAT" in
    0 )
        TEXT_FORMAT="1920x1080"
        ;;
    64)
        TEXT_FORMAT="1280x720"
        ;;
    512)
        TEXT_FORMAT="(525i) 720x483"
        ;;
    576)
        TEXT_FORMAT="(625i) 720x576"
        ;;
    *)  TEXT_FORMAT=""
        ;;
    esac
    echo "($TEXT_MODE $TEXT_P_SCAN $TEXT_FORMAT)"
}

function api_result {
    API_CALL="$1"
    URL="http://${HOST}:${PORT}${API_CALL}"
    OUT=`curl $URL $OPTIONS --max-time $TIMEOUT -o - `
    CURL_STATUS=$?
    # curl return status
    if [ $CURL_STATUS -eq 0 ]
    then
      echo $OUT
    else
      set_critical
      write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"
    fi
}
function check_encapsulator {
    OUT=$1    
    TYPE=`echo "$OUT" | jq -c ".type" | tr -d '"'`
    if [[ ${TYPE:0:1} != "8" ]]
    then
      set_critical
      write_status "ERROR: Device type is not an encapsulator"
    fi
} 

function check_video {
    OUT=$1
      # Video status
      VIDEO_VALID=`echo "$OUT" | jq -c ".format_code_valid" | tr -d '"'`
      # Get Video characteristics
      VIDEO_FORMAT_CODE_MODE=`echo "$OUT" | jq -c ".format_code_mode" | tr -d '"' `
      VIDEO_FORMAT_CODE_P_SCAN=`echo "$OUT" | jq -c ".format_code_p_scan" | tr -d '"' `
      VIDEO_FORMAT_CODE_FORMAT=`echo "$OUT" | jq -c ".format_code_format" | tr -d '"' `
      VIDEO_FORMAT=$(video_format $VIDEO_FORMAT_CODE_MODE $VIDEO_FORMAT_CODE_P_SCAN $VIDEO_FORMAT_CODE_FORMAT)
} 
function check_multicast {
    OUT=$1    
    # mcast settings
    DEV_MCAST_IP=`echo "$OUT" | jq -c ".network.dst_ip_addr" | tr -d '"'`
    DEV_MCAST_PORT=`echo "$OUT" | jq -c ".network.dst_udp_port" | tr -d '"'`
    echo "$DEV_MCAST_IP:$DEV_MCAST_PORT"
} 

################################
# main program
#
read_params "$@" 


if [ ! "$HOST" ] ; then
        echo " Error - No Address (IP or hostmame) provided "
        echo ""
        print_help
        echo ""
fi

# Check if encapsulator
# Get API info
OUT0=$(api_result "/emsfp/node/v1/self/information")
ST=$?
if [ $ST -ne 0 ]
then
    set_critical
    write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"
fi
check_encapsulator "$OUT0"

# Get API info
if [ "$V1" -eq 1 -o -n "$M1" ]
then
   OUT1=$(api_result "/emsfp/node/v1/flows/a04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"
   fi
fi

if [ "$V2" -eq 1 -o -n "$M2" ]
then
   OUT2=$(api_result "/emsfp/node/v1/flows/b04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "ERROR: Unable to contact $HOST (curl error $CURL_STATUS)"
   fi
fi

# Check multicast 1
if [ -n "$M1" ]
then
   DEV_MCAST=$(check_multicast "$OUT1")
   if [ "$DEV_MCAST" != "$M1" ]
   then 
      STATE_MSG="$STATE_MSG IN 1:Wrong MCast group $DEV_MCAST"
      set_critical
    else
      STATE_MSG="$STATE_MSG IN 1:MCast group OK"
   fi   
fi

# Check video in 1
if [ "$V1" == "1" ]
then
   check_video "$OUT1"
   if [ "$VIDEO_VALID" == "0" ]
   then 
      STATE_MSG="$STATE_MSG IN 1:(NO VIDEO IN)"
      set_warning
   else
      STATE_MSG="$STATE_MSG IN 1:$VIDEO_FORMAT"
   fi
fi
# Check multicast 2
if [ -n "$M2" ]
then
   DEV_MCAST=$(check_multicast "$OUT2")
   if [ "$DEV_MCAST" != "$M2" ]
   then 
      STATE_MSG="$STATE_MSG IN 2:Wrong MCast group $DEV_MCAST"
      set_critical
    else
      STATE_MSG="$STATE_MSG IN 2:MCast group OK"
   fi   
fi

# Check video in 2
if [ "$V2" == "1" ]
then
   check_video "$OUT2"
   if [ "$VIDEO_VALID" == "0" ]
   then 
      STATE_MSG="$STATE_MSG IN 2: (NO VIDEO IN)"
      set_warning
   else
      STATE_MSG="$STATE_MSG IN 2:$VIDEO_FORMAT"
   fi
fi

write_status "$STATE_MSG"

# bye