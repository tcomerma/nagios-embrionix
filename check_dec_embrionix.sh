#!/bin/bash
# FILE: "check_dec_embrionix.sh"
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
V1P=0
V2P=0
V1S=0
V2S=0
M1P=""
M2P=""
M1S=""
M2S=""


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
    options=$($GETOPT -o H:t:h -l "v1p, v1s,v2p, v2s,m1p:,m2p:,m1s:,m2s:,host:,timeout:" -- "$@"); set -- "$options"
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
        --v1p)
            V1P=1
            ;;
        --v2p)
            V2P=1
            ;;
        --v1s)
            V1S=1
            ;;
        --v2s)
            V2S=1
            ;;
        -h)
            print_help
            exit 0
            ;;
        --m1p)
            shift;
            M1P=$1
            ;;
        --m2p)
            shift;
            M2P=$1
            ;;
        --m1s)
            shift;
            M1S=$1
            ;;
        --m2s)
            shift;
            M2S=$1
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
function check_decapsulator {
    OUT=$1    
    TYPE=`echo "$OUT" | jq -c ".type" | tr -d '"'`
    if [[ ${TYPE:0:1} != "9" ]]
    then
      set_critical
      write_status "ERROR: Device type is not a decapsulator"
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

function check_channel {
    CH=$1
    CH_NAME=$2
    OUT_VAR_NAME=$3
    if [ "$CH" == "1" ]
    then
        check_video "${!OUT_VAR_NAME}"
        if [ "$VIDEO_VALID" == "0" ]
        then 
            STATE_MSG="$STATE_MSG OUT ${CH_NAME}:(NO VIDEO OUT)"
            set_warning
        else
            STATE_MSG="$STATE_MSG OUT ${CH_NAME}:$VIDEO_FORMAT"
        fi
    fi
}

function check_multicast_channel {
    CH=$1
    CH_NAME=$2
    OUT_VAR_NAME=$3
    if [ -n "$CH" ]
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
    write_status "$HOST no respon (curl error $CURL_STATUS)"
fi
check_decapsulator "$OUT0"

# Get API info
if [ "$V1P" -eq 1 -o -n "$M1" ]
then
   OUT1P=$(api_result "/emsfp/node/v1/flows/a04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "$HOST no respon (curl error $CURL_STATUS)"
   fi
fi

if [ "$V2P" -eq 1 -o -n "$M2" ]
then
   OUT2P=$(api_result "/emsfp/node/v1/flows/b04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "$HOST no respon (curl error $CURL_STATUS)"
   fi
fi

if [ "$V1S" -eq 1 -o -n "$M2" ]
then
   OUT1S=$(api_result "/emsfp/node/v1/flows/c04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "$HOST no respon (curl error $CURL_STATUS)"
   fi
fi

if [ "$V2S" -eq 1 -o -n "$M2" ]
then
   OUT2S=$(api_result "/emsfp/node/v1/flows/d04f66a2-9910-11e5-8894-feff819cdc9f")
   ST=$?
   if [ $ST -ne 0 ]
   then
      set_critical
      write_status "$HOST no respon (curl error $CURL_STATUS)"
   fi
fi




# Check video 
check_channel "$V1P" "1P" "OUT1P"
check_channel "$V1S" "1S" "OUT1S"
check_channel "$V2P" "2P" "OUT2P"
check_channel "$V2S" "2S" "OUT2S"


# Check multicast 2
#if [ -n "$M2" ]
#then
#   DEV_MCAST=$(check_multicast "$OUT2")
#   if [ "$DEV_MCAST" != "$M2" ]
#   then 
#      STATE_MSG="$STATE_MSG OUT 2:Wrong MCast group $DEV_MCAST"
#      set_critical
#    else
#      STATE_MSG="$STATE_MSG OUT 2:MCast group OK"
#   fi   
#fi

write_status "$STATE_MSG"
exit $STATE
# bye