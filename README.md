nagios-embrionix

Scripts to monitor embrionix emsfp-2022 devices.
version: 1.0
Toni Comerma - CCMA
April 2019

check_embrionix_alive.sh -H <IP> [-t <timeout>]
    Checks if device alive and gets basic information

    Example:
    check_embrionix_alive.sh -H 10.4.1.30
    OK: E_NAME_XX: 8 - 2022-6/7 Encapsulator, EMSFP: A2xx, Version: 0x0000034e

check_enc_embrionix.sh -H <IP> [-t <timeout>] [--v1] [--v2] [--m1 <IP>:<PORT>] [--m2 <IP>:<PORT>]
    Checks encapsulator config
      --v1: Checks if video present on port 1 primary
      --v2: Checks if video present on port 2 primary
      --m1: Checks multicast group configured to ensure nobody has changed it. For port 1 primary
      --m2: idem. For port 2 primary

    Example:
    check_enc_embrionix.sh -H 10.4.1.30 --v1 --v2 --m1 239.197.1.11:5000
    CRITICAL:  IN 1:Wrong MCast group 239.197.1.10:5000 IN 1:(HD-SDI INTERLACED 1920x1080) IN 2:(HD-SDI INTERLACED 1920x1080)

check_dec_embrionix.sh -H <IP> [-t <timeout>] [--v1p] [--v2p] [--v1s] [--v2s] [--m1p <IP>:<PORT>] [--m2p <IP>:<PORT>] [--m1s <IP>:<PORT>] [--m2s <IP>:<PORT>]
   Checks encapsulator config
      --v1p: Checks if video present on port 1 primary
      --v2p: Checks if video present on port 2 primary
      --v1s: Checks if video present on port 1 secondary
      --v2s: Checks if video present on port 2 secondary
      --m1p: Checks multicast group configured to ensure nobody has changed it. For port 1 primary
      --m2p: idem. For port 2 primary
      --m1s: idem. For port 1 secondary
      --m2s: idem. For port 2 secondary
    Example
    check_dec_embrionix.sh -H 10.4.1.150 --v1p --v2p --v1s --v2s
    WARNING:  OUT 1P:(3G-SDI PROGRESSIVE 1920x1080) OUT 1S:(NO VIDEO OUT) OUT 2P:(NO VIDEO OUT) OUT 2S:(NO VIDEO OUT)