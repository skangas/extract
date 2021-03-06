#!/usr/bin/perl

use 5.010;
use autodie;
use strict;

use Cwd qw(cwd);
use File::Path qw(remove_tree);
use Getopt::Long;

use File::Basename;
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
    'delete'           => \$conf->{delete},
    'delete-directory' => \$conf->{delete_directory},
    'pretend'          => \$conf->{pretend},
    'rename'           => \$conf->{rename},
    'target=s'         => \$conf->{target},
    'verbose'          => \$conf->{verbose},
) or die "Unable to get command line options.";

if (defined $conf->{delete_directory}
        && !defined $conf->{target}) {
    die "using --delete-directory without setting --target is disallowed";
} 

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

sub delete_directory {
    my ($file) = @_;
    my $dir = file($file)->parent;
    if ($dir =~ m/^CD\d+$/) {
        $dir = $dir->parent;
    }
    remove_tree($dir, { verbose => 0 });
}

sub get_files {
    my ($file) = @_;
    my $command = 'unrar -c- lb';
    open my $out, "$command $file |";
    my @fs;
    for my $f (<$out>) {
        chomp $f;
        push @fs, $f;
    }
    return @fs;
}

sub get_target {
    my ($file) = @_;
    if (defined $conf->{target}) {
        return $conf->{target};
    } else {
        my $dir = file($file)->parent;
        my $base = (fileparse($dir))[0];
        if ($base =~ m/^(CD\d+|Subs)$/i) {
            return file($file)->parent->parent;
        } else {
            return file($file)->parent;   
        }
    }
}

sub rename_files {
    my ($file) = @_;
    my $target = get_target($file);

    my $dir = file($file)->parent;
    my $base = (fileparse($dir))[0];
    if ($base =~ m/^(CD\d+)$/) {
        $base = (fileparse($dir->parent))[0] . ".$1";
    }

    my @fs = get_files($file);
    for my $old (@fs) {
        my ($nam, $loc, $suf) = fileparse($old, qr/\.[^.]*\Z/);
        my $new = $base . $suf;

        # Ensure file exists before trying to rename it
        unless (-f "$target/$old") {
            warn "\nAborting rename. No such file: $target/$old\n";
            return;
        }

        # Ensure new file location does not already exist
        my $i = 1;
        while (-e "$target/$new") {
            $new = $base . ".$i" . $suf;
        }

        vsay("rename: $target/$old -> $target/$new");

        rename "$target/$old", "$target/$new";
    }
}

sub vsay {
    say @_ if $conf->{verbose};
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

say "Pretending, will not actually do anything..." if $conf->{pretend};

### Otherwise, start work
for my $file (@files) {

    ### Print file name, excluding cwd
    my $cwd = cwd() . "/";
    $file =~ m/^($cwd)?(.*)/;
    print "$2 ";

    ### Extract archive
    my @cmd = qw'unrar -o+ -c- -inul x';
    push @cmd, $file;
    push @cmd, get_target($file);
    
    # Run the command
    unless ($conf->{pretend}) {
        system(@cmd);
    }
    vsay "\nCommand: " . join ' ', @cmd;

    # Check exit codes
    unless ($? == 0) {
        if ($? == 65280) {
            say 'ABORTED';
            say "\nExtraction aborted, exiting...";
            exit;
        }
        else {
            say 'FAILED';
            next;
        }
    }

    ### Rename files as needed
    if ($conf->{rename} && !$conf->{pretend}) {
        rename_files($file);
    }
    
    ### Delete files, or entire directory
    if ($conf->{delete_directory} && !$conf->{pretend}) {
        delete_directory($file);
    }
    elsif ($conf->{delete} && !$conf->{pretend}) {
        delete_archive($file);
    }

    say "OK";
}

=head1 AUTHOR

Stefan Kangas C<< <skangas at skangas.se> >>

=head1 COPYRIGHT

Copyright 2011, 2012 Stefan Kangas, all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as perl itself.

=cut
