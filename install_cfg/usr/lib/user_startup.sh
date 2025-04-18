#!/bin/sh

if [ -f /sys/kernel/health_monitor/rootfs_complete ]; then
	echo 1 > /sys/kernel/health_monitor/rootfs_complete
fi

#for mali-450 library
if [ ! -f /sys/firmware/devicetree/base/model ];then
	ln -s /usr/lib/libMali-a1000b.so /usr/lib/libMali.so
	echo "file is not /sys/firmware/devicetree/base/model"
else
	grep -q A1000B /sys/firmware/devicetree/base/model
	if [ $? -eq 0 ];then
		ln -s /usr/lib/libMali-a1000b.so /usr/lib/libMali.so
		 echo "ln -s /usr/lib/libMali-a1000b.so /usr/lib/libMali.so"
	else
                ln -s /usr/lib/libMali-a1000a.so /usr/lib/libMali.so
                echo "ln -s /usr/lib/libMali-a1000a.so /usr/lib/libMali.so"
        fi
fi

#auto insmod modules
if [ -f /usr/bin/bst_auto_insmod.sh ]; then
	echo "auto insmod..."
	/usr/bin/bst_auto_insmod.sh
fi

if [ -f /etc/boot_ctrl/open_kdump ]; then
    /bin/sh /usr/kdump/switch_kdump.sh 1
fi

if [ -f /etc/boot_ctrl/open_wdt -a -f /usr/bin/wdt_open ]; then
	    echo "startup wdt..."
	    /usr/bin/wdt_open 0xf&
fi

if [ -f /usr/bin/mac_app ]; then
	echo "startup mac_app..."
	/usr/bin/mac_app
fi

#limit perf event max sample rate (default100000 --> 20000)
echo 20000 > /proc/sys/kernel/perf_event_max_sample_rate

if [ -f /etc/boot_ctrl/remount_tmpfs ]; then
        echo "remount tmpfs to 600M..."
        mount -o remount,rw,nosuid,nodev,size=600M tmpfs /dev/shm
        mount -o remount,rw,nosuid,nodev,mode=755,size=600M tmpfs /run
        mount -o remount,ro,nosuid,nodev,noexec,mode=755,size=600M tmpfs /sys/fs/cgroup
        mount -o remount,rw,nosuid,nodev,size=600M  tmpfs /tmp
        mount -o remount,rw,relatime,size=600M tmpfs /var/volatile
        mount -o remount,rw,nosuid,nodev,relatime,size=252720k,mode=700  tmpfs /run/user/0
fi

if [ -d /etc/boot_ctrl/zram_swap ]
then
  zram_on=`cat /etc/boot_ctrl/zram_swap/enable`
  if [ $zram_on == 1 ] ;
  then echo "zram on";
    zram_size=`cat /etc/boot_ctrl/zram_swap/size`
    modprobe zram
    echo ${zram_size}M > /sys/block/zram0/disksize
    mkswap /dev/zram0
    swapon /dev/zram0
    echo 100 > /proc/sys/vm/swappiness
  fi
fi

echo "prevent system services being killed by OOM"
ps aux | grep /lib/systemd/systemd | grep -v grep | grep -v awk | awk '{printf "echo -17 > /proc/%s/oom_adj\n", $2}' >> /tmp/oom.sh 
ps aux | grep /usr/bin/SafetyService | grep -v grep | grep -v awk | awk '{printf "echo -17 > /proc/%s/oom_adj\n", $2}' >> /tmp/oom.sh 
bash /tmp/oom.sh
rm /tmp/oom.sh

#sync coreip bsnn
if [ -d /home/root/userdata/bsnn ]; then
	if  [ ! -d /userdata/bsnn ]; then
		cp -rf /home/root/userdata/bsnn  /userdata/
		rm -rf  /home/root/userdata/bsnn
	fi
fi
#sync coreip lwnn
if [ -d /home/root/userdata/lwnn ]; then
	if  [ ! -d /userdata/lwnn ]; then
		cp -rf /home/root/userdata/lwnn  /userdata/
		rm -rf  /home/root/userdata/lwnn
	fi
fi
#sync coreip rcall
if [ -d /home/root/userdata/rcall ]; then
	if  [ ! -d /userdata/rcall ]; then
		cp -rf /home/root/userdata/rcall  /userdata/
		rm -rf  /home/root/userdata/rcall
	fi
fi
#sync coreip hwcv
if [ -d /home/root/userdata/hwcv ]; then
	if  [ ! -d /userdata/hwcv ]; then
		cp -rf /home/root/userdata/hwcv  /userdata/
		rm -rf  /home/root/userdata/hwcv
	fi
fi


