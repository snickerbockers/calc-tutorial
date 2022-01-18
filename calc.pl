#!/usr/bin/env perl

###################################################################
#
# calc.pl
#
# simple compiler for evaluating polynomial expressions in the correct
# order based on operator precedence
#
# input is taken from either stdin or arguments (using perl's ARGV file handle)
# output is printed to stdout
#
###################################################################

use v5.14;

while (<>) {
    # first add whitespace around all operators then split around whitespace
    s/([\+\-\/\*\(\)])/ \1 /g;
    my @toks = split(/\s+/, $_);

    our @symbols;

    for (@toks) {
        if ($_ eq '+') { push @symbols, [ '+', $_ ]; }
        elsif ($_ eq '-') { push @symbols, [ '-', $_ ]; }
        elsif ($_ eq '/') { push @symbols, [ '/', $_ ]; }
        elsif ($_ eq '*') { push @symbols, [ '*', $_ ]; }
        elsif ($_ eq '(') { push @symbols, [ '(', $_ ]; }
        elsif ($_ eq ')') { push @symbols, [ ')', $_ ]; }
        elsif ($_ =~ /[0-9]+(\.[0-9]+)?/) { push @symbols, [ 'VAL', $_ ]; }
        # TODO: sometimes i get an empty string here if the first
        # input is a single '(' character ??? (eg try just inputting "(4)")
        elsif ($_) { die "unrecognized operator \"$_\""; }
    }

    my $count = scalar(@symbols);

    # language rules:
    # value is defined as a sequence of consecutive digits
    # product is defined as <value> OR <product> * <product> OR
    #     <product> / <product> OR ( SUM )
    # sum is defined as <product> or <sum> + <sum> or <sum> - <sum>
    # expression is defined as a lone sum
    # evaluation ends when there is only one expression remaining

    my @ast;
    while (scalar(@symbols)) {
        my $sym_ref = shift(@symbols);
        my @sym = @$sym_ref;
        my %node = (lhs => undef, rhs => undef, txt => $sym[1]);
        my $tp = $sym[0];
        $node{tp} = $tp;

        push(@ast, \%node);

        for (;;) {
            # now reduce according to the rules described above

            if ($ast[-1]{tp} eq "VAL") {
                # reduce value to product
                $ast[-1]{tp} = 'PROD';
                $ast[-1]{op} = 'LITERAL';
                $ast[-1]{literal} = $ast[-1]{txt};
            } elsif (scalar(@ast) >= 4 &&
                     $ast[-1]{tp} eq ')' &&
                     $ast[-2]{tp} eq 'SUM' &&
                     $ast[-3]{tp} eq '(' &&
                     $ast[-4]{tp} eq 'PROD') {
                # implicit multiplication, eg 3(4)
                pop(@ast);
                my $rhs = pop(@ast);
                pop(@ast);
                my $lhs = pop(@ast);
                my %newnode = ( tp => 'PROD', op => 'MULTIPLY',
                                lhs => $lhs, rhs => $rhs );
                push(@ast, \%newnode);
            } elsif (scalar(@ast) >= 3 &&
                     $ast[-1]{tp} eq ')' &&
                     $ast[-2]{tp} eq 'SUM' &&
                     $ast[-3]{tp} eq '(') {
                pop(@ast);
                my $exp = pop(@ast);
                pop(@ast);
                $exp->{tp} = 'PROD';
                push(@ast, $exp);
            } elsif (scalar(@ast) >= 3 &&
                     $ast[-1]{tp} eq 'PROD' &&
                     $ast[-2]{tp} eq '*' &&
                     $ast[-3]{tp} eq 'PROD') {
                # reduce product * product to product
                my $rhs = pop(@ast);
                pop(@ast);
                my $lhs = pop(@ast);
                my %newnode = ( tp => 'PROD', op => "MULTIPLY",
                                lhs => $lhs, rhs => $rhs );
                push(@ast, \%newnode);
            } elsif (scalar(@ast) >= 3 &&
                     $ast[-1]{tp} eq 'PROD' &&
                     $ast[-2]{tp} eq '/' &&
                     $ast[-3]{tp} eq 'PROD') {
                # reduce product / product to product
                my $rhs = pop(@ast);
                pop(@ast);
                my $lhs = pop(@ast);
                my %newnode = ( tp => 'PROD', op => 'DIVIDE',
                                lhs => $lhs, rhs => $rhs );
                push(@ast, \%newnode);
            } elsif (scalar(@ast) >= 2 &&
                     $ast[-1]{tp} eq 'PROD' &&
                     $ast[-2]{tp} eq '-' &&
                     !(scalar(@ast) >= 3 && $ast[-3]{tp} eq 'SUM')) {
                # reduce -prod to prod
                my $lhs = pop(@ast);
                pop(@ast);
                my %newnode = ( tp => 'PROD', op => 'NEG', lhs => $lhs );
                push(@ast, \%newnode);
            } elsif ($ast[-1]{tp} eq 'PROD' &&
                     (scalar(@symbols) == 0 ||
                      ($symbols[0]->[0] ne '*' &&
                       $symbols[0]->[0] ne '/' &&
                       $symbols[0]->[0] ne '('))) {
                # reduce lone product to sum
                $ast[-1]{tp} = 'SUM';
            } elsif (scalar(@ast) >= 3 &&
                     $ast[-1]{tp} eq 'SUM' &&
                     $ast[-2]{tp} eq '+' &&
                     $ast[-3]{tp} eq 'SUM') {
                # reduct sum + sum to sum
                my $rhs = pop(@ast);
                pop(@ast);
                my $lhs = pop(@ast);
                my %newnode = ( tp => 'SUM', op => 'ADD',
                                lhs => $lhs, rhs => $rhs );
                push(@ast, \%newnode);
            } elsif (scalar(@ast) >= 3 &&
                     $ast[-1]{tp} eq 'SUM' &&
                     $ast[-2]{tp} eq '-' &&
                     $ast[-3]{tp} eq 'SUM') {
                # reduce sum - sum to sum
                my $rhs = pop(@ast);
                pop(@ast);
                my $lhs = pop(@ast);
                my %newnode = ( tp => 'SUM', op => 'SUB',
                                lhs => $lhs, rhs => $rhs );
                push(@ast, \%newnode);
            } elsif (scalar(@ast) == 1 && scalar(@symbols) == 0 &&
                     $ast[0]{tp} eq 'SUM') {
                # reduce lone sum to expression
                $ast[0]{tp} = 'EXPRESSION';
            } else {
                last;
            }
        }
    }

    if (scalar(@ast) == 1 && scalar(@symbols == 0) &&
        $ast[0]->{tp} eq 'EXPRESSION') {
        my @prog;
        my $n_vars = 0;
        my $res_slot = compile_ast($ast[0], \@prog, \$n_vars);
        push(@prog, "RET $res_slot");
        $res_slot++;
        my $res = exec_program(\@prog, $res_slot);
        say $res;
    } else {
        say 'total of ' . scalar(@ast) . ' elements';
        die "error: unable to reduce statement to a single root (final type is $ast[0]->{tp})";
    }
}

