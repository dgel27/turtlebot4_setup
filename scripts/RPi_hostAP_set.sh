#!/bin/bash

sudo apt install -y iw hostapd

cat <<\EOF >> tb4_hostapd.service
[Unit]
Description=HostAP Service
After=network.target
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=true
User=root
ExecStart=/usr/sbin/tb4_hostap_stsrt.sh

[Install]
WantedBy=multi-user.target
EOF

sudo mv tb4_hostapd.service

cat <<\EOF >> tb4_hostap_stsrt.sh
#!/bin/bash

iw dev wlan0 interface add uap0 type __ap
ip link set dev uap0 address 12:34:56:78:90:12
ip addr add 192.168.77.1/24 dev uap0
ip link set dev uap0 up

hostapd /etc/hostapd/hostapd.conf -B
busybox udhcpd /etc/udhcpd.conf
EOF

chmod +x hostap.sh
sudo mv tb4_hostap_stsrt.sh /usr/sbin/

cat <<\EOF >> hostapd.conf
interface=uap0
driver=nl80211
ssid=turtlebot4
channel=11
hw_mode=g
auth_algs=1
macaddr_acl=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
#Set a password for your access point
wpa_passphrase=turtlebot4
EOF

sudo mv hostapd.conf /etc/hostapd

cat <<\EOF >> udhcpd.conf
# Sample udhcpd configuration file (/etc/udhcpd.conf)

# The start and end of the IP lease block
start		192.168.77.20	#default: 192.168.0.20
end		192.168.77.40	#default: 192.168.0.254

# The interface that udhcpd will use
interface	uap0		#default: eth0

# The maximim number of leases (includes addressesd reserved
# by OFFER's, DECLINE's, and ARP conficts
max_leases	20		#default: 254

# If remaining is true (default), udhcpd will store the time
# remaining for each lease in the udhcpd leases file. This is
# for embedded systems that cannot keep time between reboots.
# If you set remaining to no, the absolute time that the lease
# expires at will be stored in the dhcpd.leases file.
#remaining	yes		#default: yes

# The time period at which udhcpd will write out a dhcpd.leases
# file. If this is 0, udhcpd will never automatically write a
# lease file. (specified in seconds)
#auto_time	7200		#default: 7200 (2 hours)

# The amount of time that an IP will be reserved (leased) for if a
# DHCP decline message is received (seconds).
#decline_time	3600		#default: 3600 (1 hour)

# The amount of time that an IP will be reserved (leased) for if an
# ARP conflct occurs. (seconds
#conflict_time	3600		#default: 3600 (1 hour)

# How long an offered address is reserved (leased) in seconds
#offer_time	60		#default: 60 (1 minute)

# If a lease to be given is below this value, the full lease time is
# instead used (seconds).
#min_lease	60		#defult: 60

# The location of the leases file
lease_file	/var/log/udhcpd.leases	#defualt: /var/lib/misc/udhcpd.leases

# The location of the pid file
#pidfile	/var/run/udhcpd.pid	#default: /var/run/udhcpd.pid

# Everytime udhcpd writes a leases file, the below script will be called.
# Useful for writing the lease file to flash every few hours.
#notify_file				#default: (no script)
#notify_file	dumpleases	# <--- useful for debugging

# The following are bootp specific options, setable by udhcpd.
#siaddr		192.168.0.22		#default: 0.0.0.0
#sname		zorak			#default: (none)
#boot_file	/var/nfs_root		#default: (none)

# The remainer of options are DHCP options and can be specifed with the
# keyword 'opt' or 'option'. If an option can take multiple items, such
# as the dns option, they can be listed on the same line, or multiple
# lines. The only option with a default is 'lease'.

#Examles
#opt	dns	192.168.10.2 192.168.10.10
option	subnet	255.255.255.0
opt	router	192.168.77.1
opt	ntpsrv	192.168.77.1
#opt	wins	192.168.10.10
#option	dns	129.219.13.81	# appened to above DNS servers for a total of 3
#option	domain	local
#option	lease	864000		# 10 days of seconds

# Currently supported options, for more info, see options.c
#opt subnet
#opt timezone
#opt router
#opt timesrv
#opt namesrv
#opt dns
#opt logsrv
#opt cookiesrv
#opt lprsrv
#opt bootsize
#opt domain
#opt swapsrv
#opt rootpath
#opt ipttl
#opt mtu
#opt broadcast
#opt wins
#opt lease
#opt ntpsrv
#opt tftp
#opt bootfile
#opt wpad

# Static leases map
#static_lease 00:60:08:11:CE:4E 192.168.0.54
#static_lease 00:60:08:11:CE:3E 192.168.0.44
static_lease	40:31:3C:AA:71:82	192.168.77.30
EOF

sudo mv udhcpd.conf /etc/
sudo systemctl enable tb4_hostapd.service

