#!/bin/ksh

#
# Title:         gather_hmc.ksh (based on gather_hmc.ksh )
# Author:        Mark Simon
################################################################
#
#   gather_hmc.ksh runs commands on HMC boxes to collect some info
#   it puts the output in a cfg2html file so JADIS can pick it up
#
################################################################
# 11-24-2010 Date created
################################################################

function usage
{
  echo "Usage: gather_hmc.ksh [-h]"
  echo "-h Help, this text"
}

function initialize
{
logwrite "Initializing Variables"
#  Source SITE CUSTOM file  #
BASE=`dirname $1`
if [ "${BASE}x" = ".x" ];then
  BASE="`pwd`"
fi
BASE=`dirname $BASE`
echo "BASE=${BASE}"
. $BASE/etc/JADIS.ini
echo "Starting gather_hmc.ksh ver ${VERSION}"

#
PATH=/usr/local/bin:/bin:/usr/bin:/usr/seos/bin:/bin:/usr/bin:/etc:/usr/sbin:/usr/ucb:/home/v807156/bin:/usr/bin/X11:/sbin:/usr/seos/bin:.:$BASE/bin:$BASE/cgi-bin
#PATH=/usr/bin:/usr/sbin:/usr/local/bin:/usr/ccs/bin:/usr/contrib/bin:/usr/bin/X11:/usr/contrib/bin/X11:/opt/perl/bin:$BASE/bin:$BASE/cgi-bin
export PATH

today=`date +'%Y%m%d'`

# HMC Hosts List
HOSTLST=${TOPDIR}/lists/sys.hmc

# idle host list
IDLELST=${TOPDIR}/lists/sys.idle

# decom'd host list
DECOMLST=${TOPDIR}/lists/sys.decom

# RCP HOSTS
RCPHOSTS=${TOPDIR}/lists/sys.rcp

# remote file list
RFLIST=${TOPDIR}/etc/remote.lis
init_rfiles

# Auto Update script
AUTOUD=${TOPDIR}/bin/auto_update

THISHOST=`hostname | cut -d"." -f1`
# HMC Status File
STATFILE=${TOPDIR}/data/Status/HMC_status${today}.csv
echo "Hostname,Access,IP" > $STATFILE

if [[ "${JADISHOST}x" = "${THISHOST}x" ]]; then
  logwrite "This host ${THISHOST} is the JADIS master ${JADISHOST}"
  XFR=false
else
  logwrite "This host ${THISHOST} is not the JADIS master ${JADISHOST}"
  XFR=true
fi

logwrite "Initializing Variables - complete"
return 0
}


function init_rfiles
{
  logwrite "Initializing Remote File List"
  # Read the Remote file list into arrays
  PFS="${IFS}"
  IFS=,
  x=0
  cat $RFLIST | while read source[$x] rfile[$x] ldir[$x] ruser[$x];  do
    x=$((${x}+1))
  done
  NUMSOURCE=$x
  IFS="${PFS}"
  logwrite "Initializing Remote File List - complete"
}

function print_rfiles
{
  logwrite "Printing Remote Files"
  x=0
  while [[ $x < $NUMSOURCE ]]; do
    print "${source[$x]} ${rfile[$x]} ${ldir[$x]} ${ruser[$x]}"
    x=$((${x}+1))
  done 
  logwrite "Printing Remote Files - complete"
}

function logwrite
{
  # Write a formatted string to the logfile
  DATESTAMP=`date +"%Y%m%d %H:%M"`
  echo "##LOG:${DATESTAMP}: ${1}"
  return 0
}

function bg_not_complete_before_timeout
{
  # the return values are reversed as this function
  # is true if the background job is NOT complete
  # don't let the double negative fool you :-)
  sleep 1
  if ps -p $! | grep $! >> /dev/null; then
    let count="$1"
    while ps -p $! | grep $! >> /dev/null; do
      if (( $count > 0 )); then
        echo "  Waiting $count more seconds for completion."
        sleep 6
        let count="count - 6"
      else
        echo "! Failed to complete after $1 seconds."
        return 0
      fi
    done
    return 1
  fi
  return 1
}

function run_auto_update
{
  ############ THIS IS FOR AUTO UPDATES ####
  if [ -x ${AUTOUD} ]; then
    logwrite "Performing Auto Update"
    . ${AUTOUD}
  fi
}

