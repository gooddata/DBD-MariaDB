#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::More;
use lib 't', '.';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password $table);

my $dbh = DbiTestConnect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1,
                        PrintError => 0,
                        AutoCommit => 0,
                        }
                        );

my @pfenabled = $dbh->selectrow_array("show variables like 'performance_schema'");
if (!@pfenabled) {
  plan skip_all => 'performance schema not available';
}
if ($pfenabled[1] ne 'ON') {
  plan skip_all => 'performance schema not enabled';
}

if (not eval { $dbh->do("select * from performance_schema.session_connect_attrs where processlist_id=connection_id()") }) {
  my $err = $dbh->errstr || 'no permission on performance_schema tables';
  $dbh->disconnect();
  plan skip_all => $err;
}

$dbh->disconnect();
$dbh = eval { DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1,
                        PrintError => 0,
                        AutoCommit => 0,
                        mariadb_conn_attrs => { program_name => $0, foo => 'bar' },
                      }) };

if (not defined $dbh) {
  if ($DBI::errstr =~ /mariadb_conn_attrs is not supported/) {
    plan skip_all => $DBI::errstr;
  } else {
    die $DBI::errstr;
  }
}

plan tests => 8;

my $rows = $dbh->selectall_hashref("select * from performance_schema.session_connect_attrs where processlist_id=connection_id()", "ATTR_NAME");

my $pid =$rows->{_pid}->{ATTR_VALUE};
cmp_ok $pid, '==', $$;

my $progname =$rows->{program_name}->{ATTR_VALUE};
cmp_ok $progname, 'eq', $0;

my $foo_attr =$rows->{foo}->{ATTR_VALUE};
cmp_ok $foo_attr, 'eq', 'bar';

for my $key ('_platform','_client_name','_client_version','_os') {
  my $row = $rows->{$key};

  cmp_ok defined $row, '==', 1, "attribute $key";
}

ok $dbh->disconnect;
