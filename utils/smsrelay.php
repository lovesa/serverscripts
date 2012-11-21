#!/usr/bin/php -q
<?php
$smsserver = "http://smsrelay";

$response = httppost($smsserver,
		http_build_query(
			array(
				"phone" => $argv[1],
				"text"  => $argv[2],
			)
		));


       echo file_get_contents("php://input")."\n".$response."\n\n";


function httppost($url, $data, $timeout = 5) {
  $remote = parse_url($url);

  $request =
		"POST $remote[path] HTTP/1.0\r\n" .
		"Host: $remote[host]\r\n" .
		"Content-type: application/x-www-form-urlencoded\r\n" .
		"Content-length: " . strlen($data) . "\r\n" .
		"Accept: */*\r\n" .
		"\r\n" .
		"$data\r\n" .
		"\r\n";

  $sock = @fsockopen($remote['host'],
		isset($remote['port']) ? $remote['port'] : 80,
		$errno, $errstr, $timeout);
  if (!$sock)
  {
    //echo "$errstr ($errno)";
    return $errno;
  }
	stream_set_blocking($sock, 0);

	// write data
  fwrite($sock, $request);

	// read data
	$stop = time() + $timeout;
	$reply = '';
	while (!feof($sock) && time() <= $stop ) {
		sleep(1);
		$reply .= fread($sock, 4096);
	}
  fclose($sock);

	preg_match('/(.*\r\n)\r\n(.*)/s', $reply, $matches);
	if (count($matches) == 3)
		return $matches[2];
	else
		return null;
}
?>
