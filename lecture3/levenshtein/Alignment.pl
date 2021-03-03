#!/usr/bin/perl
# A perl script to calculate the string edit (levenshtein) distance between
#    two strings, taking the phonetic similarity of the segments into consideration.
# To invoke it, simply run alignment.pl
# There is an optional argument, which is the weighted cost of performing an
#    insertion or a deletion.  This weight is typically between 0 and 1; the
#    smaller the indel value, the more likely the program is to consider mismatches
#    as insertions and deletions, rather than forcing dissimilar segments to be
#    aligned with one another.  The default is set to .6, which seems to yield
#    intuitive alignments in a large number of cases. 
#
# This program requires similarity tables, as written by SimilarityCalculator.pl
#    The heart of the program is the distance(string1,string2) subroutine;
#
# It would be useful to extend this script by allowing it to read in a file
#     of a bunch of words, and letting it automatically calculate their relative
#     similarity.   (Or, let the user enter a word and have it return the k most
#     similar words.  Ideally, it would also be a Perl module, rather than a 
#     stand-alone script. 
#
# For details of string edit distance, see Kruskal (1988)
#     Kruskal (1983) An overview of sequence comparison.  In Sankoff, D. and 
#           J. Kruskal (Eds.) (1999). Time warps, string edits, and 
#           macromolecules. Stanford, CA: CSLI Publications.
#
# For details of phonetic similarity, see Frisch, Broe, and Pierrehumbert (1997):
#     Frisch, Stefan, Michael Broe, and Janet Pierrehumbert (1997) Similarity 
#           and Phonotactics in Arabic.  Available for download from 
#           http://roa.rutgers.edu/view.php3?roa=223
#
# Written by Adam Albright, albright@ucsc.edu

use bytes;
if (@ARGV > 0) {
    $indel_cost = $ARGV[0];
} else {
     $indel_cost = .6;
 }
#print "Using indel of $indel_cost\n";

$default_sims = "English.stb";

print "Enter similarity file (<RETURN> for default, $default_sims): ";
$simfile = <STDIN>;
chomp($simfile);
if ($simfile eq "") {
    $simfile = $default_sims;    
}
my %similarity_table;
my %feats_for_classes;
my $all_natural_classes;

$valid_sims = read_similarities();
if ($valid_sims) {
    COMPARESTRINGS:
    while (1) {
	# Now we'll ask for pairs of strings;    
	print "\nEnter string 1 (<RETURN> to exit): ";
	my $string1 = <STDIN>;
	chomp($string1);
	if ($string1 eq "") {
	    last COMPARESTRINGS;	
	} else {
	    print "Enter string 2: ";
	    my $string2 = <STDIN>;

	    chomp($string2);

	    $new_rule = distance($string1, $string2);
	  #  print "\n\nThe new environment learned here was: $new_rule\n";	    
	}	
    }

} else {
    print "Sorry, invalid similarity file.\n";        
}

sub distance {
  my $s1=shift(@_);
  my $s2=shift(@_);

  # Since this is meant for use by linguists, the input may contain either bracketted items to indicate
  # a natural class, or else parenthesized items to indicate optionality.
  # The bracketted items should really be checked to make sure they are a genuine natural class, or else
  # the real smallest natural class containing the items should be substituted  (in fact, this would be
  # not just a foolproofing, but a useful feature)  but I'll leave this for later.
  # Parentheses are used differently by linguists and in regular expressions.  In regular expressions, 
  # optional items are marked by a question mark, and parentheses simply mark grouping.
  # Therefore, if there are parenthesized items, let's do two things to them: first, let's break up
  # multiple things that share parentheses so each has its own parentheses:  (ab) => (a)(b)  (*** doesn't
  # mean exactly the same thing, but this system can't make use of things like an option string (ab) so
  # this is the best we can do...)  Note that we *don't* want ([ab]) => ([)(a)(b)(]), so gotta check for this.
  # Second, we'll add question marks if they don't already exist:  (a)(b) => (a)?(b)?
  # Then, when parsing the word for optional elements, we will be guaranteed that each optional element
  # will be in its own ()?
  
  # first, break up consecutive parenthesized elements
  1 while $s1 =~ s/\(([^\)\[])([^\)]+)\)/\(\1\)\(\2\)/g;
  1 while $s2 =~ s/\(([^\)\[])([^\)]+)\)/\(\1\)\(\2\)/g;

  # the following adds question marks to parenthesized elements
  # (if you don't have "1 while", it will miss the second of two consecutive parenthesized elements because
  # the second "(" is part of the regexp match from the previous one, going left to right...)
  1 while $s1 =~ s/([^\(]*)(\()([^\)]*)(\))([^\*\?]|$)/\1\2\3\4\?\5/g;    
  1 while $s2 =~ s/([^\(]*)(\()([^\)]*)(\))([^\*\?]|$)/\1\2\3\4\?\5/g;    
    
  # also, regexp-oriented users might expect to be able to type a?b to mean (a)?b, so let's add parens for them
  1 while $s1 =~ s/([^\]\)])\?/\(\1\)\?/g;
  1 while $s2 =~ s/([^\]\)])\?/\(\1\)\?/g;
  # needs a special clause for optional natural classes
  1 while $s1 =~ s/(\[[^\]]*\])\?/\(\1\)\?/g;  
  1 while $s2 =~ s/(\[[^\]]*\])\?/\(\1\)\?/g;  
  

