#! /usr/bin/perl

use strict;
use warnings;
use DBI;
use Filter::SQL;
use Test::More;

BEGIN {
    if (! $ENV{FILTER_SQL_DBI}) {
        plan skip_all => 'Set FILTER_SQL_DBI to run these tests';
    } else {
        plan tests => 24;
    }
};

my $dbh = DBI->connect($ENV{FILTER_SQL_DBI})
    or die DBI->errstr;

is(Filter::SQL->dbh, undef);
is(Filter::SQL->dbh($dbh), $dbh);
is(Filter::SQL->dbh, $dbh);

is(SELECT ROW 1;, 1);
is(SELECT ROW "test";, 'test');
is(SELECT ROW 'test';, 'test');
is(SELECT ROW "foo'a";, "foo'a");
my $a = 'foo';
is(SELECT ROW $a;, 'foo');
$a = "foo'a";
is(SELECT ROW $a;, $a);
is(SELECT ROW ${a};, $a);
is(SELECT ROW "hoge$a";, "hoge$a");
is(SELECT ROW 'hoge$a';, 'hoge$a');
$a = [ 5 ];
is(SELECT ROW $a->[0+0]+1;, 6);
$a = { foo => 3 };
is(SELECT ROW $a->{foo}-1;, 2);

is(SELECT ROW {1 + 2};, 3);

ok(SQL DROP TABLE IF EXISTS filter_sql_t;);
ok(SQL CREATE TABLE filter_sql_t (v INT NOT NULL););

for (my $n = 0; $n < 3; $n++) {
    ok(INSERT INTO filter_sql_t (v) VALUES ($n););
}

my $sth = EXEC SELECT v FROM filter_sql_t;;
ok($sth);
is_deeply(
    $sth->fetchall_arrayref,
    [ [ 0 ], [ 1 ], [ 2 ], ],
);

is_deeply(
    [ SELECT * FROM filter_sql_t; ],
    [ [ 0 ], [ 1 ], [ 2 ], ],
);
is(SELECT ROW COUNT(*) FROM filter_sql_t;, 3);
