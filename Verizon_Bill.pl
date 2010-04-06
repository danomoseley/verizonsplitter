#!/usr/bin/perl

use CGI;
use strict;
use warnings;
use CAM::PDF;
use CAM::PDF::PageText;
use Locale::Currency::Format;
use Data::Dumper;
use HTML::Template;

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

	$pdf = CAM::PDF->new("/tmp/".$basename);
}

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
my $total_taxes;
my $total = 0;
my @data = ();
my $person_count = 0;


my $count;
for($count = 1;$count<$pdf->numPages();$count++){
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
			$total_taxes = $1;
		}
	}

	if($page_content =~ /Summary for ([\w\s]+): ([\d\-]+)/){
		my %person_data;
		$person_data{name} = $1;
		$person_data{number} = $2;
		
		if($person_count==0){
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
			$person_data{total_access_charges} = $2;
			if($2>$discounted_plan){
				$person_data{access_charges} = $2-$discounted_plan;
			}else{
				$person_data{access_charges} = $2-9.99;
				$discounted_plan += 9.99;
				$additional_lines++;
			}
			
		}
		if($page_content =~ /Usage Charges(.+?)\$([\d\.]+)/s){
			$person_data{usage_charges} = $2;
		}
		if($page_content =~ /Verizon Wireless' Surcharges(.+?)\$([\d\.]+)/s){
			$person_data{surcharge_percentage} = $2/$person_data{total_access_charges};
			$person_data{surcharges} = $person_data{access_charges}*$person_data{surcharge_percentage};
			$discounted_plan += $2-$person_data{surcharges};
		}
		if($page_content =~ /Taxes, Governmental Surcharges and Fees(.+?)\$([\d\.]+)/s){
			$person_data{tax_percentage} = $2/$person_data{total_access_charges};
			$person_data{taxes} = $person_data{access_charges}*$person_data{tax_percentage};
			$discounted_plan += $2-$person_data{taxes};
		}
		$person_data{total} = $person_data{access_charges}+$person_data{usage_charges}+$person_data{surcharges}+$person_data{taxes};	
		push(@data,\%person_data);
		$person_count++;
	}

}

for($count=0;$count<$person_count;$count++){
	$data[$count]{total} = $data[$count]{total}+$discounted_plan/3;
	$total += $data[$count]{total};
}

while($total<$total_amount-0.01){
	$data[int(rand(3))]{total}+=0.01;
	$total+=0.01;
}
while($total>$total_amount+0.01){
	$data[int(rand(3))]{total}-=0.01;
	$total-=0.01;
}

for($count=0;$count<$person_count;$count++){
	$data[$count]{total} = currency_format('USD', $data[$count]{total}, FMT_SYMBOL);
	$data[$count]{access_charges} = currency_format('USD', $data[$count]{access_charges}, FMT_SYMBOL);
	$data[$count]{surcharges} = currency_format('USD', $data[$count]{surcharges}, FMT_SYMBOL);
	$data[$count]{taxes} = currency_format('USD', $data[$count]{taxes}, FMT_SYMBOL);
	$data[$count]{usage_charges} = currency_format('USD', $data[$count]{usage_charges}, FMT_SYMBOL);
	$data[$count]{total_access_charges} = currency_format('USD', $data[$count]{total_access_charges}, FMT_SYMBOL);
	$data[$count]{tax_percentage} = sprintf("%.1f",$data[$count]{tax_percentage}*100)."%";
	$data[$count]{surcharge_percentage} = sprintf("%.1f",$data[$count]{surcharge_percentage}*100)."%";
}

if(!$COMMAND_LINE){	
	my $template = HTML::Template->new(filename => 'verizon.tmpl');
	$template->param(family_info => \@data);
	$template->param(plan_cost => currency_format('USD', $family_plan_cost, FMT_SYMBOL));
	$template->param(discount => $discount."%");
	$template->param(additional_lines => $additional_lines);
	$template->param(total_shared_cost => currency_format('USD', $discounted_plan, FMT_SYMBOL));
	$template->param(total => currency_format('USD', $total, FMT_SYMBOL));
	print $template->output;
}else{
	print "Plan Cost : \$".$family_plan_cost."\n\r";
	print "Discount : ".$discount."%\n\r";
	print "Additional Lines : ".$additional_lines." at \$9.99\n\r";
	print "Total Shared Cost : \$".sprintf("%.2f",$discounted_plan)."\n\r\n\r";
	for($count=0;$count<$person_count;$count++){
		print "".$data[$count]{name}." : ";
		print currency_format('USD', $data[$count]{total}, FMT_SYMBOL)."\n\r";
	}
	print "Total : \$".$total."\n\r";
	print $person_count;
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
