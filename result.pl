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

use strict;
use warnings;

#
use CGI qw(:standard);
use FindBin qw($Bin);
use DBI;

my $DB_FILE    = "$Bin/speedtest.sqlite";
my $MAGIC_PATH = "/tmp";
my %_GET       = ();

sub read_param {
    $_GET{'ip'}        = $ENV{'REMOTE_ADDR'}     || '';
    $_GET{'useragent'} = $ENV{'HTTP_USER_AGENT'} || '';
    $_GET{'magic'}     = url_param('magic')      || '';
    $_GET{'downspeed'} = url_param('downspeed')  || '0';
    $_GET{'downtime'}  = url_param('downtime')   || '0';
    $_GET{'downsize'}  = url_param('downsize')   || '0';
    $_GET{'upspeed'}   = url_param('upspeed')    || '0';
    $_GET{'uptime'}    = url_param('uptime')     || '0';
    $_GET{'upsize'}    = url_param('upsize')     || '0';
    $_GET{'tag'}       = '';
    $_GET{'time'}      = time();
}

sub insert_data {
    my $magic_file = "$MAGIC_PATH/" . $_GET{'magic'};
    if ( -f $magic_file ) {
        unlink($magic_file);

        # lyshie_20101011: insert data to database
        die("ERROR: $DB_FILE not found!\n") if ( !-f $DB_FILE );
        my $dbh =
          DBI->connect( "dbi:SQLite:dbname=$DB_FILE", "", "",
            { AutoCommit => 0 } );
        my $sth = $dbh->prepare(
            qq{
        INSERT INTO speedtest (id, time, ip, downspeed, downtime, downsize, upspeed, uptime, upsize, useragent, tag)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
         }
        );

        $sth->execute(
            undef,              $_GET{'time'},     $_GET{'ip'},
            $_GET{'downspeed'}, $_GET{'downtime'}, $_GET{'downsize'},
            $_GET{'upspeed'},   $_GET{'uptime'},   $_GET{'upsize'},
            $_GET{'useragent'}, $_GET{'tag'}
        );
        $dbh->commit();
        $sth->finish();
        undef($sth);
        $dbh->disconnect();

        #
    }
}

sub main {
    read_param();
    insert_data();
    print redirect( -uri => 'show.pl' );
}

main();
