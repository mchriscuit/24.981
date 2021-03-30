# LFCD.pl - Hayes (2004) Low Faithfulness Constraint Demotion strategy

print "Enter name of input file to rank: ";
$inputfile = <STDIN>;
chomp($inputfile);

open (INPUT, $inputfile) or die "Warning! Can't open input file: $!\n";
$line_number = 0;
print "\n";

# First read the constraint names
$line = <INPUT>;
$line_number++;
chomp($line);
(undef, undef, undef, @constraintnames) = split(/\t/, $line);


# And then read the "short" constraint names
$line = <INPUT>;
$line_number++;
chomp($line);
(undef, undef, undef, @shortconstraintnames) = split(/\t/, $line);

if (scalar (@constraintnames) != scalar (@shortconstraintnames)) {
    print "Warning! Unequal number of full and short constraint names\n\t(Perhaps there is a formatting error in the file?)\n";
}
if ($line eq undef) {
    print "Too few lines in file to be a valid input file ($line_number).  Goodbye.\n";        
}
# Let's store the number of constraints, for later reference
$number_of_constraints = $#constraintnames;
# Now read in the constraint violations
while ($line = <INPUT>) {
    $line_number++;
    chomp($line);
    ($UR, $candidate, $winner, @candidate_violations) = split( /\t/, $line);
    if ($UR ne "") {
	$number_of_inputs++;
	$current_input++;  # redundant but easier to read
	# Remember this input
	$inputs[$current_input] = $UR;    
	$current_candidate = 1;
	$number_of_candidates[$current_input]++;		
    } else {
        $current_candidate++;
	$number_of_candidates[$current_input]++;		
    }
    if ($winner > 0) {
        if ($winners[$current_input] eq undef) {
	    $winners[$current_input] = $current_candidate;	    	    
	} else {
	    print "Warning: two winners listed for input $current_input ($inputs[$current_input])\n";	    
	    exit;	    	    
	}
    }
    
    if (scalar (@candidate_violations) > scalar (@constraintnames) ) {
        print "Warning! Line $line_number of file has too many constraint violations.\nPlease check the format of your input file, and try again.\n";        
	exit;
    }
    
    # Record the current candidate and its violations
    $candidates[$current_input][$current_candidate] = $candidate;    
    for (my $v = 0; $v <= $#candidate_violations; $v++) {
	$violations[$current_input][$current_candidate][$v] = $candidate_violations[$v];
    }    
}

# Now we are done reading in the candidates and violations
# As a check, let's print them out.
# print_tableau();

# Also, in order to impose an initial ranking of M >> F, we need to find out
# which constraints are M, and which are F
# We'll assume that this information is stored in a .constraints file, with the same name
$constraintsfile = $inputfile;
# First, strip of the "extension" (.txt, etc.)
$constraintsfile =~ s/\.[^\.]*$//;
$constraintsfile .= ".constraints";
open (CONSTRAINTS, $constraintsfile) or die "Can't open file $constraintsfile to get information about constraints: $!\n";
while ($line = <CONSTRAINTS>) {
    chomp($line);    
    $constraintsline++;        
    ($name, $type) = split("\t", $line);
    if ($type =~ /^[Mm]/) {
	$type = "M";		
    } elsif ($type =~ /^[Ff]/) {
        $type = "F";        
    } else {
        print "Warning: Can't understand constraint type '$type' in line $constraintsline of $constraintsfile\n";
	print "Please fix this and try again.\n";	
	exit;	
    }
    
    $constraint_type{$name} = $type;
}

