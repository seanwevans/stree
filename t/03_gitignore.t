use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir tempfile);
use Cpanel::JSON::XS qw(decode_json);

BEGIN {
    eval { require Parse::Gitignore; 1 } or plan skip_all => 'Parse::Gitignore module required';
}

local $SIG{__WARN__} = sub {};

my $dir = tempdir(CLEANUP => 1);
open my $fh, '>', "$dir/.gitignore" or die $!;
print $fh "ignored\n";
close $fh;
open $fh, '>', "$dir/keep" or die $!; close $fh;
open $fh, '>', "$dir/ignored" or die $!; close $fh;

my ($tmpfh, $tmpfile) = tempfile();
{
    local *STDOUT = $tmpfh;
    local @ARGV = ('--json','--gitignore',$dir);
    do "$FindBin::Bin/../stree";
    main::run();
}
close $tmpfh;

open my $rfh, '<', $tmpfile or die $!;
my $content = do { local $/; <$rfh> };
close $rfh;

# remove ANSI color codes
$content =~ s/\e\[[0-9;]*m//g;

my ($json_line) = $content =~ /(\[.*\])/s;
my $files = decode_json($json_line);

ok(!grep(/ignored$/, @$files), 'ignored file filtered');
ok(grep(/keep$/,   @$files), 'kept file present');

done_testing();
