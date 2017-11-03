#!/bin/ksh

# gen_summary.ksh
# This script generates the Summary Data file for JADIS

#
PATH=/usr/bin:/usr/sbin:/usr/local/bin:/usr/ccs/bin:/usr/contrib/bin:/usr/bin/X11:/usr/contrib/bin/X11:/opt/perl/bin
export PATH

#  Source SITE CUSTOM file  #
BASE=`dirname $1`
if [ "${BASE}x" = "x" ];then
  BASE="`pwd`"
fi
BASE=`dirname $BASE`
echo "BASE=${BASE}"
. $BASE/etc/JADIS.ini

PATH=${PATH}:$BASE/bin:$BASE/cgi-bin
export PATH

today=`date +'%Y%m%d'`

TMPFILE=/tmp/sysinfo_${today}.csv
OUTFILE=${TOPDIR}/summary_files/sysinfo_${today}.csv

# Remove current summary to force rebuild
rm $OUTFILE
rm ${TOPDIR}/summary_files/sysinfo_latest.csv

sudo -u dpphpux gen_data.pl -b -c -h sys.all -p all -o csv > ${TMPFILE}
mv ${TMPFILE} ${OUTFILE}
# Make a link for use by gen_data.pl
ln -fs ${OUTFILE} ${TOPDIR}/summary_files/sysinfo_latest.csv
chmod 644 ${TOPDIR}/summary_files/sysinfo_latest.csv
  
