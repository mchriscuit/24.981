#!/usr/bin/perl
# RCDPayoff.pl
# Compares efficiency of RCD to random stabs

$trials = 1000;
$number_of_constraints = 10;
$number_of_mdps = 10;
# A parameter for the "denseness" of tableaus
$mark_prob = .5;
$verbose = 0;

@random_iterations;
@rcd_iterations;

# Try sampling some random tableaus, a la Boersma
for (my $t = 1; $t <= $trials; $t++) {
	@mdps = undef;
	# We construct a random data set of MDP's
	for (my $mdp = 1; $mdp <= $number_of_mdps; $mdp++) {
		my $number_of_marks = 0;
		for (my $con = 1; $con <= $number_of_constraints; $con++) {
			# Add marks, with probability determined by $mark_prob parameter
			if (rand() < $mark_prob) {
				# We add a mark, with the condition that each mdp start with a W
				if (rand() < .5) {
					$mdps[$mdp][$con] = "W";
					$number_of_marks++;
				} elsif ($number_of_marks > 0) {
					$mdps[$mdp][$con] = "L";
					$number_of_marks++;
				}
			}
		}
		# If we got through the whole row and added no marks, let's scratch this row
		if ($number_of_marks == 0) {
			$mdp--;
		}
		
	} # Done constructing random data set
	
	if ($verbose) {
		print "Trial $t:\n";
		for (my $con = 1; $con <= $number_of_constraints; $con++) {
			print "\t$con";
		}
		print "\n";
		for (my $mdp = 1; $mdp <= $number_of_mdps; $mdp++) {
			print "MDP $mdp";
			for (my $con = 1; $con <= $number_of_constraints; $con++) {
				print "\t$mdps[$mdp][$con]";
			}
			print "\n";
		}
		print "\n";
	}
	
	
	# Now find a ranking by random search
	# Start with a ranking in the order given (we'll randomize it in a moment)
	for (my $con = 1; $con <= $number_of_constraints; $con++) {
		$stratum[$con] = $con;
	}

	# We just keep trying random rankings until we find one that works.
	my $success = 0;
	my $iterations = 0;
	while ($success == 0) {
		$iterations++;
		# Generate a random ranking
		fisher_yates_shuffle(\@stratum);

		# Now see if all the outputs are correct
		$number_explained = 0;
		# Go through all the mark-data pairs
		for (my $mdp = 1; $mdp <= $number_of_mdps; $mdp++) {
			# For each pair, construct a row		
			$mdp_row = undef;				
			CHECKMDP:
		    for (my $con = 1; $con <= $number_of_constraints; $con++) {
			    $mdp_row .= $mdps[$mdp][$stratum[$con]];
			    # Check if we know yet whether this row is explained or unexplained
				if ($mdp_row =~ /^W/) {
				    $number_explained++;
					last CHECKMDP;
				} elsif ($mdp_row =~ /^L/) {
					# not explained
					last CHECKMDP;
				}
				# Otherwise, not enough info yet; keep checking lower-ranked constraints
			}				
	    }

		# Now check if we've explained everything!
		if ($number_explained == $number_of_mdps) {
			$success = 1;
		}
	}
	if ($verbose) {
		if ($success) {
		    print "Constraint ranking (after $iterations iterations): " . join(" ", @stratum) . "\n"; 
		} else {
			# The following is currently pointless, since we assume there *is* a ranking, and there's no condition that would stop 
			# the search prior to a successful ranking
		    print "It appears that there is no ranking of the given\nconstraints that will generate the observed data.\n";	
		}
	}
	
	$random_iterations[$t] = $iterations;
	
	# Now see how many RCD iterations this language takes
	for (my $con = 1; $con <= $number_of_constraints; $con++) {
	    $stratum[$con] = 0;        
	}
	$current_stratum = 0;
	$number_explained = 0;
	@explained = undef;
	$success = 0;
	$rcd_iterations[$t] = apply_rcd();
	
}


print "No\tRandom\tRCD\t$number_of_constraints constraints, $number_of_mdps mdps, mark density = $mark_prob\n";
for (my $t = 1; $t <= $trials; $t++) {
	print "$t\t$random_iterations[$t]\t$rcd_iterations[$t]\n";
	
}

# Shuffle an array, from the perl cookbook
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub apply_rcd {
    # The strategy is to place in the current stratum all constraints that prefer no losers
    # If a constraint ever prefers a loser for an active mdp, it can't be in the current stratum
    # So, go through and demote all constraints that ever prefer a loser
	$iterations = shift;
	$iterations++;
    $current_stratum++;
    $previous_number_explained = $number_explained;    

    if ($verbose) {
	    print "\n************ Constructing stratum $current_stratum ************\n";        
		print " (iteration $iterations, $number_explained explained)\n";
	}
    CHECK_CONSTRAINT:
    for (my $con = 1; $con <= $number_of_constraints; $con++) {
        # If a constraint has already been placed in a higher stratum, leave it alone
        next if ($stratum[$con] < ($current_stratum-1));        
	
		# scan the mdps, seeing if this constraint is ever an L
		for (my $p = 1; $p <= $number_of_mdps; $p++) {
		    next if $explained[$p];	    	    
		    if ($mdps[$p][$con] eq "L") {
				# This constraint favors a loser; demote it.
				$stratum[$con] = $current_stratum;
				# Don't need to keep looking; favoring 1 loser is enough
				next CHECK_CONSTRAINT;
		    }
		}
    }
    
    # Now we need to check how far this got us; in particular, we need to see which mdps
    #  are now explained, and which still need work
#    print "\nNow checking which mdps are explained\n";        
    for (my $mdp = 1; $mdp <= $number_of_mdps; $mdp++) {
		# An mdp is unexplained if it has an L that lacks a higher-ranked W
		# This can be computed by "linearizing" the MDP, and checking to make sure there
		#  are no L's without higher ranked W's
		#  
		next if ($explained[$mdp]);
		$mdp_row = undef;		
		for (my $s = 0; $s <= $current_stratum; $s++) {
		    for (my $con = 1; $con <= $number_of_constraints; $con++) {
				if ($stratum[$con] eq $s) {
				    $mdp_row .= $mdps[$mdp][$con];
				}
		    }
		    # We'll place a marker between strata, to check for dominance
		    $mdp_row .= ">";	    
		}
		# print "MDP $mdp: $mdp_row\n";	
	
		# Now if the mdp row contains an L without an W...>, it's still not explained
		if ($mdp_row =~ /^([^W]*>)*W*L/) {
		    if ($verbose) {
			  print "\tMDP $mdp ($inputs[$mdp_inputs[$mdp]] -> $mdp_winners[$mdp], not $mdp_losers[$mdp]) still unexplained\n";
			}
		  # don't modify value of $explained[$mdp] yet
		} else {
		    $explained[$mdp] = 1;
		    $number_explained++;	    
		}
    }
    
    # If there are still unexplained mdp's, keep going
    if ($number_explained == $previous_number_explained) { # We're getting nowhere
		return 0;	      
    } elsif ($number_explained < $number_of_mdps) {
	    if ($verbose) {
			print "\n". ($number_of_mdps - $number_explained) . " MDP(s) still left to explain.\n";		
		}
		# ******* Here's the recursive step ***********
		$success = apply_rcd($iterations);	
    } else {
	    if ($verbose) {	
			print "\nAll MDP's successfully explained.\n";	
		}
	return $iterations;        
    }
}
