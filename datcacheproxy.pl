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


print "\n   datcacheproxy - simple, but effective HTTP caching proxy\n   Written by Alexander Kluth <contact\@alexanderkluth.com>\n\n";

#------------------------
#
my $port = '0';
my $memcached_server = '127.0.0.1';
my $memcached_port = '11211';
my $cache_dir = '/tmp/datcacheproxy/cache';

GetOptions(
    'port=s', \$port,
    'memcached-server=s', \$memcached_server,
    'memcached-port=s', \$memcached_port,
    'cache-dir=s', \$cache_dir
);
#
#-----------------------

my $cache;

if (`ps -C memcached -o pid=`) {
    print " ! Found memcached, using it as cache\n";

    $cache = CHI->new(
        driver => 'Memcached::libmemcached',
        servers => '127.0.0.1:11211',
        l1_cache => { driver => 'FastMmap', root_dir => './cache' }
    );
} else {
    print " ! Found no memcached running, using filesystem as cache\n";

    $cache = CHI->new(
        driver => 'File',
        root_dir => './cache'
    );
}

# Initialize the Meachnize::Cached module as well as the HTTP daemon
my $mech = WWW::Mechanize::Cached->new( cache => $cache );
my $daemon = HTTP::Daemon->new( LocalPort => 80000) || die;

print " * datproxy started, accessible via ", $daemon->url, "\n";
print " * Using " . $cache_dir . " as cache dir\n\n";


while (my $connection = $daemon->accept) {
    while (my $request = $connection->get_request) {
        print "   -> Accessing " . $request->uri->as_string . " from host " . $connection->sockhost . "\n";

        $request->push_header(Via => '1.1 ' . $connection->sockhost);

        my $response = $mech->get($request->uri->as_string);
        $connection->send_response($response);
    }

    $connection->close;
    undef($connection);
}
