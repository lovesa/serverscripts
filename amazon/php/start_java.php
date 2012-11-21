#!/usr/bin/php

<?php
// include the config file containing your AWS Access Key and Secret
include_once ('config.inc.php');
require_once 'AWSSDKforPHP/sdk.class.php';

try {
	$ec2 = new AmazonEC2(
		array(
			
			"certificate_authority" => AWS_AUTHORITY,
			"key"			=> AWS_ACCESS_KEY_ID,
			"secret"		=> AWS_SECRET_ACCESS_KEY,
		)
	);
	$ec2->set_region(AmazonEC2::REGION_EU_W1);

	$response = $ec2->describe_instances();
	var_dump($response);
/* 
	if($response->isOK()) {
		$describeInstancesResult = $response->getDescribeInstancesResult();
		$reservationList = $describeInstancesResult->getReservation();

		// loop the list of running instances and match those that have an AMI of the application image
		$hosts = array();
		
		foreach ($reservationList as $reservation) {
        		$runningInstanceList = $reservation->getRunningInstance();
        		foreach ($runningInstanceList as $runningInstance) {
                		$ami = $runningInstance->getImageId();

                		$state = $runningInstance->getInstanceState();

                        	$dns_name = $runningInstance->getPublicDnsName();

                        	$app_ip = gethostbyname($dns_name);

                        	$hosts[] = array(
						"host"  => $dns_name,
						"ip"	=> $app_ip,
						"ami"   => $ami,
						"state" => $state,
				);
        		}		
 		}	
	}else{
		Throw Exception("Instance description response error");
	}
*/
} catch (Exception $e) {
	echo $e->getMessage();
}

?>

