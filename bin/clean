#!/usr/bin/perl
######################################################################
# @(#)clean.pl 1.5.4 (leif@ogre.com) 05/20/96
#
# AUTHOR: Leif Hedstrom <leif@ogre.com>
#
# SYNOPSIS:
#    clean [ -adefmnpruvFT] [-i [yn]] [-s string] [names ...]
#
# HISTORY:
#    21-Jul-1991   Leif    Initial version
#    23-Mar-1992   Leif    Bugs, makeregexp, framemaker, -b option, ver 1.1
#     5-Apr-1992   Leif    Added -a and -n option, ver 1.2
#    26-Sep-1993   Leif    Added -u and cleaned man page, ver 1.3
#    25-Jan-1994   Leif    Fixed NFS mount points traversal, fixed a bug in
#                          answer, added -T, cleaned up, ver 1.4
#     5-Feb-1994   Leif    Added -m for deleted MH files, performance boost,
#                          ignore symbolic links, ver. 1.5
#    22-Oct-1994   Leif    Fixed %-bug, ver. 1.5.1
#    16-Jan-1995   Leif    Works with Perl ver. 5.000 now.
#    22-Jan-1995   Leif    Added `-c' option, and changed `%' matching.
#    20-May-1996   Leif    Added `-e' switch, to remove emacs .save files. I
#                          also moved the other emacs regexp's to $emexp.
#    14-Mar-2012   Leif    Wow, I've used this tool for 21 years... It finally
#                          broke, sort of, with the deprecation of getopts.pl.
#    
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use Getopt::Std;


#
# Global variables.
#
$USAGE   = "clean [ -acdefmnprtvuFT] [-i [yn]] [-s string] [names ...]";
$stdexp  = '[^%]*\%$|^core$';
$emexp   = '^\.saves-[0-9]+|.*\~$|^\#.*\#$';
$texexp  = '.*\.(cp|fn|ky|pg|tp|vr|aux|log|toc|fns)$';
$sysexp  = '^\.nfs.*';
$framexp = '.*\.backup$|.*\.lck';
$mhexp   = '^[,#][0-9]+$';
%anslist = ('^[yY]([eE][sS])?$', 1, '^[Nn]([oO])?$', 0);


#
# Subroutines.
#
sub answer {			# answer(STR prompt, STR default)
   local($regexp);              # STR: Holds a reg. exp.
   local($retval);              # INT: Return value of reg. exp.
   local($value) = -1;		# INT: Calculated return value

   print $_[0];
   chop($_ = <>);
   $_ = $_[1] if /^$/o;		# Default choice
   while(($regexp, $retval) = each %anslist){
      $value = $retval if $_ =~ /$regexp/ ;
   }
   return $value;
}


sub makeregexp {		# makeregexp(STR regexp)
   $_ = "^core$|" if $opt_c;
   $_ = "$stdexp|" if $opt_d || $opt_a;
   $_ .= "$texexp|" if $opt_t || $opt_a;
   $_ .= "$framexp|" if $opt_f || $opt_a;
   $_ .= "$sysexp|" if $opt_u || $opt_a;
   $_ .= "$mhexp|" if $opt_m || $opt_a;
   $_ .= "$emexp|" if $opt_e || $opt_a;
   $_ .= $_[0] if $_[0];
   chop if !$_[0];

   $_ = $stdexp if $_ eq "";
   s/ //g;			# Don't allow space in filenames
   $stdexp = $_;
   print "Searchstring is:  $stdexp\n" if $opt_v;
}


sub handledir {			# handledir(STR directory)
   local(@files);		# ARR[STR]: Files in directory

   if (opendir(thedir, $_[0]) == 0) {
      print STDERR "WARNING:can't access directory $_[0]\n";
      return 0;
   }
   print "Now processing directory \'$_[0]\'\n" if $opt_v;
   @files = readdir(thedir);	# No close, will be done on next open!
   grep(substr($_, 0, 0) = "$_[0]/", @files);
   foreach (@files) {
      next if /\/\.$/ || /\/\.\.$/;
      if (-d) {
	 next if (-l && !$opt_F);
	 next if (!$opt_T && ($org_dev != (stat(_))[0]));
	 &handledir($_) if $opt_r;
      } else {
	 &handlefile($_);
      }
   }
}


sub handlefile {		# handlefile(STR file)
   $file = substr($_[0], rindex($_[0], "/") + 1);
   if ($file =~ /$stdexp/o) {
      print "$_[0]\n" if (!$opt_i && ($opt_p || $opt_v || $opt_n));
      return if $opt_n;
      if ($opt_i) {		# Interactive mode
	 $key = -1;
	 $key = &answer("Delete $_[0] [$opt_i]? ", "$opt_i") while $key < 0;
	 return if ($key != 1);	# Don't remove anything!
      }
      unlink $_[0] || print STDERR "Could not delete $_[0]\n";
   }
}


#
# Here starts the main program.
#
unshift (@ARGV, split(/ /, $ENV{"CLEAN_OPTIONS"})); # Env. options

&getopts('acdefmnprtuvFTi:s:') || die "Usage: $USAGE\n";
$opt_i = 'n' if (defined ($opt_i) && $opt_i eq "");

&makeregexp($opt_s);

if ($#ARGV  < $[) {
   ($org_dev) = stat(".");
   &handledir(".");
} else {
    foreach (@ARGV) {
      if (-f) {
	 ($org_dev) = stat(".");
	 &handlefile($_);
      } elsif (-d) { # Recursive
	 ($org_dev) = stat(_);
	 &handledir($_);
      } else {
	 print STDERR "$_: file not found!\n";
      }
   }
}