function check_sudo
{
    # Check SuDo Privilages
    print "Checking Sudo privilages"
    PRIV="_none"
    touch /tmp/sudo$$
    case $ACCESS in
      ssh)
        ssh -o BatchMode=yes ${ruser[$x]}@${hostname} \
          "sudo -l" > /tmp/sudo$$ 2>/dev/null &
      ;;
      rsh)
        remsh ${hostname} -l ${ruser[$x]} "sudo -l" > /tmp/sudo$$ \
	  2>/dev/null &
      ;;
    esac
    if bg_not_complete_before_timeout 10; then
      echo "failed to connect to ${hostname} after 10 sec"
      kill $!
    else
      if grep -e "ALL.*NOPASSWD" /tmp/sudo$$ >/dev/null ; then
	PRIV=ALL_NOPASS
      fi
      if grep -e "root.*NOPASSWD" /tmp/sudo$$ >/dev/null ; then
	PRIV=ROOT_NOPASS
      fi
    fi
    #cat /tmp/sudo$$ # DEBUG
    #echo "Host:${HN} Priv:${PRIV}" # DEBUG
    rm /tmp/sudo$$
    echo "${hostname},$ACCESS,$PRIV" >> $STATFILE
}

function copy_files
{
  logwrite "Copying Remote Files"
  if [[ "${JADIS_NOCOPY}x" = "x" ]];then
    JADIS_NOCOPY=false
  fi

  echo "NOCOPY flag is set to ${JADIS_NOCOPY}"
  # Loop for all hosts in Host List
  NUM_HOSTS=`wc -l ${HOSTLST} | cut -d" " -f1`
  let HCOUNT=0
  logwrite "Processing Hostlist ${HOSTLST} with $NUM_HOSTS entries"
  for hostname in `cat ${HOSTLST} `
  do
    let HCOUNT=${HCOUNT}+1
    STATUS="missing"
    ACCESS="_none"
    SUDOPRIV="_none"
    x=0
    logwrite "Connecting to $hostname host $HCOUNT of $NUM_HOSTS"
    # Check for connection problems
    check_access "${hostname}"
    # If Host is accessable run auto update and check sudo
    if [[ "${ACCESS}x" = "sshx" ]] || [[ "${ACCESS}x" = "rshx" ]]; then
      run_auto_update
      #check_sudo # Not used in Frontier
    fi
    echo "${hostname},$ACCESS" >> $STATFILE
    #
    # For each remote file source defined
    # If JADIS_NOCOPY is true skip copy files from remote servers
    while [[ $x < $NUMSOURCE ]]&&[ "${JADIS_NOCOPY}x" = "falsex" ]; do
      #print "${source[$x]} ${rfile[$x]} ${ldir[$x]} ${ruser[$x]}" #DEBUG
      # Replace meta tags with wildcards in the pattern to match
      RMPAT=`echo ${rfile[$x]} | sed 's/%YYY/????/;s/%m/??/;s/%d/??/'`
      RMPAT=`echo ${RMPAT} | sed "s/%H/${hostname}/"`
      echo "lcd ${ldir[$x]}" > /tmp/get_${source[$x]}
      echo "mget ${RMPAT}" >> /tmp/get_${source[$x]}
      echo "bye" >> /tmp/get_${source[$x]}
      echo " " >>  /tmp/get_${source[$x]}
      case $ACCESS in
        down)
          true # don't waste time trying anything else
          ;;
        ssh)
          echo "Collecting ${source[$x]} files from ${hostname}"
            # Frist see if we already have the latest file
            ssh -o BatchMode=yes ${ruser[$x]}@${hostname} \
              "ls ${RMPAT} ${RMPAT}.gz 2>/dev/null" | tail -1 > /tmp/rmfile$$
            RMFILE=`cat /tmp/rmfile$$`
            RMFILE=`basename $RMFILE .gz`
            cd ${ldir[$x]}
            if [ -r $RMFILE ]; then
              # file already here
              echo "$RMFILE already collected"
            else # newest file not downloaded
              # Copy files matching the pattern and with .gz added for compressed
              # files ending in .gz, this does not pick up html_config_files.tar
              test_scp ${hostname} ${ruser[$x]}
              case $SCP in
              scp )
                # Had to add the timeout check, scp somtimes hung.
                echo "Copying ${RMPAT} to ${ldir[$x]} with scp"
                scp -B ${ruser[$x]}@${hostname}:${RMPAT} ${ldir[$x]} &
                if bg_not_complete_before_timeout 10; then
                  echo "scp failed to ${hostname} after 10 sec"
                  kill $!
                fi
                ## Commented out *gz files to speed script
                #scp -B ${ruser[$x]}@${hostname}:${RMPAT}.gz ${ldir[$x]} &
                #if bg_not_complete_before_timeout 10; then
                #  echo "scp failed to ${hostname} after 10 sec"
                #  kill $!
                #fi
                ;;
              sftp )
                # try sftp where scp1/2 compatability problems
                echo "Copying ${RMPAT} to ${ldir[$x]} with sftp"
                sftp ${ruser[$x]}@${hostname}:${RMPAT} ${ldir[$x]}
                ;;
              esac
            fi
          ;;
        rsh)
          echo "Collecting files from ${hostname} using rcp"
            # Frist see if we already have the files
            remsh ${hostname} -l ${ruser[$x]} \
              "ls ${RMPAT} ${RMPAT}.gz" 2>/dev/null | tail -1 > /tmp/rmfile$$
            RMFILE=`cat /tmp/rmfile$$`
            RMFILE=`basename $RMFILE .gz`
            cd ${ldir[$x]}
            if [ -r $RMFILE ]; then
              # file already here
              echo "$RMFILE already collected"
            else # newest file not downloaded
              echo "Copying ${RMPAT}* to ${ldir[$x]} with rcp"
              rcp ${ruser[$x]}@${hostname}:${RMPAT} ${ldir[$x]}
              ## Commented out *gz files to speed script
              #rcp ${ruser[$x]}@${hostname}:${RMPAT}.gz ${ldir[$x]}
            fi
          ;;
        *)
            echo "No remote access found"
          ;;
      esac
      # If this is not the JADIS server continue
      # loop for next source file
      if $XFR ; then
        x=$((${x}+1))
	continue
      fi
      x=$((${x}+1))
    done # Loop for all sources
  done # Loop for all Hosts
  logwrite "Copying Remote Files - complete"
}

