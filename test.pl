BEGIN {
    $| = 1;
    print "1..8\n";
}
END {print "not ok 1\n" unless $loaded;}
use Algorithm::FastPermute;
$loaded = 1;
print "ok 1\n";

my @array = (1..9);
my $i = 0;
permute { ++$i } @array;

print ($i == 9*8*7*6*5*4*3*2*1 ? "ok 2\n" : "not ok 2\n");
print ($array[0] == 1 ? "ok 3\n" : "not ok 3\n");

@array = ();
$i = 0;
permute { ++$i } @array;
print ($i == 0 ? "ok 4\n" : "not ok 4\n");

@array = ('A'..'E');
my @foo;
permute { @foo = @array; } @array;

my $ok = ( join("", @foo) eq join("", reverse @array) );
print ($ok ? "ok 5\n" : "not ok 5\n");

tie @array, 'TieTest';
permute { $_ = "@array" } @array;
print (TieTest->c() == 600 ? "ok 6\n" : "not ok 6\t# ".TieTest->c()."\n");

untie @array;
@array = (qw/a r s e/);
$i = 0;
permute {eval {goto foo}; ++$i } @array;
if ($@ =~ /^Can't "goto" out/) {
    print "ok 7\n";
} else {
    foo: print "not ok 7\t# $@\n";
}

print ($i == 24 ? "ok 8\n" : "not ok 8\n");

my $c;
package TieTest;
sub TIEARRAY  {bless []}
sub FETCHSIZE {5}
sub FETCH     { ++$c; $_[1]}
sub c         {$c}
