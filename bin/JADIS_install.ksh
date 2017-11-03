#!/bin/ksh
set -x
# This script is used to copy and install JADIS

function prompt_for_input
{
  PROMPT="$1"
  DEFAULT="$2"
  VAR=$3
  echo $PROMPT
  echo "(${DEFAULT})\c "
  read RESPONCE
  if [ "${RESPONCE}x" = "x" ]; then
    RESPONCE="${DEFAULT}"
  fi
  eval $VAR="${RESPONCE}"
return 0
}

#
while true; do
echo "Select a task to perform:
1	Build an Archive of your JADIS installation
2	Install an Archive of JADIS
3	Exit"

read task
case $task in
  1) echo "Ok, let's build an Archive"
     prompt_for_input "Enter a destination for the archive" /tmp OUTDIR
     #  Source SITE CUSTOM file  #
     BASE=`dirname $0`
     if [ "${BASE}x" = ".x" ];then
       BASE="`pwd`"
     fi
     BASE=`echo ${BASE} | sed "s/\/JADIS\/.*//"`
     . $BASE/JADIS/etc/JADIS.ini
     DATE=`date +%Y%m%d`
     # Copy site specific file to .ORIG
     echo "Base:${BASE}"
     cd $BASE/JADIS/etc
     cp JADIS.ini JADIS.ini.ORIG
     cp remote.lis remote.lis.ORIG
     cp source.lis source.lis.ORIG
     cd update_files
     cp run_sysinfo run_sysinfo.ORIG
     cd $BASE/JADIS/bin
     cp auto_update auto_update.ORIG
     chmod -x auto_update.ORIG
     # Now make the archive
     cd $BASE
     cat $TOPDIR/etc/JADIS.lis | cpio -oL > ${OUTDIR}/JADIS_${DATE}.cpio
     cp $BASE/JADIS/bin/JADIS_install.ksh ${OUTDIR}/
     cd ${OUTDIR}
     tar -cpf ${OUTDIR}/JADIS_${DATE}.tar \
       ./JADIS_${DATE}.cpio ./JADIS_install.ksh
     rm ./JADIS_${DATE}.cpio ./JADIS_install.ksh
     echo "JADIS archive ${OUTDIR}/JADIS_${DATE}.tar is complete"
     echo "Copy the tar file to your server, untar and"
     echo "run the JADIS_install.ksh script"
     exit 0
  ;;

  2) echo "Ok, let's Install JADIS"
     echo "Here are archives I found"
     ls ./JADIS*cpio
     prompt_for_input "Enter the full path to the JADIS cpio source file" /tmp/JADIS.cpio INFILE
     PWD=`pwd`
     prompt_for_input "Enter a destination where JADIS will be installed" $PWD DEST
     cd $DEST
     if [ -d "${DEST}/JADIS" ]; then
       echo "${DEST}/JADIS exists. I will continue."
     else
       echo "${DEST}/JADIS does not exist. Should I continue?"
       read answer
       answer=`echo $answer | tr [A-Z] [a-z] | cut -c 1`
       if [ ! "${answer}x" = "yx" ]; then
         exit
       fi
     fi
     cpio -divmu < $INFILE
     touch ${DEST}/JADIS/lists/sys.all
     touch ${DEST}/JADIS/lists/sys.idle
     touch ${DEST}/JADIS/lists/sys.decom
     touch ${DEST}/JADIS/lists/sys.rcp
     echo "JADIS has been installed into ${DEST}"
     echo "You will need to copy the site specific files and edit for your site"
     echo "and add a crontab entry to run JADIS"
     echo "Here is a list of the site specific template files"
     find ${DEST}/JADIS -follow -name \*.ORIG -print
     exit 0
  ;;

  3) echo "Thanks, bye"
     exit 0
  ;;

  *) echo "I don't know what task $task is."
     exit 1
  ;;
esac
done # Infinite Loop
exit 1
