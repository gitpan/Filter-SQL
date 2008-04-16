use strict;
use inc::Module::Install;

name('Filter-SQL');
all_from('lib/Filter/SQL.pm');

requires 'DBI';
requires 'Filter::Simple' => 0.82;

auto_install;
WriteAll;
