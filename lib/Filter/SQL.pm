package Filter::SQL;

use strict;
use warnings;
use Carp;
use Filter::Simple;

our $VERSION = '0.08';

FILTER_ONLY
    code => sub {
        s{(EXEC\s+(?:\S+)|SELECT\s+ROW|SELECT|INSERT|UPDATE|DELETE|REPLACE) ([^;]*);}{'Filter::SQL->' . Filter::SQL::to_func($1) . quote_vars($2) . ")"}egm;
#        print STDERR $_; $_;
    };

sub to_func {
    my $op = shift;
    $op = uc $op;
    if ($op =~ /^EXEC\s+/) {
        return "sql_prepare_exec('$' ";
    } elsif ($op =~ /^SELECT\s+ROW/) {
        return "sql_selectrow('SELECT ";
    } elsif ($op eq 'SELECT') {
        return "sql_selectall('SELECT ";
    } else {
        return "sql_prepare_exec('$op ";
    }
}

sub quote_vars {
    my $src = shift;
    my $ph = $Filter::Simple::placeholder;
    $src =~ s/$ph/recover_quotelike($&, $1)/egm;
    my $out;
    my @params;
    while ($src =~ /($ph)|(\$|\{)/) {
        $out .= $`;
        $src = $';
        if ($1) {
            $out .= '?';
            push @params, $1;
        } else {
            my ($var, $depth) = ($&, $& eq '$' ? 0 : 1);
            while ($src ne '') {
                if ($depth == 0) {
                    last
                        unless $src =~ /^(?:([A-Za-z0-9_]+(?:->|))|([\[\{\(]))/;
                    $src = $';
                    if ($1) {
                        $var .= $1;
                    } else {
                        $var .= $2;
                        $depth++;
                    }
                } else {
                    last unless $src =~ /([\]\}\)](?:->|))/;
                    $src = $';
                    $var .= "$`$1";
                    $depth--;
                }
            }
            $var =~ s/^{(.*)}$/$1/m;
            $out .= '?';
            push @params, $var;
        }
    }
    $out .= $src;
    join ',', "$out'", @params;
}

sub recover_quotelike {
    my ($ph, $n) = ($_[0], unpack('N', $_[1]));
    my $s = ${$Filter::Simple::components[$n]};
    $s =~ /^[\'\"]/ ? $ph : $s;
}

my $dbh;

sub dbh {
    my $klass = shift;
    if (@_) {
        $dbh = shift;
        return; # returns undef
    }
    ref $dbh eq 'CODE' ? $dbh->() : $dbh;
}

sub sql_prepare_exec {
    my ($klass, $sql, @params) = @_;
    my $pe = Filter::SQL->dbh->{PrintError};
    local Filter::SQL->dbh->{PrintError} = undef;
    my $sth = Filter::SQL->dbh->prepare($sql);
    unless ($sth) {
        carp Filter::SQL->dbh->errstr if $pe;
        return;
    }
    unless ($sth->execute(@params)) {
        carp Filter::SQL->dbh->errstr if $pe;
        return;
    }
    $sth;
}

sub sql_selectall {
    my ($klass, $sql, @params) = @_;
    my $pe = Filter::SQL->dbh->{PrintError};
    local Filter::SQL->dbh->{PrintError} = undef;
    my $rows = Filter::SQL->dbh->selectall_arrayref($sql, {}, @params);
    unless ($rows) {
        carp Filter::SQL->dbh->errstr if $pe;
        return;
    }
    wantarray ? @$rows : $rows->[0];
}

sub sql_selectrow {
    my ($klass, $sql, @params) = @_;
    my $pe = Filter::SQL->dbh->{PrintError};
    local Filter::SQL->dbh->{PrintError} = undef;
    my $rows = Filter::SQL->dbh->selectall_arrayref($sql, {}, @params);
    unless ($rows) {
        carp Filter::SQL->dbh->errstr if $pe;
        return;
    }
    @$rows ? wantarray ? @{$rows->[0]} : $rows->[0][0] : ();
}

sub quote {
    my ($klass, $v) = @_;
    Filter::SQL->dbh->quote($v);
}

1;

__END__

=head1 NAME

Filter::SQL - embedded SQL for perl

=head1 SYNOPSIS

  use Filter::SQL;

  Filter::SQL->dbh(DBI->connect('dbi:...')) or die DBI->errstr;

  EXEC CREATE TABLE t (v int not null);;

  $v = 12345;
  INSERT INTO t (v) VALUES ($v);;
  
  foreach my $row (SELECT * FROM t;) {
      print "v: $row[0]\n";
  }

  if (SELECT ROW COUNT(*) FROM t; == 1) {
      print "1 row in table\n";
  }

=head1 SYNTAX

Filter::SQL recognizes portion of source code starting from one of the keywords below as an SQL statement, terminated by a semicolon.

  SELECT
  SELECT ROW
  EXEC
  INSERT
  UPDATE
  DELETE
  REPLACE

=head2 "SELECT" statement

Executes a SQL SELECT statement.  Returns an array of rows.

  my @row = SELECT * FROM t;;

=head2 "SELECT ROW" statement

Executes a SQL SELECT statement and returns the first row.

  my @column_values = SELECT ROW * FROM t;;

  my $sum = SELECT ROW SUM(v) FROM t;;

=head2 "EXEC" statement

Executes following string as a SQL statement and returns statement handle.

  EXEC DROP TABLE t;;

  my $sth = EXEC SELECT * FROM t;;
  while (my @row = $sth->fetchrow_array) {
      ...
  }

=head2 "INSERT" statement

=head2 "UPDATE" statement

=head2 "DELETE" statement

=head2 "REPLACE" statement

Executes a SQL statement and returns statement handle.

=head2 VARIABLE SUBSTITUTION

Within a SQL statement, scalar perl variables may be used.  They are automatically quoted and passed to the database engine.

  my @rows = SELECT v FROM t WHERE v<$min_v;;

  my @rows = SELECT v FROM t WHERE s LIKE "abc%$str";;

A string between curly brackets it considered as a perl expression.

  my $t = 'hello';
  print SELECT ROW {$t . ' world'};;   # hello world

=head1 AUTHOR

Kazuho Oku

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Cybozu Labs, Inc.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.6 or, at your option, any later version of Perl 5 you may have available.

=cut
