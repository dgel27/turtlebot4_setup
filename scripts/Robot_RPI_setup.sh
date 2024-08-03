#!/bin/bash

# Script to create SD card for iRobot Humble from scratch
#
#

sudo dpkg-divert --rename --divert /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled --add /etc/apt/apt.conf.d/20apt-esm-hook.conf
sudo dpkg-divert --rename --divert /etc/apt/apt.conf.d/99needrestart.disabled --add /etc/apt/apt.conf.d/99needrestart
sudo echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
sudo echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl mask apt-daily-upgrade.service
sudo systemctl disable apt-daily.timer
sudo systemctl mask apt-daily.service


#sudo apt install software-properties-common
sudo add-apt-repository universe

# Add ROS2 repository
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null


# Remove UBUNTU stuff
sudo systemctl stop unattended-upgrades

sudo apt purge --auto-remove -y \
ubuntu-advantage-tools \
snapd unattended-upgrades \
cloud-init \
friendly-recovery \
apport \
eject

#sudo apt -y autoremove


sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

sudo apt update && sudo apt upgrade -y

# Install and config chrony
sudo apt install -y \
iptables-persistent \
nmap \
adb \
mc \
iw \
hostapd \
picocom \
chrony \
ros-humble-ros-base \
ros-humble-irobot-create-msgs \
ros-humble-demo-nodes-cpp \
ros-humble-teleop-twist-keyboard \
ros-humble-rplidar-ros






















# create network-config file with content:

cat <<\EOF >> 40_ether.yaml
network:
    version: 2
    ethernets:
# Rpi eternet RJ-45 usualy camera connected
        eth0:
            dhcp4: true
            optional: true
            mtu: 1400
            addresses: [192.168.185.3/24]
# Askey 5G USB dongle
        eth1:
            dhcp4: false
            optional: true
            mtu: 1400
            addresses: [192.168.43.3/24]
            routes:
            - to: 10.100.100.0/24
              via: 192.168.43.1
              metric: 100
              on-link: true
# Create3 iRobot interface
        usb0:
            dhcp4: false
            optional: true
            addresses: [192.168.186.3/24]
# Telit 5G USB dongle
        usb1:
            dhcp4: true
            mtu: 1400
            optional: true
            addresses: [192.168.225.3/24]
            routes:
            - to: 10.100.100.0/24
              via: 192.168.225.1
              metric: 100
              on-link: true
EOF

