#!/usr/bin/env perl

###################################################################
#
# test.pl
#
# simple tests for calc.pl
#
###################################################################

use v5.14;

my @testcases = (
    [ '1 + 2', '3'],
    [ '4 * 5', '20'],
    );

my $testno = 0;
for (@testcases) {
    my $testcase_str = "$$_[0] == $$_[1]";
    say "testcase " . $testno++ . ": $testcase_str";
    `echo '$$_[0]' | perl calc.pl` == $$_[1] || die "failed test case $testno: '$testcase_str'";
}

say "all test cases passed.  congratulations!"