# cleanup
if [ -d /home/root/userdata ] && [ -z "$(ls -A /home/root/userdata)" ]; then
    rm -rf /home/root/userdata
    sync && sync
fi


#support cluster normal kanzi3d
# if [ -f /bin/ClusterMonitor/run_process.sh ]; then
#     if [ -f /usr/bin/weston.sh ]; then
#         sleep 3
#         /usr/bin/weston.sh
#         sleep 5
#         /bin/ClusterMonitor/run_process.sh
#     fi
# fi
# if [ -f /bin/Kanzi3D/run_process.sh ]; then
#     if [ -f /usr/bin/weston.sh ]; then
#         sleep 3
#         /usr/bin/weston.sh
#         sleep 5
#         /bin/Kanzi3D/run_process.sh
#     fi
# fi

is_adas=`zcat /proc/config.gz | grep -i adas | grep "=y"`

if [ -n "$is_adas" -a -d /userdata/slt/ -a -f /userdata/slt/adas/msgbox/msgbox_test.sh ]; then
	/userdata/slt/adas/msgbox/msgbox_test.sh server=1
fi

if [ -d /sys/class/net/eth0 ]; then
	sysctl -w net.core.rmem_max=8388608
	sysctl -w net.core.rmem_default=8388608
	sysctl -w net.ipv4.ipfrag_time=3
	sysctl -w net.ipv6.ip6frag_time=6
fi


ethernet_configure(){
	ffetool=/usr/bin/ffe_client_adas_cpu6

	ip link set dev eth0 address 02:00:00:00:14:01
	ip addr add 198.18.36.1/16 dev eth0
	ip link set dev eth0 up
	# IP1&MAC1
	ip link add link eth0 name eth0.5 type vlan id 5
	ip link set dev eth0.5 address 02:00:00:00:14:01
	ip addr add 198.18.36.1/16 dev eth0.5
	ip link set dev eth0.5 up

	ip link add link eth0 name eth0.11 type vlan id 11
	ip link set dev eth0.11 address 02:00:00:00:14:01
	ip addr add 198.18.36.1/16 dev eth0.11
	ip link set dev eth0.11 up

	ip link add link eth0 name eth0.12 type vlan id 12
	ip link set dev eth0.12 address 02:00:00:00:14:01
	ip addr add 198.18.36.1/16 dev eth0.12
	ip link set dev eth0.12 up

	# IP2&MAC2
	ip link add link eth0 name eth0.201 type vlan id 201
	ip link set dev eth0.201 address 02:00:00:ff:00:11
	ip addr add 179.16.0.10/16 dev eth0.201
	ip link set dev eth0.201 up

	ip route add default via 198.18.32.17 dev eth0

	$ffetool bd-add --vlan 201
	$ffetool bd-update --vlan 201 --uh 0 --um 0 --mh 0 --mm 0
	$ffetool bd-insif --vlan 201 -i extern0 --tag ON
	$ffetool bd-insif --vlan 201 -i extern1 --tag ON
	$ffetool bd-insif --vlan 201 -i extern2 --tag ON
	$ffetool bd-insif --vlan 201 -i extern3 --tag ON
	$ffetool bd-insif --vlan 201 -i soc --tag ON

	$ffetool bd-add --vlan 5
	$ffetool bd-update --vlan 5 --uh 0 --um 0 --mh 0 --mm 0
	$ffetool bd-insif --vlan 5 -i extern0 --tag ON
	$ffetool bd-insif --vlan 5 -i extern1 --tag ON
	$ffetool bd-insif --vlan 5 -i extern2 --tag ON
	$ffetool bd-insif --vlan 5 -i extern3 --tag ON
	$ffetool bd-insif --vlan 5 -i soc --tag ON

	$ffetool bd-add --vlan 11
	$ffetool bd-update --vlan 11 --uh 0 --um 0 --mh 0 --mm 0
	$ffetool bd-insif --vlan 11 -i extern0 --tag ON
	$ffetool bd-insif --vlan 11 -i extern1 --tag ON
	$ffetool bd-insif --vlan 11 -i extern2 --tag ON
	$ffetool bd-insif --vlan 11 -i extern3 --tag ON
	$ffetool bd-insif --vlan 11 -i soc --tag ON

	$ffetool bd-add --vlan 12
	$ffetool bd-update --vlan 12 --uh 0 --um 0 --mh 0 --mm 0
	$ffetool bd-insif --vlan 12 -i extern0 --tag ON
	$ffetool bd-insif --vlan 12 -i extern1 --tag ON
	$ffetool bd-insif --vlan 12 -i extern2 --tag ON
	$ffetool bd-insif --vlan 12 -i extern3 --tag ON
	$ffetool bd-insif --vlan 12 -i soc --tag ON

	$ffetool hw-update
}

ethernet_configure

