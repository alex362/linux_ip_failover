# linux_ip_failover.sh
Objective
Host extra IP address on systems. Only one machine owns that IP address at a time, if one fails the other will take over the same IP address.

Detailed design

I took into account the scenario with 2 host running as only one has the virtual IP hosted at a time. 

server1 ⇒ 192.168.1.43  192.168.1.45 
server2 ⇒ 192.168.1.44 

server1 DOWN
server2 ⇒ 192.168.1.44 192.168.1.45

The program needs to be copied on both host and user account needs to be created with public/private ssh key for passwordless login. This is necessary for the script to be able to check the remote host for active virtual interface.
Variables that need to be setup before running the scripts are:

server="192.168.1.43"  >> always points to the remote system. Needs to be setup for every host
failover_interface="enp0s3:0"  >> the interface which hosts the virtual IP
failover_ip="192.168.1.45"  >> failover ip only one system has it assign at a time
login_user="failover" >> user for ssh login

When the ifup function is called it checks locally if the virtual interface is setup, if the interface is not up it ssh’s to the remote server and checks there. 
If the remote doesn’t have the failover_ip, or we cannot ssh, it assumes that it needs to initiate the failover and bring up the failover_ip  on the host is running so it jumps to ip_failover function and starts it.

If the remote host has the failover_ip  the script will jump to keep_alive function and will continuously ping the server. In case the server  is not “pingable” anymore the while loop will 
add + 1 to COUNTER, once COUNTER reaches 15 it assumes the remote host is down and will jump to keep_alive and start the virtual interface. When still in the while loop, when doing ping if remote system comes up, COUNTER will reset to 0 and ping will continue.


Further development and thoughts

As the script exits any time it runs the ip_failover, crontab job can be setup to make sure it runs even after failover_ip is up to make sure that no temporary network glitches are causing unexpected behaviour. Or maybe even upstart job can be create to run the script more often.

I was not really happy with how ping takes a lot of time to send new package when remote system is down. I tried to put different option to make it work faster but was not able to. Seems that it responds on different system differently on my testing environment where i have RHEL7 it was slower, but when i was running the script from Ubuntu 14.04 it was much faster.

I haven’t tried to use more hosts than two as i didn’t find it practical enough to ssh in all to check if the interface is up. In cluster environment based on what i can tell, there is a common storage or a common system which when the hosts are up … they are “fencing” and “competing” to “lock” the storage to host  service/package or in our case the failover_ip. ping is not really good in pinging multiple hosts either (or maybe it is and i don’t know it).