# In order to favor specificity, we need to know which constraints are more specific versions of which 
#  other constraints.   We'll try to read this from a .specificity file, which has the same format as the
#  OTSoft "a priori rankings" files.
$specificity_file = $inputfile;
$specificity_file =~ s/\.[^\.]*$//;
$specificity_file .= ".specificity";
open (SPECFILE, $specificity_file) or print "Warning: can't find file $specificity_file to provide specificity relations.\nI will proceed with no specificity relations.";
# The first line is the header; read it so we know which column is which (ideally, same order as in tableaus)
# (If we can't read it, then there is no file, so we'll just skip this block of code
if ($line = <SPECFILE>) {
    chomp($line);
    (undef, @comparison_constraints) = split("\t", $line);
    if (scalar (@comparison_constraints) != $number_of_constraints + 1) {
	print "WARNING: number of constraints in $specificity_file doesn't match the number in the input file\n";	
    }

    while ($line = <SPECFILE>) {
	chomp($line);    
	($constraint, @relations) = split("\t", $line);    
	for (my $c = 0; $c <= $#relations; $c++) {
	    if ($relations[$c] ne "") {
		print "$constraint is more specific than $comparison_constraints[$c]\n";		
		$more_specific{$constraint}{$comparison_constraints[$c]} = 1;		
	    }
        }
    }
}


# And, let's convert the original data into comparative tableaus (Prince 2000 et seq)
# In order to do this, we convert the rows into mark-data pairs (mdp's)
# Each input form has a MDP for each loser
for (my $i = 1; $i <= $number_of_inputs; $i++) {
    $winner = $winners[$i];    
#    print "Constructing mdp's for input $i: /$inputs[$i], winning output [$candidates[$i][$winner]]\n";        
     for (my $cand = 1; $cand <= $number_of_candidates[$i]; $cand++ ) {
	next if ($cand == $winner);
	$number_of_mdps++;
#	print "\tMDP: $candidates[$i][$winners[$i]] ~ $candidates[$i][$cand]\n";
	$mdp_winners[$number_of_mdps] = $candidates[$i][$winners[$i]];	
	$mdp_losers[$number_of_mdps] = $candidates[$i][$cand];
	$mdp_inputs[$number_of_mdps] = $i;		
	for (my $con = 0; $con <= $number_of_constraints; $con++) {
	    # For each constraint, check whether it favors the winner, the loser, or neither
	    if ($violations[$i][$winner][$con] > $violations[$i][$cand][$con]) {
		# This one favors the winner
		$mdps[$number_of_mdps][$con] = "L";		
	    } elsif ($violations[$i][$winner][$con] < $violations[$i][$cand][$con]) {
		$mdps[$number_of_mdps][$con] = "W";
	    } # if neither, then blank (no value)
#	    print "\t\t$shortconstraintnames[$con]:\t$mdps[$number_of_mdps][$con]\n";	    
	}
    }
}

# Now start ranking.
# At first, we start with all constraints unranked, in the same stratum,
# and all mdp's are unexplained.
# Strata are numbered from 0 (highest) to, in theory, C = number of constraints (lowest)
for (my $con = 0; $con <= $number_of_constraints; $con++) {
	$stratum[$con] = 0;        
}
$current_stratum = 0;
$number_explained = 0;

# Now, it's time to rank.  Since the procedure is recursive, it makes sense
#    to put it into a subroutine
$successful_ranking = apply_lfcd();
if ($successful_ranking) {
    print "\n************************************************\n";
    print "       Constraint ranking";
    for (my $s = 0; $s <= $current_stratum; $s++) {
	print "\nStratum ". ($s + 1) ."\n";    
	for (my $con = 0; $con <= $number_of_constraints; $con++) {
	    if ($stratum[$con] == $s) {
		print "\t$constraintnames[$con]\n";	    
	    }
	}    
    }
    print "************************************************\n";
} else {
    print "****************************************************\nIt appears that there is no ranking of the given\nconstraints that will generate the observed data.\n****************************************************\n";	
}

