#!/usr/bin/perl
###########################################################
##    TkMult ver. .9.9.999                               ##
##       by                                              ##
##    Richard Burkholder                                 ##
##    rlb_jr@hotmail.com                                 ##
##                                                       ## 
##    Description:                                       ##
##      A (primative) Tk GUI for TAR. This program       ##
##      is mainly an excersize in modularity and         ##
##      configuration files.  It will hopefully          ##
##      become adaptable for use with many other         ##
##      command line programs (such as RPM).             ##
##                                                       ##
##    Usage:  tkmult [{-v},{filename},{-c configfile}]   ##
##                                                       ##
##    Config File: tkmult.conf (see $configfile)         ##
###########################################################

use Tk;
use Carp;
use IPC::Open3;

# CONSTANTS / GLOBAL VARIABLES
# NOTE:  These are all the defaults for tar.
#        You will have to edit the config file for
#        use with other programs

$appname = "Tk Multiuse Program";                # App Name
$VERSION = "1.0.0";                              # App Version
$configfile = "tkmult.conf";                     # Configuration File
$debug = 0;                                      # Debug Switch
$splitter = ":";                                 # Config File Variables
$comment = "\#";
$program = "tar";                                # Program to Run
$B1title = "Extract";                            # Name of Buttons
$B2title = "List Files";
$B3title = "Build Archive";
$cmdB1 = "xvCf";
$cmdB2 = "-tvf";                   # Command Line Arguments for Buttons
$cmdB3 = "cf";
# Headers
$THeader = "    Permissions       Size        Date     Time      File\n";
$BHeader = "=============================================================================\n";
$Tempfile = "temp.tmp";            # Temporary File
$showoutput = 1;
$b1=1;
$b2=1;
$b3=1;

# GLOBALS
 
$errormsg;
@filelist;
@optname;
@optbtn;
@optcmd;
$numopt = 0;
$num1opt = 0;
$num2opt = 0;
$optcmdlist = "";
$outputdir = "./";
$cmdlist = "";
$opt1leader = "";
$opt2leader = "";

=head1 NAME

TkMult - A gui wrapper for tar that can be configured to work with a variety
of other command line programs

=head1 DESCRIPTION

A gui wrapper for tar that can be configured for other command line programs

=head1 PREREQUISITES

This script requires the C<tk> module, the C<carp> module, and C<IPC::Open3>.

=head1 COREQUISITES

Xwindows

=pod OSNAMES
Linux

=pod SCRIPT CATAGORIES
Unix/System_administration

=cut

# Do we have a config file to look at?
if ($ARGV[0] eq "-c") {
    $configfile = $ARGV[1];
}

# Read the config file
readconfig();

# Debug Header
if ($debug == 1){
    print "----------------------------\n";
    print "   DEBUGGING ON             \n";
    print "----------------------------\n";
    print "\CONSTANTS:\n";
    print "\$appname    =  $appname\n";
    print "\$VERSION    =  $VERSION\n";
    print "\$configfile =  $configfile\n";
    print "\$splitter   =  $splitter\n";
    print "\$comment    =  $comment\n";
    print "\$B1title    =  $B1title\n";
    print "\$B2title    =  $B2title\n";
    print "----------------------------\n\n";
}


if ($debug == 1){
    my ($index) = 0;
    foreach(@ARGV){
	print "Command Line $index = $_\n";
	$index = $index + 1;
    }
}

# Did user enter file to read?
if (length($ARGV[0])!=0){
    # Is it a file or a version check?
    if ($ARGV[0] eq "-v") {
	print "$appname ver. $VERSION\n";
	print "Copyright (C) 1999 Richard Burkholder Jr\n";
	print "Config file: $configfile\n";
	print "NOTE:\nThis program may not be disributed without a copy of the\n";
	print "license file and a copy of the GNU public license, which this\n";
	print "program was released under.\n";
	exit;
    }
    if ($ARGV[0] ne "-c"){
	$filename = $ARGV[0];
	testfile ($filename, $isgood);
    }
} else {
    $isgood = 0;
    $filename = "";
}

if ($debug == 1){
    print "Filename from command line: $filename\n\n";
}


my($main,
   $exit_button,
   $list_button,
   $load_button);

# Setup Tk interface
$main = MainWindow->new;
$main->appname ($appname);
$main->title($appname);

