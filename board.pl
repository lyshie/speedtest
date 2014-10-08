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
#
use strict;
use warnings;

#
use CGI qw(:standard *table);
use FindBin qw($Bin);
use Template;
use Template::Plugins;
use DBI;
use HTTP::BrowserDetect;

#
my $DB_FILE    = "$Bin/speedtest.sqlite";
my %_GET       = ();
my $TIME_RANGE = 0;

sub read_param {
    $_GET{'ip'}         = param('ip')         || $ENV{'REMOTE_ADDR'} || '';
    $_GET{'top_count'}  = param('top_count')  || '10';
    $_GET{'last_count'} = param('last_count') || '10';
    $_GET{'minute'}     = param('minute')     || '180';

    $_GET{'ip'}         =~ s/[^\d\.]//g;
    $_GET{'top_count'}  =~ s/\D//g;
    $_GET{'last_count'} =~ s/\D//g;
    $_GET{'minute'}     =~ s/[^\d]//g;

    $TIME_RANGE = time() - $_GET{'minute'} * 60;
}

sub minute_to_string {
    my ($minute) = @_;
    my $unit = '分鐘';

    if ( $minute % 60 == 0 ) {
        $unit = '小時';
        $minute /= 60;
    }

    if ( $minute % 24 == 0 ) {
        $unit = '天';
        $minute /= 24;
    }

    if ( $minute % 7 == 0 ) {
        $unit = '週';
        $minute /= 7;
    }

    return $minute . ' ' . $unit;
}

sub get_top_data {
    my ( $ip, $count ) = @_;
    return get_data( $ip, 'DESC', $count );
}

sub get_last_data {
    my ( $ip, $count ) = @_;
    return get_data( $ip, 'ASC', $count );
}

sub get_data {
    my ( $ip, $order, $count ) = @_;

    my $subnet = $ip;
    $subnet =~ s/\d+$//;

    my @rows        = ();
    my @subnet_rows = ();

    die("ERROR: $DB_FILE not found!\n") if ( !-f $DB_FILE );

    #-----------------------------------------------------
    my $dbh =
      DBI->connect( "dbi:SQLite:dbname=$DB_FILE", "", "", { AutoCommit => 0 } );

    my $sth = $dbh->prepare(
        qq{
        SELECT *,
               datetime(time, 'unixepoch', 'localtime') AS timestamp
          FROM speedtest
         WHERE (ip LIKE ?)
           AND  (time >= ?)
         ORDER BY downspeed $order, time DESC, id DESC
         LIMIT 1000;
        }
    );
    $sth->execute( "$subnet%", $TIME_RANGE );

    while ( my $hashref = $sth->fetchrow_hashref() ) {
        my $browser = HTTP::BrowserDetect->new( $hashref->{'useragent'} );
        if ( $browser->browser_string() ) {
            $hashref->{'useragent'} =
                ( $browser->browser_string() || '' ) . ' '
              . ( $browser->public_version() || '' );
            $hashref->{'browser'} = $browser->browser_string() || 'unknown';
        }
        else {
            $hashref->{'useragent'} =
                ( $browser->engine_string()  || '' ) . ' '
              . ( $browser->engine_version() || '' );
            $hashref->{'browser'} = $browser->engine_string() || 'unknown';
        }
        if ( $browser->os_string() ) {
            $hashref->{'useragent'} .=
              ' (' . ( $browser->os_string() || '' ) . ')';
        }

        if ( $hashref->{'ip'} eq $ip ) {
            push( @rows, $hashref ) if ( scalar(@rows) < $count );
        }
        push( @subnet_rows, $hashref ) if ( scalar(@subnet_rows) < $count );
    }

    undef($sth);
    $dbh->disconnect();

    return ( \@rows, \@subnet_rows );
}

sub main {
    read_param();

    my ( undef, $top_rows ) = get_top_data( $_GET{'ip'}, $_GET{'top_count'} );
    my ( undef, $last_rows ) =
      get_last_data( $_GET{'ip'}, $_GET{'last_count'} );

    print header( -charset => 'utf-8' );

    my $vars = {
        'ip'            => $_GET{'ip'},
        'top_count'     => $_GET{'top_count'},
        'top_rows'      => $top_rows,
        'last_count'    => $_GET{'last_count'},
        'last_rows'     => $last_rows,
        'minute_string' => minute_to_string( $_GET{'minute'} ),
    };
    my $plugins = Template::Plugins->new(
        { PLUGINS => { FormatNumber => 'FormatNumber', }, } );
    my $config = {
        INCLUDE_PATH => $Bin,         # or list ref
        POST_CHOMP   => 1,            # cleanup whitespace
        LOAD_PLUGINS => [$plugins],
    };
    my $template = Template->new($config) || die($Template::ERROR);
    $template->process( "board.tt", $vars ) || die($Template::ERROR);
}

main();

