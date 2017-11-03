#!/bin/ksh
# ---------------------------------------------------------------------------
# @(#) $Id: diskspace_plugin.sh,v 1.1 2011-04-25 Mark Simon
# ---------------------------------------------------------------------------

CFG2HTML_PLUGINTITLE="Disk Space Totals"

function cfg2html_plugin {
  PATH=$PATH:/usr/seos/bin:/apps/opt/seos/bin:/opt/CA/eTrustAccessControl/bin
  SAN_VEND="none"
  OS=`uname`
  case $OS in
  HP-UX)
    SAN_TOTAL=0
    DASD_TOTAL=0
    touch /tmp/DASD1$$
    touch /tmp/DASD$$
    touch /tmp/SAN1$$
    STARTLINE=`grep -n "Id: get_diskfirmware" $TEXT_OUTFILE_TEMP | cut -d":" -f1`
    if [[ $STARTLINE > 1 ]]; then
      STARTLINE=$(($STARTLINE +2 ))
      tail -n +${STARTLINE} $TEXT_OUTFILE_TEMP > /tmp/in1$$
      HEADER=`head -n 1 /tmp/in1$$ | cut -c1-7`
      ENDLINE=`grep -n "Note: Raw device" /tmp/in1$$ | cut -d":" -f1`
      ENDLINE=$(($ENDLINE -2 ))
      head -n $ENDLINE /tmp/in1$$ > /tmp/in2$$
      grep -e HP -e SEAGATE /tmp/in2$$ > /tmp/DASD$$
      grep -e EMC -e HITACHI -e NETAPP /tmp/in2$$ > /tmp/SAN$$
      case $HEADER in
        Hard* )
          # Process the SAN Storage File
          cat /tmp/SAN$$ | cut -c45- | sort -u > /tmp/SAN1$$
          while read line ; do
            set $line
            SAN_VEND=`echo $1 | cut -d"/" -f1`
            SAN_TOTAL=`echo "${SAN_TOTAL} + $3 " | bc`
          done < /tmp/SAN1$$
          # Process the DASD Storage File
          while read line ; do
            set $line
            if `echo $4 | grep "\." > /dev/null`; then
              SIZE=$4
            else
              SIZE=$5
            fi
            DASD_TOTAL=`echo "${DASD_TOTAL} + $SIZE " | bc`
          done < /tmp/DASD$$
        ;;
        Device* )
          # Process the SAN Storage File
          cat /tmp/SAN$$ | grep LVM > /tmp/SAN1$$
          while read line ; do
            set $line
            SAN_VEND=`echo $2 | cut -d"/" -f1`
            SAN_TOTAL=`echo "${SAN_TOTAL} + $5 " | bc`
          done < /tmp/SAN1$$
          # Process the DASD Storage File
          while read line ; do
            set $line
            DASD_TOTAL=`echo "${DASD_TOTAL} + $5 " | bc`
          done < /tmp/DASD$$
        ;;
        * )
          echo "Don't know how to parse $HEADER"
          exit 1
        ;;
      esac
      printf "DASD Total: %8.1f Gb\n" $DASD_TOTAL
      printf "SAN  Total: %8.1f Gb\n" $SAN_TOTAL
      echo   "SAN Vendor: $SAN_VEND"
    else
      #echo "No Disk Firmware section was found"
      exit
    fi
    ;;
  AIX|Linux)
    echo "This plugin is not used for ${OS}."
    ;;
  *)
    echo "This plugin is not used for ${OS}."
    ;;
  esac
rm /tmp/*$$
}

