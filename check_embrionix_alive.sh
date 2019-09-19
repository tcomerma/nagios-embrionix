#!/bin/bash
# FILE: "check_embrionix_alive.sh"
# DESCRIPTION: Check status of embrionix emsfp-2022 devices.
# AUTHOR: Toni Comerma
# DATE: september-2019
#
# Notes:
#   Verifica que pot contactar i mostra dades bàsiques.
# Examples
#
#
#



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


function print_help() {
  echo "Usage:"
  echo "  $PROGNAME -H <host> -t <timeout> "
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
    options=$($GETOPT -o H:t:h -l "host:,timeout:" -- "$@"); set -- "$options"
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
        -h)
            print_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
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
function get_type {
    OUT=$1    
    TYPE=`echo "$OUT" | jq -c ".type" | tr -d '"'`
    echo $TYPE
} 

function get_name {
    OUT=$1    
    NAME=`echo "$OUT" | jq -c ".network.hostname" | tr -d '"'`
    echo $NAME
} 

function get_emsfp_version {
    OUT=$1    
    NAME=`echo "$OUT" | jq -c ".emsfp_version" | tr -d '"'`
    echo $NAME
} 

function get_version {
    OUT=$1    
    NAME=`echo "$OUT" | jq -c ".current_version" | tr -d '"'`
    echo $NAME
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

# Check basic info
# Get API info
OUT0=$(api_result "/emsfp/node/v1/self/diag/common")
ST=$?
if [ $ST -ne 0 ]
then
    set_critical
    write_status "$HOST no respon (curl error $CURL_STATUS)"
fi
NAME=`get_name "$OUT0"`

# Get API info
OUT0=$(api_result "/emsfp/node/v1/self/information")
ST=$?
if [ $ST -ne 0 ]
then
    set_critical
    write_status "$HOST no respon (curl error $CURL_STATUS)"
fi

TYPE=`get_type "$OUT0"`
EMSFP_VERSION=`get_emsfp_version "$OUT0"`
VERSION=`get_version "$OUT0"`


write_status "$NAME: $TYPE, EMSFP: $EMSFP_VERSION, Version: $VERSION"

exit $STATE_OK
# bye