function test_scp
{
  HNAME=$1
  USER=$2
  SCP="none"
  rm /tmp/junk$$ > /dev/null 2>&1
  # Try scp
  echo "trying scp"
  scp -B ${USER}@${HNAME}:/etc/resolv.conf /tmp/junk$$ \
    2>/dev/null &
  if bg_not_complete_before_timeout 10; then
    echo "scp failed to connect to ${hostname} after 10 sec"
    kill $!
    SCP=sftp
  else # scp command completed
    # Now see if it was successful
    if [ -r /tmp/junk$$ ]; then
      echo "scp succeeded"
      SCP=scp
    else
      echo "scp failed"
      SCP=sftp
    fi
  fi # scp timeout
  rm /tmp/junk$$ > /dev/null 2>&1
}

function bg_not_complete_before_timeout
{
  # the return values are reversed as this function
  # is true if the background job is NOT complete
  # don't let the double negative fool you :-)
  sleep 1
  if ps -p $! | grep $! >> /dev/null; then
    let count="$1"
    while ps -p $! | grep $! >> /dev/null; do
      if (( $count > 0 )); then
        echo "  Waiting $count more seconds for completion."
        sleep 6
        let count="count - 6"
      else
        echo "! Failed to complete after $1 seconds."
        return 0
      fi
    done
    return 1
  fi
  return 1
}

function validate_files
{
  logwrite "Validating Data Files"
  x=0
  while [[ $x < $NUMSOURCE ]]; do
    # make sure the files are writable
    find ${ldir[$x]} -type f -exec chmod 644 {} \; \
      > /dev/null 2>&1
    # uncompress gzip'd files
    logwrite "Uncompressing ${source[$x]} Files"
    NUM=`ls ${ldir[$x]}/*gz | wc -l`
    logwrite "${NUM} compressed files found"
    find ${ldir[$x]} -name \*.gz -exec gunzip -f {} \; \
      > /dev/null 2>&1
    NUM=`ls ${ldir[$x]}/*gz | wc -l`
    logwrite "${NUM} compressed files remain"
    x=$((${x}+1))
    # Make sure HTML files are complete
    for FN in `find ${ldir[$x]} -type f -name \*html -print`; do
      if grep -i "/html" $FN > /dev/null ; then
       echo "${FN} is complete"
      else
       echo "${FN} is only partial, removing"
       rm -f ${FN}
      fi
    done
  done
  logwrite "Validating Data Files - complete"
}