sub apply_lfcd {
    # The strategy is to place in the current stratum all constraints that prefer no losers
    # If a constraint ever prefers a loser for an active mdp, it can't be in the current stratum
    # So, go through and demote all constraints that ever prefer a loser
    $current_stratum++;
    $previous_number_explained = $number_explained;    
    
    print "\n************ Constructing stratum $current_stratum ************\n";        
    CHECK_LOSERS:
    for (my $con = 0; $con <= $number_of_constraints; $con++) {
        # Obviously if a constraint has already been placed in a higher stratum, leave it alone
        next if ($stratum[$con] < ($current_stratum-1));        
	
	# scan the mdps, seeing if this constraint is ever an L
	for (my $p = 1; $p <= $number_of_mdps; $p++) {
	    next if $explained[$p];	    	    
	    if ($mdps[$p][$con] eq "L") {
		# This constraint favors a loser; demote it.
		print "$shortconstraintnames[$con] incorrectly favors $mdp_losers[$p] over $mdp_winners[$p] for input /$inputs[$mdp_inputs[$p]]/.\n\t***Demoting $shortconstraintnames[$con] to stratum ".($current_stratum+1)."\n";
		$stratum[$con] = $current_stratum;
		# Don't need to keep looking; favoring 1 loser is enough
		next CHECK_LOSERS;
	    }
	}
    }
    
    @eligible = undef;
    print "\nConstraints eligible for stratum $current_stratum.\n";    
    for (my $con = 0; $con <= $number_of_constraints; $con++) {
	if ($stratum[$con] == ($current_stratum - 1)) {
	    print "\t$constraintnames[$con]\n";
	    push (@eligible, $con);	    
	}
    } 
    # The push operation leaves a single undefined element in 0; get rid of it
    #  by splicing out the element 0 (just 1 element)
    splice @eligible, 0, 1;    
    
    for (my $e = 0; $e <= $#eligible; $e++) {
	$still_eligible[$e] = 1;	
    }
    
    # Now we need to check whether there are any markedness constraints in the current stratum,
    #   or whether it is all faithfulness
    $markedness_involved = 0; 
    CHECKFAITH:
    for (my $con = 0; $con < scalar(@eligible); $con++) {
	# The stratum we just constructed is ($current_stratum - 1)
	if ($constraint_type{$constraintnames[$eligible[$con]]} eq "M") {
	    $markedness_involved = 1;
	    last CHECKFAITH;		
	}
    }
    
    # Our next step depends on whether there are any markedness constraints or not.
    if ($markedness_involved) {
	# If there are markedness constraints, then favor them by demoting all the faithfulness constraints
	print "***FAVORING MARKEDNESS***\n";	
	FAVOR_MARKEDNESS:
	for (my $con = 0; $con <= $#eligible; $con++) {
	    if ($constraint_type{$constraintnames[$eligible[$con]]} eq "F") {
		# Demote all F constraints to the new lowest stratum
		print "\tDemoting constraint $con ($constraintnames[$eligible[$con]])\n";		    
		$stratum[$eligible[$con]] = $current_stratum;
		$still_eligible[$con] = 0;				
	    }
	}
    } else {
        # Things are more complex if we have only faithfulness constraints.
        print "\nOnly faithfulness constraints are currently eligible\n\t(checking activeness, specificity, and autonomy)\n\n";        
	
        # In this case, we need to (1) favor activeness, (2) favor specificity, and (3) favor autonomy
	# To favor activeness, we need to see whether any of the constraints ever fail to favor a winner
	@active = undef;	
	@inactive = undef;
	$number_of_active = 0;	
	$number_of_inactive = 0;	
	
	FIND_ACTIVE:	
	for (my $con = 0; $con <= $#eligible; $con++) {
	    # skip constraints that have already been excluded
	    next unless ($still_eligible[$con]);
	    
	    # scan the mdps, seeing if this constraint is ever a W
	    $active = 0;	    
	    for (my $p = 1; $p <= $number_of_mdps; $p++) {
		# skip mdp's that are already explained
		next if $explained[$p];
		# now check is the constraint favors the winner in this mdp
		if ($mdps[$p][$eligible[$con]] eq "W") {
		    # if so, we can stop looking (it's active)
		    $active = 1;
		    last;		    
		}
	    }
	    # If we went through all the mdp's and there were no w's, the constraint is inactive
	    if ($active) {
		$number_of_active++;
		$active[$con] = 1;
	    } else {
		$number_of_inactive++;		
		$inactive[$con] = 1;		
	    }
	}
	
	# Now our course of action depends on how many active and inactive constraints there were.
	# If there were some active constraints and some inactive ones, demote the inactive ones
	# If there are no active constraints, just let them all be ranked
	if ($number_of_active == 0) {
	    # Don't demote anything
	    print "The current stratum ($current_stratum) has only inactive constraints; ranking them so we can terminate\n";
	} # Otherwise, there must be active constraints.  If there were also some inactive constraints, 
	  # demote them
	elsif ($number_of_inactive > 0) {
	    print "***FAVORING ACTIVENESS***\n";	    
	    for (my $c = 0; $c <= $#eligible; $c++) {
		if ($inactive[$c]) {
		    print "\tDemoting $constraintnames[$eligible[$c]] because it is inactive.\n";
		    $stratum[$eligible[$c]] = $current_stratum;		
		    # These constraints are not eligible to stay put any more
		    $still_eligible[$c] = 0;		    
		}
	    }
	} else {
	    print "All constraints are active; control passes to FAVOR SPECIFICITY\n";	    
	}
	
	# Now we apply "Favor Specificity"
	# The strategy here is to demote any F constraint that is less specific that another active F constraint.
	# The constraints we're considering are those in @active
	# For clerical reasons, let's keep track of whether or not we actually found a relevant pair.
	$already_favored_specificity = 0;
	for (my $c1 = 0; $c1<= $#eligible; $c1++) {
	    for (my $c2 = 0; $c2 <= $#eligible; $c2++) {
		# Skip this pair is they are the same, or one has already been demoted.
		next if ($c1 == $c2 or !$still_eligible[$c1] or !$still_eligible[$c2]);
		
		if ($more_specific{$constraintnames[$eligible[$c1]]}{$constraintnames[$eligible[$c2]]}) {
		    unless ($already_favored_specificity) {
			print "***FAVORING SPECIFICITY***\n";
			$already_favored_specificity = 1;
		    }
		    print "\tDemoting $constraintnames[$eligible[$c2]], since it is less specific than $constraintnames[$eligible[$c1]]\n";			
		    $stratum[$eligible[$c2]] = $current_stratum;
		    $still_eligible[$c2] = 0;
		    # We need to keep track specifically of constraints demoted for specificity, 
		    # in case we need to calculate autonomy
		    $demoted_for_specificity[$eligible[$c2]] = 1;		    
		    $number_demoted_for_specificity++;			
		}
	    }
	}
	
	# Now we have attempted to demote as many faithfulness constraints as possible on grounds of specificity.
	# There may still be more than one active F constraint that can't be demoted on specificity grounds.
	# If so, we need to check for autonomy.
	if (($number_of_active - $number_demoted_for_specificity) > 1) {
	    print "***Still more than one active constraint in the running; now checking autonomy\n";				
	    print "\t(".($number_of_active - $number_demoted_for_specificity)." left)\n";
	    # Autonomy is defined as: prefering a winner that no other unranked constraints prefer.
	    # More generally, we want the constraint that requires as few "helpers" as possible
	    # Our goal is to calculate the *minimum number of helpers* for each constraint
	    # (see hayes' description for details)
	    # The maximum possible number of helpers is the total number of constraints;
	    # start by assuming that, and work downwards
	    @minimum_helpers = undef;
	    $overall_minimum = $number_of_constraints;	    
	    
	    # We can check this by looping through whichever constraints are still eligible, 
	    #   checking to see which winners they prefer
	    for (my $c1 = 0; $c1<=$#eligible; $c1++) {
	        next unless ($still_eligible[$c1]);	        
		$minimum_helpers[$c1] = $number_of_constraints;		
#		print "\tChecking helpers for $eligible[$c1] $constraintnames[$eligible[$c1]] (min = $minimum_helpers[$c1])\n";	        
		for (my $p = 1; $p <= $number_of_mdps; $p++) {
		    next if $explained[$p];
		    # Check if this constraint prefers the winner
		    if ($mdps[$p][$eligible[$c1]] eq "W") {
			$helpers = 0;			
			# Now see how many other constraints prefer the winner too
			# We consider only constraints that are not ranked yet, and
			# *which have not been demoted for specificity reasons*
			for (my $c2 = 0; $c2 <= $number_of_constraints; $c2++) {
			    # If this constraint is already ranked, or, ignore it
			    next if ($stratum[$c1] < ($current_stratum-1));
			    # If this constraint was demoted for specificity reasons, ignore it
			    next if ($demoted_for_specificity[$c2]);			    
#			    print "\t\tComparing for $c2 $constraintnames[$c2]\n";	        
			    
			    # If this constraint is the same constraint as c1, ignore it as well
			    next if ($eligible[$c1] == $c2);			    
			    if ($mdps[$p][$c2] eq "W") {
				# c2 is a helper
				$helpers++;				
				print "\t$constraintnames[$eligible[$c1]] is helped by $constraintnames[$c2] in the following mdp:\n";				
				print "\t\tMDP $mdp ($inputs[$mdp_inputs[$p]] -> $mdp_winners[$p], not $mdp_losers[$p])\n";	  	  
#				print "\t$helpers helpers\n";				
			    }
			}
			if ($helpers ==0) {
			    print "\t$constraintnames[$eligible[$c1]] has no helpers for the following mdp:\n";				
			    print "\t\tMDP $mdp ($inputs[$mdp_inputs[$p]] -> $mdp_winners[$p], not $mdp_losers[$p])\n";	  	  
			}
		    } else {
			# if it doesn't favor the winner here, it's irrelevant for autonomy
			next;			
		    }
		    
		    # We've now calculated how many helpers this constraint has for this mdp
		    # If this is less than the current minimum, then install it
		    if ($helpers < $minimum_helpers[$c1]) {
			$minimum_helpers[$c1] = $helpers;
#			print "Setting min helpers for constraint $eligible[$c1] to $helpers\n";			
		    }
		}
		
		# Now we know the minimum number of helpers that constraint $eligible[$c1] has.
		# If this is less than the current overall_minimum, install it as the new minimum
		if ($minimum_helpers[$c1] < $overall_minimum) {
		    $overall_minimum = $minimum_helpers[$c1];		    
		}
#		print "Minimum helpers for this constraint: $minimum_helpers[$c1]\n";		
	    }
	    
	    print "The minimum number of helpers needed by any eligible constraint is: $overall_minimum\n";	    
	}
	# Finally, go through and demote any constraint that has more than the minimum number of helpers
	for (my $c = 0; $c <= $#eligible; $c++) {
	    next unless ($still_eligible[$c]);	    
	    if ($minimum_helpers[$c] > $overall_minimum) {
		print "\t$constraintnames[$eligible[$c]] has more helpers (min = $minimum_helpers[$c])\n";		
		$stratum[$eligible[$c]] = $current_stratum;
		$still_eligible[$c] = 0;		    
	    } else {
	        print "\t$constraintnames[$eligible[$c]] has min number of helpers ($minimum_helpers[$c])\n";		
	    }
	}
    }

    print "\nAfter favoring markedness, activeness, specificity, and autonomy:\n";    
    for (my $c = 0; $c <= $#eligible; $c++) {
	if ($still_eligible[$c]) {
	    print "\t$constraintnames[$eligible[$c]]\n";	    
	}
    }

    
    # Now we need to check how far this got us; in particular, we need to see which mdps
    #  are now explained, and which still need work
    print "\nMDPs that are still unexplained:\n";        
    for (my $mdp = 1; $mdp <= $number_of_mdps; $mdp++) {
	# An mdp is unexplained if it has an L that lacks a higher-ranked W
	# This can be computed by "linearizing" the MDP, and checking to make sure there
	#  are no L's without higher ranked W's
	#  
	next if ($explained[$mdp]);
	$mdp_row = undef;		
	for (my $s = 0; $s <= $current_stratum; $s++) {
	    for (my $con = 0; $con <= $number_of_constraints; $con++) {
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
	  print "\tMDP $mdp ($inputs[$mdp_inputs[$mdp]] -> $mdp_winners[$mdp], not $mdp_losers[$mdp])\n";	  	  
	  # don't modify value of $explained[$mdp] yet
	} else {
	    $explained[$mdp] = 1;
	    $number_explained++;	    
	}
    }
    
    # If there are still unexplained mdp's, keep going
    if ($number_explained == $previous_number_explained and $number_explained < $number_of_mdps) {
	# We didn't explain anything; there's a danger that we're getting nowhere
	# check size of last stratum to see if any constraints were rankable
	print "\nThis stratum didn't explain any new MDPs.\n";	
	$last_stratum_size = 0;	
	for (my $c = 0; $c <= $number_of_constraints; $c++) {
	    if ($stratum[$c] == $current_stratum - 1) {
		$last_stratum_size++;		
	    }
	}
	if ($last_stratum_size == 0) {
	    # We're getting nowhere; better bail
	    return 0;	      
	} else {
	    print "However, there were $last_stratum_size rankable constraints, so let's keep trying\n";	    
	    apply_lfcd();	    
	}
	
    } elsif ($number_explained < $number_of_mdps) {
	print "\n". ($number_of_mdps - $number_explained) . " MDP(s) still left to explain.\n";		
	apply_lfcd();	
    } else {
	print "\tAll MDP's successfully explained.\n";	
	# If all the constraints in the next stratum are of the same type (mark/faith), then
	# we can stop.  if they are mixed, however, then the priorities for ranking
	# faith might have a say about them.
	# We'll start by paradoxically assuming they're all true
	$all_faith = 1;	    
	$all_mark = 1;	    
	for (my $c = 0; $c <= $number_of_constraints; $c++) {
	    if ($stratum[$c] == $current_stratum) {
		if ($constraint_type{$constraintnames[$c]} eq "F") {
		    $all_mark = 0;		    
		} else {
		    $all_faith = 0;		    
		}
	    }
	}
	
	if ($all_faith or $all_mark) {
	    # We're really done
	    print "The remaining constraints are homogenous\n";	        
	    if ($all_faith) {
		print "\t(All faithfulness constraints)\n";		    
	    } else {
		print "\t(All markedness constraints)\n";		    
	    }
	    return 1;		
	} else {
	    # We have a mix; we must keep going
	    print "The remaining constraints are mixed (some markedness, some faithfulness)\n";	    
	    print "\tContinuing to iterate...\n";	    
	    apply_lfcd();	        
	}
    }
}


sub print_tableau {
    print "No.\tInput\tCand No.\tWinner\tCandidate";
    for (my $con = 0; $con <= $number_of_constraints; $con++) {
	print "\t$shortconstraintnames[$con]"
    }
    print "\n";

    for (my $i = 1; $i <= $number_of_inputs; $i++) {
	for (my $cand = 1; $cand <= $number_of_candidates[$i]; $cand++) {
	    print "$i\t$inputs[$i]\t$cand\t";	
	    if ($winners[$current_input] == $cand) {
		print "->";	    	    
	    }
	    
	    print "\t$candidates[$i][$cand]";	
	    for (my $con = 0; $con <= $number_of_constraints; $con++) {
		    print "\t$violations[$i][$cand][$con]";				
	    }
	    print "\n";	    
	}
    }
    print "\n";    
}
