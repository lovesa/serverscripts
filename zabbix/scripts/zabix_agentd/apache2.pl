#!/usr/bin/perl 
my $host = $ARGV[0];
my $cmd = 'curl -A "mozilla/4.0 (compatible; cURL 7.10.5-pre2; Linux 2.4.20)" -m 12 -s -L -k -b /tmp/bbapache_cookiejar.curl -c /tmp/bbapache_cookiejar.curl -H "Pragma: no-cache" -H "Cache-control: no-cache" -H "Connection: close" "'.$host.'/server-status?auto"';
my $server_status = qx($cmd);
#print $server_status;

my @apache_checks;

$apache_checks[0] = $1 if ($server_status =~ /Total\ Accesses:\ ([\d|\.]+)/ig)||0;
$apache_checks[1] = $1 if ($server_status =~ /Total\ kBytes:\ ([\d|\.]+)/gi);
$apache_checks[2] = $1 if ($server_status =~ /CPULoad:\ ([\d|\.]+)/gi);
$apache_checks[3] = $1 if ($server_status =~ /Uptime:\ ([\d|\.]+)/gi);
$apache_checks[4] = $1 if ($server_status =~ /ReqPerSec:\ ([\d|\.]+)/gi);
$apache_checks[5] = $1 if ($server_status =~ /BytesPerSec:\ ([\d|\.]+)/gi);
$apache_checks[6] = $1 if ($server_status =~ /BytesPerReq:\ ([\d|\.]+)/gi);
$apache_checks[7] = $1 if ($server_status =~ /BusyWorkers:\ ([\d|\.]+)/gi);
$apache_checks[8] = $1 if ($server_status =~ /IdleWorkers:\ ([\d|\.]+)/gi);
$apache_checks[9] = $1 if ($server_status =~ /Scoreboard:\ ([A-Z_]+)/gi);
print "$apache_checks[$ARGV[1]]";
exit(0);