#  print "String 1: $s1\nString 2: $s2\n";  
  
  @s1 = convert_to_array($s1);
  @s2 = convert_to_array($s2);  
#  print "Compare:  \[$s1\] and \[".join('.',@s1)."\]; \[$s2\] and \[".join('.',@s2)."\].\n";  
  
  my $min_distance;

  # for now...
  $substitution_cost = 1;   #(not used when similarity_table is employed)
#  $indel_cost = .6;
  $expand_class_cost = .5;  
  

    # Step 1
    $n = @s1 ;
    $m = @s2 ;
    
    my $s1_real_segs = $n;    
    my $s2_real_segs = $m;        

    # in order to handle wildcards, we need to expand segments with asterisks to include "any number" of
    # optional copies of themselves.  although in theory we could allow an infinite number, in practice
    # we need at most the number of (real) segments in the other word.  so, let's just go through each
    # array and clone wildcard segments to make a number of identical optional segments
    for (my $a = 0; $a < $n; $a++) {
	# if this segment end in an asterisk...	
	if (substr($s1[$a], length($s1[$a]) - 1, 1) eq "\*") {
	    # this one is a wildcard; make a new temp array that clones it
	    my @wildcard;
	    for (my $b = 0; $b < $s2_real_segs; $b++) {
		$wildcard[$b] = "\(".$s1[$a]."\)";		
		$wildcard[$b] =~ s/\*\)/\)\?/g;
	    }
	    # now we have an array of optional elements big enough to swallow up string2, if need be.
	    # splice it into @s1.
	    splice(@s1,$a,1,@wildcard);	    
	    # and update the value of $n
	    $n = @s1;	    	    
	}	
    }
    for (my $a = 0; $a < $m; $a++) {
	# if this segment end in an asterisk...	
	if (substr($s2[$a], length($s2[$a]) - 1, 1) eq "\*") {
	    # this one is a wildcard; make a new temp array that clones it
	    my @wildcard;
	    for (my $b = 0; $b < $s2_real_segs; $b++) {
		$wildcard[$b] = $s2[$a];		
		$wildcard[$b] =~ s/\*/\?/g;
	    }
	    # now we have an array of optional elements big enough to swallow up string1, if need be.
	    # splice it into @s2.
	    splice(@s2,$a,1,@wildcard);	    
	    # and update the length of $m
	    $m = @s2;	    	    
	    
	}	
    }
    
    #finally, we'll make copies without the parentheses and question marks, to check for segment identity
    @s1_segs_only = @s1;    
    @s2_segs_only = @s2;    
    for (my $a = 0; $a < @s1_segs_only; $a++) {
	$s1_segs_only[$a] =~ s/[\(\)\?]//g;	
    }
    for (my $a = 0; $a < @s2_segs_only; $a++) {
	$s2_segs_only[$a] =~ s/[\(\)\?]//g;	
    }
