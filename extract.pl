#!/usr/bin/perl

use 5.010;
use autodie;
use strict;
use warnings;
        
use FindBin qw($Bin);
use lib "$Bin/lib";

use Archive::Extract;
use File::Basename;
use File::Find::Rule;
use Path::Class qw(file);
use Cwd qw(cwd abs_path);
use Data::Dumper;
use Getopt::Long;
use YAML::Syck;

our $VERSION = '0.01';

### COMMAND LINE OPTIONS
our $conf = LoadFile("$Bin/extract.yml");
GetOptions(
    'delete'   => \$conf->{delete},
    'debug'    => \$conf->{debug},
    'pretend'  => \$conf->{pretend},
    'target=s' => \$conf->{target},
    'verbose'  => \$conf->{verbose},
) or die "Unable to get command line options.";

### If there were no directories specified, use cwd
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

### Extract the files
my @rars;
my @command = qw'unrar -o+ -c- -inul x';
    {
        vprint("Will extract:");
        @rars = $find->in(@search_dirs);
        say for @rars;
        vprint("");
        say "Now extracting:";
        for my $file (@rars) {
            say $file;
            unless ($conf->{pretend}) {
                my @cmd = (@command, $file);
                push @cmd, $conf->{target} if $conf->{target};
                system(@cmd);
            }
        }
    }

### Delete the files
exit unless $conf->{delete};

say "";
vprint( "Removing files..." );
my $rar_suffix = qr/((part\d+)?\.rar|\.(r\d\d|\d{3}]))\Z/i;

for my $file (@rars) {
    my $basename = fileparse($file, $rar_suffix);
    my $back = cwd();
    my $all_volumes = File::Finder->type('f')->eval(sub {
        /$basename$rar_suffix/
    });
    if ($conf->{debug}) {
        $all_volumes = $all_volumes->print;
    }
    if (!$conf->{pretend}) {
        $all_volumes = $all_volumes->eval(sub{ unlink $_; });
    }
    $all_volumes->in(file($file)->dir);    
}

##
## VARIOUS SUBROUTINES
##

sub dprint {
    if ( $conf->{debug} ) {
        say for @_;
    }
}

sub vprint {
    if ( $conf->{verbose} || $conf->{debug} ) {
        say for @_;
    }
}

# TODO

# - FATX::Rename (or something)
#   42 bytes ASCII
#   2 gb file size
#   should be able to take a list of regexp, i.e. [qr//, qr//] and use them for removing not needed information
#   such as group tags and so on

# - break of unraring into a module which should be suitable
#   for insertion into CPAN

# - automatic sorting into directories based on regexps
# - automatic ftp upload - Net::FTP? - is this suited for
#   scextract or better left to another tool? shellscripting?

1;
