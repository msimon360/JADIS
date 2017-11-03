sub convr_patch { # Convert a Patch line in a date/rev string
  # This routine converts a Verizon custom patch name
  # into a string that can be compared for date
  # ie; Vz1123Feb2001c1 = 200102c1
  my %month = (
    'Jan' => '01',
    'January' => '01',
    'Feb' => '02',
    'Febuary' => '02',
    'Mar' => '03',
    'March' => '03',
    'Apr' => '04',
    'April' => '04',
    'May' => '05',
    'Jun' => '06',
    'June' => '06',
    'Jul' => '07',
    'July' => '07',
    'Aug' => '08',
    'August' => '08',
    'Sep' => '09',
    'September' => '09',
    'Oct' => '10',
    'October' => '10',
    'Nov' => '11',
    'November' => '11',
    'Dec' => '12',
    'December' => '12',
    );
  my $input_string = shift;
  my $name;
  my $value;
  my $text;
  my $month_str;
  my $year_string;
  my $ver_string;
  chomp ($input_string);
  # remove leading blanks
  $input_string =~ s/^ *//;
  # remove trailing blanks
  $input_string =~ s/ *$//;
  ##print "Input:".$input_string."<\n"; ## DEBUG
  for ($input_string) {
    if (/^Vz[1-9]/) {
      $input_string =~ s/^......//;
      $input_string =~ s/ .*//;
      $month_str = substr($input_string,0,3);
      $year_string = substr($input_string,3,4);
      $ver_string = substr($input_string,7);
      ##print "Conversion:".$year_string.$month{$month_str}.$ver_string."\n"; ## DEBUG
      $year_string.$month{$month_str}.$ver_string;
    }elsif (/^CPB/){
      ($name,$value,$text) = split / +/, $input_string;
      ##print "Value:".$value."\n"; ## DEBUG
      ($year_string, $month_str, $date_string) = split /\./, $value;
      $year_string.$month_str.$date_string;
    }elsif (/^XSWGR/){
      $input_string =~ s/ \(.*//;
      $pos = length $input_string;
      $pos = rindex $input_string, " ", $pos;
      ##print "Pos=".$pos."\n"; ## DEBUG
      $year_string = substr($input_string,$pos+1,4);
      ##print "Year:".$year_string."\n"; ## DEBUG
      $pos--;
      $pos2 = rindex $input_string, " ", $pos;
      ##print "Pos2=".$pos2."\n"; ## DEBUG
      ##print "Input:".$input_string."\n"; ## DEBUG
      $month_str = substr($input_string,$pos2+1,$pos-$pos2);
      ##print "Month:".$month_str."\n"; ## DEBUG
      $year_string.$month{$month_str};
    }
  }
}