#    print "String 1: ".join('.',@s1).", string 2: ".join('.',@s2)."\n";    

    

    # we'll skip returning m,n for strings of length 0, since we still want to calculate the alignment

    # Step 2
    #
    $matrix[0][0] = 0;

    for ($j=1; $j<=$m; $j++) { # initializing first column
	if ($s2[$j-1] =~ m/\([^\)]+\)\?/) {
	    # This character is optional; its indel cost will be null (don't advance it)
	    $matrix[0][$j] = $matrix[0][$j-1];	    
	} else {
	    $matrix[0][$j] = $matrix[0][$j-1] + $indel_cost;	    	    
	}
    }

    # Step 3
    for ($i=1; $i<=$n; $i++) {
	# initializing first row
	if ($s1[$i-1] =~ m/\([^\)]+\)\?/) {
	    # This character is optional; its indel cost will be null (don't advance)
	    $matrix[$i][0] = $matrix[$i-1][0];	    
	} else {
	    $matrix[$i][0] = $matrix[$i-1][0] + $indel_cost;	    	    
	}
#	$matrix[$i][0] = $i;

	# now, do the inner loop
	for ($j=1; $j<=$m; $j++) {
	    if ($s1_segs_only[$i-1] eq $s2_segs_only[$j-1]) {
		$cost = 0;
#		print "Similarity $i,$j equal\n";				
	    } else {
#		print "Similarity $i,$j = ".similarity_table($s1_segs_only[$i-1],$s2_segs_only[$j-1])."\n";				
	        $cost = (1 - similarity_table($s1_segs_only[$i-1],$s2_segs_only[$j-1]));
	    }
	    $left[$i][$j] = $matrix[$i-1][$j] + ($matrix[$i][0] - $matrix[$i-1][0]);
	    $above[$i][$j] = $matrix[$i][$j-1] + ($matrix[0][$j] - $matrix[0][$j-1]);
	    $diag[$i][$j] = $matrix[$i-1][$j-1] + $cost;

	    $matrix[$i][$j] = ($above[$i][$j] < $left[$i][$j] ?
	       ($above[$i][$j] < $diag[$i][$j] ? $above[$i][$j] : $diag[$i][$j])
	       : ($left[$i][$j] < $diag[$i][$j] ? $left[$i][$j] : $diag[$i][$j]));
	}
    }

    
#    print "Done filling out matrix.\n";        
   # for debugging, it's helpful to have an output file
#    open (OUTPUTFILE, ">alignment.out") or die "Can't open output file: $!\n";        
#    print_matrix();
#    print_above();    
#    print_diag();            
#    print_left();    
    
    
    # the minimum distance can be read out of cell [$n][$m]
    $min_distance = $matrix[$n][$m];

    # now trace backwards to get the alignment
