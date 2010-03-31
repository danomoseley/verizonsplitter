#!/usr/bin/perl
#
# file_upload.pl - Demonstration script for file uploads
# over HTML form.
#
# This script should function as is.  Copy the file into
# a CGI directory, set the execute permissions, and point
# your browser to it. Then modify if to do something
# useful.
#
# Author: Kyle Dent
# Date: 3/15/01
#

use CGI;
use strict;
use CAM::PDF;
use CAM::PDF::PageText;

my $PROGNAME = "file_upload.pl";

my $cgi = new CGI();
print "Content-type: text/html\n\n";

#
# If we're invoked directly, display the form and get out.
#
if (! $cgi->param("button") ) {
	DisplayForm();
	exit;
}

#
# We're invoked from the form. Get the filename/handle.
#
my $upfile = $cgi->param('upfile');

#
# Get the basename in case we want to use it.
#
my $basename = GetBasename($upfile);

#
# At this point, do whatever we want with the file.
#
# We are going to use the scalar $upfile as a filehandle,
# but perl will complain so we turn off ref checking.
# The newer CGI::upload() function obviates the need for
# this. In new versions do $fh = $cgi->upload('upfile'); 
# to get a legitimate, clean filehandle.
#
no strict 'refs';
#my $fh = $cgi->upload('upfile'); 
#if (! $fh ) {
#	print "Can't get file handle to uploaded file.";
#	exit(-1);
#}

#######################################################
# Choose one of the techniques below to read the file.
# What you do with the contents is, of course, applica-
# tion specific. In these examples, we just write it to
# a temporary file. 
#
# With text files coming from a Windows client, probably
# you will want to strip out the extra linefeeds.
########################################################

#
# Get a handle to some file to store the contents
#
if (! open(OUTFILE, ">/tmp/".$basename) ) {
	print "Can't open /tmp/".$basename." for writing - $!";
	exit(-1);
}

# give some feedback to browser
#print "Saving the file to /tmp<br>\n";

#
# 1. If we know it's a text file, strip carriage returns
#    and write it out.
#
#while (<$upfile>) {
# or 
#while (<$fh>) {
#	s/\r//;
#	print OUTFILE "$_";
#}

#
# 2. If it's binary or we're not sure...
#
my $nBytes = 0;
my $totBytes = 0;
my $buffer = "";
# If you're on Windows, you'll need this. Otherwise, it
# has no effect.
binmode($upfile);
#binmode($fh);
while ( $nBytes = read($upfile, $buffer, 1024) ) {
#while ( $nBytes = read($fh, $buffer, 1024) ) {
	print OUTFILE $buffer;
	$totBytes += $nBytes;
}

close(TMP);

#
# Turn ref checking back on.
#
use strict 'refs';

# more lame feedback
my $pdf = CAM::PDF->new("/tmp/outfile");

my $discount;
my $family_plan_cost;
my $discounted_plan;
my $additional_lines = 0;

my $due_date;
my $total_amount;
my $access_charges;
my $voice_usage_charge;
my $data_usage_charge;
my $surcharge;
my $taxes;
my @charges;
my @names;
my $total = 0;

my $count;
for($count = 1;$count<12;$count++){
	my $page_content = CAM::PDF::PageText->render($pdf->getPageContentTree($count));
	if($page_content =~ /Quick Bill Summary/){
		if($page_content =~ /Total Charges Due by ([\w\s,]*) \$([\d\.]*)/){
			$due_date = $1;
			$total_amount = $2;
		}

		if($page_content =~ /Monthly Access Charges \$([\d\.]*)/){
			$access_charges = $1;
		}

		if($page_content =~ /Voice \$([\d\.]*)/){
			$voice_usage_charge = $1;
		}

		if($page_content =~ /Data \$([\d\.]*)/){
			$data_usage_charge = $1;
		}

		if($page_content =~ /Verizon Wireless'  Surcharges and Other Charges & Credits \$([\d\.]*)/){
			$surcharge = $1;
		}

		if($page_content =~ /Taxes, Governmental Surcharges & Fees \$([\d\.]*)/){
			$taxes = $1;
		}
	}

	if($page_content =~ /Summary for ([\w\s]+): ([\d\-]+)/){
		my $name = $1;
		my $number = $2;
		my $total_access_charges;
		my $person_access_charges;
		my $person_usage_charges;
		my $person_surcharges;
		my $person_taxes;
		my $surcharge_percentage;
		my $tax_percentage;

		if(scalar(@charges)==0){
			if($page_content =~ /Monthly Access Charges(.+?)(\d+\.\d+)/s){
				print $2;
				$discounted_plan = $2;
				$family_plan_cost = $2;
			}
			if($page_content =~ /Monthly Access Charges(.+?)(\d+\.\d+)(.+?)(\d+\.\d+)/s){
				$discounted_plan -= $3;
				$discount = $3/$family_plan_cost;
				print $discount;
			}
		}

		if($page_content =~ /Monthly Access Charges(.+?)\$([\d\.]+)/s){
			$total_access_charges = $2;
			if($2>$discounted_plan){
				$person_access_charges = $2-$discounted_plan;
			}else{
				$person_access_charges = $2-9.99;
				$discounted_plan += 9.99;
				$additional_lines++;
			}
		}
		if($page_content =~ /Usage Charges(.+?)\$([\d\.]+)/s){
			$person_usage_charges = $2;
		}
		if($page_content =~ /Verizon Wireless' Surcharges(.+?)\$([\d\.]+)/s){
			$surcharge_percentage = $2/$total_access_charges;
			$person_surcharges = $person_access_charges*$surcharge_percentage;
			$discounted_plan += $2-$person_surcharges;
		}
		if($page_content =~ /Taxes, Governmental Surcharges and Fees(.+?)\$([\d\.]+)/s){
			$tax_percentage = $2/$total_access_charges;
			$person_taxes = $person_access_charges*$tax_percentage;
			$discounted_plan += $2-$person_taxes;
		}
		push(@charges,$person_access_charges+$person_usage_charges+$person_surcharges+$person_taxes);
		push(@names,$name);
	}

}

for($count=0;$count<scalar(@charges);$count++){
	$charges[$count] = sprintf("%.2f", $charges[$count]+($discounted_plan/3));
	$total += $charges[$count];
}
while($total<$total_amount-0.01){
	$charges[int(rand(3))]+=0.01;
	$total+=0.01;
}
while($total>$total_amount+0.01){
	$charges[int(rand(3))]-=0.01;
	$total-=0.01;
}


for($count=0;$count<scalar(@charges);$count++){
	print $names[$count]." : ";
	print "\$".$charges[$count]."<br/>";
}
print "Total : \$".$total."\n\r";


##############################################
# Subroutines
##############################################

#
# GetBasename - delivers filename portion of a fullpath.
#
sub GetBasename {
	my $fullname = shift;

	my(@parts);
	# check which way our slashes go.
	if ( $fullname =~ /(\\)/ ) {
		@parts = split(/\\/, $fullname);
	} else {
		@parts = split(/\//, $fullname);
	}

	return(pop(@parts));
}

#
# DisplayForm - spits out HTML to display our upload form.
#
sub DisplayForm {
print <<"HTML";
<html>
<head>
<title>Upload Form</title>
<body>
<h1>Upload Form</h1>
<form method="post" action="$PROGNAME" enctype="multipart/form-data">
<center>
Enter a file to upload: <input type="file" name="upfile"><br>
<input type="submit" name="button" value="Upload File">
</center>
</form>

HTML
}
