#--------------------------------------------
# Name:     SWITCHVOX XEN SCRIPT
# Author:   Tomas Nevar (tomas@lisenet.com)
# Version:  v1.0
# Date:     27/06/2014 (dd/mm/yy)
# Licence:  copyleft free software
#--------------------------------------------
#
# Script makes Swithvox SMB Amazon EC2 compatible
# Tested on Switchvox PBX build 64078
#

echo "Creating a backup of existing sshd_config file"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

echo "Creating new sshd_config file"
cat > /etc/ssh/sshd_config <<EOL
Port 22
Protocol 2
AddressFamily inet
ListenAddress 0.0.0.0
SyslogFacility AUTHPRIV
PermitRootLogin without-password
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
RSAAuthentication no
RhostsRSAAuthentication no
HostbasedAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
Compression delayed
MaxAuthTries 2
X11Forwarding no
UseDNS no
Subsystem sftp /usr/libexec/openssh/sftp-server
UsePAM no
EOL

echo "Enabling sshd on boot"
chkconfig --level 2345 sshd on

echo "Disabling avahi-daemon, iptables and openvpn"
chkconfig --level 2345 avahi-daemon off
chkconfig --level 2345 iptables off
chkconfig --level 2345 openvpn off

echo "Generating ssh keypair"
ssh-keygen -q -N "" -b 2048 -t rsa -f /root/.ssh/key
mv -f /root/.ssh/key.pub /root/.ssh/authorized_keys
mv -f /root/.ssh/key /root/.ssh/key.pem
chmod 0600 /root/.ssh/authorized_keys
# Don't forget to copy the private key file from /root/.ssh/key.pem

echo "Downloading and importing CenOS GPG key"
wget http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
rpm --import RPM-GPG-KEY-CentOS-5 

echo "Adding CentOS 5 yum repositories"
cat > /etc/yum.repos.d/file.repo <<EOL
[base]
name=CentOS-5 - Base
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=i386&repo=os
#baseurl=http://mirror.centos.org/centos/5/os/i386/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
 
[updates]
name=CentOS-5 - Updates
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=i386&repo=updates
#baseurl=http://mirror.centos.org/centos/5/updates/i386/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
 
[extras]
name=CentOS-5 - Extras
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=i386&repo=extras
#baseurl=http://mirror.centos.org/centos/5/extras/i386/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
enabled=0
EOL

echo "Creating modprobe.conf backup"
cp /etc/modprobe.conf /etc/modprobe.conf.backup

echo "Adding modprobe aliases"
cat > /etc/modprobe.conf <<EOL
alias eth0 xennet
alias scsi_hostadapter xenblk
EOL

echo "Installing xen kernel"
yum -y install kernel-xen kernel-xen-devel

echo "Checking xen kernel version installed under /boot"
KVERSION=$(ls -1 /boot|grep vmlinuz.*xen|cut -d- -f2-3)
echo "Kernel version:" "$KVERSION"

echo "Creating initrd file with xennet and xenblk"
mkinitrd -v -f --preload=xennet --preload=xenblk \
/boot/initrd-"$KVERSION"-xennet.img \
"$KVERSION"

echo "Configuring ifcfg-eth0"
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOL
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
TYPE=Ethernet
PEERDNS=yes
EOL

echo "Configuring /etc/sysconfig/network"
cat > /etc/sysconfig/network <<EOL
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=localhost.localdomain
EOL

echo "Don't forget to copy the SSH private key file from /root/.ssh/key.pem"
exit 0
