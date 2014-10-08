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
use DBI;

#
my $DB_FILE           = "$Bin/speedtest.sqlite";
my %_GET              = ();
my $TIME_RANGE        = 0;
my %SUBNET_DATA       = ();
my @SUBNET_ARRAY_DATA = ();

sub read_param {
    $_GET{'minute'} = param('minute') || '180';
    $_GET{'minute'} =~ s/[^\d]//g;

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

sub ipv4_to_string {
    my ($ip) = @_;

    return join( "", map( sprintf( "%03d", $_ ), split( /\./, $ip ) ) );
}

sub get_data {
    die("ERROR: $DB_FILE not found!\n") if ( !-f $DB_FILE );

    #-----------------------------------------------------
    my $dbh =
      DBI->connect( "dbi:SQLite:dbname=$DB_FILE", "", "", { AutoCommit => 0 } );

    my $sth = $dbh->prepare(
        qq{
        SELECT *,
               datetime(time, 'unixepoch', 'localtime') AS timestamp
          FROM speedtest
         WHERE (time >= ?)
        }
    );
    $sth->execute($TIME_RANGE);

    while ( my $hashref = $sth->fetchrow_hashref() ) {
        my $subnet = $hashref->{'ip'};
        $subnet =~ s/\d+$//g;

        # total sum
        if ( defined( $SUBNET_DATA{$subnet}{'sum'} ) ) {
            $SUBNET_DATA{$subnet}{'sum'}   += $hashref->{'downspeed'};
            $SUBNET_DATA{$subnet}{'count'} += 1;
        }
        else {
            $SUBNET_DATA{$subnet}{'sum'}   = $hashref->{'downspeed'};
            $SUBNET_DATA{$subnet}{'count'} = 1;
        }

        # min
        if ( defined( $SUBNET_DATA{$subnet}{'min'} ) ) {
            if ( $hashref->{'downspeed'} < $SUBNET_DATA{$subnet}{'min'} ) {
                $SUBNET_DATA{$subnet}{'min'} = $hashref->{'downspeed'};
            }
        }
        else {
            $SUBNET_DATA{$subnet}{'min'} = $hashref->{'downspeed'};
        }

        # max
        if ( defined( $SUBNET_DATA{$subnet}{'max'} ) ) {
            if ( $hashref->{'downspeed'} > $SUBNET_DATA{$subnet}{'max'} ) {
                $SUBNET_DATA{$subnet}{'max'} = $hashref->{'downspeed'};
            }
        }
        else {
            $SUBNET_DATA{$subnet}{'max'} = $hashref->{'downspeed'};
        }
    }

    undef($sth);
    $dbh->disconnect();
}

sub hash_to_array {
    foreach my $subnet (
        sort { ipv4_to_string($a) cmp ipv4_to_string($b) }
        keys(%SUBNET_DATA)
      )
    {
        $SUBNET_DATA{$subnet}{'subnet'} = $subnet;
        push( @SUBNET_ARRAY_DATA, $SUBNET_DATA{$subnet} );
    }
}

sub main {
    read_param();

    get_data();
    hash_to_array();

    print header( -charset => 'utf-8' );

    my $vars = {
        'minute'        => $_GET{'minute'},
        'minute_string' => minute_to_string( $_GET{'minute'} ),
        'rows'          => \@SUBNET_ARRAY_DATA,
    };
    my $config = {
        INCLUDE_PATH => $Bin,    # or list ref
        POST_CHOMP   => 1,       # cleanup whitespace
    };
    my $template = Template->new($config) || die($Template::ERROR);
    $template->process( "chart.tt", $vars ) || die($Template::ERROR);
}

main();

