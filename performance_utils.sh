# Functions for managing incrementing performance counters (gauges) that
# increments between executions and so, they require persistence to file.

# Usage
# Performance vars MUST:
#   Begin with PERF_
#   Variables stored in file will end with _PRE
#   Variables fetched in current execution MUST end in _CUR
#   Calculated variables will not have suffix

# TODO: Handle 32 bit counter overflow

function get_current_time {
  date +%s
}

function print_all_vars {
  local vars=""

  echo "TIME_PRE=$TIME_PRE"
  echo "TIME_CUR="`get_current_time`
  echo "TIME_DIFF="$((`get_current_time`-$TIME_PRE))

  vars=`compgen -A variable | grep "PERF_.*_CUR"`
  for v in $vars
  do
    local vname_cur=${v}
    local vname_pre=${v%_CUR}_PRE
    local vname_inc=${v%_CUR}_INC
     echo "$vname_cur=${!vname_cur}, $vname_pre=${!vname_pre}, $vname_inc=${!vname_inc}"
  done

}

function read_state_file {
  local file=$1

  # Clear previous vars
  vars=`compgen -A variable | grep "PERF_.*_PRE"`
  for v in $vars
  do
    eval ${v}=""
  done
  unset TIME_PRE
  # Read from file
  if [ -f $file ]
  then
    source $file
  fi
}


function write_state_file {
  local file=$1
  local vars=""

  echo "TIME_PRE="`get_current_time` >  $file

  vars=`compgen -A variable | grep "PERF_.*_CUR"`
  for v in $vars
  do
     vname=${v%_CUR}_PRE
     echo "$vname=${!v}" >> $file
  done


}

function calc_diff {
  local vars=""
  local t=`get_current_time`

  vars=`compgen -A variable | grep "PERF_.*_CUR"`
  for v in $vars
  do
     local vname_cur=${v}
     local vname_pre=${v%_CUR}_PRE
     local vname_inc=${v%_CUR}_INC
     if [ -z "${!vname_pre}" ]
     then
        eval ${vname_pre}=${!vname_cur}
     fi
     if [ -z "$TIME_PRE" ]
     then
        TIME_PRE=0
     fi
     eval ${vname_inc}=$(( (${!vname_cur}-${!vname_pre})/($t-$TIME_PRE) ))
  done

}
