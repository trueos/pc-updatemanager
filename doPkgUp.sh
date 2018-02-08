#!/bin/sh

# Don't change these, get set dynamically at upgrade time by pc-updatemanager
PKG_FLAG="%%PKG_FLAG%%"
REALPKGDLCACHE="%%REALPKGDLCACHE%%"
PKGFILENAME="%%PKGFILENAME%%"
SYSBASEFILENAME="%%SYSBASEFILENAME%%"
SYSBASEORIGIN="%%SYSBASEORIGIN%%"

# Files to overwrite in /etc with upgrades
ETC_DISTUPGRADE="./etc/rc ./etc/rc.shutdown ./etc/rc.devd ./etc/devd.conf ./etc/defaults/rc.conf ./etc/auto_master /etc/autofs"

# Default OpenRC Services to enable
OPENRC_BOOT_SERV="abi adjkerntz bootmisc cron devd dumpon fsck hostid hostname localmount loopback modules motd network newsyslog nisdomain"
OPENRC_BOOT_SERV="${OPENRC_BOOT_SERV} root routing savecore staticroute swap syscons sysctl syslogd urandom zfs zvol "
OPENRC_DEFAULT_SERV="local netmount"
OPENRC_SHUTDOWN_SERV="savecache"
OPENRC_NONET_SERV="local"
export OPENRC_BOOT_SERV OPENRC_DEFAULT_SERV OPENRC_SHUTDOWN_SERV OPENRC_NONET_SERV

## Try to get error status of first command in pipeline ##
run_cmd_wtee()
{
  ((((${1} 2>&1 ; echo $? >&3 ) | tee -a ${2} >&4 ) 3>&1) | (read xs; exit $xs)) 4>&1
  return $?
}

# Copy over the trueos pkg fingerprints
rm -rf /etc/pkg/trueos-fingerprints.previous 2>/dev/null
mv /etc/pkg/trueos-fingerprints /etc/pkg/trueos-fingerprints.previous 2>/dev/null
cp -r /usr/local/etc/pkg/fingerprints/trueos /etc/pkg/trueos-fingerprints

# Set the cache directory
PKG_CFLAG="-C /var/db/pc-updatemanager/.pkgUpdate.conf"
echo "PKG_CACHEDIR: $REALPKGDLCACHE" > /var/db/pc-updatemanager/.pkgUpdate.conf
echo "PKG_DBDIR: /var/db/pc-updatemanager/pkgdb" >> /var/db/pc-updatemanager/.pkgUpdate.conf

# Cleanup the old pkgs
echo "Removing old packages... Please wait..."
pkg-static ${PKG_CFLAG} ${PKG_FLAG} unlock -ay

# Bad PKG, bad!
pkg-static ${PKG_CFLAG} ${PKG_FLAG} delete -y javavmwrapper-2.5_1 2>/dev/null >/dev/null
pkg-static ${PKG_CFLAG} ${PKG_FLAG} delete -y javavmwrapper-2.5_2 2>/dev/null >/dev/null

# Since we cant remove pkgs via repository, this will have to do
pkg-static query -e '%n !~ FreeBSD-*' %o | grep -v 'ports-mgmt/pkg' | xargs pkg-static ${PKG_CFLAG} ${PKG_FLAG} delete -fy
if [ $? -ne 0 ] ; then
  echo "WARNING: Failed removing old packages..."
fi

tar xvpf ${REALPKGDLCACHE}/${PKGFILENAME} -C / /usr/local/sbin/pkg-static >/dev/null 2>/dev/null

sleep 2

# Copy back the saved fingerprints
mkdir -p /usr/local/etc/pkg/fingerprints >/dev/null 2>/dev/null
cp -r /etc/pkg/trueos-fingerprints /usr/local/etc/pkg/fingerprints/trueos

echo "Installing pkg from local cache..."
echo "/usr/local/sbin/pkg-static ${PKG_CFLAG} ${PKG_FLAG} install -U -y -f ports-mgmt/pkg"
/usr/local/sbin/pkg-static ${PKG_CFLAG} ${PKG_FLAG} install -U -y -f ports-mgmt/pkg
if [ $? -ne 0 ] ; then
  # If we fail to install pkgng, try updating first
  echo "Installing pkg from file..."
  echo "/usr/local/sbin/pkg-static ${PKG_CFLAG} ${PKG_FLAG} add -f ${REALPKGDLCACHE}/${PKGFILENAME}"
  /usr/local/sbin/pkg-static ${PKG_CFLAG} ${PKG_FLAG} add -f ${REALPKGDLCACHE}/${PKGFILENAME}
  if [ $? -ne 0 ] ; then
    echo "FAILED INSTALLING ports-mgmt/pkg"
    exit 1
  fi
fi
cd ${REALPKGDLCACHE}

# And now we re-install pkg without -U flag
# Sucks that we have to do this, but -U won't allow upgrading local
# on-disk database schema also
#pkg \${PKG_CFLAG} ${PKG_FLAG} install -f -y ports-mgmt/pkg

# Need to export this before installing pkgs, some scripts may try to be interactive
PACKAGE_BUILDING="YES"
export PACKAGE_BUILDING