# Config the Geometry for the main window
my ($height) = $main->vrootheight();
my ($width) = $main->vrootwidth();
my ($y) = ($height / 2) - 200;
my ($x) = ($width / 2) - 400;
my ($geo) = "800x400+$x+$y";
$main->geometry($geo);

if ($debug == 1){
    print "\$main successfully setup\n";
    print "\$main Geometry = $geo\n\n";
}

# Declare buttons and frames
$frame1 = $main->Frame->pack(-side => 'top', -fill => 'x');
$exit_button = $frame1->Button(-text => "Exit", -command => sub { exit })->pack (-side => 'right');
$text = $main->Scrolled("Text", -scrollbars => 'osoe')->pack(-side => 'top', -fill => 'both', -expand => 1);
if ($b1 == 1){
$extract_button = $frame1->Button(-text => $B1title, 
				  -command => [\&extractfile])->pack(-side => 'left');
}
if ($b2 == 1){
$list_button = $frame1->Button(-text => $B2title,
			       -command => [\&listfile, $filename])->pack(-side => 'left');
}
if ($b3 == 1){
$build_button = $frame1->Button(-text => $B3title, -command => [\&LoadDialog, "extended", 1])->pack(-side => 'left');
}
$browse=$frame1->Button(-text => "...", -command => sub { LoadDialog("single", 0) })->pack (-side => 'right');
$load_entry = $frame1->Entry(-textvariable => $filename)->pack(-side => 'right', -fill => 'x', -expand => 1);
$load_entry->bind("<Return>",[\&loadfile, \$filename]);
$frame2 = $main->Frame->pack(-side => 'bottom', -fill => 'x');
$file_label = $frame2->Label(-text => "Current File: $filename")->pack(-side => 'right');
$about_label = $frame2->Label(-text => "$appname v. $VERSION by Richard Burkholder")->pack(-side => 'left');
$load_button = $frame1->Button(-text => "Load", -command => [\&loadfile, \$filename])
                               ->pack (-side => 'left');
#$test_button = $main->Button(-text => "Test", -command => [\&OptionsDialog, 2])->pack (-side => 'bottom');
# Main loop
MainLoop;

#######################################################################
########                        SUBS                          #########
#######################################################################

## Final sub to execute when 3rd button is pushed
## Parameters:
##    None
sub button3 {
    if ($debug == 1){
	print "buildarchive entered\n";
	print "\n";
    }
    my $fliststring = "";
    foreach (@filelist){
	$fliststring = $fliststring." $_";
    }
    $pid = open3(*PRG_IN, *PRG_OUT, *PRG_ERR, "$program $opt2leader$cmdlist $outputdir$fliststring");
    close (PRG_IN);
    @outlist = <PRG_OUT>;
    @errlist = <PRG_ERR>;

    if ($debug == 1){
	print "\$program = $program\n";
	print "\$opt2leader = $opt2leader\n";
	print "\$cmdlist = $cmdlist\n";
	print "\$fliststring = $fliststring\n";
	print "\$outputdir = $outputdir\n";
	print "$program $opt2leader"."$cmdlist $outputdir$fliststring\n";
    }

    $text->delete ("1.0","end");
    if ($errlist[0] eq ""){
	$text->insert('end',"Operation Succesful\n");
	foreach(@outlist){
	    $text->insert('end',$_);
	}
    } else {
	if ($debug == 1){
	    foreach (@errlist){
		print "$_";
	    }
        }
	$text->insert ('end', "\nAn error has occured...\n");
    }
}