#    print "Going backwards:\n";    
    $generalized = traceback('', '', '', '', $n, $m,'','');
    print "\nThe edit distance between \'$s1\' and \'$s2\' = $min_distance.\n(indel cost = $indel_cost, mismatched natural class cost = $expand_class_cost)\n";
    return $generalized;

    
    #traceback subroutine within the distance subroutine
    sub traceback {
	# taken from http://www.csse.monash.edu.au/~lloyd/tildeAlgDS/Dynamic/Edit.html
	my $row1 = shift(@_);
	my $row2 = shift(@_);
	my $row3 = shift(@_);
	my $row4 = shift(@_);		
	my $i = shift(@_);
	my $j = shift(@_);
	my $rule = shift(@_);

	my $local_cost = 0;	
	
#	my $spacing = "      ";
	my $spacing = "\t";
	
	if ($i > 0 and $j > 0) {
#	    print "Comparing segments s1($i) and s2($j); in other words, considering path back from cell ($i,$j)\n";

	    # The traceback preferences are tricky; in general, we want to prefer substituting segments for other segments
	    # "before" (more locally than) doing indels.  This forces words like tap and tatap to align as (ta)tap instead
	    # of ta(ta)p.  We can accomplish this by checking if the matrix cell equals the diagonal before checking if
	    # it equals the left or above values (in other words, in cases of tie, take the substitution).
	    # However, if there are variables involved, we want to prefer deleting variable material rather than matching it
	    # (this forces the minimal match of variables, a sound linguistic principle).  Thus, just in case the cost of
	    # a deletion is 0, do it; otherwise, prefer substitution first, then deletion then insertion (or vice versa, 
	    # doesn't matter as far as I can tell).

	    # if the deletion cost is 0 (optional seg) and the current cell equals the left value, do a deletion.
	    if ((($matrix[$i][0] - $matrix[$i-1][0]) eq 0) and ($matrix[$i][$j] eq $left[$i][$j])) {
		# a deletion -- add an optional element to the unification
		# (if already optional, just keep it as such)
		if ($s1[$i-1] =~ m/\([^\)]+\)\?/ ) {
		    $rule = $s1[$i-1].$rule;
		} else {
		    if (length($s1_segs_only[$i-1]) > 1 ) {
			$rule = "([".$s1_segs_only[$i-1]."])?".$rule;
		    } else {
			# otherwise, add parens and question mark
			$rule = "(".$s1_segs_only[$i-1].")?".$rule;
		    }
		}
		$local_cost = $matrix[$i][0] - $matrix[$i-1][0];				
#		print "\tDeletion of an optional segment.\t$rule\n";				
	        traceback($s1[$i-1].$spacing.$row1, " $spacing".$row2, "-$spacing".$row3, round($local_cost,2).$spacing.$row4, $i-1, $j, $rule);
	    }
	      elsif ($matrix[$i][$j] eq $diag[$i][$j]) { 	    # if we did a substitution
		# check if it was an exact match or not
		if ($s1_segs_only[$i-1] ne $s2_segs_only[$j-1]) {
		    $diagChar = " ";
		    # not a match, find the tightest natural class that includes both
		    my $tightest_class = find_tightest_class($s1_segs_only[$i-1],$s2_segs_only[$j-1]); #

		    if ((substr($s1[$i-1],length($s1[$i-1])-1) eq "\?") or (substr($s2[$j-1],length($s2[$j-1])-1) eq "\?"))
		    {
#		        print "Preserving optionality of a segment.\n";		        			
			$tightest_class = "\(".$tightest_class."\)\?";						
		    }
		                                                                   		                                                                   
		    $rule = $tightest_class.$rule;
		    $local_cost = 1 - similarity_table($s1[$i-1],$s2[$j-1]);
#		    print "\tSubstitution.\t$rule\n";		    
		    
		} else {
		    $diagChar = "|";
		    # A match, keep this segment in the unification
		    # First, a subtlety: if this segment was optional in either of the source strings,
		    # gotta remember that.  Best way to tell this, I guess, is if the last segment of either
		    # is a question mark  (or, by substracting the row/column headers)
		    my $optional;		    		    
		    if ((substr($s1[$i-1],length($s1[$i-1])-1) eq "\?") or (substr($s2[$j-1],length($s2[$j-1])-1) eq "\?"))
		    {
#		        print "Preserving optionality of a segment.\n";		        			
		      	$optional = 1;		      				
			$rule = "\)\?".$rule;						
		    }		    
		    
		    # if it's a natural class, put in brackets
		    if ( length($s1_segs_only[$i-1]) > 1 ) {
			# a natural class
			$rule = "[".$s1_segs_only[$i-1]."]".$rule;			
		    } else {
		    	$rule = $s1_segs_only[$i-1].$rule;
		    }
		    
		    # and now the left paren for an optional element
		    if ($optional)
		    {
			$rule = "\(".$rule;						
		    }		    
		    $local_cost = 0;		    		    
#		    print "\tMatch.\t$rule\n";		    		    
		}
		# then peel off and trace back further
		traceback($s1[$i-1].$spacing.$row1 , $diagChar.$spacing.$row2 , $s2[$j-1].$spacing.$row3, round($local_cost,2).$spacing.$row4 , $i-1, $j-1, $rule);
	    } elsif ($matrix[$i][$j] eq $left[$i][$j]) {
		# a deletion -- add an optional element to the unification
		# (if already optional, just keep it as such)
		if ($s1[$i-1] =~ m/\([^\)]+\)\?/ ) {
		    $rule = $s1[$i-1].$rule;
		} else {
		    if (length($s1_segs_only[$i-1]) > 1 ) {
			$rule = "([".$s1_segs_only[$i-1]."])?".$rule;
		    } else {
			# otherwise, add parens and question mark
			$rule = "(".$s1_segs_only[$i-1].")?".$rule;
		    }
		}
		$local_cost = $matrix[$i][0] - $matrix[$i-1][0];				
#		print "\tDeletion.\t$rule\n";				
#	        traceback($s1[$i-1].$spacing.$row1, " $spacing".$row2, "-$spacing".$row3, round($local_cost,2).substr($spacing,0,length($spacing)-3).$row4, $i-1, $j, $rule);
	        traceback($s1[$i-1].$spacing.$row1, " $spacing".$row2, "-$spacing".$row3, round($local_cost,2).$spacing.$row4, $i-1, $j, $rule);
	    } elsif ($matrix[$i][$j] eq $above[$i][$j]) {
	        # an insertion -- add an optional element to the unification.
	        # (if already optional, just keep it as such)
	        if ($s2[$j-1] =~ m/\([^\)]+\)\?/ ) {
		    $rule = $s2[$j-1].$rule;
		} else {
		    if (length($s2_segs_only[$j-1]) > 1 ) {
			# a natural class; add brackets
			$rule = "([".$s2_segs_only[$j-1]."])?".$rule;
		    } else {
			# otherwise, just add parens and question mark
			$rule = "(".$s2_segs_only[$j-1].")?".$rule;
		    }
		}
		
		$local_cost = $matrix[0][$j] - $matrix[0][$j-1];
