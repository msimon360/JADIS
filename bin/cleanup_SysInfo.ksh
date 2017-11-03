#!/bin/ksh

# This script is used to cleanup the SysInfo
# data directory on the JADIS Master

cd /apps/opt/JADIS/data/SysInfo

export PATH=$PATH:/apps/opt/JADIS/bin
BEFORE=`ls | wc -l`
echo "Started with $BEFORE files"
echo "### delete all empty files"
find . -size 0 -exec rm {} \;
AFTER=`ls | wc -l`
echo "### Now there are $AFTER files"
echo "### uncompress all gzip'd files"
find . -name \*.gz -exec gunzip -f {} \;
echo "### delete all tar files"
find . -name \*.tar -exec rm {} \;
AFTER=`ls | wc -l`
echo "### Now there are $AFTER files"

echo "### for each .html file"
for FN in sysinfo_*_????????.html ; do
  BASE=`basename $FN .html`
  if `grep FRAMESET $FN > /dev/null` ; then
    echo "$FN has FRAMESET converting"
    sysinfo_remove_frames $FN
  else
    rm -f ${BASE}.main.html
    rm -f ${BASE}.index.html
    if `tail -2 $FN | grep "End" >/dev/null`; then
      #echo "Fixing  End after HTML close"
      grep -vi "\\BODY" $FN | grep -vi "\\HTML" > /tmp/${FN}$$
      echo "<\BODY><\HTML>" >> /tmp/${FN}$$
      cp /tmp/${FN}$$ $FN
      rm /tmp/${FN}$$
    fi
  fi
done
AFTER=`ls | wc -l`
echo "### Started with $BEFORE files"
echo "### Now there are $AFTER files"
exit 0
