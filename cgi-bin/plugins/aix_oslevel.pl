#!/usr/bin/perl
# ---------------------------------------------------------------------------
# @(#) $Id: aix_oslevel.pl,v 1.0 2011-09-30 Mark Simon
# ---------------------------------------------------------------------------

sub aix_oslevel {
  my $debug = "true";
  open (OUT,">/tmp/aix_oslevel.log") or die "Unable to open aix_oslevel.log: $!";
  print OUT "+++++++++++++++++++++++++++++ in aix_oslevel +++++\n";
  $OSLEVEL="_unk";
  print OUT "OS:".$os."\n";
  if ($os eq "AIX" ) {
    $finished="false";
    $_= shift (@lines);
    while ($finished ne "true" ) {
    print OUT $_."\n" if $debug;
    if (/PRE/) {
      print OUT "found it\n" if $debug;
      chomp;
      s/^(.*?)>//;
      s/^(.*?)>//;
      s/\<.*$//;
      $OSLEVEL = $_;
      $finished = "true";
    } # found
    if (/NAME=/i) {
      $finished = "true";
    }
    print OUT "Now moving to the next line\n" if $debug;
    $_ = shift (@lines);
    print OUT @lines."\n" if $debug;
    } # while not finished
  } # if AIX
  print OUT "Returning:".$OSLEVEL."\n";
  close (OUT);
  $OSLEVEL;
} # end sub aix_oslevel
