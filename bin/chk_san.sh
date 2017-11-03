#!/bin/ksh

if [ "${1}x" = "headerx" ]; then
  echo "SAN"
  return 0
fi
if grep "NETAPP LUN" $1 > /dev/null 2>&1 ; then
  SANSTOR="${SANSTOR}VSU"
fi
if grep "HITACHI" $1 > /dev/null 2>&1 ; then
  SANSTOR="${SANSTOR}HDS"
fi
if grep "EMC SYMMETRIX" $1 > /dev/null 2>&1 ; then
  SANSTOR="${SANSTOR}EMC"
fi
if [ "${SANSTOR}x" = "x" ];then
  SANSTOR=none
fi
echo "SAN Storage = $SANSTOR"
