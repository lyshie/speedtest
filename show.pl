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
use CGI qw(:standard);
use FindBin qw($Bin);
use Template;
use Template::Plugins;
use DBI;
use HTTP::BrowserDetect;

#
my $DB_FILE = "$Bin/speedtest.sqlite";
my %_GET    = ();

sub read_param {
    $_GET{'ip'} = param('ip') || $ENV{'REMOTE_ADDR'} || '';
    $_GET{'ip'} =~ s/[^\d\.]//g;

    $_GET{'server_addr'}  = $ENV{'SERVER_ADDR'}  || '127.0.0.1';
    $_GET{'http_referer'} = $ENV{'HTTP_REFERER'} || '';
}

sub get_data {
    my ($ip) = @_;

    my $subnet = $ip;
    $subnet =~ s/\d+$//;

    my @rows        = ();
    my @subnet_rows = ();

    die("ERROR: $DB_FILE not found!\n") if ( !-f $DB_FILE );

    #-----------------------------------------------------
    my $dbh =
      DBI->connect( "dbi:SQLite:dbname=$DB_FILE", "", "", { AutoCommit => 0 } );

    my $sth = $dbh->prepare(
        q{
        SELECT *,
               datetime(time, 'unixepoch', 'localtime') AS timestamp
          FROM speedtest
         WHERE ip LIKE ?
         ORDER BY time DESC, id DESC
         LIMIT 1000;
        }
    );
    $sth->execute("$subnet%");

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
            push( @rows, $hashref ) if ( scalar(@rows) < 5 );
        }
        push( @subnet_rows, $hashref ) if ( scalar(@subnet_rows) < 10 );
    }

    undef($sth);
    $dbh->disconnect();

    return ( \@rows, \@subnet_rows );
}

sub main {
    read_param();

    my ( $rows, $subnet_rows ) = get_data( $_GET{'ip'} );

    print header( -charset => 'utf-8' );

    my $vars = {
        'ip'           => $_GET{'ip'},
        'rows'         => $rows,
        'subnet_rows'  => $subnet_rows,
        'server_addr'  => $_GET{'server_addr'},
        'http_referer' => ( $_GET{'http_referer'} =~ m/download\.php/ ) ? 1 : 0,
    };
    my $plugins = Template::Plugins->new(
        { PLUGINS => { FormatNumber => 'FormatNumber', }, } );
    my $config = {
        INCLUDE_PATH => $Bin,         # or list ref
        POST_CHOMP   => 1,            # cleanup whitespace
        LOAD_PLUGINS => [$plugins],
    };
    my $template = Template->new($config) || die($Template::ERROR);
    $template->process( "show.tt", $vars ) || die($Template::ERROR);
}

main();