#		print "\tInsertion.\t$rule\n";				
	        traceback("-$spacing".$row1, " -$spacing".$row2, $s2[$j-1].$spacing.$row3, round($local_cost,2).$spacing.$row4, $i, $j-1, $rule);
	    }
	} elsif ($i > 0) {
	    # exhausted material in string2
	    # if segment here was already optional, leave it as such
#	    print "String 2 is done; getting rid of stuff in string 1\n";
	    if ($s1[$i-1] =~ m/\([^\)]+\)\?/ ) {
		$rule = $s1[$i-1].$rule;
	    } else {
		# otherwise, add parens and question mark
		if (length($s1_segs_only[$i-1]) > 1) {
		    $rule = "([".$s1_segs_only[$i-1]."])?".$rule;
		} else {
		    $rule = "(".$s1_segs_only[$i-1].")?".$rule;
		}
	    }
	    $local_cost = $matrix[$i][0] - $matrix[$i-1][0];				
	    traceback($s1[$i-1].$spacing.$row1, " $spacing".$row2, "-$spacing".$row3, round($local_cost,2).$spacing.$row4, $i-1, $j, $rule);
	} elsif ($j > 0) {
#	    print "String 1 is done; getting rid of stuff in string 2\n";
	    # exhausted material in string1
	    # (if already optional, just keep it as such)
	    if ($s2[$j-1] =~ m/\([^\)]+\)\?/ ) {
		$rule = $s2[$j-1].$rule;
	    } else {
		# otherwise, add parens and question mark
		if (length($s2_segs_only[$j-1]) > 1) {
		    $rule = "([".$s2_segs_only[$j-1]."])?".$rule;
		} else {
		    $rule = "(".$s2_segs_only[$j-1].")?".$rule;
		}
	    }
	    $local_cost =  $matrix[0][$j] - $matrix[0][$j-1];				
    	    traceback("-$spacing".$row1, " $spacing".$row2, $s2[$j-1].$spacing.$row3, round($local_cost,2).$spacing.$row4, $i, $j-1, $rule);
	} else { # i==0 and j==0
	         # 
	         # 
	         # a cleanup operation: by the "phonology can't count" principle, we want to generalize over consecutive
	         # optional elements
		while ($rule =~ /\(([^\)]+)\)[\?\*]\(([^\)]+)\)[\?\*]/) {
#		    print "Combining adjacent optional elements\n";
		    my $combined = find_tightest_class($1,$2);
		    # now get rid of any internal brackets ("[[ab]c]")
#		    print "Getting rid of nested brackets\n";
		    $combined =~ s/(\[)([^\]]*)\[/$1$2/g;    
		    $combined =~ s/(\])([^\[]*)\]/$1$2/g;    
#		    print "Got rid of nested brackets\n";
		    
		    $rule =~ s/\(([^\)]+)\)[\?\*]\(([^\)]+)\)[\?\*]/\($combined\)\*/;    
		}
		
		# now, we can create a "phonologist" version of the rule that tells us the features involved
		my $phon_rule = $rule;		
		# in order to do this, we'll replace natural classes with their feature specifications
		while ($phon_rule =~ /\[([^\]\+\-\,]*)\]/) {
#		    print "Rule \"$rule\" has natural class \{$1\}.\n";		    		    
		    my $feats = get_feats( $1 );		    
		    $phon_rule =~ s/\[([^\]\+\-\,]*)\]/\[$feats\]/;		    		    
		}		