################################################################################
#
# compile_ast assembles an abstract syntax tree into a simple assembly-like
# language.  There is no flow-control so this language is not turing-complete.
#
# syntax is:
# OPERATOR <first_operand> <second_operand> <third_operand>
#
# the angle-brackets aren't used in the actual language, only in this
# documentation
#
# "slot" refers to memory locations, and is zero-indexed
# anything >= 0 is a valid slot, anything negative is invalid
#
# dst_slot is always a new slot, this language does not ever modify a memory
# location that has already been written to
#
# whitespace is used as a delimiter
#
# not all operators use all three operands, some only use the first 1 or 2
#
# operators with three operands:
#     MUL <dst_slot> <lhs_slot> <rhs_slot>
#     DIV <dst_slot> <lhs_slot> <rhs_slot>
#     ADD <dst_slot> <lhs_slot> <rhs_slot>
#     SUB <dst_slot> <lhs_slot> <rhs_slot>
#
#     these all do what you'd expect them to.  dst_slot is written to and
#     lhs_slot and rhs_slot are read from.
#
# operators with two operands:
#     MOV <dst_slot>, <literal_value>
#
#     mov sets a destination to a literal value.  this is used to initialize
#     the program.
#
# operators with one operand:
#     RET <src_slot>
#
#     ret ends the program.  the value contained in src_slot is the result of
#     the calculation.
#
################################################################################

