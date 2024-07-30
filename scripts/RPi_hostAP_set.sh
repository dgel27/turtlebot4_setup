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
ExecStart=/usr/sbin/hostap.sh

[Install]
WantedBy=multi-user.target
EOF

sudo mv tb4_hostapd.service

cat <<\EOF >> hostap.sh
#!/bin/bash

iw dev wlan0 interface add uap0 type __ap
ip link set dev uap0 address 12:34:56:78:90:12
ip addr add 192.168.77.1/24 dev uap0
ip link set dev uap0 up

hostapd /etc/hostapd/hostapd.conf -B
busybox udhcpd /etc/udhcpd.conf
EOF

chmod +x hostap.sh
sudo mv hostap.sh /usr/sbin/

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