#		printf OUTPUTFILE "\n\t$row1\n\t$row2\n\t$row3\n\n\t$row4\n\n\t$rule\n\t$phon_rule\n"; 
		print "\n\t$row1\n\t$row2\n\t$row3\n\n\t$row4\n\n\t$rule\n\t$phon_rule\n";
		return $rule;		
	    }	
    }

} # end of the distance subroutine

sub similarity_table {
    my @pair = @_;
    #unfortunately, sometimes segments might have parentheses and question marks;
    # get rid of them for the purpose of computing similarity
    $pair[0] =~ s/[\(\)\[\]\?]//g;    
    $pair[1] =~ s/[\(\)\[\]\?]//g;        
    
    @pair = sort @pair;        
    my $longest = ( length($pair[0]) > length($pair[1]) ? length($pair[0]) : length($pair[1]) );    	
    
    my $pair = join('\\',@pair);

     # we can tell if there's a natural class then $pair is longer than 2 segments
      if (length($pair) > 3)
      {
	#       print "Trying to match a natural class with a segment ($pair[0] vs. $pair[1], longest length = $longest)";
        	# if the longer natural class actually includes the entire other segment/class, then the substitution cost is 0
          my $uniqed = remove_duplicates($pair); 	
  	if (length($uniqed) == $longest + 1) # plus one because of the backslash that was added by the join a few lines above
  	  {
  	    # subsumed -- return 0
#	    print "A subsumed natural class -- $pair[0] and $pair[1]\n";	    	    
	    if (exists $similarity_table{$pair}) {
		return 1 - ($similarity_table{$pair} / 1000);
	    } else {
	    print "Warning! unknown pair: $pair\n";
		return 0;
	    }
	    
	    
  	    return 1;	    
	   } else {
# 	    print "Not subsumed; $uniqed is longer than $longest chars long\n";	     	    
  	    # otherwise, gotta look it up	    
	    if (exists $similarity_table{$pair}) {
		return $similarity_table{$pair};
	    } else {
	    print "Warning! unknown pair: $pair\n";
		return 0;
	    }
	  }
	} else {
#	 print "Length of pair $pair is ".length($pair)."\n";	 	 
	if (exists $similarity_table{$pair}) {
	    return $similarity_table{$pair};
	} else {
#	    print "Warning! unknown pair: $pair\n";
	    return 0;

	}
    }    
}


sub find_tightest_class {
    # This looks convoluted, but if the target elements can contain either natural classes
    # or individual segments, its possible that we need to integrate a segment with a list
    # of segments, or even interlace two lists.
    # The best way I can think of to do this is to join them and resplit them so we
    # end up with a list longer than two elements, and then sort and remove duplicates.

    my $target_segments = remove_duplicates(join('',@_));    
#    print "Target segments =".join(".", split('',$target_segments))."\n";    
    
    # now compose the search string, which is a bracket, and all of the target segments with anything
    # allowed before, in between, or afterwards.
    my $search_string = "\\\[\([^\\\[]*";    
    for (my $i = 0; $i < length($target_segments); $i++) {
	$search_string .= substr($target_segments,$i,1)."[^\\\]]*";		
    }
    $search_string .= "\)\\\]";    

        $all_natural_classes =~ m/($search_string)/;
	my $natural_class = $1;
	# should check for no match, so as to return some default
	if ($natural_class eq undef) {
	    $natural_class = "\[".$target_segments."\]";	    	    
	    print "Warning: need to use an unknown natural class: $natural_class\n";	    
	}
	
#	print "Tightest natural class for \{$target_segments\} is $natural_class\n";    
	
	return $natural_class;

}

sub get_feats {
      $target_class = shift(@_);
#      print "Getting features for $target_class\n";
      
	    my $desc = $feats_for_classes{$target_class};      
	    if ($desc eq undef) {
		$desc = "\?\?\?";	  	  
	    }           
      	    return $desc;
	}
