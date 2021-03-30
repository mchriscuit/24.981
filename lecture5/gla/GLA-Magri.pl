#!/usr/bin/perl
$verbose = 0;

# GLA Parameters
$number_of_learning_trials = 2000;
$number_of_testing_trials = 1000;
$initial_markedness_ranking = 100;
$initial_faithfulness_ranking = 0;

# The "margin" added to the denominator to ensure that promotion is less than demotion (can be 0, but inefficient)
# Magri calls this "calibration", and 1 is a simple default
$calibration_threshold = 1;

# Magri does not use decrements, since he does not deal with variation--but we could if we wanted to for some reason
$initial_plasticity = 1;
$plasticity_decrement = 0;

# Praat assumes that if multiple constraints have the same ranking value, they are crucially tied--
# that is, violations sum across the stratum.  This is unlike more standard assumptions about refining
# partial hierarchies to total hierarchies.  If $crucial_ties is set to 1, this script should behave
# like Praat.  If it is set to 0, it will assume a random refinement in case of ties.
$crucial_ties = 0;

# To avoid dividing by zero
$tiny = 1e-20;

$inputfile = $ARGV[0];
while (!$valid_inputfile) {
    if ($inputfile eq "") {
        print "Enter name of input file: ";        
	$inputfile = <STDIN>;	
	chomp($inputfile);	
    }  
    if (-e $inputfile) {
	$valid_inputfile = 1;	
    } else {
        print "Input file $inputfile does not exist.  Please try again.\n\n";        
    }
}

$ranking_history_file = "$inputfile.rankings";
open ( RANKINGSFILE, ">$ranking_history_file" ) or die "Error! Can't write file of ranking values\n";

$current_plasticity = $initial_plasticity;

# The first step is to read in the input data and convert it to mark data
#   pairs.  This part is the same as RCD.pl and LFCD.pl
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

# Store indices of constraints so we can do "reverse look-up" on them
for (my $c = 0; $c < scalar (@constraintnames); $c++) {
	$constraint_index{$constraintnames[$c]} = $c;
}

# Well-formedness check: same number of full and short constraint names?
if (scalar (@constraintnames) != scalar (@shortconstraintnames)) {
    print "Warning! Unequal number of full and short constraint names\n\t(Perhaps there is a formatting error in the file?)\n";
}

