#!/usr/bin/perl
#
# A simple and lightweight caching proxy, mainly for my
# own purpose.
#
# It caches all data in a memcache server or on the
# filesystem via CHI.
#
# Licensed under the terms of the MIT license.
# See LICENSE for more details.
#
use strict;
use warnings;
use CHI;
use Getopt::Long;
use HTTP::Daemon;
use HTTP::Status;
use WWW::Mechanize::Cached;

$| = 1;
my $nofork = $^O =~ /Win32/i;

print "\n   datcacheproxy - simple, but effective HTTP caching proxy\n   Written by Alexander Kluth <contact\@alexanderkluth.com>\n\n";

#------------------------
#
my $port = 31337;
my $memcached;
my $memcached_server = '127.0.0.1';
my $memcached_port = '11211';
my $cache_dir = '/tmp/datcacheproxy/cache';
my $verbose;
my $ultra_verbose;

GetOptions(
    'port=i', \$port,
    'memcached', \$memcached,
    'memcached-server=s', \$memcached_server,
    'memcached-port=s', \$memcached_port,
    'cache-dir=s', \$cache_dir,
    'verbose', \$verbose,
    'ultra-verbose', \$ultra_verbose
);
#
#-----------------------

my $cache;

if ($memcached) {
    print ' ! Trying to connect to memached server at ' . $memcached_server . ':' . $memcached_port .'...\n';

    $cache = CHI->new(
        driver => 'Memcached::libmemcached',
        servers => $memcached_server . ':' . $memcached_port,
        l1_cache => { driver => 'FastMmap', root_dir => $cache_dir }
    );
} else {
    print " ! Using filesystem as cache\n";

    $cache = CHI->new(
        driver => 'File',
        root_dir => './cache'
    );
}

# Initialize the Meachnize::Cached module as well as the HTTP daemon
my $mech = WWW::Mechanize::Cached->new( cache => $cache );
my $daemon = HTTP::Daemon->new( LocalPort => $port) || die;

print " * datproxy started, accessible via ", $daemon->url, "\n";
print " * Using " . $cache_dir . " as cache dir\n\n";


while (my $connection = $daemon->accept) {
    next unless $nofork || ! fork();
    &ultra_verbose_log("  ! -> Forked child\n") unless $nofork;
    handle_connection($connection);
    kill_child("       ! -> Child quit\n") unless $nofork;
}


sub handle_connection
{
    local $SIG{PIPE} = 'IGNORE';
    my ($connection) = @_;

    while (my $request = $connection->get_request) {
        &log("       -> Accessing " . $request->uri->as_string . " from host " . $connection->sockhost . "\n");

        $request->push_header(Via => '1.1 ' . $connection->sockhost);

        my $response = $mech->get($request->uri->as_string);
        $connection->send_response($response);
    }

    $connection->close;
}


sub kill_child
{
    my $msg = shift;

    &ultra_verbose_log($msg);
    exit(1);
}


sub log
{
    my $str = shift;

    print $str if $verbose;
}


sub ultra_verbose_log
{
    &log(shift) if $ultra_verbose;
}

