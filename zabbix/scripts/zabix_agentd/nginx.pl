#!/usr/bin/perl 
my $host = 'localhost';
my $cmd = 'curl -A "mozilla/4.0 (compatible; cURL 7.10.5-pre2; Linux 2.4.20)" -m 12 -s -L -k -b /tmp/bbapache_cookiejar.curl -c /tmp/bbapache_cookiejar.curl -H "Pragma: no-cache" -H "Cache-control: no-cache" -H "Connection: close" "'.$host.'/server_status"';
my $server_status = qx($cmd);
#print $server_status;

my @apache_checks;

$apache_checks[0] = $1 if ($server_status =~ /Active\ connections:\ ([\d|\.]+)/ig)||0;
$apache_checks[1] = $1 if ($server_status =~ /Reading:\ ([\d|\.]+)/gi);
$apache_checks[2] = $1 if ($server_status =~ /Writing:\ ([\d|\.]+)/gi);
$apache_checks[3] = $1 if ($server_status =~ /Waiting:\ ([\d|\.]+)/gi);
$apache_checks[5] = $1 if ($server_status =~ /([\d|\.]+)\ /gi);
print "$apache_checks[$ARGV[0]]";                                                                                                                                                             
exit(0);
