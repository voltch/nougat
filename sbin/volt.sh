#!/system/bin/sh

# Mount root as RW to apply tweaks and settings
mount -t rootfs -o remount,rw rootfs

# Synapse
chmod 666 /sys/module/workqueue/parameters/power_efficient
chmod -R 777 /res/*
ln -fs /res/synapse/uci /sbin/uci
/sbin/uci

# default kernel params
/sbin/kernel_params.sh


mount -t rootfs -o remount,ro rootfs
mount -o remount,rw /system
mount -o remount,rw /data
sleep 1
# Set correct r/w permissions for LMK parameters
chmod 666 /sys/module/lowmemorykiller/parameters/cost;
chmod 666 /sys/module/lowmemorykiller/parameters/adj;
chmod 666 /sys/module/lowmemorykiller/parameters/minfree;
/system/bin/setprop pm.sleep_mode 1
/system/bin/setprop ro.telephony.call_ring.delay 1000
/system/bin/setprop ro.ril.power_collapse 0
/system/bin/setprop ro.ril.disable.power.collapse 1
/system/bin/setprop persist.sys.use_dithering 0
/system/bin/setprop wifi.supplicant_scan_interval 300
/system/bin/setprop persist.radio.add_power_save 1
/system/bin/setprop ro.fast.dormancy 1
/system/bin/setprop ro.ril.fast.dormancy.rule 1
/system/bin/setprop persist.radio.data_no_toggle 1
/system/bin/setprop profiler.force_disable_err_rpt 1
/system/bin/setprop ro.com.google.networklocation 0
echo "1050" > /sys/devices/battery/so_limit_input
echo "1050" > /sys/devices/battery/so_limit_charge
echo "650" > /sys/devices/14ac0000.mali/max_clock

# Disable rotational storage for all blocks
# We need faster I/O so do not try to force moving to other CPU cores (dorimanx)
for i in /sys/block/*/queue; do
        echo "0" > "$i"/rotational
        echo "2" > "$i"/rq_affinity
done

# Setup for Cron Task
if [ ! -d /data/.volt ]; then
	mkdir -p /data/.volt
	chmod -R 0777 /.volt/
fi;
# Copy Cron files
cp -a /res/crontab/ /data/

# init.d support
if [ ! -e /system/etc/init.d ]; then
   mkdir /system/etc/init.d
   chown -R root.root /system/etc/init.d
   chmod -R 755 /system/etc/init.d
fi

# start init.d
for FILE in /system/etc/init.d/*; do
   sh $FILE >/dev/null
done;

su -c "pm enable com.google.android.gms/.update.SystemUpdateActivity"
su -c "pm enable com.google.android.gms/.update.SystemUpdateService"
su -c "pm enable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver"
su -c "pm enable com.google.android.gms/.update.SystemUpdateService$Receiver"
su -c "pm enable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver"
su -c "pm enable com.google.android.gsf/.update.SystemUpdateActivity"
su -c "pm enable com.google.android.gsf/.update.SystemUpdatePanoActivity"
su -c "pm enable com.google.android.gsf/.update.SystemUpdateService"
su -c "pm enable com.google.android.gsf/.update.SystemUpdateService$Receiver"
su -c "pm enable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver"

BB=/system/xbin/busybox;

# Run Cortexbrain script
# Cortex parent should be ROOT/INIT and not Synapse
cortexbrain_background_process=$(cat /res/synapse/volt/cortexbrain_background_process);
if [ "$cortexbrain_background_process" == "1" ]; then
sleep 30
$BB nohup $BB sh /sbin/cortexbrain-tune.sh > /dev/null 2>&1 &
fi;


# Start CROND by tree root, so it's will not be terminated.
cron_master=$(cat /res/synapse/volt/cron_master);
if [ "$cron_master" == "1" ]; then
$BB nohup $BB sh /res/crontab_service/service.sh 2> /dev/null;
fi;
