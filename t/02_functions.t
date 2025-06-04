use strict;
use warnings;
use Test::More;
use FindBin;

local $SIG{__WARN__} = sub {};
local @ARGV = ();
do "$FindBin::Bin/../stree";

is(human_readable_size(1024), '1.0 KB', 'human readable 1KB');
is(format_permissions(0100644), '-rw-r--r--', 'format permissions 0644');
is(format_permissions(0104755), '-rwsr-xr-x', 'format permissions setuid');

done_testing();
