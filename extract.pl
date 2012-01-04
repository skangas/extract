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

##
## PARSE OPTIONS
##

our $conf = LoadFile("$Bin/extract.yml");
GetOptions(
    'delete'   => \$conf->{delete},
    'pretend'  => \$conf->{pretend},
    'target=s' => \$conf->{target},
) or die "Unable to get command line options.";

##
## SUBROUTINES
##

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
say "Pretending, will not actually do anything..." if $conf->{pretend};

### Otherwise, start work
for my $file (@files) {
    print $file;

    unless ($conf->{pretend}) {

        ### Extract archive
        my @cmd = qw'unrar -o+ -c- -inul x';
        push @cmd, $file;
        push @cmd, $conf->{target} if $conf->{target};
        system(@cmd);
        unless ($? == 0) {
            say " FAILED";
            next;
        }

        ### Delete all files
        if ($conf->{delete}) {
            delete_files($file);
        }
    }

    say " DONE";
}

