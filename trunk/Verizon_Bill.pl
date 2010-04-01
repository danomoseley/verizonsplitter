#!/usr/bin/perl

use CGI;
use strict;
use warnings;
use CAM::PDF;
use CAM::PDF::PageText;
use Locale::Currency::Format;

my $pdf;
my $COMMAND_LINE=0;

my $PROGNAME = "Verizon_Bill.pl";

my $filename;
if($filename = shift){
	$pdf = CAM::PDF->new($filename);
	$COMMAND_LINE=1;
}else{
	my $cgi = new CGI();
	print "Content-type: text/html\n\n";
	
	if (! $cgi->param("button") ) {
		DisplayForm();
		exit;
	}

	my $upfile = $cgi->param('upfile');

	my $basename = GetBasename($upfile);

	no strict 'refs';

	if (! open(OUTFILE, "> /tmp/".$basename) ) {
		print "Can't open /tmp/".$basename." for writing - $!";
		exit(-1);
	}

	my $nBytes = 0;
	my $totBytes = 0;
	my $buffer = "";
	binmode($upfile);
	while ( $nBytes = read($upfile, $buffer, 1024) ) {
		print OUTFILE $buffer;
		$totBytes += $nBytes;
	}

	close(OUTFILE);

	use strict 'refs';

	$pdf = CAM::PDF->new("/tmp/".$basename);
}
print "<head><link href=../css/style.css rel=stylesheet media=screen><script src=../js/jquery-1.4.2.min.js type=text/javascript></script><script src=../js/control.js type=text/javascript></script></head>";
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
my @access;
my @overage;
my @surcharges;
my @taxes;
my $total = 0;

my $count;
for($count = 1;$count<12;$count++){
	my $content_tree = $pdf->getPageContentTree($count);
	my $page_content = CAM::PDF::PageText->render($content_tree);
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
				$discounted_plan = $2;
				$family_plan_cost = $2;
			}
			if($page_content =~ /Monthly Access Charges(.+?)(\d+\.\d+)(.+?)(\d+\.\d+)/s){
				$discounted_plan -= $4;
				$discount = $4/$family_plan_cost*100;
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
			push(@access,$person_access_charges);
			
		}
		if($page_content =~ /Usage Charges(.+?)\$([\d\.]+)/s){
			$person_usage_charges = $2;
			push(@overage,$person_usage_charges);
		}
		if($page_content =~ /Verizon Wireless' Surcharges(.+?)\$([\d\.]+)/s){
			$surcharge_percentage = $2/$total_access_charges;
			$person_surcharges = $person_access_charges*$surcharge_percentage;
			$discounted_plan += $2-$person_surcharges;
			push(@surcharges,$person_surcharges);
		}
		if($page_content =~ /Taxes, Governmental Surcharges and Fees(.+?)\$([\d\.]+)/s){
			$tax_percentage = $2/$total_access_charges;
			$person_taxes = $person_access_charges*$tax_percentage;
			$discounted_plan += $2-$person_taxes;
			push(@taxes,$person_taxes);
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

if(!$COMMAND_LINE){
	print "<table>";
	print "<tr><td><b>Plan Cost</b></td><td>\$".$family_plan_cost."</td></tr>";
	print "<tr><td><b>Discount</b></td><td>".$discount."%</td></tr>";
	print "<tr><td><b>Additional Lines</b></td><td>".$additional_lines." at \$9.99</td></tr>";
	print "<tr><td><b>Total Shared Cost</b></td><td>\$".sprintf("%.2f",$discounted_plan)."</td></tr>";
	print "</table><br/><br/>";
	
	for($count=0;$count<scalar(@charges);$count++){
		print "<div class=person>";
		print $names[$count]." : ";
		print "\$".$charges[$count];
		print "<div class=details>";
		print "Access Charges : ".currency_format('USD', $access[$count], FMT_SYMBOL)."<br/>";
		print "Overage Charges : ".currency_format('USD', $overage[$count], FMT_SYMBOL)."<br/>";
		print "Surcharges : ".currency_format('USD', $surcharges[$count], FMT_SYMBOL)."<br/>";
		print "Taxes : ".currency_format('USD', $taxes[$count], FMT_SYMBOL)."<br/>";		
		print "</div>";
		print "</div>";
	}
	print "Total : \$".$total;
}else{
	print "Plan Cost : \$".$family_plan_cost."\n\r";
	print "Discount : ".$discount."%\n\r";
	print "Additional Lines : ".$additional_lines." at \$9.99\n\r";
	print "Total Shared Cost : \$".sprintf("%.2f",$discounted_plan)."\n\r\n\r";
	for($count=0;$count<scalar(@charges);$count++){
		print "".$names[$count]." : ";
		print "\$".$charges[$count]."\n\r";
	}
	print "Total : \$".$total."\n\r";
}



sub GetBasename {
	my $fullname = shift;

	my(@parts);
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
