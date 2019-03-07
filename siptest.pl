#!/usr/bin/perl
# -=-=-=-=-=-=
# SipTest v1.0
# -=-=-=-=-=-=
#
# Pepelux <pepeluxx@gmail.com>
 
use warnings;
use strict;
use IO::Socket;
use NetAddr::IP;
use Getopt::Long;

my $useragent = 'siptest';
 
my $host = '';		# host
my $lport = '';	# local port
my $dport = '';	# destination port
my $from = '';		# source number
my $to = '';		# destination number
my $fromname = ''; # from name
my $method = '';	# method to use (INVITE, REGISTER, OPTIONS)
my $v = 0;		# verbose mode
my $user = '';		# auth user
my $proto = '';	# protocol (UDP, TCP)

my $to_ip = '';
my $from_ip = '';

sub init() {
    # check params
    my $result = GetOptions ("h=s" => \$host,
				"m=s" => \$method,
				"d=s" => \$to,
				"s=s" => \$from,
				"fn=s" => \$fromname,
				"ip=s" => \$from_ip,
				"u=s" => \$user,
				"l=s" => \$lport,
				"r=s" => \$dport,
				"proto=s" => \$proto,
				"ua=s" => \$useragent,
				"v+" => \$v);
 
	help() if ($host eq "");
 
	$lport = "5070" if ($lport eq "");
	$dport = "5060" if ($dport eq "");
	$user = "100" if ($user eq "");
	$from = $user if ($from eq "");
	$to = $user if ($to eq "");
	$proto = lc($proto);
	$proto = "udp" if ($proto ne "tcp" && $proto ne "udp");

	$method = uc($method);
	$method = "OPTIONS" if ($method eq "");
 
 	my $ip = inet_ntoa(inet_aton($host));
	$from_ip = $ip if ($from_ip eq "");

	send_message($ip, $from_ip, $lport, $dport, $from, $fromname, $to, $user, $proto);

	exit;
}

sub send_message {
	my $to_ip = shift;
	my $from_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $fromname = shift;
	my $to = shift;
	my $user = shift;
	my $proto = shift;

	send_register($from_ip, $to_ip, $lport, $dport, $from, $fromname, $to, $user, $proto) if ($method eq "REGISTER");
	send_invite($from_ip, $to_ip, $lport, $dport, $from, $fromname, $to, $user, $proto) if ($method eq "INVITE");
	send_options($from_ip, $to_ip, $lport, $dport, $from, $fromname, $to, $user, $proto) if ($method eq "OPTIONS");	
}
 
# Send REGISTER message
sub send_register {
	my $from_ip = shift;
	my $to_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $fromname = shift;
	my $to = shift;
	my $user = shift;
	my $proto = shift;
	my $response = "";
	my $cseq = 1;

	my $sc = new IO::Socket::INET->new(PeerPort=>$dport, LocalPort=>$lport, Proto=>$proto, PeerAddr=>$to_ip, Timeout => 5);

	if ($sc) {
		my $branch = &generate_random_string(71, 0);
		my $callid = &generate_random_string(32, 1);
	
		my $msg = "REGISTER sip:".$to_ip." SIP/2.0\r\n";
		$msg .= "Via: SIP/2.0/".uc($proto)." $from_ip:$lport;branch=$branch\r\n";
		$msg .= "From: $fromname <sip:".$user."@".$to_ip.">;tag=0c26cd11\r\n";
		$msg .= "To: <sip:".$user."@".$to_ip.">\r\n";
		$msg .= "Contact: <sip:".$user."@".$from_ip.":$lport;transport=$proto>\r\n";
		$msg .= "Call-ID: ".$callid."\r\n";
		$msg .= "CSeq: $cseq REGISTER\r\n";
		$msg .= "User-Agent: $useragent\r\n";
		$msg .= "Max-Forwards: 70\r\n";
		$msg .= "Allow: INVITE,ACK,CANCEL,BYE,NOTIFY,REFER,OPTIONS,INFO,SUBSCRIBE,UPDATE,PRACK,MESSAGE\r\n";
		$msg .= "Expires: 10\r\n";
		$msg .= "Content-Length: 0\r\n\r\n";

		my $data = "";
		my $line = "";
		my $cid = "";

		print $sc $msg;

		print "[+] $to_ip:$dport/$proto - Sending REGISTER $from => $to\n" if ($v ne 1);
		print "[+] $to_ip:$dport/$proto - Sending:\n=======\n$msg" if ($v eq 1);

		use Errno qw(ETIMEDOUT EWOULDBLOCK);
		
		LOOP: {
			while (<$sc>) {
				$line = $_;
			
				if ($line =~ /^SIP\/2.0/ && ($response eq "" || $response =~ /^1/)) {
					$line =~ /^SIP\/2.0\s(.+)\r\n/;
				
					if ($1) { $response = $1; }
				}

				if ($line =~ /Call-ID/i) {
					$line =~ /Call-ID\:\s(.+)\r\n/i;
 
					$cid = $1 if ($1);
				}

				if ($cid eq $callid || $cid eq "") {
					$data .= $line;
 
					if ($line =~ /^\r\n/) {
						print "[-] $response\n" if ($v ne 1);
						print "Receiving:\n=========\n$data" if ($v eq 1);

						last LOOP if ($response !~ /^1/);
					}
				}
			}
		}
	}
	
	return;
}

