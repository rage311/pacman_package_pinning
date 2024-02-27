#!/usr/bin/env perl
use 5.036;
use Archive::Tar;

### check uname -r (best way?) to see current version
# ex:
# 6.7.6-zen1-1-zen
# use version of installed zen kernel instead? (in case of currently running other kernel)
my $uname = `/usr/bin/env uname -r`;

my $current->@{qw/ major minor patch /} = $uname =~ /(\d+)\.(\d+)(?:\.(\d+))?-zen.*/;
die "No current 'major.minor.patch' pattern from regex in uname -r"
  unless defined $current->{major}
    && defined $current->{minor};

### check extra.db to see the new version
# really a .tar.gz
# /var/lib/pacman/sync/extra.db
# after extraction, directories like:
# ./linux-zen-6.7.6.zen1-1/desc (all that's in dirs)
my $tar = Archive::Tar->new;
$tar->read('/var/lib/pacman/sync/extra.db', 1);
my @target = grep { /linux-zen-\d+\.\d+(\.\d+)?/ } $tar->list_files();

my $new->@{qw/ major minor patch /} = $target[0] =~ /linux-zen-(\d+)\.(\d+)(?:\.(\d+))?/; 
die "No new 'major.minor.patch' pattern from regex in pacman db tar archive"
  unless defined $new->{major}
    && defined $new->{minor};

### see if it's still in the major/minor version
my $eligible =
     $current->{major} >= $new->{major}
  && $current->{minor} >= $new->{minor};

my $current_version_str =
  "$current->{major}.$current->{minor}"
  . (defined $current->{patch}
    ? ".$current->{patch}"
    : '');
say "Current (running) zen kernel: $current_version_str";

my $new_version_str =
  "$new->{major}.$new->{minor}"
  . (defined $new->{patch}
    ? ".$new->{patch}"
    : '');
say "Update candidate zen kernel:  $new_version_str";

# JustUnixThings
if ($eligible) {
  # all good
  exit 0;
} else {
  say "Installing linux-zen kernel $new_version_str"
    . " violates major/minor version pinning to version "
    . join '.', $current->@{qw/ major minor /}, 'X'
    . "\n";
  exit 1;
}
