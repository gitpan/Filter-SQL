use Test::More tests => 4;

use_ok('Filter::SQL');

my $r = 1;
Filter::SQL->dbh(sub { $r++ });
is($r, 1);
is(Filter::SQL->dbh(), 1);
is($r, 2);
