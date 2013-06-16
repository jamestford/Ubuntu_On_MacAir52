#!/bin/bash

# Install script to get MacBookAir4 (11' and 13') up and running.
#
# A General Comment:
#   This script is meant to be a "living howto" 
#   Everyone should read through each step of this script and decide if the
#   action makes sense.  Although...I know most won't.
#   But don't cry to me when it doesn't do what you wanted/ecxpected.
#
# Changelog
#
# Wed May  2 22:36:00 CEST 2012 - initial version (based on post-install-oneiric 08-Mar-2012 11:54)
# Mon May  7 11:26:36 UTC 2012  - add lightum-indicator
# Tue May 15 07:49:07 UTC 2012  - make sure the script is run as user, not as root
# Mon May 21 15:50:06 UTC 2012  - add fix for wifi timeout after suspend/resume
# Thu May 24 21:45:51 UTC 2012  - updated wifi fix, now using broadcom-sta from poliva/pof ppa
# Thu Jun  7 07:50:26 UTC 2012  - blacklist bcma module

# http://pof.eslack.org/archives/files/mba42/post-install-precise.sh
# Copyright (c) 2012 Pau Oliva Fora,
# Based on http://almostsure.com/mba42/post-install-oneiric.sh
# Copyright (c) 2012 Joshua V Dillon,
# All rights reserved. See end-of-file for license.


# --- Verify Device ---------------------------------------------

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

if [[ "12.04" = "${UBU}" ]];then
	echo "Good; you seem to be running Ubuntu Precise."
else
	echo "It seems you have a \"${UBU}\" and not Ubuntu Precise 12.04."
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

# aptitude is better
[ -z "$(which aptitude)" ] && sudo apt-get install aptitude


# --- macfanctld
# It is highly recommended to use the fan controller daemon that is included in
# the mactel-support ppa called macfanctl. 
echo "Adding macfanctld ppa (fan control daemon)."
sudo add-apt-repository ppa:mactel-support/ppa

# --- lightum
echo "Adding lightum ppa (automatic light sensor daemon)."
sudo add-apt-repository ppa:poliva/lightum-mba

# --- broadcom-sta
echo "Adding broadcom-sta ppa (better wireless module)."
sudo add-apt-repository ppa:poliva/pof

# --- fix 30seconds wifi timeout using wl driver
sudo aptitude purge bcmwl-kernel-source

echo "Installing packages."
sudo aptitude update
sudo aptitude install macfanctld lightum lightum-indicator lm-sensors broadcom-sta-dkms

mkdir -p ~/.config/autostart
sudo chown -R `id -u`:`id -g` ~/.config/

# --- xmodmap
echo "Making xmodmap run at login (custom keys)."
tee ~/.config/autostart/xmodmap.desktop <<-EOF
	[Desktop Entry]
	Type=Application
	Exec=/usr/bin/xmodmap ~/.Xmodmap
	Hidden=false
	NoDisplay=false
	X-GNOME-Autostart-enabled=true
	Name[en_US]=Xmodmap
	Name=Xmodmap
	Comment[en_US]=Load custom .Xmodmap.
	Comment=Load custom .Xmodmap.
EOF

echo "Making xmodmap run after resume (custom keys)."
wget -Nq http://pof.eslack.org/archives/files/mba42/00_usercustom || wget -Nq http://almostsure.com/mba42/00_usercustom 
sed -i "s/xxxxxxxx/$USER/" 00_usercustom
chmod 0755 00_usercustom
sudo mv 00_usercustom /etc/pm/sleep.d/00_usercustom

# The program lmsensors detects the sensors, however it does not know what they
# are yet. The module coretemp will allow lm-sensor to detect the others
# sensors, the rotation speed of the fan, and the GPU temperature.
sudo tee -a /etc/modules <<-EOF
	coretemp
	hid_apple
EOF

# make function keys behave normally and fn+ required for macro
sudo tee -a /etc/modprobe.d/hid_apple.conf <<-EOF
	options hid_apple fnmode=2
EOF
sudo modprobe coretemp hid_apple

# blacklist conflicting wireless module
sudo tee -a /etc/modprobe.d/blacklist-bcma.conf <<-EOF
	blacklist bcma
EOF

# configure macfanctld
tee <<-EOF
	Configuring macfanctld to ignore some sensors. On my system three
	sensors gave bogus readings, i.e.,
	    TH0F: +249.2 C                                    
	    TH0J: +249.0 C                                    
	    TH0O: +249.0 C
	Run 'sensors' to see current values; run 'macfanctld -f' to
	obtain the list of sensors and their associated ID.
	Applying this exclude: 13 14 15.
EOF
sudo service macfanctld stop
sudo cp /etc/macfanctl.conf /etc/macfanctl.conf.$(date +%Y-%m-%d)
sudo sed -i "s/\(^exclude:\).*\$/\\1 13 14 15/" /etc/macfanctl.conf
sudo service macfanctld start



