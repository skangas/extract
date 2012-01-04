#!/usr/bin/perl

use 5.010;
use autodie;
use strict;

use Cwd qw(cwd);
use Getopt::Long;

use File::Find::Rule;
use Path::Class;

=head1 NAME

extract.pl - Extract rar archives

=cut

##
## PARSE OPTIONS
##

my $conf;
GetOptions(
    'delete'   => \$conf->{delete},
    'pretend'  => \$conf->{pretend},
    'target=s' => \$conf->{target},
) or die "Unable to get command line options.";

##
## SUBROUTINES
##

sub delete_archive {
    my ($file) = @_;
    my $command = 'unrar -c- -v l';
    open my $out, "$command $file |";
    my @volumes;
    for (<$out>) {
        if (/^Volume (.*)$/) {
            push @volumes, $1;
        }
    }
    unlink $_ for @volumes;
}

sub get_files {
    my ($file) = @_;
    my $command = 'unrar -c- lb';
    open my $out, "$command $file |";
    my @files;
    for (<$out>) {
        push @files, $_;
    }
    return @files;
}

##
## MAIN PROGRAM
##

### Find all .rar files
my $find = File::Find::Rule->new;
$find->file
    ->nonempty
    ->exec(sub {
               m{\.001\Z}
            || m{\.part0*1\.rar\Z}i
            || m{\.rar\Z}i && !m{\.part\d+\.rar\Z}i;
           });

### If there were no directories specified, use the cwd
my @dirs;
if (scalar @ARGV) {
    @dirs = @ARGV;
} else {
    @dirs = cwd();
}
my @files = sort $find->in(@dirs);

### If pretending, print files and exit
say "Pretending, will not actually do anything..." if $conf->{pretend};

### Otherwise, start work
for my $file (@files) {

    ### Print file name, excluding cwd
    my $cwd = cwd() . "/";
    $file =~ m/^($cwd)?(.*)/;
    print "$2 ";

    unless ($conf->{pretend}) {

        ### Extract archive
        my @cmd = qw'unrar -o+ -c- -inul x';
        push @cmd, $file;

        # Set target directory
        if (defined $conf->{target}) {
            push @cmd, $conf->{target};
        }
        else {
            push @cmd, file($file)->parent;
        }

        # Run the command
        system(@cmd);

        # Check exit codes
        unless ($? == 0) {
            if ($? == 65280) {
                say "ABORTED";
                say "\nExtraction aborted, exiting...";
                exit;
            }
            else {
                say "FAILED";
                next;
            }
        }

        ### Delete all files
        if ($conf->{delete}) {
            delete_archive($file);
        }
    }

    say "OK";
}

=head1 AUTHOR

Stefan Kangas C<< <skangas at skangas.se> >>

=head1 COPYRIGHT

Copyright 2011 Stefan Kangas, all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as perl itself.

=cut
