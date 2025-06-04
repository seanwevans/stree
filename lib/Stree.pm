package Stree;
use v5.10;
use strict;
use warnings;

use utf8;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(:mode);
use File::Find;
use File::Spec;
use File::stat;
use POSIX qw(strftime);
use Term::ANSIColor qw(:constants);
use User::grent;
use User::pwent;

use Cpanel::JSON::XS qw(encode_json);
use HTML::Tiny;
use Sort::Versions qw(versioncmp);
use Text::CSV;
use YAML::XS qw(Dump);
use XML::Writer;

$Term::ANSIColor::AUTORESET = 1;

our $VERSION = '0.1.1';

my $sk = 'rwxoRWXOezsfdlpSbctugkTB';
my $sv = '<>*!{}#^"-%./$|=@+:~`&[]';
my %SUFS = map { substr($sk, $_, 1) => substr($sv, $_, 1) } 0 .. length($sk)-1;

my %COLORS = (
  prefix => (BOLD WHITE),
  inode  => BLUE,
  device => YELLOW,
  perms  => GREEN,
  user   => RED,
  group  => MAGENTA,
  date   => CYAN,
  size   => WHITE,
  path   => GREEN,
  suffix => YELLOW,
  hash   => WHITE,
);

sub new {
    my ($class, $opt) = @_;
    my $self = {
        opt    => $opt,
        output => *STDOUT,
        current_depth => 0,
        log1024 => log(1024),
        partial_size => $opt->partial || 256,
        starting_dev => undef,
        num_files => 0,
        num_dirs  => 0,
        files     => [],
        fromfile_dirs => [],
        units     => [qw(B KB MB GB TB PB EB ZB YB RB QB)],
        field_order => [qw(prefix inode device perms user group date size path suffix hash)],
        gitignore_patterns => [],
        pattern_re => defined $opt->pattern ? ($opt->ignore_case ? qr/$opt->pattern/i : qr/$opt->pattern/) : undef,
        ignore_re  => defined $opt->ignore  ? ($opt->ignore_case ? qr/$opt->ignore/i  : qr/$opt->ignore/)   : undef,
        seen_links => {},
        children_count => {},
        child_index => {},
        prefix_for_dir => {},
        use_color => 0,
    };
    bless $self, $class;
    return $self;
}

sub run {
    my ($self, $dir) = @_;
    $dir //= '.';
    die "$!\n" unless -d $dir && -r $dir;
    my $opt = $self->{opt};

    $self->{starting_dev} = $opt->xdev ? (lstat($dir))->dev : '';

    # from-file check
    if ($opt->from_file) {
        die "Cannot read fromfile: $!\n" unless -r $opt->from_file;
    }

    # output handle
    if ($opt->output) {
        open my $fh, '>:encoding(UTF-8)', $opt->output or die "$!\n";
        $self->{output} = $fh;
    }
    my $output = $self->{output};
    $self->{use_color} = -t $output;

    # gitignore
    if ($opt->gitignore && -e "$dir/.gitignore") {
        open my $fh, '<:encoding(UTF-8)', "$dir/.gitignore" or die "$!\n";
        chomp(@{$self->{gitignore_patterns}} = <$fh>);
        close $fh;
    }

    if ($opt->from_file) {
        local $/;
        open my $fin, '<:encoding(UTF-8)', $opt->from_file or die "$!\n";
        chomp(@{$self->{fromfile_dirs}} = <$fin>);
        close $fin;
        find({
            wanted      => sub { $self->wanted(@_) },
            preprocess  => sub { $self->preprocess(@_) },
            postprocess => sub { $self->postprocess(@_) },
            no_chdir    => 1
        }, @{$self->{fromfile_dirs}});
    } else {
        say $output BLUE ON_GREEN $dir;
        find({
            wanted      => sub { $self->wanted(@_) },
            preprocess  => sub { $self->preprocess(@_) },
            postprocess => sub { $self->postprocess(@_) },
            no_chdir    => 1
        }, $dir);
    }

    $self->csv($self->{files}, $output)       if $opt->csv;
    $self->html($self->{files}, $output)      if $opt->html;
    $self->json($self->{files}, $output)      if $opt->json;
    $self->markdown($self->{files}, $output)  if $opt->markdown;
    $self->xml($self->{files}, $output)       if $opt->xml;
    $self->yaml($self->{files}, $output)      if $opt->yaml;

    close $output if $opt->output;

    say $output '';
    say $output BRIGHT_WHITE $self->{num_dirs}-1, ' directories, ', $self->{num_files}, ' files';
    return 1;
}

sub human_readable_size {
    my ($self, $bytes) = @_;
    return "0 B" unless $bytes;
    my $p = int(log($bytes)/$self->{log1024});
    $p = $#{$self->{units}} if $p > $#{$self->{units}};
    return sprintf("%.1f %s", $bytes / (1024 ** $p), $self->{units}->[$p]);
}