########################################################################################################################
sub convert_to_array {
    
    my @convert = split('',shift(@_));    
    
    # first, remove empty elements, should they arise somehow
    for (my $i = 0; $i < @convert; $i++) {
	if ($convert[$i] eq undef) {
	    splice(@convert,$i,1);	    
	}
    }    
    
#    print "Converting array: ".join("\.",@convert)."\n";    
    
    
    # we need to collapse the following into single elements:
    # (1) items within brackets    ("a[bmp]a" => (a, bmp, a))
    # (2) items within parentheses ("a(m)?pa" => (a, (m)?, p, a), and "a([bmp])?a" => (a, (bmp)?, a)
    # (3) items with asterisks     ("a[bmp]*a" => (a, ([bmp])*, a)
    # 
    # We'll make some simplifying assumptions here, because all this routine needs to handle is collapsed
    # rules, not the entire class of possible regular expressions
    # 
    # First, we'll assume that there are no nested square brackets ([ab[cd]e])
    # Also, we'll assume that we won't get things like parentheses within brackets, etc.
    # 
    # First, the parens -- since we assured at the beginning that multiple elements within parens are split
    # into separate parens, then everything between parens can be merged into a single element
    for (my $i = 0; $i < @convert; $i++) {
	# check for stuff that signals that we need to collapse elements
	if ($convert[$i] eq "\(") {
#	    print "Position $i: a left paren...";	    	    
	    # we found a left paren -- go through the subsequent elements looking for a right one.
	    my $right_paren_index = $i+1;	    	    
	    while ($convert[$right_paren_index] ne "\)" ) {
		$right_paren_index++;		
	    }	
#	    print "ending at $right_paren_index\n";	    
	    
	    # all the segments up to $right_paren_index should get concatenated to $convert[$i] 
	    for (my $j = $i+1; $j <= $right_paren_index; $j++) {
		$convert[$i] .= $convert[$j];				
	    }
	    
	    # In the case of wildcards, we also need to delete the brackets and parens
	    $convert[$i] =~ s/\(\[([^\]]*)\]\)/\1/;	    
	    
	    # and now delete the guys we folded into $convert[$i]
	    splice(@convert, $i+1, $right_paren_index - $i);	 
	    # and back up to be sure to catch an immediately following paren
#	    $i--;	    
	    
	} elsif ($convert[$i] eq "\[") {
	    # we found a left bracket -- go through the subsequent elements looking for a right one.
#	    print "Position $i: a bracket...";	    	    
	    my $right_bracket_index = $i+1;	    	    
	    while ($convert[$right_bracket_index] ne "\]" ) {
		$right_bracket_index++;		
	    }	    
#	    print "ending at $right_bracket_index\n";	    
	    
	    # all the segments up to $right_bracket_index should get concatenated to $convert[$i] 
	    for (my $j = $i+1; $j <= $right_bracket_index; $j++) {
		$convert[$i] .= $convert[$j];				
	    }
	    # and we remove the brackets from $convert[$i]
	    $convert[$i] =~ s/[\[\]]//g;	    	    
	    # and now delete the guys we folded into $convert[$i]
	    splice(@convert, $i+1, $right_bracket_index - $i);	    
#	    print "Result of collapsing brackets: ".join(".",@convert)."\n";	    
	    
	} elsif ($convert[$i] eq "\?") {
	    # question marks are simpler -- just merge into previous element
	    $convert[$i-1] .= "\?";	    
	    splice(@convert, $i, 1);
	    $i =- 1;	    	    
	} elsif ($convert[$i] eq "\*") {
	    # asterisks are like question marks -- just merge into previous element
	    $convert[$i-1] .= "\*";	    
	    splice(@convert, $i, 1);
	    $i =- 1;	    	    
	}
	
	# if not one of those symbols, not something eligible for collapsing, just keep going.	
    }
    return (@convert);        

}
########################################################################################################################
sub remove_duplicates {
#	my $purge = join('',sort split('',shift (@_)));

	my $purge = shift(@_);	
	$purge =~ s/[\(\)\[\]\?]//g;
	$purge = join('',sort split('', $purge));		
	
	# xxx could also probably leave as an array and use SPLICE Array, Offset, Length to get rid of dups
#	print "Sorted string = $purge\n\n$purge\n";	
	for (my $i = 0; $i < length($purge); $i++) {
	    if (substr($purge,$i,1) eq substr($purge,$i+1,1)) {
		$purge = substr($purge,0,$i).substr($purge,$i+1);		
#		print "$purge\n";
	    }	    
	}
	return $purge;	
}
########################################################################################################################
# from http://www.perlmonks.org/index.pl?node_id=1873
sub round {
    my ($number,$decimals) = @_;
    return substr($number+("0."."0"x$decimals."5"),
                  0, $decimals+length(int($number))+1);
}
########################################################################################################################
sub print_matrix {
    printf OUTPUTFILE "Distance\t\t";
    for ($i = 0; $i <= $n; $i++) { 
	printf OUTPUTFILE "$s1[$i]\t";    
    }
    printf OUTPUTFILE "\n";    
    
    
    for ($j = 0; $j <= $m; $j++) {
	if ($j > 0) {
	    printf OUTPUTFILE "$s2[$j-1]\t";	
	} else {
	    printf OUTPUTFILE "\t";	    	    
	}
	
 	for ($i = 0; $i <= $n; $i++) {
 	    printf OUTPUTFILE "$matrix[$i][$j]\t";	    	    
 	}	
 	printf OUTPUTFILE "\n";		
    }
    printf OUTPUTFILE "\n\n";    
 }