function combine_status
{
  logwrite "Combine Status Files"
  cd ${TOPDIR}/data/Status
  head -1 ${THISHOST}_status${today}.csv > status${today}.csv
  for FN in `ls *_status${today}.csv`; do
    tail -n +2 $FN >> status${today}.csv
  done
  logwrite "Combine Status Files Complete"
}

function test_rsh
{
  HNAME=$1
  # Try rsh
  echo "trying rsh"
  remsh ${HNAME} -l ${ruser[$x]} 'uname -n' > /tmp/hostname$$ \
    2>/dev/null &
  if bg_not_complete_before_timeout 10; then
    echo "rsh failed to connect to ${hostname} after 10 sec"
    kill $!
  else # rsh command completed
    if grep "^${HNAME}" /tmp/hostname$$ > /dev/null 2>&1; then
      echo "rsh login succeeded"
      ACCESS="rsh"
    else
      echo "rsh to ${HNAME} failed `cat /tmp/hostname$$` returned"
    fi # rsh returned hostname
  fi # rsh timeout
}

function check_access
{
  HNAME="$1"
  # first see if it is online
  ping ${HNAME} -c 3 -i 2 > /tmp/ping$$ 2>&1
  if grep -e unknown /tmp/ping$$ > /dev/null;then
    ACCESS="noDNS"
    echo "${HNAME} address not resolved"
    IPADDR="0.0.0.0"
    return 0
  else
    IPADDR=`grep "^PING " /tmp/ping$$ | sed 's/^.* (//1;s/).*//'`
  fi
  if grep -e "100%" /tmp/ping$$ > /dev/null;then
    ACCESS="down"
    echo "${HNAME} does not respond to ping"
    return 0
  fi
  # ping succeeded
  echo "${HNAME} is up"
  # No need to test ssh for HMC boxes
  ACCESS="failed_ssh"
  return 0

  echo "trying ssh"
  ssh -o BatchMode=yes ${ruser[$x]}@${HNAME} 'uname -n' \
    2>/tmp/sshout$$ > /tmp/hostname$$ &
  if bg_not_complete_before_timeout 10; then
    echo "ssh failed to connect to ${HNAME} after 10 sec"
    kill $!
    ACCESS="timeout"
    # Try rsh for hosts that fail ssh
    test_rsh ${HNAME}
  else # ssh connection succeeded
    if grep "Name" /tmp/sshout$$ > /dev/null 2>&1; then
      ACCESS="noDNS"
        echo "${HNAME} not in DNS"
    else
      if grep "^${HNAME}" /tmp/hostname$$ > /dev/null 2>&1; then
        # ssh login succeeded
        ACCESS="ssh"
          echo "ssh login succeeded"
      else # ssh did not return hostname match
        ACCESS="failed_ssh"
          logwrite "${HNAME} does not match output of `cat /tmp/hostname$$`"
        test_rsh ${HNAME}
      fi # ssh returns hostname
    fi # name not in DNS
  fi # if ssh timeout
  return 0
}