#######################################################################################################
## Displays a load file dialog box
## Parameters:
##   $loption = "single"/"multiple"  :  Which type of load box to display
##   $arg1 = 1/0  :  Execute Button 3 or no
sub LoadDialog {
    if ($debug == 1){
	print "LoadDialog entered:  \$loption = $loption, \$filename = $filename\n";
    }
    
    my ($loption, $arg1) = @_;
    my ($tempvar) = $filename;
    $fmask = "./*";
    my ($where) = "../";
    my ($height) = $main->vrootheight();
    my ($width) = $main->vrootwidth();
    my ($y) = ($height / 2) - 110;
    my ($x) = ($width / 2) - 100;
    $win = MainWindow->new;
    $win->title ("Select File");
    my ($geo) = "200x220+$x+$y";
    $win->geometry ($geo);
    
    if ($debug == 1){
        print "\$win created\n";
        print "\$win geometry = $geo\n\n";
    }

    @a;
    $where="../";
    $a[0]="./";
    $a[1]="../";
    my ($entry) = $win->Entry (-textvariable => $fmask)->pack (-fill => 'x');
    $listbox = $win->Scrolled ("Listbox", -scrollbars => "e", -selectmode => $loption)->pack (-fill => 'both');
    $frameGlob = $win->Frame->pack (-side => 'bottom', -fill => 'x');
    $entry->bind ("<Return>", sub {$t = $entry->get();
				   my (@stuff) = glob ($t);
				   $listbox->delete (0, 'end');
				   $listbox->insert ('end',@a);
				   $listbox->insert ('end',@stuff);});
    $listbox->bind ("<Double-Button-1>", sub {@temp = $listbox->curselection;
					   my $stuffstuff = $listbox->get($temp[0], $temp[0]);					 
					   if ($stuffstuff eq "./"){
					       my (@dirlist) = glob ("./*");
					       $listbox->delete (0, 'end');
					       $listbox->insert ('end',@a);
					       $listbox->insert ('end',@dirlist);
					   }else{
					       if ($stuffstuff eq "../"){
						   my (@dirlist) = glob ($where."*");
						   $where = $where."../";
						   $listbox->delete (0, 'end');
						   $listbox->insert ('end',@a);
						   $listbox->insert ('end',@dirlist);
					       } else{
						   my (@dirlist) = glob ("$stuffstuff/*");
						   if ($dirlist[1] ne ""){
						       $listbox->delete (0,'end');
						       $listbox->insert ('end',@a);
						       $listbox->insert ('end',@dirlist);
						       my $wlength = length($where);
						       if ($wlength > 3){
							   $where = substr($where,0,($wlength-3));
						       }
						   }
					         }
					     }
				       });
    my ($button1) = $frameGlob->Button (-text => "OK", -command => sub {@lists = $listbox->curselection();
								        if ( ($loption eq "single") && ($lists[0] ne "") ){
									    $junk = $lists[0];
									    $filename = $listbox-> get($junk, $junk);
									    $load_entry->delete(0, 'end');
									    $load_entry->insert('end', $filename);
									    print "Wrong\n";
									}
									if ($loption eq "extended"){
									    $index = 0;
									    print "Right\n";
									    foreach (@lists){
										$filelist[$index] = $listbox->get($_);
										$index = $index+1;
									    }
									}
									if ($arg1 == 1){
									    OptionsDialog(2, $cmdB3, 3);
									}
								        $win->destroy if Tk::Exists ($win); }
								    )->pack (-side => 'left'); 
    my ($button) = $frameGlob->Button (-text => "Cancel", -command => sub {$canceled = 0; $win->destroy if Tk::Exists ($win);})->pack (-side => 'right');
    my(@stuff) = glob($fmask);
    $listbox->insert ('end', @a);
    $listbox->insert ('end', @stuff);
}

#######################################################################################################
## Sub executed to extract a file
## Parameters:
##    None
sub extractfile{
    if ($debug == 1){
	print "extractfile entered:  \$filename = $filename\n\n";
    }
    if ($isgood == 0){
	$errormsg = "Please load a file first";
	Errorbox();
	return;
    }
    $text->delete ("1.0", 'end');

    OptionsDialog (1, $cmdB1, 1);
}

#######################################################################################################    
## Sub executed when Button2 is pressed
## Parameters:
##    None
sub listfile{
    if ($debug == 1){
	print "listfile entered:  \$filename = $filename\n";
    }
    if ($isgood == 0){
	$errormsg = "Please load a file first";
	Errorbox();
	return;
    }
    
    $text->delete("1.0","end");
    if ($debug == 1){
	print "\$program = $program\n";
	print "\$cmdB2 = $cmdB2\n";
	print "\$filename = $filename\n\n";
    }

    $pid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, "$program $cmdB2 $filename");
    close (HIS_IN);
    @outlines = <HIS_OUT>;
    @errlines = <HIS_ERR>;
    if ($errlines[0] eq ""){
	$text->insert ('end',$THeader);
	$text->insert ('end',$BHeader);
	foreach (@outlines){
	    $text->insert ('end', $_);
	}
    } else {
	if ($debug == 1){
	    foreach (@errlines){
		print "Error:  $_";
	    }
	    print "\n";
	}
	$text->insert ('end',"Error:  Function could not execute");
    }
}

