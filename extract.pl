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
    'target=s' => \$conf->{target},
    'verbose'  => \$conf->{verbose},
) or die "Unable to get command line options.";

### Decide which directories to work on

my @search_dirs;
if (scalar @ARGV) {
    @search_dirs = @ARGV;
} else {
    push @search_dirs, cwd();
}

### Build the extract command

my $rars = File::Finder->type('f')->eval(sub {
    m{\.001\Z} || m{\.rar\Z}i && ( m{\.part0*1\.rar\Z}i || !m{\.part\d+\.rar\Z}i);
});

### Extract the files

my @rars;
    {
        vprint "Will extract:";
        $rars = $rars->print;
        $rars->in(@search_dirs);
        vprint "";
        unless ($conf->{pretend}) {
            my @command = qw'unrar -o+ -inul';
            #    push @command, "-inul" unless $conf->{verbose};
            push @command, qw'x {}';
            push @command, $conf->{target} if $conf->{target};            
            $rars = $rars->exec(@command);
            
        }
        say "Now extracting:";
        @rars = $rars->in(@search_dirs);
        say "";
    }

### Delete the files

exit unless $conf->{delete};

vprint( "Removing files..." );
my $rar_suffix = qr/\.(?:rar|r\d\d|\d{3}])\Z/i;

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
