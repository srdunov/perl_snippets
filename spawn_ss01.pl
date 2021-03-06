#!/usr/bin/perl -w
###########################################################################
# Script: spawn template
#
#    Spawn multiple child processes to execute a common task on many targets,
#    presumably remote hosts.  The number of simultaneous children is limited
#    to $max_family_size to avoid total meltdown of the host server.  In
#    addition, each child process is reniced to a lower priority.
#
#    To use this template:
#
#      1. Add 'use' statements and global variable declarations as necessary
#      2. Add preparation code to lamaze()
#      3. Add the code that each child will execute to child_labor()
#      4. Modify the usage() message and comment blocks as appropriate
#
# xx/xx/xx - author
#   description
###########################################################################

use strict;
use Fcntl ':flock';
# < Add modules as necessary >

#--------------------------------------------------
# Declarations
#--------------------------------------------------
my (
  @things, $pid, $child_babble,
  # < Add other declarations here >
);

# Be aware of the impact of increasing this number
my $max_family_size = 10;           # Maximum number of children to spawn
my $offspring       =  0;           # Number of active children
my $debug           =  0;


#--------------------------------------------------
# Gather command line options, things
#--------------------------------------------------
usage() unless @ARGV;
($ARGV[0] eq "-d") and $debug = shift;

if ($ARGV[0] eq "-o") {             # Send status messages to a file
  shift; usage() unless my $status_file = shift; chomp($status_file);

  print "Sending output to $status_file\n" if $debug;
  unlink $status_file;
  open(OUT, ">$status_file") or die "Failed to open $status_file: $!\n";
} else {                            # Send status messages to STDOUT
  print "Sending output to STDOUT\n" if $debug;
  open(OUT, ">&STDOUT");
}

if ($ARGV[0] eq "-f") {             # Targets supplied in a file
  usage() unless $ARGV[1];
  open(LIST, "$ARGV[1]") or die "Error opening $ARGV[1]: $!\n";
  chomp(@things = <LIST>);
  close LIST;
} else {                            # Targets supplied on command line
  usage() unless $ARGV[0];
  @things = @ARGV;
}

#--------------------------------------------------
# Prepare for having kids
#--------------------------------------------------
lamaze();

#--------------------------------------------------
# Main loop
#--------------------------------------------------

for my $thing (@things) {
  $thing =~ s/\s+//g;                       # Strip whitespace
  next if ($thing eq "");                   # Skip if blank line

  # If max children are active, wait on one to die before spawning another.
  reaper() if ($offspring >= $max_family_size);

  print "Spawning child for $thing\n" if $debug;

  if (! defined ($pid = fork() ) ) {     # Can't fork
    die "ERROR: fork failed: $!\n";
  } elsif ($pid) {                          # Parent
    $offspring++;
  } else {                                  # Child.  Lower my priority then
    `/usr/bin/renice -n 10 $$`;             # call subroutine to do the
    $child_babble = child_labor($thing);    # real work.

    flock(OUT,LOCK_EX) or die "Child $$ ($thing): Lock failed: $!\n";
    print OUT "$thing: $child_babble\n";
    flock(OUT,LOCK_UN);

    exit 1;
  }
}

#--------------------------------------------------
# Wait for all remaining children
#--------------------------------------------------
print "Waiting on remaining children...\n" if $debug;
while (reaper()) {}

exit 0;


#--------------------------------------------------
# Subroutine: lamaze()
# Purpose:    Prepare for having children
# Input:      None
# Returns:    Whatever
# Global:     $debug, OUT (file handle for output)
#--------------------------------------------------
sub lamaze
{
  # < put code here >
}

#--------------------------------------------------
# Subroutine: child_labor()
# Purpose:    Contains the actual code to run in each child process.  
# Input:      The "thing" to act on
# Returns:    Text string containing a status message
# Global:     $debug, OUT (file handle for output, if needed)
#--------------------------------------------------
sub child_labor {
  my $device = $_[0];
  my $stat_msg;
  
  print "Child PID $$, handling $device\n" if $debug;
  #
  # < put code here >
  my $out = `ssh ov00ss01 sudo /opt/OV/bin/OpC/opcragt -distrib -templates -actions -monitors -commands -force $device 2>&1`;
  #
  # If you want to output something directly to the status file in addition
  # to whatever's in $stat_msg, print to the OUT filehandle  and enclose the
  # print in calls to flock, for example:
  #
    flock(OUT,LOCK_EX) or die "Child $$ ($device): Lock failed: $!\n";
    print OUT $out;
    flock(OUT,LOCK_UN);
  #

  $stat_msg = "$device checks out OK";     # Sample status message

  return $stat_msg;
} # End of child_labor()

#--------------------------------------------------
# Subroutine: reaper()
# Purpose:    Wait on a child process.  Its return code is displayed if in
#             debug mode.  Decrement the active child counter.
# Input:      None
# Returns:    0 is no child found, 1 otherwise
# Global:     $debug, $offspring, OUT
#--------------------------------------------------
sub reaper
{
  if ((my $child_pid = wait()) > -1) {
    print "Child $child_pid returned " . $? / 256 . "\n" if ($debug);
    $offspring--;
    return 1;
  } else {
    return 0;                             # wait() returned -1, no children
  }
}

#--------------------------------------------------
# Subroutine: usage()
# Purpose:    Print usage message and exit.
# Input:      None
# Returns:    Doesn't
# Global:     $0
#--------------------------------------------------
sub usage
{
  print "
Usage: $0 [-d] [-o status_file] [-f filelist | target1 [target2..]]

  -d  Turns on debug mode which displays child status to STDOUT.
  -o  Send non-debug messages to <status_file> rather than STDOUT.
  -f  File <filelist> contains a list of devices to operate on.
      Alternatively, one or more devices may be specified on the command line.

";
  exit 1;
}

