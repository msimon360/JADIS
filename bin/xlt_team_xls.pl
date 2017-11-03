#!/usr/bin/perl -w 

# For each tab (worksheet) in a file (workbook), 
# spit out columns separated by ",", 
# and rows separated by c/r. 

use Spreadsheet::ParseExcel; 
use strict; 

my $filename = shift || "Book1.xls"; 
my $outfile = shift || "Out.csv";
my $e = new Spreadsheet::ParseExcel; 
my $eBook = $e->Parse($filename); 
my $sheets = $eBook->{SheetCount}; 
my ($eSheet, $sheetName); 
my $content;

# Open output
open(OUTPUT, ">$outfile") || die "cannot open $outfile for write";
 
foreach my $sheet (0 .. $sheets - 1) { 
    $eSheet = $eBook->{Worksheet}[$sheet]; 
    $sheetName = $eSheet->{Name}; 
    #print "#Worksheet $sheet: $sheetName\n"; #DEBUG
    my $column = 0;
    next unless ($sheetName eq "Servers" );
    next unless (exists ($eSheet->{MaxRow}) and (exists ($eSheet->{MaxCol}))); 
    foreach my $row ($eSheet->{MinRow} .. $eSheet->{MaxRow}) { 
        foreach $column ($eSheet->{MinCol} .. ($eSheet->{MaxCol}) -1) { 
            if (defined $eSheet->{Cells}[$row][$column]) 
            { 
                $content=$eSheet->{Cells}[$row][$column]->Value ;
                $content =~ s/\015?\012?//g;
                print OUTPUT $content.",";
            } else { 
                print OUTPUT ","; 
            } 
        } 
        $column = $eSheet->{MaxCol};
        if (defined $eSheet->{Cells}[$row][$column])
            {
                $content=$eSheet->{Cells}[$row][$column]->Value ;
                $content =~ s/\015?\012?//g;
                print OUTPUT $content.",";
            }
        print OUTPUT "\n"; 
    } 
} 
close(OUTPUT);
