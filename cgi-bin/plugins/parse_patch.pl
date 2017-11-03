sub parse_patch { # Parse a Patch line into a Patch value
  # This subroutine tries to figure out which Vz Patch is the latest
  #
  my $new_patch = $_;
  my $new_string;
  my $cur_string = 0;
  #chomp ($new_patch);
  #print "PATCH:".$new_patch."\n"; ## DEBUG
  $new_string = convr_patch $new_patch;
  ##print " ".$new_string."\n"; ## DEBUG
  # If this is the first patch no need to compare
  if ( ! exists $dataoutput{$hostname}{"VzPatch"} ){
    #print "First patch ".$hostname." set to ".$new_string."\n"; ## DEBUG
    return $new_string;
  }
  # Is this patch newer than what we found before?
  else {
    $cur_string = $dataoutput{$hostname}{"VzPatch"};
    if ( $cur_string eq "not_found") { $cur_string = 0 }
    #print "New=".$new_string." Old=".$cur_string."\n"; ## DEBUG
    if ($new_string gt $cur_string) {
      #print $new_string." newer than ".$cur_string."\n"; ## DEBUG
      return $new_string;
    }else{
      return $cur_string;
    }
  }
}
