#!/bin/bash

# ip_failover.sh
# Author: Aleksandar Stoykovski <bavarien362@protonmail.ch>
# IP failover script is responsible for keeping ${failover_ip} up and running.
# BEFORE RUNNING CHECK BELLOW: 
# Global variable such as ${server} need to be setup manually.
# ${server} always points to the remote host.
# ${failover_interface} is the virtual interface on which the virtual IP 
# ${failover_ip} is running.
# ${login_user} needs to be created on both systems, with ssh keys for
# for password less login.
# Tested with 2 systems. Replace IP in ${server} with remote IP
# to suit your configuration. Replace failover_interface and failover_ip to
# your configuration.

server="192.168.1.43"
failover_interface="enp0s3:0"
failover_ip="192.168.1.45"
login_user="failover"
date="$(date +%Y-%m-%d_%H-%M-%S)"

function ifup() {
   # First check if local system has the virtual interface up.
   # If interface is not up, check remote system.
   # Server should be able to reach each other in order to check if
   # the failover_interface is taken.
   ifconfig "${failover_interface}" | grep -q "${failover_ip}"
   if [[ ${?} -ne 0 ]]; then
     echo ""${date}" | Failover IP "${failover_ip}" is not running on this $(hostname) "
     echo ""${date}" | Checking remote system "${server}""

     ssh "${login_user}"@"${server}" \
     "$(which ifconfig) "${failover_interface}" | grep "${failover_ip}""
     if [[ "${?}" -ne 0 ]]; then
       echo ""${date}" | Failover IP "${failover_ip}" not running on remote system"
       echo
       # If remote system is not available or interface is not taken
       # start the failover and assign virtual ip.
       ip_failover
     else
       # If other system has the interface, start pinging.
       echo ""${date}" | Failover IP "${failover_ip}" running on remote system"
       echo
       keep_alive
     fi
   fi
   echo
   echo ""${date}" | System is primary"
   exit 0
  
}

function keep_alive() {
  # Ping the remote system with one packages, if is not responding add + 1
  # to COUNTER, if COUNTER reaches 15 it will assume remote system is down
  # and will start the virtual interface. ping is not the fastest tool when
  # returning exit status even setting timeout is not really of help.
  # COUNT=15 is arround 20-30 secounds based on the testing in my virtual env.
  # Standard output from ping is send to /dev/null as it generates huge log.
  COUNTER=0
  while true; do 
    ping -c 1 "${server}" > /dev/null
    if [[ "${?}" -ne 0 ]]; then 
      echo "${COUNTER}"
      COUNTER=$[${COUNTER} +1]
      #sleep 1
    else
      COUNTER=0
    fi
      if [[ "${COUNTER}" -eq 15 ]]; then 
        echo ok
        COUNTER=0
        ip_failover
      fi
  done

}

function ip_failover() {
  echo ""${date}" | Starting failover process, switching to IP "${failover_ip}""
  echo  
  echo ""${date}" | ifconfig "${failover_interface}" "${failover_ip}""
  sudo ifconfig "${failover_interface}" "${failover_ip}"
  if [[ "${?}" -ne 0 ]]; then
    echo ""${date}" | Cannot setup failover interface, manual check needed."
    exit 1
  fi
  exit 0
}


# Main function.
function main() {
  # Log stdout and stderr.
  exec > >(tee -a /tmp/ip_failover_$(date +%Y-%m-%d).log)

  # Call ifup function.
  ifup

}

main "${@}"
