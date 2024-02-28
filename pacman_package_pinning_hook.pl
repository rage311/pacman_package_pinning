#!/usr/bin/env perl
use 5.38.2;
use Archive::Tar;
use List::Util 'first';
use Getopt::Long;

# operator is one of: ^ ~ < =
# for simple MAJOR.MINOR.PATCH versioning only
sub semver_pattern($pattern, $current = undef) {
  chomp($pattern);

  return do {
    # pin to current major version -- unknown at this point
    if ($pattern eq 'major') {
      # we must go deeper
      sub ($test) { $current->{major} == $test->{major} }
    # pin to current minor version -- unknown at this point
    } elsif ($pattern eq 'minor') {
      sub ($test) {
           $current->{major} == $test->{major}
        && $current->{minor} == $test->{minor}
      }
    } else {
      my ($operator, $version) =
        $pattern =~ /([<~^=])\s*(\d+\.\d+(?:\.\d+)?)/;

      die "Unable to parse version: '$version'"
        unless
          my $rule = parse_version($version);

      {
        '=' => sub ($test) {
             $test->{major} == $rule->{major}
          && $test->{minor} == $rule->{minor}
          && $test->{patch} == $rule->{patch}
        },
        # less than
        '<' => sub ($test) {
          $test->{major} < $rule->{major}
          || ($test->{major} == $rule->{major} && $test->{minor} < $rule->{minor})
          || (   $test->{major} == $rule->{major}
              && $test->{minor} == $rule->{minor}
              && $test->{patch} <  $rule->{patch}
             )
        },
        # can only differ in patch versions
        '~' => sub ($test) {
          $test->{major} == $rule->{major} && $test->{minor} == $rule->{minor}
        },
        # can only differ in minor and patch versions
        '^' => sub ($test) { $test->{major} == $rule->{major} },
      }
      ->{$operator};
    }
  };
}

sub parse_version($string) {
  my ($major, $minor, $patch) = $string =~ /(\d+)\.(\d+)(?:\.(\d+))?/;
  return unless defined $major && defined $minor;
  $patch //= 0;

  return {
    major => $major,
    minor => $minor,
    patch => $patch,
  };
}

sub deparse_version($version) {
  return join '.',
    $version->{major},
    $version->{minor},
    $version->{patch};
}

sub print_usage() {
  return<<~EOF;
Usage:
    $0 --package PACKAGE_NAME --repo REPO_NAME --pin PIN_STRING
    e.g.
    perl pacman_kernel_pinning_hook.pl --package "linux-zen" --repo "extra" --pin "~6.7"
EOF
}

sub main() {
  # e.g. "linux-zen"
  my $package;
  # e.g. "extra"
  my $repo;
  # e.g. "~6.7"
  my $pin;

  die ("Error getting command line arguments.\n" . print_usage())
    unless
      GetOptions (
        "package=s" => \$package,
        "repo=s"    => \$repo,
        "pin=s"     => \$pin,
      )
      && defined $package
      && defined $repo
      && defined $pin;

  # find current version
  my @pacman_results = split /\s*\n/, `/usr/bin/env pacman -Q`;

  my ($pacman_current) =
    map { $_ =~ /(\S+)\s+(\S+)/ and $2 }
    first { (index $_, $package) == 0 } @pacman_results;

  my $current = parse_version($pacman_current);

  die "Couldn't determine current version"
    unless defined $current;

  ### check ${repo}.db to see the new version
  # /var/lib/pacman/sync/{extra,core,...}.db
  # really a .tar.gz file
  # after extraction, directories like: ./linux-zen-6.7.6.zen1-1/desc
  my $tar = Archive::Tar->new;
  die "Unable to read pacman ${repo}.db file:\n$!"
    unless $tar->read("/var/lib/pacman/sync/${repo}.db", 1);

  my $target = first { /$package-\d+\.\d+(\.\d+)?/ } $tar->list_files();

  my $new = parse_version($target);
  die "No new 'major.minor.patch' pattern from regex in pacman db tar archive"
    unless defined $new;

  my $eligible = semver_pattern($pin, $current)->($new);

  my $current_version_str = deparse_version($current);
  my $new_version_str     = deparse_version($new);

  say "Current         : $current_version_str";
  say "Update candidate: $new_version_str";
  say "Pin             : $pin";

  # JustUnixThings
  if ($eligible) {
    # all good
    say "OK!\n";
    exit 0;
  } else {
    say "Installing $package $new_version_str"
      . " violates version pinning to $pin\n";
    exit 1;
  }
}

main();