#######################################################################################################
## Sub to load the file
## Parameters:
##    None
sub loadfile {
    $filename = $load_entry->get();
    if ($debug == 1){
	print "loadfile entered:  \$filename = $filename\n\n";
    }
    testfile ($filename,$isgood);
    if ($isgood == 1) {
	$file_label->configure(-text => "Current File: $filename");
	$text->delete("1.0","end");
	$text->insert('end', "File $filename Loaded\n");
    } else {
	$errormsg = "File Not Found";
	Errorbox();
    }
}

#######################################################################################################
## Test a file to see if it exists
## Parameters:
##    $testfilea = "Filename"  :  The filename to test
sub testfile {
    if ($debug == 1){
	print "testfile entered:  \$filename = $filename\n";
    }
    my ($testfilea) = @_;
    $isgood = 1;
    open (TESTFH, "<$testfilea")or $isgood = 0;
    if ($debug == 1){
	print "\$isgood = $isgood\n\n";
    }
    close (TESTFH);
}

#######################################################################################################
## Sub to read the config file and set the global variables
## Parameters:
##    None
sub readconfig{
    testfile ($configfile);
    if ($isgood==0){
	$errormsg = "Config File: $configfile not in current directory";
	Errorbox();
	return;
    }
    open (CONFIG, "<$configfile");
    while (<CONFIG>) {
	# Process config files
	$line = $_;
	chomp ($line);
	my ($temp) = substr($line,0,1);
	if ( ($temp ne $comment) && (length($line)!=0) ) {
	    # Process the line
	    ($header,$back) = split (/$splitter/,$line);
	    $header =~ tr/A-Z/a-z/;
	    $header =~ s/ //g;
	    if ($header eq "appname"){
		$appname = $back
	    }
	    if ($header eq "program"){
		$program = $back;
	    }
	    if ($header eq "button1"){
		$B1title = $back;
	    }
	    if ($header eq "button2"){
		$B2title = $back;
	    }
	    if ($header eq "debug"){
		$debug = 1;
	    }
	    if ($header eq "theader"){
		$THeader = $back."\n";
	    }
	    if ($header eq "bheader"){
		$BHeader = $back."\n";
	    }
	    if ($header eq "tempfile"){
		$Tempfile = $back;
	    }
	    if ($header eq "cmdbutton1"){
		$cmdB1 = $back;
	    }
	    if ($header eq "cmdbutton2"){
		$cmdB2 = $back;
	    }
	    if ($header eq "cmdbutton3"){
		$cmdB3 = $back;
	    }
	    if ($header eq "opt1"){
		($cmdname, $cmdpart) = split(/=/, $back);
		$optbtn[$numopt]=1;
		$optname[$numopt]=$cmdname;
		$optcmd[$numopt]=$cmdpart;
		$numopt = $numopt + 1;
	    }
	    if ($header eq "opt2"){
		($cmdname, $cmdpart) = split(/=/, $back);
		$optbtn[$numopt]=2;
		$optname[$numopt]=$cmdname;
		$optcmd[$numopt]=$cmdpart;
		$numopt = $numopt + 1;
	    }
	    if ($header eq "outputdirectory"){
		$outputdir = $back;
	    }
	    if ($header eq "optoutput"){
		$showoutput = $back;
	    }
	    if ($header eq "opt1leader"){
		$opt1leader = $back;
	    }
	    if ($header eq "opt2leader"){
		$opt2leader = $back;
	    }
	    if ($header eq "b1"){
		$b1 = $back;
	    }
	    if ($header eq "b2"){
		$b2 = $back;
	    }
	    if ($header eq "b3"){
		$b3 = $back;
	    }
	}
    }
    close (CONFIG);
}