function get_teamdoc
{
  logwrite "# Get Excel Spreadsheet from Team Website"
######## Had to use wget with passwd now that site is protected
#  # Try curl
#  FOUND=`whence curl`
#  if [ "${FOUND}x" != "x" ]; then
#    curl --silent --show-error --user=mark.simon --password=Sjs8Mts10knAug \
#    http://ncdcwss.northcentralnetworks.com/sites/unix/Shared%20Documents/Common%20Docs/CurrentInventory.xls >\
#    ${TOPDIR}/data/Teamsite/Team.xls
#  else
#    # if curl not found try wget
#    FOUND=`whence wget`
#    if [ "${FOUND}x" != "x" ]; then
      wget --no-proxy --tries=1 --user=mark.simon --password=Mts8Sjs10knDec \
      http://ncdcwss.northcentralnetworks.com/sites/unix/Shared%20Documents/Common%20Docs/CurrentInventory.xls \
      -O ${TOPDIR}/data/Teamsite/Team.xls
#    else
#      echo "## No curl or wget found. Exiting."
#      exit 1
#    fi
#  fi
  echo "# Translate Excel file into CSV for columns we want"
  xlt_team_xls.pl ${TOPDIR}/data/Teamsite/Team.xls \
    ${TOPDIR}/data/Teamsite/NC${today}.tmp
  #ls -l ${TOPDIR}/data/Teamsite/NC${today}.csv # DEBUG
  # This is a cludge it should be moved to xlt_team_xls.pl
  sed 's/ \,/\,/' ${TOPDIR}/data/Teamsite/NC${today}.tmp > \
    ${TOPDIR}/data/Teamsite/NC${today}.csv
  rm ${TOPDIR}/data/Teamsite/NC${today}.tmp
  chmod 666 ${TOPDIR}/data/Teamsite/NC${today}.csv
  # Check master list
  sed 's/ $//;s/	$//' $ALLHOSTLST > /tmp/hostlist$$
  #ls -l /tmp/hostlist$$ # DEBUG
  linenum=0
  cat ${TOPDIR}/data/Teamsite/NC${today}.csv | while read line ; do
    # Skip over first line
    if (( $linenum < 1 )); then
      linenum=$(( ${linenum}+1))
      continue
    fi
    #echo "Raw:${line}" # DEBUG
    hostname=`echo $line | cut -d"," -f1`
    # remove blanks and convert to lowercase
    hostname=`echo ${hostname} | tr A-Z a-z  | sed 's/ //g;s/	//g'`
    # strip off fully qualified names
    hostname=`echo ${hostname} | sed 's/\..*//g'`
    #echo "HOST:${hostname}" # DEBUG
    if `grep -e "^${hostname}$" /tmp/hostlist$$ > /dev/null`; then
      true # Alread there
    else
      echo ${hostname} >> /tmp/hostlist$$
    fi
  done
  grep -v "^$" /tmp/hostlist$$ | sort -u > $ALLHOSTLST
  logwrite "# Get Excel Spreadsheet from Team Website - complete"
}

function gen_csv
{
  # This function runs the gen_data.pl script with the options to create a
  # comma seperated value (csv) file of all hosts and all parameters
  # parsed from the SysInfo files. It is ment to be run daily from cron.
  # The gen_data.pl cgi script then uses the csv file to run interactive
  # reports.
  logwrite "Generating Summary Data File"

  # Must use a temp file for output so gen_data does not open the empty file
  TMPFILE=/tmp/sysinfo_${today}.csv
  OUTFILE=${TOPDIR}/summary_files/sysinfo_${today}.csv

  echo "# Generate datafile $OUTFILE"
  # If run with the -f option remove the current csv file to force generation.
  if [ "${FORCE_CSV}" != "true" ]; then
    rm $OUTFILE ${TOPDIR}/summary_files/sysinfo_latest.csv
  fi
  
  ${TOPDIR}/cgi-bin/gen_data.pl -b -c -h sys.all -p all -o csv > \
    ${TMPFILE} 2> ${TOPDIR}/logs/gen_data.log
  mv ${TMPFILE} ${OUTFILE}
  chmod 644 ${OUTFILE}
  # Make a link for use by gen_data.pl
  ln -fs ${OUTFILE} ${TOPDIR}/summary_files/sysinfo_latest.csv
  chmod 644 ${TOPDIR}/summary_files/sysinfo_latest.csv
  logwrite "Generating Summary Data File - complete"
}

function gen_summary
{
  logwrite "# Generate webpage ${TOPDIR}/summary.html"

  ${TOPDIR}/cgi-bin/gen_data.pl -b -o hsum \
    -p "Access Admin AppID Critical Env Model OS OS_rel Portfolio SysInfo cfg2html" \
    2> ${TOPDIR}/logs/gen_summary.log | \
    tail -n +2 > ${TOPDIR}/summary.html
  logwrite "# Generate summary - complete"
}

function gen_dflt_report
{
  logwrite "# Generate webpage ${TOPDIR}/index.html"

  ${TOPDIR}/cgi-bin/gen_data.pl -b -o html \
    -p "Access AppID Critical Env Model OS OS_rel RemoteIP SysInfo cfg2html" \
    2> ${TOPDIR}/logs/gen_dflt_report.log | \
    tail -n +2 > ${TOPDIR}/index.html
  logwrite "# Generate dflt_report - complete"
}