sub suffix {
    my ($self, $file) = @_;
    my $ret = '';
    for (keys %SUFS) {
        $ret .= $SUFS{$_} if eval "-$_ \$file";
    }
    return $ret;
}

sub preprocess {
    my ($self, @entries) = @_;
    my $opt = $self->{opt};
    return () if $self->{current_depth} > $opt->max_depth;
    @entries = grep { $_ ne '.' && $_ ne '..' } @entries;
    @entries = grep { !/^\./ } @entries unless $opt->all;
    if ($opt->prune) {
        @entries = grep { -s "$File::Find::dir/$_" || -d "$File::Find::dir/$_" } @entries;
    }
    if ($opt->dirs) {
        @entries = grep { -d "$File::Find::dir/$_" } @entries;
    }
    unless ($opt->no_sort) {
        if ($opt->dirs_first) {
            @entries = sort { (-d "$File::Find::dir/$b") <=> (-d "$File::Find::dir/$a") } @entries;
        } elsif ($opt->files_first) {
            @entries = sort { (-f "$File::Find::dir/$b") <=> (-f "$File::Find::dir/$a") } @entries;
        } elsif ($opt->sort_version) {
            @entries = sort { versioncmp($a, $b) } @entries;
        } elsif ($opt->time) {
            @entries = sort { (lstat($b)->mtime) <=> (lstat($a)->mtime) } @entries;
        } elsif ($opt->status) {
            @entries = sort { (lstat($b)->ctime) <=> (lstat($a)->ctime) } @entries;
        }
    }
    @entries = reverse @entries if $opt->reverse;
    $self->{children_count}{$File::Find::dir} = scalar(@entries);
    $self->{child_index}{$File::Find::dir} = 0;
    $self->{prefix_for_dir}{$File::Find::dir} //= '';
    $self->{current_depth}++;
    return @entries;
}

sub postprocess {
    my ($self) = @_;
    $self->{current_depth}-- if $self->{current_depth} > 0;
}

sub csv {
    my ($self, $files_ref, $output) = @_;
    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->say($output, [$_]) for @$files_ref;
}

sub html {
    my ($self, $files_ref, $output, $title) = @_;
    $title //= 'Directory Listing';
    my $html = HTML::Tiny->new;
    say $output $html->html([
        $html->head($html->title($title)),
        $html->body([
            $html->h1($title),
            $html->ul([ map { $html->li($_) } @$files_ref ])
        ])
    ]);
}

sub json {
    my ($self, $files_ref, $output) = @_;
    say $output encode_json($files_ref);
}

sub markdown {
    my ($self, $files_ref, $output) = @_;
    say $output "- $_" for @$files_ref;
}

sub xml {
    my ($self, $files_ref, $output) = @_;
    my @files = @$files_ref;
    my $writer = XML::Writer->new(OUTPUT => $output, DATA_MODE => 1, DATA_INDENT => 2);
    $writer->xmlDecl('UTF-8');
    $writer->startTag('filesystem');
    foreach my $file (@files) {
        my $stat = lstat($file);
        next unless $stat;
        my $perms = sprintf("%04o", $stat->mode & 07777);
        my $owner = getpwuid($stat->uid) // $stat->uid;
        my $group = getgrgid($stat->gid) // $stat->gid;
        my $size  = $stat->size;
        my $type  = -d $file ? 'directory' : 'file';
        $writer->startTag($type,
            name     => $file,
            size     => $size,
            owner    => $owner,
            group    => $group,
            perms    => $perms,
            modified => strftime("%Y-%m-%dT%H:%M:%S", localtime($stat->mtime))
        );
        $writer->endTag($type);
    }
    $writer->endTag('filesystem');
    $writer->end();
}

sub yaml {
    my ($self, $files_ref, $output) = @_;
    say $output Dump($files_ref);
}

sub format_output {
    my ($self, %fields) = @_;
    my @output;
    my $use_colors = $self->{use_color};
    for my $field (@{$self->{field_order}}) {
        next unless defined $fields{$field};
        if ($use_colors) {
            push @output, $COLORS{$field}, $fields{$field};
        } else {
            push @output, $fields{$field};
        }
    }
    return @output;
}

