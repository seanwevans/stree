use strict;
use warnings;
use Test::More;
use FindBin;

# suppress redefine warnings when loading script multiple times
local $SIG{__WARN__} = sub {};

# --csv
{
    local @ARGV = ('--csv');
    do "$FindBin::Bin/../stree";
    ok($main::opt->{csv}, 'csv option parsed');
}

# --json
{
    local @ARGV = ('--json');
    do "$FindBin::Bin/../stree";
    ok($main::opt->{json}, 'json option parsed');
}

done_testing();