sub print_above {
    printf OUTPUTFILE "Above\t\t";
    for ($i = 0; $i <= $n; $i++) { 
	printf OUTPUTFILE "$s1[$i]\t";    
    }
    printf OUTPUTFILE "\n";    
    
    
    for ($j = 0; $j <= $m; $j++) {
	if ($j > 0) {
	    printf OUTPUTFILE "$s2[$j-1]\t";	
	} else {
	    printf OUTPUTFILE "\t";	    	    
	}
	
 	for ($i = 0; $i <= $n; $i++) {
 	    printf OUTPUTFILE "$above[$i][$j]\t";	    	    
 	}	
 	printf OUTPUTFILE "\n";		
    }
    printf OUTPUTFILE "\n\n";        
 }
 sub print_left {
    printf OUTPUTFILE "Left\t\t";
    for ($i = 0; $i <= $n; $i++) { 
	printf OUTPUTFILE "$s1[$i]\t";    
    }
    printf OUTPUTFILE "\n";    
    
    
    for ($j = 0; $j <= $m; $j++) {
	if ($j > 0) {
	    printf OUTPUTFILE "$s2[$j-1]\t";	
	} else {
	    printf OUTPUTFILE "\t";	    	    
	}
	
 	for ($i = 0; $i <= $n; $i++) {
 	    printf OUTPUTFILE "$left[$i][$j]\t";	    	    
 	}	
 	printf OUTPUTFILE "\n";		
    }
    printf OUTPUTFILE "\n\n";      
 }
 sub print_diag {
    printf OUTPUTFILE "Diag\t\t";
    for ($i = 0; $i <= $n; $i++) { 
	printf OUTPUTFILE "$s1[$i]\t";    
    }
    printf OUTPUTFILE "\n";    
    
    
    for ($j = 0; $j <= $m; $j++) {
	if ($j > 0) {
	    printf OUTPUTFILE "$s2[$j-1]\t";	
	} else {
	    printf OUTPUTFILE "\t";	    	    
	}
	
 	for ($i = 0; $i <= $n; $i++) {
 	    printf OUTPUTFILE "$diag[$i][$j]\t";	    	    
 	}	
 	printf OUTPUTFILE "\n";		
    }
    printf OUTPUTFILE "\n\n";      
}
########################################################################################################################
sub read_similarities {
    # we'll read in the similarities in $simfile
    open (SIMFILE, "<$simfile") or die "Can't open similarities file: $!\n";        
    print "Reading in similarities.\n";        
    
    # check the first line
    $line = <SIMFILE>;
    chomp($line);        
    if ($line ne "class1\tclass2\tshared\tnon-shared\tsimilarity" and 
	  $line ne "class1\tclass2\tshared\ttotal\tsimilarity") {
	# uh oh, an invalid similarity file
	print "Sorry, doesn't look like a valid .stb file\n";	
	
	return 0;		
    } else {
        # ok, a valid similarity file.
        while ($line = <SIMFILE>) {
	    chomp($line);	    
	    ($pair[0], $pair[1], $shared, $nonshared, $sim) = split("\t",$line);	    
	    @pair = sort(@pair);	    
	    $similarity_table{ "$pair[0]\\$pair[1]"} = $sim;	    
	}	
    }

    my $classfile = $simfile;    
    $classfile =~ s/\.stb/\.cls/;        
    open (CLASSESFILE, "<$classfile") or die "Can't open file of natural classes: $!\n";    
    print "Reading in natural class descriptions.\n";    
    while ($line = <CLASSESFILE>) {
	chomp($line);	
	($class_segs, undef, $description) = split("\t",$line);		
	$feats_for_classes{$class_segs} = $description;
	$all_natural_classes .= "\[$class_segs\] ";		
    }
    
    return 1;        
}