function cleanup
{
  # cleanup temp files
  rm -f /tmp/*$$ > /dev/null 2>&1
  return 0
}

function wait_for_remote
{
  logwrite "Waiting for Remote Server"
  # Enter Potentially Infinite Loop
  while true; do
    (( ALL_DONE=1 ))
    for SERVER in $RMSERVERS ; do
      if [[ -r ${TOPDIR}/tmp/${SERVER}_complete ]]; then
        (( ALL_DONE=$ALL_DONE * 1 ))
      else
        (( ALL_DONE=$ALL_DONE * 0 ))
      fi
    done # loop for all remote servers
    if (( $ALL_DONE == 1 )) ;then
      rm ${TOPDIR}/tmp/*_complete
      return 0
    fi
    sleep 60
  done # not so Infinite Loop
  logwrite "Waiting is over"
}

function init_data_list
{
  logwrite "Init Data Sources List"
  # Read the Remote file list into arrays
  PFS="${IFS}"
  IFS=,
  x=0
  cat $DLIST | while read source[$x] ldir[$x] datatype[$x];  do
    ldir[$x]=`dirname ${ldir[$x]}`
    x=$((${x}+1))
  done
  NUMSOURCE=$x
  IFS="${PFS}"
  logwrite "Init Data Sources List complete"
}

function xfr_files
{
  logwrite "Transfer Files"
  init_data_list
  # Uncompress any GZip'd files first so rsync will match
  validate_files
  # Use rsync to transfer files to the JADIS master Host
  # For each remote file source defined
  x=0
  while [[ $x < $NUMSOURCE ]]; do
    logwrite "rsync of ${source[$x]} starting"
    rsync -avz --size-only \
      ${TOPDIR}/data/${source[$x]}/ \
      ${JADISHOST}:${JADISDIR}/data/${source[$x]}
    logwrite "rsync of ${source[$x]} complete"
    x=$((${x}+1))
  done
  #
  # Set flag file so Master Server can Proceed
  ssh ${JADISHOST} "touch ${JADISDIR}/tmp/${THISHOST}_complete"
  logwrite "Transfer Files - complete"
}

function copy_to_datafeed
{
  logwrite "# Generate csv for MySQL"

  ${TOPDIR}/cgi-bin/gen_data.pl -b -o csv \
    -p "Cabinet# Cluster Complex Cores CPU# CPU_bits CPU_Rev CPU_Speed CPU_Type FWRev Ignite IP Memory Model NPAR OS OS_bits OS_rel Serial# SSH SysID Vendor VPAR VzPatch" \
    2> ${TOPDIR}/logs/gen_mysql_report.log | \
    tail -n +2 > ${TOPDIR}/mysql_report.csv
  logwrite "# Generate mysql_report - complete"
  scp  ${TOPDIR}/mysql_report.csv \
    vzpncdc@nctss:/apps/opt/var/datafeed/
}

function gather_hmc_data
{
  #set -x
  # Loop for all hosts in Host List
  NUM_HOSTS=`wc -l ${HOSTLST} | cut -d" " -f1`
  let HCOUNT=0
  logwrite "Processing Hostlist ${HOSTLST} with $NUM_HOSTS entries"
  for hostname in `cat ${HOSTLST} `
  do
    let HCOUNT=${HCOUNT}+1
    STATUS="missing"
    ACCESS="_none"
    IPADDR="_none"
    x=0
    logwrite "Connecting to $hostname host $HCOUNT of $NUM_HOSTS"
    # Check for connection problems
    check_access "${hostname}"
    echo "${hostname},$ACCESS,$IPADDR" >> $STATFILE
    #
    OUTFILE=${TOPDIR}/data/cfg2html/cfg2html_${hostname}_${today}.html
    DATA=`expect -c "spawn ssh hscroot@rgfwr15a lshmc -v
    match_max 10000
    expect \"*?assword:*\"
    send -- \"Ra!n2day\"
    send -- \"\r\"
    expect eof"`
    #
    print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">" \
    > $OUTFILE
    print "<TITLE>cfg2html file for ${hostname}</TITLE>" >> $OUTFILE
    print "<HTML><BODY><PRE>" >> $OUTFILE
    print "${hostname}" >> $OUTFILE
    print "This is a made up cfg2html file for HMC boxes" >> $OUTFILE
    echo "${DATA}" | sed 's///g' >> $OUTFILE
    print "</PRE></BODY></HTML>" >> $OUTFILE
  done 
}


#### MAIN script ####
initialize $0
#cd ${SIDIR}
#cleanup
# Get command line options
while [ $# -gt 0 ]
do
  case $1 in
    -h )  usage; exit 0
          ;;
    * )
       echo "No option $1 , exiting.";usage;exit 1
       ;;
  esac
done

if $XFR ; then
  gather_hmc_data
  xfr_files
else
  gather_hmc_data
fi
echo "gather_hmc.ksh complete"
exit 0