# Send INVITE message
sub send_invite {
	my $from_ip = shift;
	my $to_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $fromname = shift;
	my $to = shift;
	my $user = shift;
	my $proto = shift;
	my $response = "";
	my $cseq = 1;

	my $sc = new IO::Socket::INET->new(PeerPort=>$dport, LocalPort=>$lport, Proto=>$proto, PeerAddr=>$to_ip, Timeout => 5);

	if ($sc) {
		my $branch = &generate_random_string(71, 0);
		my $callid = &generate_random_string(32, 1);
	
		my $msg = "INVITE sip:".$to."@".$to_ip." SIP/2.0\r\n";
		$msg .= "Via: SIP/2.0/".uc($proto)." $from_ip:$lport;branch=$branch\r\n";
		$msg .= "From: \"$from\" <sip:".$user."@".$to_ip.">;tag=0c26cd11\r\n";
		$msg .= "To: <sip:".$to."@".$to_ip.">\r\n";
		$msg .= "Contact: <sip:".$from."@".$from_ip.":$lport;transport=$proto>\r\n";
		$msg .= "Supported: replaces, timer, path\r\n";
		$msg .= "P-Early-Media: Supported\r\n";
		$msg .= "Call-ID: $callid\r\n";
		$msg .= "CSeq: $cseq INVITE\r\n";
		$msg .= "User-Agent: $useragent\r\n";
		$msg .= "Max-Forwards: 70\r\n";
		$msg .= "Allow: INVITE,ACK,CANCEL,BYE,NOTIFY,REFER,OPTIONS,INFO,SUBSCRIBE,UPDATE,PRACK,MESSAGE\r\n";
		$msg .= "Content-Type: application/sdp\r\n";

		my $sdp .= "v=0\r\n";
		$sdp .= "o=anonymous 1312841870 1312841870 IN IP4 $from_ip\r\n";
		$sdp .= "s=session\r\n";
		$sdp .= "c=IN IP4 $from_ip\r\n";
		$sdp .= "t=0 0\r\n";
		$sdp .= "m=audio 2362 RTP/AVP 0\r\n";
		$sdp .= "a=rtpmap:18 G729/8000\r\n";
		$sdp .= "a=rtpmap:0 PCMU/8000\r\n";
		$sdp .= "a=rtpmap:8 PCMA/8000\r\n\r\n";

		$msg .= "Content-Length: ".length($sdp)."\r\n\r\n";
		$msg .= $sdp;

		my $data = "";
		my $line = "";
		my $cid = "";

		print $sc $msg;

		print "[+] $to_ip:$dport/$proto - Sending INVITE $from => $to\n" if ($v ne 1);
		print "[+] $to_ip:$dport/$proto - Sending:\n=======\n$msg" if ($v eq 1);

		LOOP: {
			while (<$sc>) {
				$line = $_;
				if ($line =~ /^SIP\/2.0/ && ($response eq "" || $response =~ /^1/)) {
					$line =~ /^SIP\/2.0\s(.+)\r\n/;
				
					if ($1) { $response = $1; }
				}

				if ($line =~ /Call-ID/i) {
					$line =~ /Call-ID\:\s(.+)\r\n/i;
 
					$cid = $1 if ($1);
				}

				if ($cid eq $callid || $cid eq "") {
					$data .= $line;
 
					if ($line =~ /^\r\n/) {
						print "[-] $response\n" if ($v ne 1);
						print "Receiving:\n=========\n$data" if ($v eq 1);

						last LOOP if ($response !~ /^1/);
					}
				}
			}
		}
	}
	
	return;
}

