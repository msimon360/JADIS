#!/usr/bin/perl
# ---------------------------------------------------------------------------
# @(#) $Id: diskspace_plugin.pl,v 1.0 2011-05-05 Mark Simon
# ---------------------------------------------------------------------------

sub get_diskspace {
print "+++++++++ in get_diskspace\n";
  if ($os = "HP-UX" ) {
    next;
    next;
    while ($finished != "true" ) {
    if (/HP/) {
      print "Found HP";
      $SAN_Vend =~ "HP";
    } # If HP
    if (/EMC/) {
      print "Found EMC";
      $SAN_Vend =~ "EMC";
    } # If EMC
    if (/^$/) {
      $finished =~ "true";
    }
    next;
    } # while not finished
  } # if HP-UX
  return $SAN_Vend;
} # end sub get_diskspace

