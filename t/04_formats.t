use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir tempfile);
use YAML::XS qw(Load);
use Digest::SHA qw(sha256_hex);

# suppress redefine warnings when loading script multiple times
local $SIG{__WARN__} = sub {};

my $dir = tempdir(CLEANUP => 1);
open my $fh, '>', "$dir/file" or die $!;
print $fh "hello";
close $fh;

# --html
{
    my ($tmpfh, $tmpfile) = tempfile();
    {
        local *STDOUT = $tmpfh;
        local @ARGV = ('--html', $dir);
        do "$FindBin::Bin/../stree";
        main::run();
    }
    close $tmpfh;
    open my $rfh, '<', $tmpfile or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;
    $content =~ s/\e\[[0-9;]*m//g;
    like($content, qr/<html>/, 'html output contains <html> tag');
    like($content, qr/<li>\Q$dir\E\/file<\/li>/, 'html output lists file');
}

# --yaml
{
    my ($tmpfh, $tmpfile) = tempfile();
    {
        local *STDOUT = $tmpfh;
        local @ARGV = ('--yaml', $dir);
        do "$FindBin::Bin/../stree";
        main::run();
    }
    close $tmpfh;
    open my $rfh, '<', $tmpfile or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;
    $content =~ s/\e\[[0-9;]*m//g;
    my ($yaml_str) = $content =~ /(---\n(?:- [^\n]*\n)+)/;
    my $data = Load($yaml_str);
    ok(grep { $_ eq "$dir/file" } @$data, 'yaml output lists file');
}

# --hash
{
    my ($tmpfh, $tmpfile) = tempfile();
    {
        local *STDOUT = $tmpfh;
        local @ARGV = ('--hash', $dir);
        do "$FindBin::Bin/../stree";
        main::run();
    }
    close $tmpfh;
    open my $rfh, '<', $tmpfile or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;
    $content =~ s/\e\[[0-9;]*m//g;
    my $expected = sha256_hex('hello');
    like($content, qr/\bfile\b\s+$expected/, 'hash output includes digest');
}

done_testing();

