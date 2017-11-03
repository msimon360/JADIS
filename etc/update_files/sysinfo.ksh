#!/bin/ksh
#
### Updated 2009-10-13 cleanup old files, date output file, remove gzip. Mark Simon
### Updated 10-15-2008 to add the date to the sysinfo output. Shaun Seela
### Updated 11-04-2008 to add the -c option to the script to run custom scripts. Shaun Seela

CONFIG_DIR=/apps/support/sysinfo
RUNDATE=`date +"%Y%m%d"`

# Temp directory to put local output files
# Exported because it is also used in SysInfo
SYSINFO_LOGDIR=${SYSINFO_LOGDIR:-"${CONFIG_DIR}/data"} export SYSINFO_LOGDIR

DEPOT_SERVER=159.161.125.58:/apps/opt/depots/hp/11xx/tools

# Installation directory of SysInfo product on local system
SYSINFO_INSTALLDIR=/usr/bin

# Basename of all output files
HOSTNAME=`hostname | cut -d"." -f1`
SYSINFO_BASENAME=sysinfo_${HOSTNAME}_${RUNDATE}
SYSINFO_LOGFILE=${SYSINFO_LOGDIR}/${SYSINFO_BASENAME}.output

CUST_SCRIPT=${CONFIG_DIR}/bin/run_all_chk

# remove left over files from previous runs
rm -f ${SYSINFO_LOGDIR}/sysinfo_${HOSTNAME}* 2>/dev/null

# make sure NC_SysInfo is latest version
/usr/sbin/swinstall -x mount_all_filesystems=false -s ${DEPOT_SERVER} NC_SysInfo >>${SYSINFO_LOGFILE}

# make sure HP SysInfo is latest version
/usr/sbin/swinstall -x mount_all_filesystems=false -s ${DEPOT_SERVER} SysInfo >>${SYSINFO_LOGFILE}

# run SysInfoA
SYSINFO_REL=`grep "^version" ${SYSINFO_INSTALLDIR}/SysInfo | sed 's/version="//;s/".*//'`
if [[ "${SYSINFO_REL}" > "3.15" ]]; then
  ${SYSINFO_INSTALLDIR}/SysInfo -HaTso ${SYSINFO_LOGDIR}/${SYSINFO_BASENAME}.html \
    -c ${CUST_SCRIPT} >>  ${SYSINFO_LOGFILE} 2>&1
else
  ${SYSINFO_INSTALLDIR}/SysInfo -Hfso ${SYSINFO_LOGDIR}/${SYSINFO_BASENAME}.html >>\
    ${SYSINFO_LOGFILE} 2>&1
fi

cat ${CONFIG_DIR}/log/sysinfo.log >> ${SYSINFO_LOGFILE}

print "sysinfo.ksh completed"
#
exit 0
