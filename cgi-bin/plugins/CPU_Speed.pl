sub parse_speed { # Parse CPU Speed
  # This subroutine translates CPU Speeds into integer
  # values in MHz from Integer or Decimal values in
  # MHz or GHz

  #$cpu_speed = shift;
  eval s/^.*: *//;
  $cpu_speed=$_;
  for ($cpu_speed){
    ##print "Input:$cpu_speed\n";
    if (/.* M/) { $cpu_speed =~ s/\..* M/ M/; }
    elsif (/^\d *G/) {$cpu_speed =~ s/ G/000 M/; }
    elsif (/.*\.\d G/) { $cpu_speed =~ s/\.//;
         $cpu_speed =~ s/ *G/00 M/; }
    elsif (/.*\.\d\d G/) { $cpu_speed =~ s/\.//;
         $cpu_speed =~ s/ *G/0 M/; }
    elsif (/.*\.\d\d\d G/) { $cpu_speed =~ s/\.//;
         $cpu_speed =~ s/ *G/ M/; }
    }
  return $cpu_speed;
}

