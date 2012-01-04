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

###
### PARSE OPTIONS
###

our $conf = LoadFile("$Bin/extract.yml");
GetOptions(
    'delete'   => \$conf->{delete},
    'debug'    => \$conf->{debug},
    'pretend'  => \$conf->{pretend},
    'target=s' => \$conf->{target},
    'verbose'  => \$conf->{verbose},
) or die "Unable to get command line options.";

##
## VARIOUS SUBROUTINES
##

sub vprint {
    if ( $conf->{verbose} || $conf->{debug} ) {
        say for @_;
    }
}

sub delete_files {
    my ($file) = @_;
    my $command = 'unrar -c- -v l';
    open my $out, "$command $file |";
    my @volumes;
    for (<$out>) {
        if (/^Volume (.*)$/) {
            push @volumes, $1;
        }
    }
    unlink for @volumes;
}

##
## MAIN PROGRAM
##

### If there were no directories specified, use the cwd
my @search_dirs;
if (scalar @ARGV) {
    @search_dirs = @ARGV;
} else {
    push @search_dirs, cwd();
}

### Find all .rar files
my $find = File::Find::Rule->new;
$find->file
    ->nonempty
    ->exec(sub {
               m{\.001\Z}
            || m{\.part0*1\.rar\Z}i
            || m{\.rar\Z}i && !m{\.part\d+\.rar\Z}i;
           });
my @files = $find->in(@search_dirs);

### If pretending, print files and exit
if ($conf->{pretend}) {
    vprint("Pretending...");
    say for @files;
    exit;
}

### Extract the files
my @command = qw'unrar -o+ -c- -inul x';
for my $file (@files) {
    print $file;
    unless ($conf->{pretend}) {
        my @cmd = (@command, $file);
        push @cmd, $conf->{target} if $conf->{target};
        system(@cmd);
    }

    ### Delete the files
    if ($conf->{delete}) {
        delete_files($file);
    }

    print " DONE\n";
}