#######################################################################################################
## Sub to display an errorbox
## Paramters:
##    None
sub Errorbox {
    if ($debug == 1){
	print "Entered Errorbox sub:  \$errormsg = $errormsg\n\n";
    }
    my $ebox = MainWindow->new;
    my ($height) = $main->vrootheight();
    my ($width) = $main->vrootwidth();
    my ($y) = ($height / 2) - 35;
    my ($x) = ($width / 2) - 100;
    my ($geo) = "200x75+$x+$y";
    $ebox->geometry($geo);
    $ebox->title("Error");
    my ($elabel) = $ebox->Label(-text => $errormsg)->pack;
    my ($ebutton) = $ebox->Button(-text => "Ok",
                                  -command => sub {$ebox->destroy if Tk::Exists ($ebox)})->pack(-side => 'bottom');
}

#######################################################################################################
## Sub to display the options box
## Parameters:
##    $typebox=1/2  :  Which options to load (group 1 or 2)
##    $arguments=   :  The default command line for that command
##    $btn          :  Which button that was pushed
sub OptionsDialog{
    if ($debug == 1){
	print "Entering OptionsDialog\n";
    }
    my ($typebox, $arguments, $btn) = @_;
   
    $optwin = MainWindow->new;
    $optwin->title("Options");
    my ($height) = $main->vrootheight();
    my ($width) = $main->vrootwidth();
    my ($y) = ($height / 2) - 150;
    my ($x) = ($width / 2) - 200;
    my ($geo) = "400x300+$x+$y";
    $optwin->geometry ($geo);
    
    @optindex;
    my ($tempcmdlist) = $arguments;
    my ($i) = 0;
    my ($j) = 0;
    my ($k) = 0;
    $outputdir = "";
    my ($lframe) = $optwin->Frame->pack(-side => 'bottom', -fill => 'x');
    my ($uframe) = $optwin->Frame->pack(-side => 'bottom', -fill => 'x');
    my ($tframe) = $optwin->Frame->pack(-side => 'bottom', -fill => 'x');
    my ($label1) = $tframe->Label(-text => "Optional Flags:  ")->pack (-side => 'left');
    my ($optflags) = $tframe->Entry(-textvariable => \$optflags)->pack (-fill => 'x');
    if ($showoutput == 1){
	my ($label) = $uframe->Label(-text => "Output Directory: ")->pack (-side => 'left');
	$dir_e = $uframe->Entry(-textvariable => \$tempoutputdir)->pack ( -fill => 'x');
    }
    my ($exit_b) = $lframe->Button(-text => "OK", -command => sub
				   { 
				       while ($j <= $k) {
					   if ($optindex[$j] == 1) {
					       $tempcmdlist = $optcmd[$j].$tempcmdlist;
					   }
					   $j = $j + 1;
				       }
				       $cmdlist = $optflags->get().$tempcmdlist;
				       if ($showoutput == 1){
					   $outputdir = $dir_e->get();
					   if ($outputdir eq ""){
					       $outputdir = "./";
					   }
				       } else {
					   $outputdir = "";
				       }
				       if ($debug == 1){
					   print "\$program = $program\n";
					   print "\$cmdlist = $cmdlist\n";
					   print "\$outputdir = $outputdir\n";
					   print "\$filename = $filename \n\n";
				       }
				       if ($btn == 3){
					   button3();
					   $optwin->destroy if Tk::Exists ($optwin);
					   $die
				       } else 
				       {
				       $pid = open3(*PRG_IN, *PRG_OUT, *PRG_ERR, "$program $opt1leader"."$cmdlist $outputdir $filename");
				       close (PRG_IN);
				       @outlist = <PRG_OUT>;
				       @errlist = <PRG_ERR>;

				       if ($errlist[0] eq ""){
					   foreach(@outlist){
					       $text->insert ('end', $_);
					   }
				       } else {
					   if ($debug == 1) {
					       foreach (@errlist){
						   $text->insert ('end', $_);
					       }
					   }
					   $text->insert ('end', "Operation Failed");
				       }
				       $optwin->destroy if Tk::Exists ($optwin)
				       }
				    })->pack(-side, 'left',-anchor => 's');

    my ($cancel_b) = $lframe->Button(-text => "Cancel", -command => sub
				     {
					 $optwin->destroy if Tk::Exists ($optwin);
				     })->pack (-side => 'right');
    foreach (@optbtn){
	if ($_ == $typebox){
	    $optwin->Checkbutton(-text => $optname[$i], -variable => \$optindex[$k])->pack (-side => 'top');
	    $k = $k + 1;
	}
	$i = $i + 1;
    }
}
