#!/bin/bash

# Install script to get MacBookAir 5,2 up and running.
#
# Changelog
# Wed May  2 22:36:00 CEST 2012 - initial version (based on post-install-oneiric 08-Mar-2012 11:54)

# https://github.com/jamestford/Ubuntu_On_MacAir52/blob/master/post-install-ubuntu-macair.sh
# Credits:
#      Based on http://almostsure.com/mba42/post-install-oneiric.sh
#      Based on http://pof.eslack.org/archives/files/mba42/post-install-precise.sh
# 

# -----------------------------------------------------------
# Verify Device
# -----------------------------------------------------------

echo "Verifying system hardware."

SysPrdNam=$(cat /sys/class/dmi/id/product_name)
UBU=$(lsb_release -r|cut -f2)

if [ "MacBookAir4,1" = "${SysPrdNam}" ] || [ "MacBookAir4,2" = "${SysPrdNam}" ]; then
	echo "Good; You seem to have a 2011 MacBook Air."
else
	echo "I don't know how to configure a \"${SysPrdNam}\". This script is for the 2011 MacBook Air."
	read -n 1 -r -p 'To continue anyway, press Y. To quit, press any other key. ' choice
	echo
	case "$choice" in
		[yY]) ;;
		*) exit 1;;
	esac
fi

if [[ "12.10" = "${UBU}" ]];then
	echo "Good; you seem to be running Ubuntu Precise."
else
	echo "It seems you have a \"${UBU}\" and not Ubuntu Quantal 12.10."
	read  -n 1 -r -p 'To continue anyway, press Y. To quit, press any other key. ' choice
	echo
	case "$choice" in
		[Yy]) ;;
		*) exit 2;;
	esac
fi

whoami |grep -w root 2>&1 >/dev/null
if [ $? == 0 ]; then
	echo
	echo "ERROR: this script must be run as regular user, not root"
	echo "hint: do not use sudo"
	exit 1
fi

# -----------------------------------------------------------
# Setup TRIM for SSD Drive
# -----------------------------------------------------------

echo "Adding trim to ext4 mounts (assuming you use ext4)."
# http://sites.google.com/site/lightrush/random-1/howtoconfigureext4toenabletrimforssdsonubuntu
sudo cp /etc/fstab /etc/fstab.$(date +%Y-%m-%d)
sudo sed -i '/\W\/\W/s/errors/discard,errors/g' /etc/fstab

# -----------------------------------------------------------
# Enable Two Finger Scrolling
# -----------------------------------------------------------

synclient VertTwoFingerScroll=1
synclient HorizTwoFingerScroll=1


