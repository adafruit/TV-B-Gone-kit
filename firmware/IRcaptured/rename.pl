#!/bin/perl

$inc = $ARGV[0];
if (opendir(DIR, $ARGV[1])) {
  @files = readdir( DIR ) or die "Couldn't read from $directory : $!\n+";
  foreach $oldname (@files) {
    if ($oldname =~ /([a-z]+)([0-9]+)\.dat/) {
      $newname = $1 . ($2 + $inc) . ".dat";
      print "mv $oldname $newname\n";
      `mv $ARGV[1]/$oldname $ARGV[1]/$newname`;
    }
  }
}
