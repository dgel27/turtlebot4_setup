#!/bin/bash

# Script to create SD card for iRobot Humble from scratch
#
#
# create network-config file with content:

cat <<\EOF >> 40_ether.yaml
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

sudo cp 40_ether.yaml /etc/netplan/
sudo cfmod 6666 /etc/netplan/*.yaml
sudo netplan generate

sudo sed -i -e '$a\'$'\n''dtoverlay=dwc2,dr_mode=peripheral' /boot/firmware/config.txt
sudo sed -i 's|rootwait|rootwait modules-load=dwc2,g_ether|g' /boot/firmware/cmdline.txt



sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

#sudo apt install software-properties-common
sudo add-apt-repository universe
# Add ROS2 repository



sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Remove UBUNTU stuff
sudo systemctl stop unattended-upgrades
sudo apt purge -y ubuntu-advantage-tools snapd unattended-upgrades cloud-init
sudo apt -y autoremove
sudo dpkg-divert --rename --divert /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled --add /etc/apt/apt.conf.d/20apt-esm-hook.conf
#touch /etc/cloud/cloud-init.disabled


# Iptables rules
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
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.185.5:80
-A PREROUTING -p tcp -m tcp --dport 8022 -j DNAT --to-destination 192.168.185.5:22
-A PREROUTING -p tcp -m tcp --dport 554 -j DNAT --to-destination 192.168.185.5:554
-A PREROUTING -p udp -m udp --dport 554 -j DNAT --to-destination 192.168.185.5:554
-A PREROUTING -p tcp -m tcp --dport 8081 -j DNAT --to-destination 192.168.186.2:80
-A POSTROUTING -o wlan0 -j MASQUERADE
-A POSTROUTING -o eth0 -j MASQUERADE
-A POSTROUTING -o eth1 -j MASQUERADE
-A POSTROUTING -o usb1 -j MASQUERADE
-A POSTROUTING -o usb0 -j MASQUERADE
COMMIT
# Completed on Sat Aug 13 08:48:05 2022
EOF
sudo mkdir /etc/iptables/
sudo mv rules.v4 /etc/iptables/

# Enable packets redirecting
sudo sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf

# udev rules
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

# TODO: Add fastdds discovery server
cat <<\EOF >> fastddsdiscovery.sh
#!/bin/bash
source /opt/ros/humble/setup.bash
fastdds discovery -i 0 -p 11811
EOF

sudo mv fastddsdiscovery.sh /usr/sbin/
sudo chmod +x /usr/sbin/fastddsdiscovery.sh


cat <<\EOF >> fastdds.service
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

sudo mv fastdds.service /etc/systemd/system


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

sudo apt update && sudo apt upgrade -y

# Install and config chrony
sudo apt install -y iptables-persistent nmap \
adb mc picocom chrony ros-humble-ros-base \
ros-humble-irobot-create-msgs ros-humble-demo-nodes-cpp \
ros-humble-teleop-twist-keyboard ros-humble-rplidar-ros

# chrony config
sudo sed -i '/maxsources 2/a #\n\n# Create3 settings:\n#server 192.168.186.2 presend 0 minpoll 0 maxpoll 0 iburst prefer trust\nallow 192.168.186.0/24\nlocal stratum 10' /etc/chrony/chrony.conf

# Enable FastDDS discovery server
sudo systemctl enable fastdds.service

# ROS2 sourcing
echo >> ~/.bashrc
echo "# ROS2 settings" >> ~/.bashrc
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
echo "source /etc/robot/ros2_aliases.sh" >> ~/.bashrc
echo "export RMW_IMPLEMENTATION=rmw_fastrtps_cpp" >> ~/.bashrc
echo "export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/robot/rpi_fastdds_superclient.xml" >> ~/.bashrc
echo "#export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/robot/rpi_fastdds_local.xml" >> ~/.bashrc