# Send OPTIONS message
sub send_options {
	my $from_ip = shift;
	my $to_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $fromname = shift;
	my $to = shift;
	my $user = shift;
	my $proto = shift;
	my $response = "";
	my $cseq = 1;

	my $sc = new IO::Socket::INET->new(PeerPort=>$dport, LocalPort=>$lport, Proto=>$proto, PeerAddr=>$to_ip, Timeout => 5);

	if ($sc) {
		my $branch = &generate_random_string(71, 0);
		my $callid = &generate_random_string(32, 1);
	
		my $msg = "OPTIONS sip:".$to."@".$to_ip." SIP/2.0\r\n";
		$msg .= "Via: SIP/2.0/".uc($proto)." $from_ip:$lport;branch=$branch\r\n";
		$msg .= "From: <sip:".$user."@".$to_ip.">;tag=0c26cd11\r\n";
		$msg .= "To: <sip:".$user."@".$to_ip.">\r\n";
		$msg .= "Contact: <sip:".$user."@".$from_ip.":$lport;transport=$proto>\r\n";
		$msg .= "Call-ID: $callid\r\n";
		$msg .= "CSeq: $cseq OPTIONS\r\n";
		$msg .= "User-Agent: $useragent\r\n";
		$msg .= "Max-Forwards: 70\r\n";
		$msg .= "Allow: INVITE,ACK,CANCEL,BYE,NOTIFY,REFER,OPTIONS,INFO,SUBSCRIBE,UPDATE,PRACK,MESSAGE\r\n";
		$msg .= "Content-Length: 0\r\n\r\n";

		my $data = "";
		my $line = "";
		my $cid = "";

		print $sc $msg;

		print "[+] $to_ip:$dport/$proto - Sending OPTIONS $from => $to\n" if ($v ne 1);
		print "[+] $to_ip:$dport/$proto - Sending:\n=======\n$msg" if ($v eq 1);

		LOOP: {
			while (<$sc>) {
				$line = $_;
			
				if ($line =~ /^SIP\/2.0/ && ($response eq "" || $response =~ /^1/)) {
					$line =~ /^SIP\/2.0\s(.+)\r\n/;
				
					if ($1) { $response = $1; }
				}

				if ($line =~ /Call-ID/i) {
					$line =~ /Call-ID\:\s(.+)\r\n/i;
 
					$cid = $1 if ($1);
				}

				if ($cid eq $callid || $cid eq "") {
					$data .= $line;
 
					if ($line =~ /^\r\n/) {
						print "[-] $response\n" if ($v ne 1);
						print "Receiving:\n=========\n$data" if ($v eq 1);

						last LOOP if ($response !~ /^1/);
					}
				}
			}

			last LOOP;
		}
	}
	
	return $response;
}

 
sub generate_random_string {
    my $length_of_randomstring = shift;
    my $only_hex = shift;
    my @chars;
 
    if ($only_hex == 0) {
        @chars = ('a'..'z','0'..'9');
    }
    else {
        @chars = ('a'..'f','0'..'9');
    }
    my $random_string;
    foreach (1..$length_of_randomstring) {
        $random_string.=$chars[rand @chars];
    }
    return $random_string;
}
 
sub help {
    print qq{
SipTest - by Pepelux <pepeluxx\@gmail.com>
-------

Usage: perl $0 -h <host> [options]
 
== Options ==
-m  <string>     = Method: REGISTER/INVITE/OPTIONS (default: OPTIONS)
-u  <string>     = Username
-s  <integer>    = Source number (CallerID) (default: 100)
-d  <integer>    = Destination number (default: 100)
-r  <integer>    = Remote port (default: 5060)
-proto <string>  = Protocol (udp, tcp) - By default: UDP)
-ip <string>     = Source IP (by default it is the same as host)
-ua <string>     = Customize the UserAgent
-v               = Verbose (trace information)
 
== Examples ==
\$perl $0 -h 192.168.0.1
\tTo search SIP services on 192.168.0.1 port 5060 (using OPTIONS method)
\$perl $0 -h 192.168.0.1 -m INVITE
\tTo search SIP services on 192.168.0.1 port 5060 (using INVITE method)

};
 
    exit 1;
}
 
init();