sub format_permissions {
    my ($self, $mode) = @_;
    my $type = '-';
    $type = 'd' if S_ISDIR($mode);
    $type = 'l' if S_ISLNK($mode);
    $type = 'c' if S_ISCHR($mode);
    $type = 'b' if S_ISBLK($mode);
    $type = 'p' if S_ISFIFO($mode);
    $type = 's' if S_ISSOCK($mode);
    my $perms = '';
    my @perm_bits = qw(r w x);
    for my $i (0..2) {
        my $shift = 6 - 3 * $i;
        my $bitmask = ($mode >> $shift) & 7;
        for my $j (0..2) {
            $perms .= ($bitmask & (1 << (2 - $j))) ? $perm_bits[$j] : '-';
        }
    }
    my $special = $mode & 07000;
    substr($perms, 2, 1, 's') if $special & 04000;
    substr($perms, 5, 1, 's') if $special & 02000;
    substr($perms, 8, 1, 't') if $special & 01000;
    return $type . $perms;
}

sub wanted {
    my ($self) = @_;
    my $opt = $self->{opt};
    my $entry = $_;
    my $dir = $File::Find::dir;
    my $full_path = File::Spec->rel2abs($File::Find::name);
    my (undef, undef, $filename) = File::Spec->splitpath($full_path);

    $self->{num_files}++ if -f $entry;
    $self->{num_dirs}++  if -d $entry;

    return if $entry eq '.' or $entry eq '..';
    my $stat = lstat($entry) or return;

    if ($opt->links && -l $entry) {
        return if $self->{seen_links}{File::Spec->rel2abs($entry)}++;
        my $link_target = File::Spec->rel2abs(readlink($entry), $dir);
        if (-d $link_target) {
            find({
                wanted      => sub { $self->wanted(@_) },
                preprocess  => sub { $self->preprocess(@_) },
                postprocess => sub { $self->postprocess(@_) },
                no_chdir    => 1
            }, $link_target);
        }
    }

    return if $opt->xdev && $stat->dev != $self->{starting_dev};
    return if defined $self->{pattern_re} && $entry !~ $self->{pattern_re};
    return if defined $self->{ignore_re}  && $entry =~ $self->{ignore_re};

    $entry =~ s/[^[:print:]]/?/g if $opt->question_marks;
    $entry = qq{"$entry"} if $opt->quotes;

    for my $pattern (@{$self->{gitignore_patterns}}) {
        return if $full_path =~ /$pattern/;
    }

    if ($opt->csv || $opt->json || $opt->xml || $opt->yaml || $opt->html || $opt->markdown) {
        push @{$self->{files}}, ($opt->full ? $full_path : $entry);
    }

    my $parent_prefix = $self->{prefix_for_dir}{File::Spec->rel2abs($dir)} // '';
    my $count = $self->{children_count}{$dir} // 1;
    my $is_last = ($self->{child_index}{$dir}++ == $count - 1);

    my ($connector, $prefix);
    if ($opt->no_indent) {
        $connector = '';
        $prefix = '';
    } else {
        $connector = $is_last ? '\── ' : '|-- ';
        $prefix = $parent_prefix . $connector;
    }

    my $inode  = $opt->inodes      ? $stat->ino . ' '                                 : '';
    my $device = $opt->device      ? $stat->dev . ' '                                  : '';
    my $perms  = $opt->permissions ? $self->format_permissions($stat->mode) . ' '      : '';
    my $user   = $opt->user        ? getpwuid($stat->uid)->[0] . ' '                   : '';
    my $group  = $opt->group       ? getgrgid($stat->gid)->[0] . ' '                   : '';
    my $date   = $opt->date        ? strftime("%Y-%m-%d %H:%M:%S", localtime($stat->mtime)) . ' '  : '';
    my $size   = $opt->size        ? $self->human_readable_size($stat->size) . ' '     : '';
    my $dpath  = $opt->full ? $full_path . ' ' : $filename . ' ';
    my $suffix = $opt->suffix ? $self->suffix($entry) . ' ' : '';

    my $hash_digest;
    if ($opt->hash) {
        $hash_digest = do {
            if (open my $fin, '<:raw', $entry) {
                my $buffer = '';
                if ($opt->partial) {
                    read($fin, $buffer, $self->{partial_size}) or $buffer = '';
                } else {
                    local $/;
                    $buffer = <$fin> // '';
                }
                close $fin;
                sha256_hex($buffer);
            } else {
                '0' x 64;
            }
        };
    }

    if (-d _) {
        if ($opt->no_indent) {
            $self->{prefix_for_dir}{$full_path} = '';
        } else {
            $self->{prefix_for_dir}{$full_path} = $parent_prefix . ($is_last ? '    ' : '|   ');
        }
    }

    say $self->{output} $self->format_output(
        prefix => $prefix,
        inode  => $inode,
        device => $device,
        perms  => $perms,
        user   => $user,
        group  => $group,
        date   => $date,
        size   => $size,
        path   => $dpath,
        suffix => $suffix,
        hash   => $hash_digest,
    );
}

1;

__END__

=pod

=head1 NAME

Stree - Tree, but better.

=head1 SYNOPSIS

  use Stree;
  my $stree = Stree->new($opt);
  $stree->run($dir);

=cut
