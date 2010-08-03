#!/usr/bin/perl

use 5.010;
use autodie;
use strict;
use warnings;
        
use FindBin qw($Bin);
use lib "$Bin/lib";

use Archive::Extract;
use File::Basename;
use File::Finder;
use Path::Class qw(file);
use Cwd qw(cwd abs_path);
use Data::Dumper;
use Getopt::Long;
use YAML::Syck;

our $VERSION = '0.01';
our $log;

### COMMAND LINE OPTIONS
our $conf = LoadFile('/home/skangas/code/Scextract/scextract.yml');
GetOptions(
    'delete'   => \$conf->{delete},
    'debug'    => \$conf->{debug},
    'pretend'  => \$conf->{pretend},
    'quiet'    => \$conf->{quiet},
#    'rename'   => \$conf->{rename},
    'target=s' => \$conf->{target},
    'verbose'  => \$conf->{verbose},
#    'yes|y'    => \$conf->{yes},
) or die "Unable to get command line options.";

my $all_rars = File::Finder->type('f')->eval(sub{
    ### find the type of file we want
    /(?:\.part0*1.rar # 1  part01.rar
     |
         
         (?:
             (?:[^p][^a][^r][^t]\d+)
         |
             \D
         )
         \.rar    # 2  rar
     |\.001           # 3  001
     )\Z/ix;
});
# Matches: tdf-ptaa.part11.rar
#          tcg.cd1-iffm.part39.rar

    {
        if ($conf->{debug}) {
            $all_rars = $all_rars->print;
        }
        unless ($conf->{pretend}) {
            my @command = qw'unrar -o+ -inul';
            #    push @command, "-inul" unless $conf->{verbose};
            push @command, 'x';
            push @command, '{}';
            push @command, $conf->{target} if $conf->{target};            
            $all_rars = $all_rars->exec(@command);
        }
    }

### Decide directories to work on
my @search_dirs;
if (scalar @ARGV) {
    @search_dirs = @ARGV;
} else {
    push @search_dirs, cwd();
}

my @files = $all_rars->in(@search_dirs);

### Delete the files

sleep 1 unless $conf->{pretend};

dprint( "\n###### REMOVED FILES ######\n" );
my $rar_suffix = qr/\.(?:rar|r\d\d|\d{3}])\Z/i;

for my $file (@files) {
    my $basename = fileparse($file, $rar_suffix);
    my $back = cwd();
    my $all_volumes = File::Finder->type('f')->eval(sub {
        /$basename$rar_suffix/
    });
    if ($conf->{debug}) {
        $all_volumes = $all_volumes->print;
    }
    if ( $conf->{delete} && !$conf->{pretend}) {
        $all_volumes = $all_volumes->eval(sub{ unlink $_; });
    }
    $all_volumes->in(file($file)->dir);
    
}

##
## VARIOUS SUBROUTINES
##

sub dprint {
    if ( $conf->{debug} ) {
        print for @_;
    }
}

sub vprint {
    if ( $conf->{verbose} || $conf->{debug} ) {
        print for @_;
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
