#!/usr/bin/perl

#use strict;
#use sigtrap;
#use diagnostics;
use Getopt::Long;
use CGI qw/:standard :html3/ ;
use File::Spec;

##
## This perl script is the first of a 2 part form
## here the user selects data source(s) and a list
## of hosts to report on. This script then calls
## another form where the user selects fields from
## the data source(s)

# Revision History
# 01.01 20090407 Select CSV file from list (Mts)

sub init_vars {

  # Read site custom variables from init file
  $currentfile = File::Spec->rel2abs( $0 );
  ($vol, $dir, $file) = File::Spec->splitpath( $currentfile );
  @dirs = File::Spec->splitdir( $dir );
  pop(@dirs);
  pop(@dirs);
  push(@dirs,"etc");
  $dir = File::Spec->catdir(@dirs);
  $initfile= File::Spec->catfile( "",$dir,"JADIS.init");
  &get_site_custom($initfile);

  #Set Site Custom vars
  $basedir = $config{TOPDIR};
  $websvr = $config{WEBSVR};
  ## END Site Custom Vars
  #$csvfile = $basedir."/summary_files/sysinfo_latest.csv";
  $csvdir = $basedir."/summary_files";
  $listdir = $basedir."/lists";

  ## Read command line or Set defaults 
  my %opts;
  my $parms;
  my $i=0;
  my $b=0;

  ##print $csvfile."\n";
  @parm_list = ();
  @list_list = ();
  @csv_list = ();

  chdir $listdir;
  #open(KEY,$csvfile) || die "cannot open $csvfile for read";
  #($line = <KEY>);
  #chop $line;
  #@parm_list = split(/,/, $line);
  #shift(@parm_list);
}

sub get_site_custom {
  my $file = shift;
  open(CONFIG,$file) or die "can't open $file: $!";
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

sub output_html {
$postsite="http://".$websvr."/JADIS/cgi-bin/gen_req2.pl";
print header;
print "\n";
print start_html(-title=>'System Info Request',
		 -author=>'mark.simon@sbcglobal.net',
		 -style=>{'src'=>'/JADIS/etc/default_form.css'}),
    p,
    h1('FTR JADIS Request'),
    start_form("POST",$postsite,),
    h2('Select Data Source'),
    p,
    scrolling_list(-name=>'source',
		   -values=>[@csv_list],
                   -default=>'sysinfo_latest.csv',
                   -size=>9,
                   -multiple=>'false'),
    "&nbsp;&nbsp;&nbsp;&nbsp;",
    submit(-id=>'button', -name=>'button',
	   -value=>'Next'),
    p,
    hr,
    h3('Pick a List of Hosts'),
    p,
    scrolling_list(-name=>'hostlist',
	       -values=>[@list_list],
	       -default=>'sys.all',
	       -size=>9,
	       -multiple=>'true'),
    "&nbsp;&nbsp;&nbsp;&nbsp;",
    submit(-id=>'button', -name=>'button',
	   -value=>'Next'),
    p,
    end_form,
    hr,

    end_html;
}

sub init_csvlist { ## get list of csv files
   my $listdir = shift;
   my $listname = " ";
   chdir $listdir;
   while ($listname = <*.csv>){
      unshift(@csv_list, "$listname");
   }
}


sub init_hostlist { ## get list of host lists
   my $listdir = shift;
   my $listname = " ";
   chdir $listdir;
   while ($listname = <sys.*>){
      push (@list_list, "$listname");
   }
}

## Call all sub routines
##print "Getting Started\n";
&init_vars();
&init_hostlist($listdir);
&init_csvlist($csvdir);
&output_html();
print "\n";