# --- Suspend ---------------------------------------------------

echo "Fixing post-hibernate hang."
sudo tee -a /etc/pm/config.d/macbookair_fix <<-EOF
	# The following brings back eth0 after suspend when using the apple usb-ethernet adapter.
	SUSPEND_MODULES="asix usbnet"
EOF

# no password after resume (like mac)
echo "Disable lock screen after resume."
gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'


# --- Boot ------------------------------------------------------

echo "Setting boot parm (better power usage)."
sudo cp /etc/default/grub /etc/default/grub.$(date +%Y-%m-%d)
SWAP=$(cat /etc/fstab |grep "# swap was on" |awk '{print $5}')
sudo sed -i "s:\(GRUB_CMDLINE_LINUX_DEFAULT=\).*\$:\\1\"quiet splash i915.i915_enable_rc6=1 resume=${SWAP}\":" /etc/default/grub
sudo update-grub


echo "Adding trim to ext4 mounts (assuming you use ext4)."
# http://sites.google.com/site/lightrush/random-1/howtoconfigureext4toenabletrimforssdsonubuntu
sudo cp /etc/fstab /etc/fstab.$(date +%Y-%m-%d)
sudo sed -i '/\W\/\W/s/errors/discard,errors/g' /etc/fstab

echo "Ensuring bcm5974 loads before usbhid (editing /etc/rc.local)."
# update /etc/rc.local to ensure bcm5974 is loaded BEFORE usbhid
sudo cp /etc/rc.local /etc/rc.local.$(date +%Y-%m-%d)
sudo sed -i '$i modprobe -r usbhid\nmodprobe -a bcm5974 usbhid' /etc/rc.local

# set-up different key configurations
echo "Installing modified key mapping (Note: ~/.Xmodmap needs tweaking!)."
wget -Nq http://pof.eslack.org/archives/files/mba42/dotXmodmap || wget -Nq http://www.almostsure.com/mba42/dotXmodmap 
[ -e ~/.Xmodmap ] && cp ~/.Xmodmap ~/.Xmodmap.bak-$(date +%Y-%m-%d)
mv dotXmodmap ~/.Xmodmap
xmodmap ~/.Xmodmap

# --- Extra Power Management ------------------------------------

echo "Configuring extra power management options."
wget -Nq http://pof.eslack.org/archives/files/mba42/99_macbookair || wget -Nq http://www.almostsure.com/mba42/99_macbookair
chmod 0755 99_macbookair
sudo mv 99_macbookair /etc/pm/power.d/99_macbookair
# disable bluetooth by default
sudo sed -i '$i /usr/sbin/rfkill block bluetooth' /etc/rc.local

# --- enable lightum
/usr/bin/lightum
/usr/bin/lightum-indicator &
gsettings set org.gnome.settings-daemon.plugins.power idle-dim-ac 'false'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim-battery 'false'


# --- re-enable hibernate 
# https://help.ubuntu.com/12.04/ubuntu-help/power-hibernate.html
sudo tee /etc/polkit-1/localauthority/50-local.d/com.ubuntu.enable-hibernate.pkla <<-EOF
[Re-enable hibernate by default]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
ResultActive=yes
EOF
gsettings set org.gnome.settings-daemon.plugins.power critical-battery-action 'hibernate'


# --- Avoid Long EFI Wait Before GRUB ---------------------------

tee <<-EOF
	If your Macbook spends 30 seconds with "white screen" before GRUB
	shows, try booting into Mac OS X, open a terminal and enter:
		sudo bless --device /dev/disk0s4 --setBoot --legacy --verbose
	where /dev/disk0s4 is your linux boot partition. If you are
	unsure which partition to use, enter:
	    diskutils list
EOF

tee <<-EOF
	If you haven't done so already, it may be wise to use the Lion Recovery
	Disk Assistant [1] to make a USB restore drive. It should be run from
	MacOS.
	[1] http://support.apple.com/kb/DL1433
EOF

exit 0

#
# Copyright (c) 2012 Joshua V Dillon,
# http://almostsure.com/mba42/post-install-oneiric.sh
# All rights reserved. See end-of-file for license.
#
#  Redistribution and use in source and binary forms, with or
#  without modification, are permitted provided that the
#  following conditions are met:
#   * Redistributions of source code must retain the above
#     copyright notice, this list of conditions and the
#     following disclaimer.
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the
#     following disclaimer in the documentation and/or other
#     materials provided with the distribution.
#   * Neither the name of the author nor the names of its
#     contributors may be used to endorse or promote products
#     derived from this software without specific prior written
#     permission.
#  
#  THIS SOFTWARE IS PROVIDED BY JOSHUA V DILLON ''AS IS'' AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JOSHUA
#  V DILLON BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

