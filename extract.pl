#!/usr/bin/perl

use 5.010;
use autodie;
use strict;

use Cwd qw(cwd abs_path);
use Data::Dumper;
use File::Basename;
use FindBin qw($Bin);
use Getopt::Long;

use File::Find::Rule;
use Path::Class qw(file);
use YAML::Syck;

### COMMAND LINE OPTIONS
our $conf = LoadFile("$Bin/extract.yml");
GetOptions(
    'delete'   => \$conf->{delete},
    'debug'    => \$conf->{debug},
    'pretend'  => \$conf->{pretend},
    'target=s' => \$conf->{target},
    'verbose'  => \$conf->{verbose},
) or die "Unable to get command line options.";

### If there were no directories specified, use the cwd
my @search_dirs;
if (scalar @ARGV) {
    @search_dirs = @ARGV;
} else {
    push @search_dirs, cwd();
}

### Build the extract command
my $find = File::Find::Rule->new;
$find->file
    ->nonempty
    ->exec(sub {
               m{\.001\Z}
            || m{\.part0*1\.rar\Z}i
            || m{\.rar\Z}i && !m{\.part\d+\.rar\Z}i;
           });

### Print the files
vprint("Will extract:");
my @files;
@files = $find->in(@search_dirs);
say for @files;
vprint("");

### Extract the files

my @command = qw'unrar -o+ -c- -inul x';
say "Now extracting:";
for my $file (@files) {
    say $file;
    unless ($conf->{pretend}) {
        my @cmd = (@command, $file);
        push @cmd, $conf->{target} if $conf->{target};
        system(@cmd);
    }
}

### Delete the files
exit unless $conf->{delete};

say "";
vprint( "Removing files..." );

my $command = 'unrar -c- -v l';

for my $file (@files) {
    my $out;
    open $out, "$command $file |";
    my @volumes;
    for (<$out>) {
        if (/^Volume (.*)$/) {
            push @volumes, $1;
        }
    }
    say for @volumes;
}

##
## VARIOUS SUBROUTINES
##

sub vprint {
    if ( $conf->{verbose} || $conf->{debug} ) {
        say for @_;
    }
}
