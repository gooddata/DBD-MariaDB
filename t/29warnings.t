use strict;
use warnings;

use Test::More;
use DBI;
use lib '.', 't';
require 'lib.pl';
$|= 1;

use vars qw($test_dsn $test_user $test_password);

my $dbh = DbiTestConnect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 0, AutoCommit => 0 });

plan tests => 14;

ok(defined $dbh, "Connected to database");

ok(my $sth= $dbh->prepare("DROP TABLE IF EXISTS no_such_table"));
ok($sth->execute());

is($sth->{mariadb_warning_count}, 1, 'warnings from sth');

ok($dbh->do("SET sql_mode=''"));
ok($dbh->do("CREATE TEMPORARY TABLE dbd_drv_sth_warnings (c CHAR(1))"));
ok($dbh->do("INSERT INTO dbd_drv_sth_warnings (c) VALUES ('perl'), ('dbd'), ('mysql')"));
is($dbh->{mariadb_warning_count}, 3, 'warnings from dbh');


# tests to make sure mariadb_warning_count is the same as reported by mysql_info();
# see https://rt.cpan.org/Ticket/Display.html?id=29363
ok($dbh->do("CREATE TEMPORARY TABLE dbd_drv_count_warnings (i TINYINT NOT NULL)") );

my $q = "INSERT INTO dbd_drv_count_warnings VALUES (333),('as'),(3)";

ok($sth = $dbh->prepare($q));
ok($sth->execute());

is($sth->{'mariadb_warning_count'}, 2 );

# this test passes on mysql 5.5.x and fails on 5.1.x
# so change number of expected warnings from mysql_info()
my $expected_warnings = 2;
if ($dbh->{mariadb_serverversion} >= 50000 && $dbh->{mariadb_serverversion} < 50500) {
    $expected_warnings = 1;
}
# $dbh->{mariadb_info} actually uses mysql_info()
my $info = $dbh->{mariadb_info};
like($info, qr/Warnings:\s\Q$expected_warnings\E$/);

ok($dbh->disconnect);
