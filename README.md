check_embrionix.sh

Script to monitor embrionix emsfp-2022 devices.
version: 0.1
Toni Comerma
April 2017

Parameters
-H host
-p port (defaults to 8080)
-n novideo: returns OK instead of WARNING if there is no video.
-t timeout


Performance
The script returns the increment of the variable tx_pkt_cnt/rx_pkt_cnt as performance counter.