# If we're already out of lines in the input file, we're not going to get very far
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
		$attestations[$current_input][$current_candidate] = $winner;
		# Warn if already saw another winner for this output
		if ($total_attested[$current_input] > 0) {
			print "Warning: two winners listed for input $current_input ($inputs[$current_input])\n";	    			
		}
		$total_attested[$current_input] += $winner;

		# if this is an attested form, include it as part of the training data
		for (1 .. $winner) {
			$training_inputs[$number_of_training_inputs] = $current_input;
			$training_outputs[$number_of_training_outputs] = $current_candidate;
			$number_of_training_inputs++;
			$number_of_training_outputs++;
		}
    }
    
    if (scalar (@candidate_violations) > scalar (@constraintnames) ) {
		print "Warning! Line $line_number of file has too many constraint violations.\nPlease check the format of your input file, and try again.\n";        
		exit;
    }
    
    # Record the current candidate and its violations
    $candidates[$current_input][$current_candidate] = $candidate;    
    for (my $v = 0; $v <= $#candidate_violations; $v++) {
        if ($candidate_violations[$v] eq "") {
			$candidate_violations[$v] = 0;	    
		}
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
open (CONSTRAINTS, $constraintsfile) or print "Can't open file $constraintsfile to get information about constraints: $!\n\tI'm going to assume they are all markedness constraints.\n";
while ($line = <CONSTRAINTS>) {
    chomp($line);    
    $constraintsline++;        
    ($name, $type) = split("\t", $line);
    if ($type =~ /^[Mm]/) {
		$type = "M";		
    } elsif ($type =~ /^[Ff]/) {
		$type = "F";        
    } elsif ($type =~ /^\d+$/) {
		# Just digits: take this as an initial ranking value
	    $ranking_value[$constraint_index{$name}] = $type;
		$type = "Prespecified";
	} else {
		print "Warning: Can't understand constraint type '$type' in line $constraintsline of $constraintsfile\n";
		print "Please fix this and try again.\n";	
		exit;	
    }
    
    $constraint_type{$name} = $type;
    $constraint_types[$constraint_index{$name}] = $type;
#    print "$constraint_index{$name} $name: $constraint_types[$constraint_index{$name}]\n";
}

# Initialize rankings to initial values
for (my $c = 0; $c <= $number_of_constraints; $c++) {
	if ($constraint_types[$c] eq "F") {
		$ranking_value[$c] = $initial_faithfulness_ranking;
	} elsif ($constraint_types[$c] ne "Prespecified") {
		$ranking_value[$c] = $initial_markedness_ranking;
	}
}

printf RANKINGSFILE "Time\tDatum\t". join("\t",@constraintnames)."\n";

$previous_datum = undef;
for (my $t = 1; $t <= $number_of_learning_trials; $t++) {
	
	# Save the current ranking values  (could also be put in with learning, to write values only when things actually change)
	printf RANKINGSFILE "$t\t$previous_datum";
	for (my $c = 0; $c <= $number_of_constraints; $c++) {			
			printf RANKINGSFILE "\t$ranking_value[$c]";
	}	
	printf RANKINGSFILE "\n";

	# a trial starts with an (input,output) pair sampled randomly
	# from the training corpus
	$datum = rand($number_of_training_inputs);	
	$training_input = $training_inputs[$datum];
	$training_output = $training_outputs[$datum];
	$empirical_training_distribution[$training_input]++;
	
	if ($verbose) {print "PLD:\t/$inputs[$training_input]/, [$candidates[$training_input][$training_output]]\n";}
	
	# Now we need to determine what we would have said given the current ranking values
	for (my $c = 0; $c <= $number_of_constraints; $c++) {
		$current_total_hierarchy[$c] = $c;
		$actual_ranking_value[$c] = $ranking_value[$c];		
	}
	@current_total_hierarchy = sort { $actual_ranking_value[$b] <=> $actual_ranking_value[$a] } @current_total_hierarchy;
	
	# If two constraints tie in their ranking values, assume a random refinement.  We do this by randomly swapping
	# the positions of adjacent constraints if they have the same ranking value
	# Note that in case of 3-or-more-way ties, this doesn't assign equal probabilities to all possible refinements, 
	# but it should be sufficient for learning crucial rankings.
	unless ($crucial_ties) {
		for (my $c = 1; $c <= $number_of_constraints; $c++) {
			if ($actual_ranking_value[$current_total_hierarchy[$c]] == $actual_ranking_value[$current_total_hierarchy[$c-1]]) {
				if (rand() > .5) {
					# Swap $c and $c-1
					$temp = $current_total_hierarchy[$c-1];
					$current_total_hierarchy[$c-1] = $current_total_hierarchy[$c];
					$current_total_hierarchy[$c] = $temp;
				}
			}
		}
	}
	
	# Now we check what output we would actually produce given this hierarchy
	$my_output = apply_grammar($training_input);
	
	$previous_datum = sprintf("%d /$inputs[$training_input]/, [$candidates[$training_input][$training_output]] ([$candidates[$training_input][$my_output]])", $datum);
	
	if ($my_output == $training_output) {
		if ($verbose) {print "Me:\tI agree! I would also say [$candidates[$training_input][$my_output]]\n\n";}
		# no learning necessary, under an error-driven learning regime		
	} else {
		if ($verbose) {print "Me:\tHmmmmm. I would have said [$candidates[$training_input][$my_output]]\n";	}
		
		$number_of_error_trials++;

		# Magri's update rule: 
		# Demote all undominated loser-preferring constraints by 1
		# Promote winner-preferring constraints by the number of undominated loser-preferring constraints / number of winner-preferrers + 1 (or some n > 0)
		my @winner_preferrers = ();
		my $highest_winner_preferrer = undef;
		my @undominated_loser_preferrers = ();
		
		# This is inefficient, but should do the trick
		# First find the winner-preferrers
		for (my $c = 0; $c <= $number_of_constraints; $c++) {
			if ($violations[$training_input][$training_output][$c] < $violations[$training_input][$my_output][$c]) {
				push(@winner_preferrers, $c);
				if ($ranking_value[$c] > $highest_winner_preferrer) {
					$highest_winner_preferrer = $c;
				}
			}
		}
		
		# Now find the undominated loser-preferrers
		for (my $c = 0; $c <= $number_of_constraints; $c++) {
			if ($violations[$training_input][$training_output][$c] > $violations[$training_input][$my_output][$c]) {
				# This is a loser-preferrer.  Is it undominated by a W?
				if ($ranking_value[$c] >= $ranking_value[$highest_winner_preferrer]) {
					# Yes, this one is undominated.  add to the count of loser_preferrers, and demote it
					push(@undominated_loser_preferrers, $c);
					
					$new_ranking_value = $ranking_value[$c];
					$new_ranking_value -= $current_plasticity;
					# A constraint: don't go below 0
					if ($new_ranking_value < 0) {
						$new_ranking_value = 0;
					}					
					$ranking_value[$c] = $new_ranking_value;
					if ($verbose) {print "\t$ranking_value[$c]\t$new_ranking_value\t$constraintnames[$c]\t$mdp[$c]\n";}
				}
			}
		}
		
		# Now go back and promote all the W's by the number of undominated loser-preferrers
		for (my $c = 0; $c < scalar(@winner_preferrers); $c++) {
			$new_ranking_value = $ranking_value[$winner_preferrers[$c]];
			$new_ranking_value += $current_plasticity * scalar(@undominated_loser_preferrers)/(scalar(@winner_preferrers) + $calibration_threshold);
			$ranking_value[$winner_preferrers[$c]] = $new_ranking_value;
			if ($verbose) {print "\t$ranking_value[$winner_preferrers[$c]]\t$new_ranking_value\t$constraintnames[$winner_preferrers[$c]]\t$mdp[$winner_preferrers[$c]]\n";}
		}
		
	}
	
	if ($verbose) {print "\n"; }
	
	# Decrement plasticity according to schedule
	$current_plasticity -= $plasticity_decrement;
	
}

print "\nEmpirical training frequencies:\n";
for (my $i = 1;  $i <= $number_of_inputs; $i++ ) {
	print "\t$inputs[$i]\t$empirical_training_distribution[$i]\n";
}
print "\n";

print "Ranking values\n";
for (my $c = 0; $c <= $number_of_constraints; $c++) {
	$current_total_hierarchy[$c] = $c;
}
@current_total_hierarchy = sort { $ranking_value[$b] <=> $ranking_value[$a] } @current_total_hierarchy;
for (my $c = 0; $c <= $number_of_constraints; $c++) {
	print "\t$shortconstraintnames[$current_total_hierarchy[$c]]\t$ranking_value[$current_total_hierarchy[$c]]\n";	
}
print "\n";

#  Now test the grammar on what it derives for the words in the input file.  This means test it on
#  what it would produce for each attested word, and possibly any wug words (which are entered by
#  including URs and candidates, but not marking a freq > 1 by any of the candidates)

print "Testing the resulting grammar:\n";
for (my $i = 1; $i <= $number_of_inputs; $i++) {
	my @winning_candidates = undef;
	for (1 .. $number_of_testing_trials) {
		for (my $c = 0; $c <= $number_of_constraints; $c++) {
			$current_total_hierarchy[$c] = $c;
			$actual_ranking_value[$c] = $ranking_value[$c];
		}
		@current_total_hierarchy = sort { $actual_ranking_value[$b] <=> $actual_ranking_value[$a] } @current_total_hierarchy;

		# Now run the grammer on the current input
		$output = apply_grammar($i);
		$winning_candidates[$output]++;
	}
	print "Input $i: $inputs[$i]\n"; 
	for (my $candidate =  1; $candidate <= $number_of_candidates[$i]; $candidate++)  {
		$empirical_percentage = $winning_candidates[$candidate] / $number_of_testing_trials;
		$given_percentage = $attestations[$i][$candidate] / ($total_attested[$i]+$tiny);
#		print "\t$candidates[$i][$candidate]\t$empirical_percentage\t$given_percentage\n";
		printf "\t$candidates[$i][$candidate]\t%.3f\t%.3f\n" , $empirical_percentage, $given_percentage ; 
	}
	
}


close(RANKINGSFILE);


########################################################################################################################
# The following subroutine is *extremely* inefficient, in some kind of obvious ways.
# For now, the inefficiency is not bad enough to impede simulations, so let's keep it legible and corresponding 
# to how humans evaluate tableaus, just to keep it intuitive and not introduce bugs...
sub apply_grammar {
    my $input = @_[0];        
    # The job of a grammar is to determine what output is predicted for this input, 
    #    under this ranking.  At first, all candidates are possible contenders
    for (my $candidate =  1; $candidate <= $number_of_candidates[$input]; $candidate++) {
		$current_contender[$candidate] = 1;
    }
    my $number_of_contenders = $number_of_candidates[$input];    
    
    # Now we winnow candidates, by going down through the ranking, eliminating any candidate
    #   that violates more than the minimum in this column.   (This is the same as performing
    #   mark cancellation and eliminating candidates with remaining marks)
    my $last_cancelled = 0;
    for (my $con = 0; $con <= $number_of_constraints; $con++) {    
        # If constraints tie with one another, we need to allow them to compete with one another.
        # There are two strategies in the OT literature: pick a random strict ranking, or sum across all constraints
        # Praat uses crucial ties (sum across all tied constraints); the $crucial_ties parameter makes the program act
		# like Praat, holding off on mark cancellation until we reach the end of a set of tied constraints.
		# Otherwise, just do mark cancellation for each constraint in turn, assuming a total hierarchy.
		if (!$crucial_ties or (($actual_ranking_value[$current_total_hierarchy[$con]] != $actual_ranking_value[$current_total_hierarchy[$con+1]]) or ($con == $number_of_constraints))) {
			# For each constraint, we determine the minimum number of violations for any candidate for this input
			#   (that is, the number of "cancelled violations")
			$minimum_violations = 1000000000;	
			@candidate_violations = undef;
			for (my $candidate = 1; $candidate <= $number_of_candidates[$input]; $candidate++) {
				# skip candidates that are no longer in the running; consider only live contenders
				if ($current_contender[$candidate]) {
				    for (my $c = $last_cancelled; $c <= $con; $c++) {
						$candidate_violations[$candidate] += $violations[$input][$candidate][$current_total_hierarchy[$c]];
					}
					if ($candidate_violations[$candidate] < $minimum_violations) {
						$minimum_violations = $candidate_violations[$candidate];		    
					}
				}
			}

			# Now go back through the candidates, eliminating those that have more than the minimum
			for (my $candidate = 1; $candidate <= $number_of_candidates[$input]; $candidate++) {
				# check if this is a live contender but over the minimum number of violations
				if ($current_contender[$candidate] and $candidate_violations[$candidate] > $minimum_violations) {
					# no longer a live contender
					$current_contender[$candidate] = 0;
					$number_of_contenders--;
				} 
			}
			
			$last_cancelled = $con;
		} else {
            # A tie; keep going without doing anything
        }

		# No need to consider further constraints, if all except a unique winner have been eliminated
		last if ($number_of_contenders == 1);	
    }
    
    
    @winners = undef;
    $number_of_winners = 0;
    # Now figure out which was the winner (there is probably a more efficient way to do this)
    for (my $candidate = 1; $candidate <= $number_of_candidates[$input]; $candidate++) {
		if ($current_contender[$candidate]) {
			$winners[$number_of_winners] = $candidate;
			$number_of_winners++;
		}
    }
    # We have now eliminated as many contenders as possible; hopefully all except if
    if ($number_of_contenders != 1 and $verbose) {
		print "\nWarning: grammar failed to yield a unique output for this input and ranking.\n\t($number_of_contenders contenders left)\n";	
		print "\t";
		for (my $w = 0; $w < $number_of_winners; $w++) {
			print "[$winners[$w]]\t";
		}
		print "\n";
    }

    $winner = @winners[rand @winners];
#    print "Grammar: $winner\n";
    return $winner;    
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
