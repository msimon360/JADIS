#!/usr/bin/perl -w

# Revision History
# 01.00 20110920 Compare two CSV files (Mts)
#
# (Mts) Mark T Simon
#
#use strict;
#use sigtrap;
#use diagnostics;
use Getopt::Long;
use File::Spec;
use Text::CSV;
# Commented out Switch, it is not compatable with Apache mod_perl
#use Switch;
use CGI qw/:standard :html3/ ;
use lib "/infra/opt/JADIS/cgi-bin/plugins";

##
## This perl script compares two csv files on common fields
##

sub init_vars { # Initialize Variables
  ## SITE CUSTOM ##
  #
  # Determine location of JADIS init file
  my $vol;
  my $dir;
  my $file;
  $currentfile = File::Spec->rel2abs( $0 );
  ($vol, $dir, $file) = File::Spec->splitpath( $currentfile );
  @dirs = File::Spec->splitdir( $dir );
  pop(@dirs);
  pop(@dirs);
  push(@dirs,"etc");
  $dir = File::Spec->catdir(@dirs);
  $initfile = File::Spec->catfile( "",$dir,"JADIS.init");

  # Read Site file var's into array
  &get_site_custom($initfile);

  # Set local var's from array values
  $version     = $config{VERSION};
  $basedir     = $config{TOPDIR};
  $etcdir      = $basedir."/etc/";
  $datalist    = $config{DLIST};
  $pagetitle   = $config{TITLEPG};
  $docsite     = $config{DOCLOC};
  $website     = $config{WEBSVR};
  $per_month   = $config{PERMONTH};
  ## End SITE CUSTOM ##

  ## Read command line or Set defaults 
  my %opts;
  my $parms;
  my $sec;
  my $min;
  my $hour;
  my $mday;
  my $mon;
  my $year;
  my $wday;
  my $yday;
  my $isdst;
  my $i=0;
  my $b=0;
  my $junk;
  my $rest;
  my @csv_parm_list = ();

  ($sec,$min,$hour,$mday,$mon,$year,$wday,
  $yday,$isdst)=localtime(time);
  $year = $year+1900;
  $mon = $mon+1;
  $month_string = sprintf "%02d", ( $mon);
  $mdate_string = sprintf "%02d", ($mday);
  $button = "none";
  $csvfile = $basedir."/summary_files/sysinfo_latest.csv";
  $modellist = $basedir."/etc/Model.lis";
  ##print $csvfile."\n";
  @parm_list = ();
  &load_sources($datalist);
  &load_doclist($modellist);
  # Get command line options
  GetOptions(\%opts,'a' => \$a ,'b' => \$b ,'c' => \$c ,'h'=> \$h ,'i' => \$i ,'l=s' ,'n' => \$NOCSV ,'o=s','p=s' ,'s' => \$s );
  $all_hosts = $a;
  $help      = $h;
  if ($help) { die "usage : compare_csv.pl [-ah] file1 file2
    -a  Report on all hosts not just entries with differences
    -h  Print this help
    -s  Case Sensitive comparisions\n"
  };
  $listdir   = $opts{'l'} || $basedir."/lists";
  $output  = $opts{'o'} || 'html';
  $parms   = $opts{'p'} || 'all';
  #print $parms; #DEBUG
  ##print "==============================================\n";
  if ( $#ARGV != 1 ) { die "You must enter 2 files to compare\n"};
  @csvfile_list = @ARGV ;
  #&print_file_list();
  $batch = $b;
  $interactive = $i;
  $case_ignore = "";
  $case_ignore = "i" unless ( $s);

  # If the csv flag is set look for a csv file with the current date
  # or generate one if it does not exist.
  $csv = $c;
  if ( $csv ){
    my $datestamp = sprintf "%04d%02d%02d",( $year,$mon,$mday);
    $csvfile = $basedir."/summary_files/sysinfo_".$datestamp.".csv";
  }
  # If the No CSV flag is set do not load the csv file.
  if ( $NOCSV ){
    $csvfile = "none";
  }

  #&load_parser($keyfile);
  %summary = ();
#  $dataoutput[0] = (
#        'hostname' => { 'parameter' => 'value'}
#        );
#  $dataoutput[1] = (
#        'hostname' => { 'parameter' => 'value'}
#        );
  @file_parm_list = ();

format STDOUT =
@<< @<<<<<<<<<<<<<<<	@<< @<<<<<<<<<<<<<<<
$firstcolnum, $fisrtcolname, $secondcolnum, $secondcolname
.


  ## Read params passed by webform or set defaults

  if  ($interactive || $batch ) {
    # This is for testing
    $cgi = new CGI;
    }
  else
  {
    $cgi = new CGI;
    # redirect STDERR to keep from filling up Apache logs
    #open STDERR, ">>/dev/null";

  ## bundle up form submissions into a parm_list array
    $parms = "";
    foreach $field (sort ($cgi->param)) {
      $_=$field;
      if(/parm/) {
          foreach $value ($cgi->param($field)) {
             $parms = $parms." ".$value;
          }
          $parms = substr($parms,1,);
      }
      elsif (/hostlist/) {
        foreach $value ($cgi->param($field)) {
        $host_list=$value;
        }
      }
      elsif (/source/) {
        foreach $value ($cgi->param($field)) {
	  $csvfile=$basedir."/summary_files/".$value;
	}
      }
      elsif (/button/) {
        foreach $value ($cgi->param($field)) {
	  $button=$value;
	}
      }
    }
  }
  for ($button){
    if (/Export to Excel/) {
      $output= "excel";
    }
  }
  # Moved the parameter expansion after the CGI form read
  # so Keyfile date matches csvfile date selected
    foreach $source (keys %sources ) {
      $keyfile = $sources{$source}[1];
      #print "$keyfile\n"; #DEBUG
      chomp $keyfile;
      if ($keyfile eq 'CSV' ){
        if ( $parms =~ /all/ ){
          $keyfile = $sources{$source}[0];
          #print "$keyfile\n"; #DEBUG
          $keyfile =~ s/%YYY/$year/;
          $keyfile =~ s/%y/20$year/;
          $keyfile =~ s/%m/$month_string/;
          $keyfile =~ s/%d/$mdate_string/;
          #print "$keyfile\n"; #DEBUG
          open(KEY,$keyfile) || die "cannot open $keyfile for read\n";
          $line = <KEY>;
          close (KEY);
          ##print "Raw Line:".$line."\n"; ## DEBUG
          chomp $line;
          ($junk, $rest) = split /\,\s*/, $line, 2;
          ##print "Junk:".$junk."Rest:".$rest."\n"; ## DEBUG
          @csv_parm_list = split ',', $rest ;
          foreach $value (@csv_parm_list){
            print STDERR "Key:".$value."\n";
            push (@parm_list, $value);
          }
        }
      }
      elsif ($keyfile eq 'DATA' ){
        if ( $parms =~ /all/ ){
          print STDERR "Key:".$source."\n";
          push (@parm_list, "$source");
        }
      }
      else {
        if ($parms =~ /all/ ){
          print STDERR "Key:".$source."\n";
          push (@parm_list, "$source");
        }
        $keyfile = $etcdir.$sources{$source}[1];
        chomp $keyfile;
        open(KEY,$keyfile) || die "cannot open $keyfile for read\n";
        while ($line = <KEY>) {
          ($param, $rest) = split /:\s*/, $line, 2;
          if ($parms =~ /all/ ){
            print STDERR "Key:".$param."\n";
            push (@parm_list, "$param");
          }
          @fields = split ',', $rest; 
          $datapoints{$param} =  [ @fields ];
          #print "#####################"; #DEBUG
          #print $datapoints{$param}[3]; #DEBUG
        }
        close (KEY);
      }
    }
    if ( $parms ne "all" ){
      @parm_list = split(/ /, $parms);
      #print @parm_list ; # DEBUG
      #print $parms."\n";
    }
  # The next four lines sort the parms list into unique valaues
  @in = @parm_list;
  undef %saw;
  @saw{@in} = ();
  @parm_list = sort keys %saw;
}

sub print_file_list {
  foreach $csvfile (@csvfile_list){
    print "Input file ".$csvfile;
  }
  die;
}
sub get_site_custom { # Get Common Site Variables
  # Parse a ksh style init file in an array
  my $file = shift;
  open(CONFIG,$file) or die "can't open $file: $! \n";
  while (<CONFIG>) {
    chomp;
    s/#.*//; # Remove comments
    s/^\s+//; # Remove opening whitespace
    s/\s+$//;  # Remove closing whitespace
    next unless length;
    my ($key, $value) = split(/\s*=\s*/, $_, 2);
    $config{$key} = $value;
  }
  close(CONFIG);
  #print "Completed get_site_custom\n"
}

sub load_sources { ## load list of data sources
my $keyfile = shift;
open(InFILE,$keyfile) || die "cannot open $keyfile for read\n";
while ($line = <InFILE>) {
  ($source, $spath, $skey) = split ',', $line;
  ##print "Source:".$source."Path:".$spath."Key:".$skey."\n"; ## DEBUG
  $sources{$source} =  [ $spath, $skey ];
  }
}

sub load_parser {  ## load hash to parse data
my $keyfile = shift;
open(InFILE,$keyfile) || die "cannot open $keyfile for read\n";
while ($line = <InFILE>) {
    ($param, $rest) = split /:\s*/, $line, 2;
    ##print "param $param REST $rest";
    @fields = split ',', $rest; 
    $datapoints{$param} =  [ @fields ];
 #print "##############################\n"; # DEBUG
 #print "PARM:".$param." Sort:".$datapoints{$param}[3]."\n"; # DEBUG
  }
  #print "Loaded keyfile ".$keyfile; ## DEBUG
}

sub init_host { # Initalize values for a host
  ##print "In init_host for ".$hostname."\n"; ## DEBUG
  $hostname = shift;
  foreach $param ( @parm_list) {
    $dataoutput{$hostname}{$param} = $datapoints{$param}[2] || "not_found";
  }
}

sub load_doclist { ## load the table for model documents
  my $modfile = shift;
  my $modstring;
  my  $doc;

  open(IN,$modfile) || die "cannot open $modellist for read\n";
  while (<IN>) {
    ($modstring, $doc) = split / /;
    chop $modstring;
    chop $doc;
    $modeldocs{$modstring} = $doc;
  }
#  foreach $modstring ( keys %modeldocs ) {
#    print "String".$modstring." Doc ".$modeldocs{$modstring};   
#  }
}

sub load_csv {  ## load the csv file into array
  $csvfile = $_[0];
  my $x = $_[1];
  my $line_num = 1 ;
  my @fields;
  my $field = "";
  my @parm_list;
  my $hostname;
  my $csv = Text::CSV->new();
  my $line;

  open(IN,$csvfile) || die "cannot open $csvfile for read\n";
  while ($line = <IN>) {
    chop $line;
    my $status = $csv->parse($line);
    #print $status." csv parse status\n"; # DEBUG
    # process header line
    if ( $line_num == 1 ){
      #print $line."\n"; #DEBUG
      @parm_list = $csv->fields();
      #print @parm_list." fields found\n"; ## DEBUG
      foreach $field ( @parm_list){
        push @{$file_parm_list[$x]}, $field;
        #print $field."\n"; #DEBUG
      }
      # now remove 1st field - hostname
      shift (@{$file_parm_list[$x]});
      shift (@parm_list);
      $line_num++;
    } # end process header line
    else {
      # read data line
      @fields = $csv->fields($line);
      #@fields = split ',';
      $hostname = shift(@fields);
      $hostname =~ tr/A-Z/a-z/; # convert hostname to lower case
      # Add hostname to list of all hosts
      push (@host_list,$hostname);
      # Add hostname to list of this files hosts
      push (@{$file_host_list[$x]},$hostname);
      foreach $param (@parm_list){
	$dataoutput[$x]{$hostname}{$param} = shift(@fields);
         #print $x." ".$hostname." ".$param." ".$dataoutput[$x]{$hostname}{$param}."\n"; ## DEBUG
      } # end reading field values
    } # end reading data line
  } # end while <IN>
  close(IN);
  # find common fields
  if ( $x == 1 ){
    #print "second file\n"; ##DEBUG
    foreach $field_A (0..@{$file_parm_list[0]}-1){
      my $valueA = $file_parm_list[0][$field_A];
      #print "A ".$valueA."\n"; ##DEBUG
      foreach $field_B (0..@{$file_parm_list[1]}-1){
      my $valueB = $file_parm_list[1][$field_B];
        #print "B ".$valueB."\n"; ##DEBUG
        if ( $valueA eq $valueB ){
          push (@common_fields, $valueA );
        }
      }
    } # end parameters
    if ( @common_fields == 0) {die "There are no common fields to compare\n"};
  #print "Fields Common to both Files: "; ##DEBUG
  #for my $value (@common_fields){
  #  print $value.", ";
  #}
  #print "\n";
  # Get union and intersection of host lists
  @all_host_list = @host_list = my @diff = ();
  my %count = ();
  foreach my $element (@{$file_host_list[0]}, @{$file_host_list[1]}) {
      $count{$element}++;
  };
  foreach my $element (keys %count) {
      push @all_host_list, $element;
      push @{ $count{$element} > 1 ? \@host_list : \@diff }, $element;
  };
  # The next four lines sort the host list into unique valaues
#  @in = @union;
#  undef %saw;
#  @saw{@in} = ();
#  @host_list = sort keys %saw;
  ##print "Fields Common to both Files: "; ##DEBUG
  #for my $value (@common_fields){
  #  print $value.", ";
  #}
  #print "\n";
  } # end processing for second file
} # end load_csv


sub parse_file {  ## parse a data file
  #print "In parse_file for Host:".$hostname." Source:".$source."\n"; ## DEBUG
  $hostname = shift;
  $source = shift;
  my $newestfile = '';
  my $newfiledate = '';
  my $oldfiledate = '';
  my $oldname = '';
  my $infile = $sources{$source}[0];
  my $outfile = "";
  my $formstr = $infile;
  $formstr =~ s/%H/$hostname/;
  $infile =~ s/%H/$hostname/;
  $infile =~ s/%YYY/????/;
  $infile =~ s/%m/??/;
  $infile =~ s/%d/??/;
  #print "File Match:".$infile."\n"; ## DEBUG
  my @a = <${infile}>;
  foreach $name (@a){
   #print $name."\n"; ## DEBUG
   $newfiledate = &parse_filename($formstr, $name);
   #print "New:".$newfiledate." Old:".$oldfiledate."\n"; ## DEBUG
   if ( $newfiledate gt $oldfiledate){
     $newestfile = $name;
     #print $newestfile."\n"; ## DEBUG
     # If the per_month flag is set delete all but the newest file for each month
     if ( $per_month ){
       if ( substr($oldfiledate,0,6) eq substr($newfiledate,0,6)){
	 #print substr($oldfiledate,0,6);  # DEBUG
	 #print " matches ";  # DEBUG
	 #print substr($newfiledate,0,6);  # DEBUG
	 #print "\n";  # DEBUG
	 unlink ($oldname);
	 print STDERR "### Delete $oldname \n";  # LOG
       }
     }
     $oldfiledate = $newfiledate;
   }
   $oldname=$name;
  } # Loop all data files for a host source combination

  $infile = $newestfile;
  if ( $infile eq "" ){
    return;
  }
  my $keyfile = $sources{$source}[1];
  #print "Datafile:".$infile." Key:".$keyfile."\n";  ## DEBUG
  my $linenum = 1;
  undef %datapoints;

  # If keyfile = CSV set key to hostname and transform to parse_csv
  for ($keyfile ) {
    if (/CSV/) {
      $datapoints{"CSV"}[0] = "\^".$hostname.",";
      $datapoints{"CSV"}[1] = "&parse_csv";
      $datapoints{"CSV"}[2] = "_N/A";
      $datapoints{"CSV"}[3] = "default";
    }
    elsif (/DATA/) {
      $datestring = &parse_filename($formstr,$infile);
      $dataoutput{$hostname}{$source} = $datestring;
      ##print "In DATA for ".$hostname.$source.$datestring."\n"; ## DEBUG
      return
    }
    else {
      &load_parser ( $etcdir.$keyfile );
    }
  }
  ##print $infile; ## DEBUG
  print STDERR "### In parse_file:".$infile."\n"; ## LOG
  # Open the data file and read
  open(IN,$infile) || return ;
  # If the file opens get it's date
  $datestring = &parse_filename($formstr,$infile);
  #print "File:".$infile." Date:".$datestring."\n"; ## DEBUG
  $dataoutput{$hostname}{$source} = $datestring;
  
  if ($source eq "SysInfo"){
    $outfile = $infile;
    $outfile =~ s/^.*\///;
    $outfile = "/tmp/".$outfile."$$";
    open(OUT,">".$outfile) or die "Unable to open $outfile: $!";
    print STDERR "Writing new sysinfo file $outfile\n";
  }
  # set these vars for SysInfo files
  $end_div="";
  $no_div="true";
  if ($source eq "cfg2html" || $source eq "cfg2html2"){
    @os_list = ("AIX","HP-UX","linux","HMC","Tandem");
    #print "check os in cfg2html"; ## DEBUG
    LINE: while ($linein = <IN>) {
      #print "Checking line ".$linenum." for OS\n"; ## DEBUG
      if ($linenum == 40 ){
        last LINE;
      }
      $_ = $linein;
      foreach $os ( @os_list ) {
        if (/$os/){
          #print "Matched OS ".$os."on line \n##".$linein."\n"; ## DEBUG
          $keyfile=$os."_".$keyfile;
          &load_parser ( $etcdir.$keyfile );
          print STDERR "Found ".$os." in ".$infile."\n";
          print STDERR "Keyfile is now ".$keyfile."\n";
          last LINE;
        }
      }
    } 
    close (IN);
    open(IN,$infile) || return ;
  }
  #
  # Parse the file line by line
  while ($linein = <IN>) {
    #chomp $linein;
    if ($linenum == 1 ){
      $lineone = $linein;
      $linenum++;
    }
    # For each parameter in the keyfile
    foreach $param ( keys %datapoints ) {
      ##print "Parm:".$param."\n"; ## DEBUG
      $_ = $linein;
      # See if the Match string is found on this line
      if (/$datapoints{$param}[0]/){
        ##print "Raw line:$_"."\n"; ## DEBUG
        ##print "$datapoints{$param}[1]"."\n"; ## DEBUG
        # Set the source parameter to the file date
        $dataoutput{$hostname}{$source} = $datestring;
	# When a line matches see if the transform action is a subroutine
        if ($datapoints{$param}[1] =~ /\&/){
          ##print "Calling sub $datapoints{$param}[1]\n"; ## DEBUG
	  ##print "Raw line:$_"."\n"; ## DEBUG
  	  $dataoutput{$hostname}{$param} = eval $datapoints{$param}[1];
        }
        else
        {
  	# If not a subroutine then evaluate it
          ##print "Eval $datapoints{$param}[1] on line\n"; ## DEBUG
          # Replace quotes with space to keep eval happy
            eval s/\'/ /g;
          # Replace < with space to keep eval happy
            eval s/\"/ /g;
            eval s/\</ /g;
            eval s/\>/ /g;
          ##print "Transformed line:$_".":\n"; ## DEBUG
          ##print "Eval string:".$datapoints{$param}[1]."\n"; ## DEBUG
  	  eval $datapoints{$param}[1];
  	  # Replace comma with space to keep CSV fields
  	  eval s/\,/ /g;
          ##print "Output:".$_.":\n"; ## DEBUG
  	  $dataoutput{$hostname}{$param} =  $_;
        }
        ##print $dataoutput{$hostname}{$param}; ## DEBUG
  	chomp ($dataoutput{$hostname}{$param});
        ##$junk = <>; ## DEBUG
      } # if a match is found
    } # Loop for each Parameter to match
    if ($source eq "SysInfo"){
      # Use a variable so no ending DIV is printed unless a starting DIV is added first
      if ($no_div eq "true"){
        if (/DIV STYLE/){
	  print STDERR "HTML already contains DIVs\n";
	  $no_div="false";
	  print OUT $_;
	}
	elsif (/\>Table Of Contents\</){
  	  print STDERR "found begining of TOC\n"; # LOG
  	  print OUT "<DIV STYLE=\"position:relative; float:left; padding-left:2em; height=35em; width=18%; overflow:auto\">\n";
  	  print OUT $_;
  	  $end_div="</DIV>\n";
  	}
        elsif (/=== END Table Of Contents ===/){
  	  print STDERR "found end of TOC\n"; # LOG
  	  print OUT $_;
  	  print OUT "</DIV>\n";
  	  print OUT "<DIV STYLE=\"position:relative; float:left; padding-left:2em; width:72%; height:35em; overflow:auto\">\n";
  	}
        elsif (/<\/BODY>/){
          print STDERR "found end of BODY\n";
        }
        elsif (/<\/HTML>/i){
          print STDERR "found end of HTML\n";
        }
        elsif (/End SysInfo [0-9]/){
          print STDERR "found end of SysInfo\n";
          print OUT $_;
          print OUT $end_div;
          print OUT "</BODY></HTML>\n";
        }
        else{
  	  print OUT $_;
        }
      } # if no DIV markers in input file
      else{
	print OUT $_;
      }
    } # if source is SysInfo
  } # Finished reading file
  close(IN);
  if ($source eq "SysInfo"){
    close(OUT);
    my @args=("cp",$outfile,$infile);
    system(@args) == 0 or print STDERR "failed to copy $outfile to $infile \n";
    unlink($outfile);
  }
} # end parse_file

sub parse_filename { # Get the date string from a filename
  $formstr = shift;
  $filename = shift;
  my @symbols = ("%YYY","%y","%m","%d");
  my $datestring = '';
  #print $filename."\n"; ## DEBUG
  #print "FormStr:".$formstr."\n"; ## DEBUG
  # If there is no date in the filename use the timestamp of the file
  if (( $formstr =~ m/%YYY|%y/)&&( $formstr =~ m/%m/)&&( $formstr =~ m/%d/)){ 
    foreach $symbol (@symbols) {
      $pos = index ($formstr,$symbol);
      if ($pos > 0){
        #print $filename." ".$pos." ".length($symbol)."\n"; # DEBUG
        $value = substr($filename,$pos,length($symbol));
        #print $symbol." = ".$value."\n"; ## DEBUG
        if ($symbol eq "%y"){
          $value = "20".$value;
        }
        $datestring = $datestring.$value;
      }
    }
  }else{
    $filedate = (stat($filename))[9];
    $datestring = (localtime($filedate))[6];
    #print $datestring;  ## DEBUG
    $datestring = $datestring.(localtime($filedate))[5];
    $datestring = $datestring.(localtime($filedate))[4];
  }
  #print "Date:".$datestring."\n"; # DEBUG
  return $datestring;
} # end parse_filename

sub extract_filename { # Given a format and date generate a filename
  $formstr = shift;
  $date_string = shift;
  if ($date_string =~ /not_found/){
    return "not_found";
  }
  my $year  = substr($date_string,0,4);
  my $month = substr($date_string,4,2);
  my $day   = substr($date_string,6,2);
  my $filename = $formstr;
  #print "$filename $date_string $year $month $day \n"; # DEBUG
  $filename =~ s/%YYY/$year/;
  $filename =~ s/%y/20$year/;
  $filename =~ s/%m/$month/;
  $filename =~ s/%d/$day/;
  #print "$filename $basedir \n"; # DEBUG
  $filename =~ s:$basedir:/JADIS:;
  return $filename;
} # end extract_filename

sub parse_csv { # Pasre data from a csv file 
  my $line = $_;
  my $x = 0;

  #print "CSV Header:".$lineone."\n"; ## DEBUG
  #print "CSV Data:".$line."\n"; ## DEBUG
  chomp $line;
  chomp $lineone;
  my $csv = Text::CSV->new();
  my $status = $csv->parse($lineone);
  my @params = $csv->fields();
  ##my @params = split ',', $lineone;
  $status = $csv->parse($line);
  my @values = $csv->fields();
  ##my @values = split ',', $line;
  foreach $param (@params) {
    # Prevent error from changing udef value
    $values[$x] =~ s/\,/\./g if defined($values[$x]);
    #print "Parm:".$params[$x]."Val:".$values[$x]."\n"; ## DEBUG
    $dataoutput{$hostname}{$param} = $values[$x];
    $x++;
  }
} # end parse_csv

sub print_output { # Print output in chosen format
  my $tvalue;
  ## my $junk;
  ## print "junk to continue";
  ## $junk = <STDIN>;
  my $param;
  my $source_file;
  for ($output){
    if (/text/){
      print "HOST: $hostname \n";
        #print @parm_list; #DEBUG
        #print "Output\n"; #DEBUG
      foreach $param ( @parm_list) {
	  print $param.": ".$dataoutput{$hostname}{$param}."\n"
	}
    }
    elsif (/summary|hsum/){
      #print "Load Summary\n"; ## DEBUG
      #print @param_list; ## DEBUG
      foreach $param ( @parm_list) {
        if ($param =~ /:/) {
          $value="";
          @combo = split ':',$param ;
          foreach $combo_param (@combo) {
            $value = $value." ".$dataoutput{$hostname}{$combo_param};
            #print "PARM:".$combo_param."\n"; ## DEBUG
            #print "VALUE:".$value."\n"; ## DEBUG
          }
          $value = substr $value, 1;
        }else{
	  $value = $dataoutput{$hostname}{$param};
        }
        #print "HOST:".$hostname."\n"; ## DEBUG
        #print "PARM:".$param."\n"; ## DEBUG
        #print "VALUE:".$dataoutput{$hostname}{$param}."\n"; ## DEBUG
        $summary{$param}{$value}++;
        #print "Parm:".$param." Value:".$value." Count:".$summary{$param}{$value}."\n"; ## DEBUG
      }
    }
    elsif (/html/){
      $formstr = $sources{"SysInfo"}[0];
      $formstr =~ s/%H/$hostname/;
      $value=$dataoutput{$hostname}{"SysInfo"};
      $source_file = &extract_filename($formstr, $value);
      if ($source_file eq "not_found" ){
        print "<tr>\n<td>".$hostname."</td>\n";
      }else{
        print "<tr>\n<td><a href=\"".$source_file."\" target=\"_blank\">".$hostname."</a></td>\n";
      }
      foreach $param ( @parm_list ) {
        $value='';
	$value=$dataoutput{$hostname}{$param};
	chomp($value);
        #print "Param".$param;
        if ($param =~ /Model/){
          $tvalue = $value;
          foreach $modstring (sort keys %modeldocs ) {
            ##print "Value:".$value." String:".$modstring."  \n";
            if ($value =~ /$modstring/i){
                $tvalue = "<a href=\"".$docsite.$modeldocs{$modstring}."\" target=\"_blank\">".$value."</a>";
		last;
            }
          }
          $value = $tvalue;
        }
        foreach $source (keys %sources ) {
          if ($param =~ /$source/){
	    $formstr = $sources{$source}[0];
            $formstr =~ s/%H/$hostname/;
	    #print "Date:".$value." Format:".$formstr."\n"; # DEBUG
            $source_file = &extract_filename($formstr, $value);
	    $value = "<a href=".$source_file." target=\"_blank\">".$value."</a>";
	  }

        }
        print "<td>".$value."</td>\n";
      }
      print "</tr>\n";
    }
    elsif (/csv|excel/){
        print "\n";
        print "$hostname";
      foreach $param ( @parm_list ) {
        #print "\n".$param."\n"; ## DEBUG
        print ",".$dataoutput{$hostname}{$param};
      }
    }
    else { print "I don't know how to format $output in body yet.\n";
      exit 1;
    }
  }
} # end print_output

sub process_list { ## Process list of hosts
  my $infile = shift;
  my $count = 0;
  my $total = 0;
  print STDERR "Working on ".$infile."\n"; ## LOG
  open(HOST_LIST,$infile) || die "cannot open $infile for read";
  my(@lines) = <HOST_LIST>;
  my %hashtemp = map { $_ => 1 } @lines;
  @lines = sort keys %hashtemp;
  $total = @lines;
  foreach $hostname (@lines){{ # loop thru list
    $count++;
    #print ">>>>>>".$hostname."\n"; ## DEBUG
    next if ($hostname =~ /^#/ );
    print STDERR "\nHost:".$hostname." ".$count." of ".$total."\n"; ## LOG
    chomp($hostname);
    if ( ! -e $csvfile ){
      #print "No CSV File"; ## DEBUG
      &init_host($hostname);
      foreach $source (keys %sources ) {
        print STDERR "\nParse ".$hostname." Source ".$source."\n";  ## LOG
        &parse_file($hostname,$source);
      }
    };
    }continue{
    $_ = $hostname;
    if (! /^#/ ){
      if (! exists $dataoutput{$hostname} ){
        &init_host($hostname);
      }
      &print_output;
      }
    }
  }
  close(HOST_LIST);
} # end process_list

sub choose_list { ## Select a host list to process
   #$host_list = "sys.new";
   #return;
   my $listdir = shift;
   chdir $listdir;
   $listname = " ";
   $listnum = 0;
   my @listlist;
   while ($listname = <sys.*>){
     $listlist[$listnum] = "$listname";
     $listnum++;
   }
   # Add one more entry in case there is an odd number of files
   # so the write will not fail on uninitalized data
   $listlist[$listnum] = " ";
   for ($i = 0; $i < $listnum; $i += 2) {
      $firstcolnum = $i;
      $fisrtcolname = $listlist[$i];
      $secondcolnum = $i +1;
      $secondcolname = $listlist[$i + 1];
      write;
   }
   print "Pick a file from the list above.";
   print "Just enter the number.";
   $choice = <STDIN>;
   chop($choice);
   $host_list = $listlist[$choice];
} # end choose_list

sub output_header { # Output file header
  for ($output){
    if (/text/){
        print "Data Output for $host_list\n";
    }
    elsif (/summary/){
      print "Data Summary for $host_list\n\n";
    }
    elsif (/excel/){
      print "Content-type: application/octet-stream\n";
      print "Content-disposition: attachment;filename=\"JADIS.csv\"\n\n";
      print "Hostname";
      foreach $param ( @parm_list ) {
        print ",".$param;
      }
    }
    elsif (/hsum/){
      ## print HTML Header File
      my $summary_title = $pagetitle;
      $summary_title =~ s/\"//g;
      print $cgi->header( -type => 'text/html' );
        print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en-US\" xml:lang=\"en-US\">
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html\"; charset=\"iso-8859-1\"></meta>
<title>Summary HP-UX Systems</title>
<script src=\"/JADIS/etc/table.js\" type=\"text/javascript\" ></script>
<link rel=\"stylesheet\" media=\"all\" type=\"text/css\" href=\"/JADIS/etc/default_summary.css\" />
</head>";

        print "<body>
<div class=\"header\">
<table class=\"header\">
   <tr>
        <th width=20% style='background:white;padding:.75pt .75pt .75pt .75pt'>
        <p align=\"middle\">
        <a HREF=\"http://ncdcwss.northcentralnetworks.com/sites/unix/\">
        <img src=\"/JADIS/icons/frontierLogo_RGB.gif\" border=0 alt=\"Frontier\" align=\"middle\" height=\"30px\"/>
        </a>
        </p>
        </th>
        <th width=\"10%\">
        <p align=\"middle\">
        <img src=\"/JADIS/icons/sign_divider.gif\" border=\"0\" align=\"middle\"/>
        </p>
        </th>
        <th width=60% style=\"white-space: nowrap;\">
        <p align=\"middle\">
        <font color=\"#D00000\" size=\"5\">Summary Data for </font>
        <font color=\"#D00000\" size=\"5\"> $summary_title </font>
        </p>
        </th>
        <th width=10%>
        <a HREF=\"http://$website/JADIS/index.html\">
        <img src=\"/JADIS/icons/btn_default.gif\" border=0 alt=\"Default Report\" align=\"middle\"/></a>
        </th>
        <th width=10%>
        <a HREF=\"http://$website/JADIS/cgi-bin/gen_req.pl\">
        <img src=\"/JADIS/icons/btn_custom.gif\" border=0 alt=\"Generate a Custom Report\" align=\"middle\"/></a>
        </th>
        <th>&nbsp;</th>
   </tr>
   <tr><th>&nbsp;</th></tr>
   <tr><th>&nbsp;</th></tr>
   <tr><th>&nbsp;</th></tr>
   <tr><th>&nbsp;</th></tr>
</table>
</div>";

    }
    elsif (/html/){
        $pagetitle =~ s/\"//g;
	$filter = "<th class=\"filter\"><input name=\"filter\" size=\"8\" onkeyup=\"Table.filter(this,this)\"></input></th>\n";
        ## print HTML Header File
        print $cgi->header( -type => 'text/html' );
#       print start_html(-title=>"Data Report ".$pagetitle, 
#	 -author=>'mark.simon@verizon.com',
#	 -script=>{-type=>'text/javascript',
#	    -src=>'/JADIS/etc/table.js'},
#	 -style=>{ -src=>'/JADIS/etc/default_house.css'},
#         -head=>meta({-http_equiv => 'Content-Type',
#	   -charset => 'iso-8859-1', -content => 'text/html'}));
        print "\n";
        print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<HTML xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en-US\" xml:lang=\"en-US\">
<HEAD>
<META http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">
<TITLE>${pagetitle}</TITLE>
<SCRIPT src=\"/JADIS/etc/table.js\"></SCRIPT>
<LINK rel=\"stylesheet\" media=\"all\" type=\"text/css\" href=\"/JADIS/etc/default_house.css\" >
</HEAD><BODY>";

        print "
<div class=\"header\">
<table class=\"header\">
   <tr>
        <th width=20% style='background:white;padding:.75pt .75pt .75pt .75pt'>
        <p align=\"middle\">
        <a HREF=\"http://ncdcwss.northcentralnetworks.com/sites/unix/\">
        <img src=\"/JADIS/icons/frontierLogo_RGB.gif\" border=0 alt=\"Frontier\" align=\"middle\" height=\"32px\"/>
        </p>
        </th>
        <th width=\"10%\">
        <p align=\"middle\">
        <img src=\"/JADIS/icons/sign_divider.gif\" border=\"0\" align=\"middle\"/>
        </p>
        </th>
        <th width=70% style=\"white-space: nowrap;\">
        <p align=\"middle\">
        <font color=\"#D00000\" size=\"5\">System Data for </font>
        <font color=\"#D00000\" size=\"5\">$pagetitle</font>
        </p>
        </th>
        <th width=10%>
        <a HREF=\"http://$website/JADIS/summary.html\">
        <img src=\"/JADIS/icons/btn_summary.gif\" border=\"0\" alt=\"Summary Report\" align=\"middle\"/></a>
        </th>
        <th width=10%>
        <a HREF=\"http://$website/JADIS/cgi-bin/gen_req.pl\">
        <img src=\"/JADIS/icons/btn_custom.gif\" border=0 alt=\"Generate a Custom Report\" align=\"middle\"/></a>
        </th>
	<th>&nbsp;</th>
   </tr>
   <tr>
	<th colspan=\"3\" >&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Click Header Text to Sort, Enter Text in Boxes to Filter, Filter Counts at Bottom.</th>
   </tr>
</table>
</div>
<div class=\"outer\">
<div class=\"innera\">
<TABLE id=\"t1\" class=\"table-autosort:0 table-autofilter table-stripeclass:alternate table-filtered-rowcount:t1filtercount table-rowcount:t1allcount\" width=\"100%\">\n";

        print "<thead>\n";
	$filter_row = "<tr>
	   <th class=\"filter firstcell\">
	   <img src=\"/JADIS/icons/divider_nav.gif\" align=\"left\" height=\"24px\"/>
	     &nbsp;&nbsp;&nbsp;
	   <input name=\"filter\" size=\"8\" onkeyup=\"Table.filter(this,this)\"></input>
	   </th>\n";

	$header_row =  "<tr valign=\"top\"><th class=\"filterable table-sortable:default firstcell\">
               <img src=\"/JADIS/icons/divider_nav.gif\" align=\"left\" height=\"24px\"/>
               <img src=\"/JADIS/icons/divider_nav.gif\" align=\"right\" height=\"24px\"/>
                &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hostname&nbsp;&nbsp;&nbsp;</th>\n";
        foreach $param ( @parm_list ) {
          # This is not working
          #if ( ! defined $datapoints{$param}[3] ){
          #  $datapoints{$param}[3] = "default";
          #}
          #print "SORT:".$datapoints{$param}[3]."\n"; # DEBUG
	  chomp ($datapoints{$param}[3]);
	  $header_row = $header_row."<th class=\"filterable table-sortable:".($datapoints{$param}[3] || "default")."\"><img src=\"/JADIS/icons/divider_nav.gif\" align=\"right\" height=\"24px\"/>".$param."</th>\n";
	  $filter_row = "$filter_row"."$filter";
        }
        print $filter_row;
        print "</tr>\n";
        print $header_row;
        print <<"EOF";
</tr>
</thead>
<tfoot>
<tr>
  <td colspan="16"><font color="black" >
  <b><span id="t1filtercount">
  </span></b>&nbsp;of <b>
  <span id="t1allcount">
  </span></b>&nbsp;rows match filter(s)</font></td>
</tr>
</tfoot>
<tbody>
EOF
    }
    elsif (/csv/){
      print "Hostname";
      foreach $param ( @parm_list ) {
      print ",".$param;
      }
    }
    else { print "I don't know how to format $output in header yet.\n";
      exit 1;
    }
  }
} # end output_header

# usage: $string = prettydate( [$time_t] ); 
# omit parameter for current time/date 
sub prettydate {  # Convert Date/Time into usable string
   @_ = localtime(shift || time); 
   return(sprintf("%02d:%02d %02d/%02d/%04d", @_[2,1], $_[4]+1, $_[3], $_[5]+1900)); 
} # end prettydate

sub output_footer { # Output file footer
    my $datestring = prettydate(); 
    my $k1; # Key to parameters
    my $k2; # Key to values
    
  for ($output){ 
    if (/text/){
        print "\n";
    }
    elsif (/summary/){
      ##print "Print Summary\n"; ## DEBUG
format SUMMARY =
@<<<<<<<<<<<<<<<<<<<<<<<<        @>>>>>>
$out1, $out2
.
select(STDOUT);
$~ = "SUMMARY";
      for $k1 ( sort keys %summary ) {
        $out1 = $k1;
        $out2 = "count";
        write;
        print "==============================     =====\n";
        $total = 0;
	for $k2 ( sort keys %{$summary{ $k1 }} ) {
          $out1 = $k2;
	  $out2 = $summary{ $k1 }{ $k2 };
          write;
          $total = $total + $out2;
        }
        print "==============================     =====\n";
        $out1 = "Total";
        $out2 = $total;
        write;
        print "\n";
      }
    }
    elsif (/hsum/){
      ##print "Print Summary\n"; ## DEBUG
      my $count = 0; # count of unique values for a parameter
      my $total = 0; # total of hosts for a parameter
      my $p2; # Print version of k2
      print "<div class=\"sumouter\">\n";
      for $k1 ( sort keys %summary ) {
	# Start a new Table for each Parameter
        print "<div class=\"summary\">\n<div class=\"model\">\n";
        print "<div class=\"innerb\">\n";
        print "<table class=\"summary table-autosort:0 table-stripeclass:alternate\" >\n";
        print "<col align=\"left\" />\n";
        print "<col align=\"right\" />\n";
        print "<thead>\n";
        print "<tr>\n<th class=\"firstcell table-sortable:ignorecase\">\n";
        print "<B>".$k1."</B></th>\n";
        print "<th class=\"table-sortable:numeric\">Count</th></tr>\n</thead>\n<tbody>\n";
        $count = 0;
        $total = 0;
	for $k2 ( sort keys %{$summary{ $k1 }} ) {
	  $p2 = $k2;
	  $p2 =~ s/ /\&nbsp\;/;
	  ##print "\t". $k2."\t". $summary{ $k1 }{ $k2 }."\n"; ## DEBUG
          print "<tr><td>".$p2."</td><td>".$summary{ $k1 }{ $k2 }."</td></tr>\n";
          $count++;
	  $total = ($total + $summary{ $k1 }{ $k2 });
        }
        print "</tbody><tfoot>\n";
        print "<tr><td>Unique&nbsp;".$count."</td>";
        print "<td><b>Total&nbsp;".$total."</b></td></tr>\n";
        print "</tfoot></table></div></div></div>\n";
      }
      print <<"      EOF";
      </div>
      <div class="summaryfooter">
      Updated $datestring by JADIS ver $version
      </div>
      </body>
      </html>
      EOF
      print "\n";
    } # End for hsum
    elsif (/excel/){
        print "\n";
    }
    elsif (/html/){
        ## print HTML Footer File
print <<"EOF";
</tbody>
</table>
</div>
</div>
<div class="rpt_last_line">
&nbsp;
</div>
<div class="reportfooter">
Updated $datestring by JADIS ver $version
</div>
</body>
</html>
EOF
    }
  }
} # end output_footer

sub list_unique{
  my $y=0;
  for ($x = 1 ; $x >= 0; $x--){
    my @union = my @inter = my @diff = ();
    my %count = ();
    print "Unique hostnames in file ".$csvfile_list[$y]."\n";
    $y++;
    foreach my $element (@all_host_list, @{$file_host_list[$x]}) {
        $count{$element}++;
    };
    foreach my $element (sort keys %count) {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@inter : \@diff }, $element;
    };
    foreach $host (@diff){
      print $host."\n";
    }
  print "\n";
  }
} # end list_unique

sub compare_files{
  ##print "In compare_files subroutine\n"; ##DEBUG
#  format REPORT_TOP=
#                    File_A           File_B
#                    @<<<<<<<<<<<<<   @<<<<<<<<<<<<<
#$head1, $head2
#                    ==============   ==============
#.

  format REPORT=
^<<<<<<<<<<<<<<<    ^<<<<<<<<<<<<<<<<  ^<<<<<<<<<<<<<<<< ~~
$out1, $out2, $out3
.

  $~ = "REPORT";
  &list_unique();
  my $data1 = my $data2 = ();
  my $output_count = 0;
  print "File_A = ".$csvfile_list[0]."\n";
  print "File_B = ".$csvfile_list[1]."\n\n";
  print "Only differences are listed\n" unless $all_hosts;
  foreach $param (@common_fields){
#    print "\n";
#    $out1 = " ";
#    $out2 = "File_A";
#    $out3 = "File_B";
#    write(REPORT);
#    #print $out1."\t".$out2."\t".$out3;
#    $out1 = "Hostname";
#    $head1 = $param;
#    $head2 = $param;
#    write;
#    $out1 = "=================";
#    $out2 = "=================";
#    $out3 = "=================";
#    write;
#    #print $out1."\t".$out2."\t".$out3;
    my $output_count=0;
    foreach $host (sort @host_list){
      $data1="X";
      $data1=$dataoutput[0]{$host}{$param} if defined ($dataoutput[0]{$host}{$param});
      $data2="X";
      $data2=$dataoutput[1]{$host}{$param} if defined ($dataoutput[1]{$host}{$param});
#      unless (( $data1 eq $data2) && (! $all_hosts)){
      unless (( $data1 =~  m/$data2/i) && (! $all_hosts)){
        &write_field_header() if ( $output_count == 0);
        $output_count++;
        $out1=$host;
        $out2=$data1;
        $out3=$data2;
        write;
      }; # end output data
      #print $out1."\t".$out2."\t".$out3;
    } # next common fields
  } # next host
} # end compare_files

sub write_field_header{
    print "\n";
    print "                    File_A             File_B\n";
    $out1 = "Hostname";
    $out2 = $param;
    $out3 = $param;
    write;
    print "=================   =================  =================\n";
} # end write_field_header

## MAIN - Call all sub routines
##print "Getting Started\n";
umask 022;
&init_vars();
#&print_file_list();
#print STDERR "## Starting compare_csv.pl ver ".$version."\n"; ## LOG
if ($interactive){ 
  &choose_list($listdir);
}
# Load csv files into arrays
$count=0;
foreach $csvfile (@csvfile_list){
  #print STDERR "## Loading CSV File ".$csvfile." \n"; ## LOG
  &load_csv($csvfile,$count);
  $count++;
}
&compare_files();
die "\n";
print STDERR "## Output Header\n"; ## LOG
&output_header;
##$junk = <>;
print STDERR "## Process List\n"; ## LOG
&process_list($listdir."/".$host_list);
print STDERR "## Output Footer\n"; ## LOG
&output_footer;
print "\n";
print STDERR "## gen_data.pl Complete\n"; ## LOG
