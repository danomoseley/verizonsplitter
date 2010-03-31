#!/usr/bin/perl

use strict;
use warnings;
 use Locale::Currency::Format;

use CAM::PDF;
use CAM::PDF::PageText;

my $filename = shift || die "Supply pdf on command line\n";

my $pdf = CAM::PDF->new($filename);
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
				#print $2;
				$discounted_plan = $2;
				$family_plan_cost = $2;
			}
			if($page_content =~ /Monthly Access Charges(.+?)(\d+\.\d+)(.+?)(\d+\.\d+)/s){
				#print $4;
				$discounted_plan -= $4;
				$discount = $4/$family_plan_cost;
				#print $discount*100;
				#print "% discount\n\r";
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
	print "\$".$charges[$count]."\n\r";
}
print "Total : \$".$total."\n\r";

__END__
