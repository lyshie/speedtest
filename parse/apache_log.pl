#!/usr/bin/perl -w
#
#    Copyright (C) 2011~2014 SHIE, Li-Yi (lyshie) <lyshie@mx.nthu.edu.tw>
#
#    https://github.com/lyshie
#	
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation,  either version 3 of the License,  or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful, 
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not,  see <http://www.gnu.org/licenses/>.
#
#===============================================================================
#
#         FILE:  apache_log.pl
#
#        USAGE:  cat <ARGV> | ./apache_log.pl < <ARGV>
#
#  DESCRIPTION:  Apache Access Log Parser
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Hsieh, Li-Yi (lyshie@mx.nthu.edu.tw)
#      COMPANY:  NTHU
#      VERSION:  1.0
#      CREATED:  2010/10/22 08:25:20
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use FindBin qw($Bin);

#use URI;
#use URI::Escape;
#use URI::Split qw(uri_split);
use Template;
use Template::Plugins;

#use Encode;
#use Encode::Guess qw(big5);
use Number::Format qw(:subs);
use HTTP::BrowserDetect;
use lib "$Bin";

# LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %T/%D %I/%O" combined
my $PAT_IPV4 = qr/\d+\.\d+\.\d+\.\d+/;
my $PAT_IPV6 = qr/[\d\:]+/;

my $PAT_SYSLOG      = qr/^.+?\[.+?\]/;
my $PAT_CLIENT      = qr/($PAT_IPV4|$PAT_IPV6)/;    # capture
my $PAT_RFC1413     = qr/(?:.+?)/;                  #
my $PAT_USERID      = qr/(?:.+?)/;                  #
my $PAT_DATETIME    = qr/\[(.+?)\]/;                # capture
my $PAT_REQUEST     = qr/"(.+?)"/;                  # capture
my $PAT_STATUS_CODE = qr/(\d+|\-)/;                 # capture
my $PAT_SIZE        = qr/(\d+|\-)/;                 # capture
my $PAT_REFERER     = qr/"(?:.+?)"/;                #
my $PAT_UA          = qr/"(.+?)"/;                  # capture
my $PAT_TIME        = qr/(\d+)\/(?:\d+)/;           # capture
my $PAT_IO          = qr/(\d+)\/(\d+)/;             # capture/capture

# lyshie_20101021: Perl 5.8 no named capture, it's bad to use numbering!!
my $PAT_ACCESS_LOG = qr/
                        $PAT_CLIENT      \s+    # 1
                        $PAT_RFC1413     \s+    #
                        $PAT_USERID      \s+    #
                        $PAT_DATETIME    \s+    # 2
                        $PAT_REQUEST     \s+    # 3
                        $PAT_STATUS_CODE \s+    # 4
                        $PAT_SIZE        \s+    # 5
                        (?:$PAT_REFERER)*  (?:\s+)* #
                        (?:$PAT_UA)*       (?:\s+)* # 6 (optional)
                        (?:$PAT_TIME)*     (?:\s+)* # 7 (optional)
                        (?:$PAT_IO)*            # 8,9 (optional)
                        /xms;

sub main {
    my @rows = ();

    my $total   = 0;
    my $match   = 0;
    my $unmatch = 0;
    while (<ARGV>) {
        $total++;
        print STDERR "Processing $total lines...\n"
          if ( $total % 10000 == 0 );

        if ( $_ =~ m/$PAT_ACCESS_LOG/ ) {
            $match++;

            my $client   = defined($1) ? $1 : '';
            my $datetime = defined($2) ? $2 : '';
            my $uri      = defined($3) ? $3 : '';
            my $code     = defined($4) ? $4 : '';
            my $size     = defined($5) ? $5 : 0;
            my $ua       = defined($6) ? $6 : '';
            my $time     = defined($7) ? $7 : 0;
            my $in_size  = defined($8) ? $8 : 0;
            my $out_size = defined($9) ? $9 : 0;

            next unless ($size);
            next unless ($time);
            next unless ($out_size);

            next if ( index( $code, '2' ) != 0 );
            if ( $uri =~ m/\s+\/\d+mb\s+/ ) {
                my %hash = ();
                $hash{'speed'}    = $out_size * 8 / $time / 1024 / 1024;
                $hash{'client'}   = $client;
                $hash{'datetime'} = $datetime;
                $hash{'uri'}      = $uri;
                $hash{'out_size'} = $out_size;
                $hash{'time'}     = $time;

                my $browser = HTTP::BrowserDetect->new($ua);
                if ( $browser->browser_string() ) {
                    $hash{'useragent'} =
                        ( $browser->browser_string() || '' ) . ' '
                      . ( $browser->public_version() || '' );
                    $hash{'browser'} = $browser->browser_string()
                      || 'unknown';
                }
                else {
                    $hash{'useragent'} =
                        ( $browser->engine_string()  || '' ) . ' '
                      . ( $browser->engine_version() || '' );
                    $hash{'browser'} = $browser->engine_string() || 'unknown';
                }
                if ( $browser->os_string() ) {
                    my $device_name = "";
                    if ( $browser->robot() ) {
                        $device_name = "/robot";
                    }
                    $hash{'useragent'} .= ' ('
                      . ( $browser->os_string() || '' )
                      . $device_name . ')';
                }
                if ( $hash{'useragent'} =~ m/^\s+$/ ) {
                    $hash{'useragent'} = $ua;
                }

                unshift( @rows, \%hash );
            }
        }
        else {
            $unmatch++;
            print STDERR "$_\n";
        }
    }

    printf STDERR (
        "Total %s lines, match %s lines (%.1f%%).\n",
        Number::Format::format_number($total),
        Number::Format::format_number($match),
        ( $match / $total ) * 100
    );

    my $vars =
      { 'rows' => \@rows, 'parse_time' => scalar( localtime( time() ) ), };
    my $plugins = Template::Plugins->new(
        { PLUGINS => { FormatNumber => 'FormatNumber', }, } );
    my $config = {
        INCLUDE_PATH => $Bin,         # or list ref
        POST_CHOMP   => 1,            # cleanup whitespace
        LOAD_PLUGINS => [$plugins],
    };
    my $template = Template->new($config) || die($Template::ERROR);
    $template->process( "apache_log.tt", $vars ) || die($Template::ERROR);
}

main();
