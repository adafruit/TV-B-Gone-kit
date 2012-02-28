#!/usr/bin/perl

foreach $arg (@ARGV) {
  #print "$arg\n"; 
  if (opendir(DIR, $arg)) {
    @files = readdir( DIR ) or die "Couldn't read from $directory : $!\n+";
   closedir( DIR );
    @files = grep ( /\.dat$/, @files);
    #print @files;
    foreach $f (@files) {
      push(@ARGV, $arg."/".$f);
    }
    next;
  }

  #print "opening datafile ".$arg;
  open(INPUT, $arg) or die $!;
  $outname = $arg . ".out";

  open(OUTPUT, ">", $outname) or die $!;

  $arg =~ /([a-z0-9]+).dat/;
  $codename = $1;

  $avgperiod = $freq = 0;
  @pulses = ();
  $currentpulselen = 0;
  while ($line = <INPUT>) {
    $line =~ /[0-9]+:\s+1\s+([0-9]+)\s+0\s+([0-9]+)/;
    $timeon = $1;
    $timeoff = $2;

    #print "$timeon   $timeoff\n";

    # for now, lets assume that the first line will tell us the freq
    if ($freq == 0) {
      $avgperiod = $timeon + $timeoff;
      $freq = round(1000000000/$avgperiod); #avgperiod is in ns
      #print "\nDetected $freq carrier frequency\n"
      # MEME: check that 90% of the lines have the same timing?
    }

    # Note that the timing can be off by 100 nanoseconds and we'll let it slide
    if ((($timeon + $timeoff - 100) <= $avgperiod) &&
	(($timeon + $timeoff + 100) >= $avgperiod)) {
      # This line is a carrier (high)
      $currentpulselen += $timeon + $timeoff;
    } else {
      # ok end of a pulse, it seems
      $currentpulselen += $timeon;
      $currentpulselen = round($currentpulselen/10000)/10.0;
      push(@pulses, $currentpulselen);
      #print "pulse high $currentpulselen ms\n";
      $currentpulselen = 0;  # reset
      #print $line;
      $timeoff = round($timeoff/10000)/10.0;
      push(@pulses, $timeoff);
      #print "pulse low $timeoff ms\n";
    }
  }

  #####################################################################
  # To debug, we can print out the pairs
  for ($i = 0; $i < @pulses ; $i+= 2) {
    #print "$pulses[$i] , $pulses[$i+1]\n";
  }

  #####################################################################
  # Pair up each On and Off timing code into an array

  @pairs = ();
  @uniquepairs = ();
  for ($i = 0; $i < @pulses ; $i+= 2) {
    push(@pairs, [$pulses[$i], $pulses[$i+1]]);

    $flag = 0;
    for ($j=0; $j<@uniquepairs; $j++) {
      if (($uniquepairs[$j][0] == $pulses[$i]) &&
	  ($uniquepairs[$j][1] == $pulses[$i+1])) {
	$flag = 1;
	break;
      }
    }
    if ($flag == 0) {
      push(@uniquepairs, [$pulses[$i], $pulses[$i+1]]);
    }
  }

  #####################################################################
  # Now sort them, so we can detect duplicates eaiser!

  @uniquepairs = sort { if ($a->[0] != $b->[0]) {$a->[0] <=> $b->[0]} else {$a->[1] <=> $b->[1]}} @uniquepairs;


  #print "Unique pulse pairs: \n";
  #for ($i = 0; $i < @uniquepairs ; $i++) {
  #  print "$uniquepairs[$i][0] $uniquepairs[$i][1]\n";
  #}
  #  print "\nTiming table bytes used: ".(@uniquepairs * 4)."\n";

  #####################################################################
  # To save space we detect duplicate timing tables so we can reuse them

  $timetablename = $codename;

  $flag = 0;
  foreach $timetable (@timecodetables) {
    $timetable = [ @$timetable ];
    $timecodename = $timetable->[0];

    #print "length = ". ((scalar @$timetable) -1). " $timecodename \n";
    if (((scalar @$timetable) - 1) != @uniquepairs) {
      # not the same length so def. not the same
      next;
    }
    # same length, lets compare!
    for ($timei=1; $timei < (scalar @$timetable); $timei++) {
      #print "$timetable->[$timei][0] , $timetable->[$timei][1]\t$uniquepairs[$timei][0], $uniquepairs[$timei][1]\n";
      if ( ($timetable->[$timei][0] == $uniquepairs[$timei-1][0]) &&
	   ($timetable->[$timei][1] == $uniquepairs[$timei-1][1]) ) {
	$flag = 1;
      } else {
	#print "nomatch\n";
	$flag = 0;
	last;
      }
    }
    if ($flag) {
      $timetablename = $timecodename;
      last;
    }
  }

  # add to our collection of timecode tables
  push (@timecodetables, [$codename, @uniquepairs]);

  ###################################################################
  # Output the  the timing table
  print "\n";
  if ($flag) { print "\n/* Duplicate timing table, same as $timecodename !\n"}
  print "const uint16_t code_".$codename."Times[] PROGMEM = {\n";
  for ($i = 0; $i < @uniquepairs ; $i++) {
    print "\t".($uniquepairs[$i][0]*10).", ".($uniquepairs[$i][1]*10).",\n";
  }
  print "};\n";

  if ($flag) {
    print "*/\n";
  }

  ###################################################################
  # Calculate how many bits we need to index into the timing table

  if (@uniquepairs <= 4) {
    $compression = 2;
  } elsif (@uniquepairs <= 8) {
    $compression = 3;
  } elsif (@uniquepairs <= 16) {
    $compression = 4;
  } elsif (@uniquepairs <= 32) {
    $compression = 5;
  } elsif (@uniquepairs <= 64) {
    $compression = 6;
  } elsif (@uniquepairs <= 128) {
    $compression = 7;
  } elsif (@uniquepairs <= 256) {
    $compression = 8;
  } else {
    exit("too many unique pairs!");
  }

  if (@pairs > 255) {
    exit("too many pairs!");
  }

  ###################################################################
  # Output the IR code

  print "const struct IrCode code_".$codename."Code PROGMEM = {\n";
  print "\tfreq_to_timerval($freq),\n";
  print "\t".@pairs.",\t\t// # of pairs\n";
  print "\t$compression,\t\t// # of bits per index\n";
  print "\tcode_".$timetablename."Times,  \n\t{\n";
  $bitstring = "";
  for ($i=0; $i<@pairs; $i++) {
    $flag = 0;
    for ($j=0; $j<@uniquepairs; $j++) {
       if (($uniquepairs[$j][0] == $pairs[$i][0]) &&
	  ($uniquepairs[$j][1] == $pairs[$i][1])) {
	 $flag = 1;
	 $printformat = "%0".$compression."B";
	 # we stuff the bits into a really long string of 0's and 1's
	 $bitstring .= sprintf $printformat, $j;
	 break;
       }
     }
  }
  # We'll break up the bit string into bytes, make sure its padded nicely
  while (length($bitstring) % 8) {
    $bitstring .= "0";
  }



  #print "$bitstring (".length($bitstring).")\n";

  # divvy it up into 8's and print out hex codes
  for ($i =0; $i < length($bitstring); $i += 8) {
    $byte = 
      128 * substr($bitstring, $i, 1) +
	64 * substr($bitstring, $i+1, 1) +
	  32 * substr($bitstring, $i+2, 1) +
	    16 * substr($bitstring, $i+3, 1) +
	      8 * substr($bitstring, $i+4, 1) +
		4 * substr($bitstring, $i+5, 1) +
		  2 * substr($bitstring, $i+6, 1) +
		    1 * substr($bitstring, $i+7, 1);
    printf "\t\t0x%02X,\n", $byte;
  }
  print "\t}\n};";

  foreach $bits (@allbitstrings) {
    if ($bits eq $bitstring) {
      print "// Duplicate IR Code???\n";
    }
  }
  push (@allbitstrings, $bitstring);
  
}


sub round {
    my($number) = shift;
    return int($number + .5);
}