sudo mv 40_ether.yaml /etc/netplan/
sudo chmod 600 /etc/netplan/*.yaml
sudo netplan generate



sudo sed -i -e '$a\'$'\n''dtoverlay=dwc2,dr_mode=peripheral' /boot/firmware/config.txt
sudo sed -i -e '$a\'$'\n''dtoverlay=i2c-gpio,bus=3,i2c_gpio_delay_us=1,i2c_gpio_sda=4,i2c_gpio_scl=5' /boot/firmware/config.txt
sudo sed -i 's|rootwait|rootwait modules-load=dwc2,g_ether|g' /boot/firmware/cmdline.txt





# Iptables rules
# TODO: split parts with dynamic udev rules

cat <<\EOF >> rules.v4
# Generated by iptables-save v1.8.4 on Sat Aug 13 08:48:05 2022
*filter
:INPUT ACCEPT [1375988:251050748]
:FORWARD ACCEPT [7825:6434598]
:OUTPUT ACCEPT [604072:92996726]
-A FORWARD -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
-A FORWARD -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A FORWARD -p tcp -m state --state NEW -m tcp --dport 554 -j ACCEPT
-A FORWARD -p udp -m state --state NEW -m udp --dport 554 -j ACCEPT
COMMIT
# Completed on Sat Aug 13 08:48:05 2022
# Generated by iptables-save v1.8.4 on Sat Aug 13 08:48:05 2022
*nat
:PREROUTING ACCEPT [18:4716]
:INPUT ACCEPT [15:4620]
:OUTPUT ACCEPT [203:15612]
:POSTROUTING ACCEPT [4:252]
-A PREROUTING -p tcp -m tcp --dport 8180 -j DNAT --to-destination 192.168.43.1:80
-A PREROUTING -p tcp -m tcp --dport 8280 -j DNAT --to-destination 192.168.225.1:80
-A PREROUTING -p tcp -m tcp --dport 8122 -j DNAT --to-destination 192.168.43.1:22
-A PREROUTING -p tcp -m tcp --dport 8222 -j DNAT --to-destination 192.168.225.1:22
-A PREROUTING -p tcp -m tcp --dport 8081 -j DNAT --to-destination 192.168.185.5:80
-A PREROUTING -p tcp -m tcp --dport 8022 -j DNAT --to-destination 192.168.185.5:22
-A PREROUTING -p tcp -m tcp --dport 554 -j DNAT --to-destination 192.168.185.5:554
-A PREROUTING -p udp -m udp --dport 554 -j DNAT --to-destination 192.168.185.5:554
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.186.2:80
-A POSTROUTING -o wlan0 -j MASQUERADE
-A POSTROUTING -o eth0 -j MASQUERADE
-A POSTROUTING -o eth1 -j MASQUERADE
-A POSTROUTING -o usb1 -j MASQUERADE
-A POSTROUTING -o usb0 -j MASQUERADE
COMMIT
# Completed on Sat Aug 13 08:48:05 2022
EOF
#sudo mkdir /etc/iptables/
sudo mv rules.v4 /etc/iptables/

# Enable packets redirecting
sudo sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf

# udev rules
# TODO: add actions when new device added
cat <<\EOF >> 50_robot.rules

SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK="RPLIDAR", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"
SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="dialout", MODE="0660"
SUBSYSTEM=="i2c-dev", KERNEL=="i2c*", GROUP="dialout", MODE="0666"
SUBSYSTEM=="spidev", KERNEL=="spidev*", GROUP="dialout", MODE="0660"
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="dialout", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTRS{idProduct}=="9059", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="1bc7", ATTRS{idProduct}=="1052", MODE="0666", GROUP="plugdev"
EOF

sudo mv 50_robot.rules /etc/udev/rules.d/

# Add fastdds discovery server
cat <<\EOF >> fastddsdiscovery.sh
#!/bin/bash
source /opt/ros/humble/setup.bash
/opt/ros/humble/bin/fast-discovery-server -i0
EOF

sudo mv fastddsdiscovery.sh /usr/sbin/
sudo chmod +x /usr/sbin/fastddsdiscovery.sh


cat <<\EOF >> tb4_fastdds.service
[Unit]
Description=FastDDS discovery server
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=1
ExecStart=/bin/bash -e /usr/sbin/fastddsdiscovery.sh

[Install]
WantedBy=multi-user.target
EOF

sudo mv tb4_fastdds.service /etc/systemd/system


# Create FastDDS profile file
cat <<\EOF >> rpi_fastdds_superclient.xml
<?xml version="1.0" encoding="UTF-8" ?>
<dds>
    <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
        <participant profile_name="super_client_profile" is_default_profile="true">
            <rtps>
                <builtin>
                    <discovery_config>
                        <discoveryProtocol>SUPER_CLIENT</discoveryProtocol>
                        <discoveryServersList>
                            <RemoteServer prefix="44.53.00.5f.45.50.52.4f.53.49.4d.41">
                                <metatrafficUnicastLocatorList>
                                    <locator>
                                        <udpv4>
                                            <address>127.0.0.1</address>
                                            <port>11811</port>
                                        </udpv4>
                                    </locator>
                                </metatrafficUnicastLocatorList>
                            </RemoteServer>
                        </discoveryServersList>
                    </discovery_config>
                </builtin>
            </rtps>
        </participant>
    </profiles>
</dds>
EOF

cat <<\EOF >> rpi_fastdds_local.xml
<?xml version="1.0" encoding="UTF-8" ?>
<dds>
    <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
        <participant profile_name="turtlebot4_default_profile" is_default_profile="true">
            <rtps/>
        </participant>
    </profiles>
</dds>
EOF

# ROS2 helpful aliases
cat <<\EOF >> ros2_aliases.sh
# Restart ROS2 daemon
alias robot-daemon-restart='ros2 daemon stop; ros2 daemon start'

# Restart ntpd on Create 3
alias robot-ntpd-sync='curl -X POST http://192.168.186.2/api/restart-ntpd'

robot_dock()
{
	ros2 action send_goal /dock irobot_create_msgs/action/Dock "{}"
}

robot_undock()
{
	ros2 action send_goal /undock irobot_create_msgs/action/Undock "{}"
}

robot_control()
{
	ros2 run teleop_twist_keyboard teleop_twist_keyboard
}

robot_move()
{
       ros2 action send_goal \
             /drive_distance irobot_create_msgs/action/DriveDistance \
             "{distance: ${1},max_translation_speed: 0.15}"
}

robot_navto()
{
       ros2 action send_goal \
             /navigate_to_position irobot_create_msgs/action/NavigateToPosition \
             "{achieve_goal_heading: true,goal_pose:{pose:{position:{x: 1,y: 0.2,z: 0.0}, orientation:{x: 0.0,y: 0.0, z: 0.0, w: 1.0}}}}"
}


robot_rotate()
{
	ros2 action send_goal \
             /rotate_angle irobot_create_msgs/action/RotateAngle \
             "{angle: ${1},max_rotation_speed: 0.5}"
}

robot_arc()
{
        ros2 action send_goal \
             /drive_arc irobot_create_msgs/action/DriveArc \
             "{angle: 1.57,radius: 0.3,translate_direction: 1,max_translation_speed: 0.3}"
}

robot_pwr_off()
{
	ros2 service call /robot_power irobot_create_msgs/srv/RobotPower "{}"
}

create3_update()
{
	echo "Image path: $1";
	curl -X POST --data-binary @$1 http://192.168.186.2/api/firmware-update
}

lidar_stop()
{
	ros2 service call /stop_motor std_srvs/srv/Empty "{}"
}

lidar_start()
{
	ros2 service call /start_motor std_srvs/srv/Empty "{}"
}
EOF

sudo mkdir /etc/robot
chmod +x ros2_aliases.sh
sudo mv rpi_fastdds_superclient.xml /etc/robot
sudo mv rpi_fastdds_local.xml /etc/robot
sudo mv ros2_aliases.sh /etc/robot


# chrony config
sudo sed -i '/maxsources 2/a #\n\n# Create3 settings:\n#server 192.168.186.2 presend 0 minpoll 0 maxpoll 0 iburst prefer trust\nallow 192.168.186.0/24\nlocal stratum 10' /etc/chrony/chrony.conf

# Enable FastDDS discovery server
sudo systemctl enable tb4_fastdds.service




cat <<\EOF >> tb4_hostapd.service
[Unit]
Description=HostAP Service
After=network.target
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=true
User=root
ExecStart=/usr/sbin/tb4_hostap_start.sh

[Install]
WantedBy=multi-user.target
EOF

sudo mv tb4_hostapd.service /etc/systemd/system/

cat <<\EOF >> tb4_hostap_start.sh
#!/bin/bash

iw dev wlan0 interface add uap0 type __ap
ip link set dev uap0 address 12:34:56:78:90:12
ip addr add 192.168.77.1/24 dev uap0
ip link set dev uap0 up

hostapd /etc/hostapd/hostapd.conf -B
busybox udhcpd /etc/udhcpd.conf
EOF

chmod +x tb4_hostap_start.sh
sudo mv tb4_hostap_start.sh /usr/sbin/

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

# TODO: create tb4_start.service
# ros2 launch turtlebot4_bringup standard.launch.py





# ROS2 sourcing
echo >> ~/.bashrc
echo "# ROS2 settings" >> ~/.bashrc
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
echo "source /etc/robot/ros2_aliases.sh" >> ~/.bashrc
echo "export RMW_IMPLEMENTATION=rmw_fastrtps_cpp" >> ~/.bashrc
echo "export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/robot/rpi_fastdds_superclient.xml" >> ~/.bashrc
echo "#export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/robot/rpi_fastdds_local.xml" >> ~/.bashrc