sub compile_ast {
    my $root = shift;
    my $prog = shift;
    my $n_vars = shift;

    my $lhs_res = -1;
    my $rhs_res = -1;
    $lhs_res = compile_ast($root->{lhs}, $prog, $n_vars) if ($root->{lhs});
    $rhs_res = compile_ast($root->{rhs}, $prog, $n_vars) if ($root->{rhs});

    if ($root->{op} eq "LITERAL") {
        ($lhs_res >= 0 || $rhs_res >= 0) && die "malformed LITERAL";
        my $slot = ${$n_vars}++;
        my $asm = "MOV $slot $root->{txt}";
        push(@$prog, $asm);
        return $slot;
    } elsif ($root->{op} eq "MULTIPLY") {
        ($lhs_res >= 0 && $rhs_res >= 0) || die "malformed MULTIPLY";
        my $slot = ${$n_vars}++;
        my $asm = "MUL $slot $lhs_res $rhs_res";
        push(@$prog, $asm);
        return $slot;
    } elsif ($root->{op} eq "DIVIDE") {
        ($lhs_res >= 0 && $rhs_res >= 0) || die "malformed DIVIDE";
        my $slot = ${$n_vars}++;
        my $asm = "DIV $slot $lhs_res $rhs_res";
        push(@$prog, $asm);
        return $slot;
    } elsif ($root->{op} eq 'ADD' || $root->{op} eq 'SUB') {
        ($lhs_res >= 0 && $rhs_res >= 0) || die "malformed $root->{op}";
        my $slot = ${$n_vars}++;
        my $asm = "$root->{op} $slot $lhs_res $rhs_res";
        push(@$prog, $asm);
        return $slot;
    } elsif ($root->{op} eq 'NEG') {
        $lhs_res >= 0 || die "malformed NEG";
        my $slot = ${$n_vars}++;
        my $asm = "NEG $slot $lhs_res";
        push(@$prog, $asm);
        return $slot;
    } else { die "unimplemented operator '$root->{op}'"; }
}

# this executes a program created by compile_ast.
# see the above comment for an explanation of the syntax
sub exec_program {
    my ($program, $n_slots) = @_;
    my @mem = (0) x $n_slots;

    for (@$program) {
        my @toks = split(/\s/, $_);
        if ($toks[0] eq 'MOV') {
            $mem[$toks[1]] = $toks[2];
        } elsif ($toks[0] eq 'MUL') {
            my $lhs = $mem[$toks[2]];
            my $rhs = $mem[$toks[3]];
            my $res = $lhs * $rhs;
            $mem[$toks[1]] = $res;
        } elsif ($toks[0] eq 'DIV') {
            my $lhs = $mem[$toks[2]];
            my $rhs = $mem[$toks[3]];
            my $res = $lhs / $rhs;
            $mem[$toks[1]] = $res;
        } elsif ($toks[0] eq 'ADD') {
            my $lhs = $mem[$toks[2]];
            my $rhs = $mem[$toks[3]];
            my $res = $lhs + $rhs;
            $mem[$toks[1]] = $res;
        } elsif ($toks[0] eq 'SUB') {
            my $lhs = $mem[$toks[2]];
            my $rhs = $mem[$toks[3]];
            my $res = $lhs - $rhs;
            $mem[$toks[1]] = $res;
        } elsif ($toks[0] eq 'RET') {
            return $mem[$toks[1]];
        } elsif ($toks[0] eq 'NEG') {
            my $lhs = $mem[$toks[2]];
            $mem[$toks[1]] = -$lhs;
        } else {
            die "unknown assembler token '$toks[0]'";
        }
    }
    die "no return statement!?!?!?";
}