# Cleanup the old /compat/linux for left-overs
umount /compat/linux/proc >/dev/null 2>/dev/null
umount /compat/linux/sys >/dev/null 2>/dev/null
rm -rf /compat/linux
mkdir -p /compat/linux/proc
mkdir -p /compat/linux/sys
mkdir -p /compat/linux/usr
mkdir -p /compat/linux/dev
mkdir -p /compat/linux/run
ln -s /usr/home /compat/linux/usr/home

# Make sure the various openrc dirs exist
mkdir -p /etc/runlevels 2>/dev/null
mkdir -p /etc/runlevels/boot 2>/dev/null
mkdir -p /etc/runlevels/default 2>/dev/null
mkdir -p /etc/runlevels/nonetwork 2>/dev/null
mkdir -p /etc/runlevels/shutdown 2>/dev/null
mkdir -p /etc/runlevels/sysinit 2>/dev/null
mkdir -p /libexec/rc/init.d 2>/dev/null

while read pkgLine
do
  pkgOrigin="`echo $pkgLine | cut -d ' ' -f 1`"
  pkgName="`echo $pkgLine | cut -d ' ' -f 2`"
  if [ ! -e "${pkgName}" ] ; then
     echo "No such package: ${pkgName}"
     echo "No such package: ${pkgName}" >>/removed-pkg-list
     continue
  fi

  echo "Installing $pkgOrigin... ${pkgName}"
  run_cmd_wtee "pkg-static ${PKG_CFLAG} ${PKG_FLAG} add -f ${pkgName}" "/pkg-add.log"
  if [ $? -ne 0 ] ; then
     echo "Failed installing ${pkgOrigin}"
     cat /pkg-add.log
     echo "Failed installing ${pkgOrigin}" >>/failed-pkg-list
     cat /pkg-add.log >>/failed-pkg-list
  fi
done < /install-pkg-list
rm /pkg-add.log

echo "Installing $SYSBASEORIGIN... $SYSBASEFILENAME"
run_cmd_wtee "pkg-static ${PKG_CFLAG} ${PKG_FLAG} add -f $SYSBASEFILENAME" "/pkg-add.log"
if [ $? -ne 0 ] ; then
  echo "FAILED INSTALL: ${SYSBASEORIGIN}"
  sleep 10
  exit 1
fi

# Verify the base package was installed
echo "pkg-static info -q ${SYSBASEORIGIN}"
pkg-static info -q ${SYSBASEORIGIN}
if [ $? -ne 0 ] ; then
  echo "FAILED INFO: ${SYSBASEORIGIN}"
  sleep 10
  exit 1
fi

# Lock the TrueOS base package
pkg-static ${PKG_CFLAG} ${PKG_FLAG} lock -y ${SYSBASEORIGIN}
if [ $? -ne 0 ] ; then
  echo "FAILED LOCK: ${SYSBASEORIGIN}"
  sleep 10
  exit 1
fi

# Update kernel hints
kldxref /boot/kernel /boot/modules

if [ -e "/etc/init.d" ] ; then

  # Update some of the etc files from make distribution
  echo "Extracting distribution files..."
  tar xvpf ${REALPKGDLCACHE}/fbsd-distrib.txz -C / ${ETC_DISTUPGRADE}
  if [ $? -ne 0 ] ; then
    echo "Warning: Failed extracting distribution upgrade files"
  fi

  # Enable OpenRC Services
  for serv in ${OPENRC_BOOT_SERV}
  do
     rc-update add $serv boot
  done
  for serv in ${OPENRC_DEFAULT_SERV}
  do
     rc-update add $serv default
  done
  for serv in ${OPENRC_SHUTDOWN_SERV}
  do
     rc-update add $serv shutdown
  done
  for serv in ${OPENRC_NONET_SERV}
  do
     rc-update add $serv nonetwork
  done

  # Determine if we need to do first-time rc -> openrc migration
  if [ ! -e /var/migrate-rc-openrc ] ; then
    echo "Running OpenRC Migration..."
    /usr/local/bin/migrate_rc_openrc
    touch /var/migrate_rc_openrc
  fi
fi

echo "Moving updated pkg repo..."
rm -rf /var/db/pkg.preUpgrade 2>/dev/null
mv /var/db/pkg /var/db/pkg.preUpgrade
mv /var/db/pc-updatemanager/pkgdb /var/db/pkg

# Save the log files
if [ ! -d "/usr/local/log/pc-updatemanager" ] ; then
  mkdir -p /usr/local/log/pc-updatemanager
fi
touch /install-pkg-list
touch /previous-pkg-list
touch /removed-pkg-list
touch /failed-pkg-list
mv /install-pkg-list /usr/local/log/pc-updatemanager/
mv /previous-pkg-list /usr/local/log/pc-updatemanager/
mv /removed-pkg-list /usr/local/log/pc-updatemanager/
mv /failed-pkg-list /usr/local/log/pc-updatemanager/
pkg-static info > /usr/local/log/pc-updatemanager/current-pkg-list

echo "Updating pkgng config..."
if [ -e "/var/db/trueos-pkg-ipfs-next" ] ; then
  mv /var/db/trueos-pkg-ipfs-next /var/db/trueos-pkg-ipfs
fi
/usr/local/bin/pc-updatemanager syncconf
if [ $? -ne 0 ] ; then exit 1; fi

exit 0
