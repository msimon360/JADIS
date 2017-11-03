#!/usr/bin/perl -w

#use strict;
#use sigtrap;
#use diagnostics;
use Getopt::Long;
use CGI qw/:standard :html3/ ;
use File::Spec;

##
## This perl script reads a key file and generates a form
## where the user can select which parameters to report on.
## A directory is searched for list files to use.
## Plese edit the "" SITE CUSTOM ## variables below.

# Revision History
# 01.03 20090407 Select CSV file from list (Mts)
# 01.02 20090127 Read parameter list from CSV file not Key file (Mts)
# 01.01 20081001 New script (Mts)

sub init_vars {

  # Read site custom variables from init file
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
  $initfile= File::Spec->catfile( "",$dir,"JADIS.init");
  &get_site_custom($initfile);

  #Set Site Custom vars
  $basedir = $config{TOPDIR};
  $websvr = $config{WEBSVR};
  ## END Site Custom Vars
  #$csvfile = $basedir."/summary_files/sysinfo_latest.csv";
  $csvdir = $basedir."/summary_files/";
  $listdir = $basedir."/lists";

  ## Read command line or Set defaults 
  my %opts;
  my $parms;
  my $i=0;
  my $b=0;

  ## read form submissions
  
  #$button = param('button');
  ##print "Button=".$button."\n"; ## DEBUG
  $csvfile = param('source');
  $csvfile = $csvdir.$csvfile;
  $host_list = param('hostlist');

  ##print $csvfile."\n";
  @parm_list = ();
  @list_list = ();
  @csv_list = ();

  chdir $listdir;
  open(KEY,$csvfile) || die "cannot open $csvfile for read";
  ($line = <KEY>);
  chop $line;
  @parm_list = split(/,/, $line);
  shift(@parm_list);
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
$postsite="http://".$websvr."/JADIS/cgi-bin/gen_data.pl";
print header;
print "\n";
print start_html(-title=>'System Info Request',
		 -author=>'mark.simon@sbcglobal.net',
		 -style=>{'src'=>'/JADIS/etc/default_form.css'}),
    p,
    h1('USE-HP System Info Request'),
    start_form("POST",$postsite,),
    h2('Select Parameters to Report On'),
    p,
    checkbox_group(-name=>'parm',
		   -values=>[@parm_list]),
    p,
    hr,
    submit(-id=>'button', -name=>'button',
	   -value=>'Gen Report'),
    "&nbsp;&nbsp;&nbsp;&nbsp;",
    submit(-id=>'button', -name=>'button',
           -value=>'Export to Excel'),
    p,
    hidden(-name=>'hostlist', -values=>$host_list),
    hidden(-name=>'source', -values=>$csvfile),
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
      push (@csv_list, "$listname");
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

sub print_csv {
  my $infile = shift;
    #print "Content-type: application/vnd.ms-excel\n";
    print "Content-type: application/octet-stream\n";
    print "Content-disposition: attachment;filename=JADIS.csv\n\n";
  open(EXCEL,$infile) or die "can't open $infile: $!";
  while (<EXCEL>) {
    print $_;
  }
  close(EXCEL);
}

## Call all sub routines
##print "Getting Started\n";
&init_vars();
#&init_hostlist($listdir);
&output_html();
print "\n";
