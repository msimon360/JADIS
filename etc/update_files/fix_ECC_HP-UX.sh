#!/bin/ksh
set -x
#
# This script updates the EMC Command Center software
# with the correct server for Frontier North Central
#
# Check the OS, this script only works on HP-UX
OS=`uname`
if [ "${OS}x" != "HP-UXx" ]; then
  exit
else
  # Update the SSI file so future installs work
  HOSTNAME=`hostname`
  SDDIR=/apps
  SSIDIR=$SDDIR/etc/SSI
  SSIFILE=$SSIDIR/host.$HOSTNAME.VZecc
  CONFIG_FILE=/apps/opt/ECC/exec/ctg.ini
  #
  # Create the SSI file
  #
  echo "THE_SERVER_IP=138.83.9.153" > $SSIFILE
  echo "THE_SERVERNAME=ftwp1lveccd01v" >> $SSIFILE
  echo "THE_SERVER_PORT=5799" >> $SSIFILE
  echo "THE_ECC_AGENT_PORT=5798" >> $SSIFILE
  echo 'ECC52_OVERRIDE_ANCHOR="FALSE"' >> $SSIFILE
  echo 'ECC52_INSTALL_PATH=""' >> $SSIFILE
  echo 'ECC52_OVERRIDE_SIZE="FALSE"' >> $SSIFILE
  echo "ECC52_PERCENTAGE=90" >> $SSIFILE
  echo 'ECC52_SIZE=""' >> $SSIFILE
  #
  # Stop the ECC software
  /sbin/init.d/eccmad stop
  #
  # Update the config file
  sed 's/^Server Host =.*/Server Host = 138.83.9.153/' \
  $CONFIG_FILE > /tmp/config.$$
  mv /tmp/config.$$ $CONFIG_FILE
  #
  # Start the ECC software
  /sbin/init.d/eccmad start
  #
fi
rm -f /tmp/fix_ECC_HP-UX.sh
exit 0
