#!/bin/ksh

## This script removes a host from the lists used by JADIS
## and moves all data files for the host to the DECOMD dir.

#  Source SITE CUSTOM file  #
BASE=`dirname $0`
if [ "${BASE}x" = "x" ] || [ "${BASE}x" = ".x" ];then
  BASE="`pwd`"
fi
BASE=`dirname $BASE`
#echo "BASE=${BASE}"
. $BASE/etc/JADIS.ini


## Use this script to remove a host from all active lists.
## and add to the sys.decom list

the_host="$1"

cd $BASE/lists

grep -lE "^${the_host}$" sys.* > /tmp/filelist$$
echo "Removing ${the_host} from lists:"
cat /tmp/filelist$$
for file in `cat /tmp/filelist$$`
do
  grep -v "^${the_host}$" $file > /tmp/the_file$$
  cp /tmp/the_file$$ $file
done

# Now add it to the decom list
echo "Adding ${the_host} to Decom List"
cp  sys.decom /tmp/decom$$
echo "${the_host}" >> /tmp/decom$$

sort -u /tmp/decom$$ > sys.decom

rm /tmp/*$$

# Now move the data files to DECOMD

cd $BASE/data

for DIR in cfg2html CFG_Log CFG_text Output SI_Log SysInfo ; do
  mv ${DIR}/*_${the_host}_* DECOMD/ 2>/dev/null
  rm -f ${DIR}/*${the_host}.* 
done

exit 0
