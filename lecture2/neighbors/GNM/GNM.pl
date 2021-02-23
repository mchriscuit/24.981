#!/usr/bin/perl
use IO::Handle;
use POSIX qw(log10);

# GNM.pl - script for counting neighborhood density two ways:
#    1) "traditional" way (all words with just one modification)
#    2) Bailey and Hahn (2001) "Generalized Neighbor Model" (GNM)
# The GNM-Celex.pl script is designed to handle a training corpus from CELEX
# (in particular, it translates the input file of test words into the DISC
#  transcription scheme, under the assumption that this is what the corpus also
#  uses)

# Some parameters of the model
# The indel cost is used in performing the alignments; Bailey and Hahn use .7
#    (but they say anything from .6 to 1 works OK); they also assume in = del
$indel_cost = .7;
# A, B, and C are coefficients in the quadratic equation for taking frequency into account;
#  Bailey & Hahn used: A = -.47, B = .17, C = 1.87
#  Setting A & B to 0 and C = 1 would turn off the effect of frequency weighting (weight = 0*freq^2 + 0*freq + 1)

#($A_coeff, $B_coeff, $C_coeff) = (-.47, .17, 1.87);
($A_coeff, $B_coeff, $C_coeff) = (0, 0, 1);

# Bailey and Hahn also add a constant to all frequencies, to avoid 0's
# For some reason, they add 2, but this could be changed
$freq_boost = 2;

# The GCM also has some free parameters s and P.
# P is a coefficient, and must be 1 or 2; Albright & Hayes (2003) found that 1 worked
#   better in modeling human intuitions, and Bailey and Hahn omit it (implicit choice of 1)
# The s parameter models "sensitivity", meaning how quickly the influence of less similar
#   items drops off.  In Nosofsky's original formulation, the distance d is divided by s.
#   (the greater s is, the more equal the similar values will be, and the greater the sensitivity
#   to dissimilar forms)
# Bailey and Hahn multiply distance by a parameter D, rather than dividing by s.
# They do not say what they used, but according to Todd Bailey, they
# initialized the parameter search with D = 5.5, so it may have been in
# that ballpark.
# Albright & Hayes found that .4 was best; this would translate to a D of 2.5
# A good default value might be 2, equivalent to an s of .5
$p_exp = 1;
$D_coeff = 5.75;

# Finally, a stupidity of CELEX: duplicate entries.  The most neutral thing
# would be to count them as separate words, avoiding the need to decide if 
# two entries are duplicates (and increasing replicability)
# It seems sensible, though, to want to try to avoid counting things twice 
# just because they show up twice in CELEX.  I'll leave it as an option.
$skip_duplicates = 0;
# Bailey and Hahn seem to have collapsed duplicates on purely phonological grounds (i.e.,
#    two words spelled differently but with the same pronunciation are not counted twice,
#    since it's just one phonological wordform)
# I'm not sure this is really the right way to go, but leave it as an option.
$collapse_homophones = 0;

# For debugging or expository purposes: can output similarities for each
# test word
$verbose_outputs = 0;

# For English, the usual training corpora are from CELEX, and it is assumed that we will be
#   using training files of wordlists derived from CELEX (IdNum, COB freq, Orthog, Phonetic)
# If this is turned off, the program will assume files of just two fields (Phonetic, Freq)
$celex_format = 1;

# Bailey and Hahn count just over monosyllables
MONOSYLLABLESONLY:
while (1 == 1) {
    print "Exclude polysyllabic wordforms? ([n]) ";
    $monosyllables_only = <STDIN>;    
    chomp($monosyllables_only);    
    if ($monosyllables_only =~ /(yes|y|1|Y|Yes|YES|yES)/ ) {
	$monosyllables_only = 1;	
	last MONOSYLLABLESONLY;	
    } elsif ($monosyllables_only =~ /(no|n|N|NO|No|nO)/ or $monosyllables_only eq "") {
        $monosyllables_only = 0;        
	last MONOSYLLABLESONLY;	
    } else {
        print "\tSorry, couldn't  understand response.  Please type y, n, or enter for default.\n\n";        
    }
}
# It's not clear whether Bailey and Hahn used wordforms, or lemmas
#    (nor is it clear what the better strategy would be)
WORDFORMSORLEMMAS:
while (1==1) {
    print "\nWord forms or lemmas?\n\t1. word forms\n\t2. lemmas\n? ";    
    $lemmas = <STDIN>;    
    chomp($lemmas);    
    if ($lemmas =~ /^1/ or $lemmas =~ /^[Ww]ord/) {
	$lemmas = 0;	
	last WORDFORMSORLEMMAS;	
    } elsif ($lemmas =~ /^2/ or $lemmas =~ /^[Ll]em/) {
        $lemmas = 1;        
	last WORDFORMSORLEMMAS;	
    } else {
        print "\tSorry, couldn't understand response.  Please type 1 or 2\n\n";        
    }
}

if ($lemmas) {
    if ($monosyllables_only) {
	$corpusfile =  "wordlists/CelexLemmasInTranscription-DISC-Monosyls.txt";
    } else {
	$corpusfile =  "wordlists/CelexLemmasInTranscription-DISC.txt";   
    }
    
} else {
    if ($monosyllables_only) {
	$corpusfile =  "wordlists/CelexWordFormsInTranscription-DISC-Monosyls.txt";
    } else {
	$corpusfile =  "wordlists/CelexWordFormsInTranscription-DISC.txt";   
    }    
}

open (CORPUS, "$corpusfile") or die "Can't open corpus file: $!";

$infile = $ARGV[0];
open (TESTWORDS, "$infile") or die "Can't open test file $infile: $!\n";

print "Enter similarity file (<RETURN> for default English features): ";
$simfile = <STDIN>;
chomp($simfile);
if ($simfile eq "") {
#    $simfile = "similarity/English-DISC-FrischFeatures.stb";
#     $simfile = "similarity/PVMSsim.stb";
#     $simfile = "similarity/BaileyHahnFeatures.stb";
    $simfile = "similarity/BaileyHahnSimilarityValues.stb";
}
my %similarity_table;

$valid_sims = read_similarities();

if (scalar (@ARGV) > 1) {
   $outputfile = $ARGV[1];   
}

# The outputfiles will be stored in a directory called "outputfiles" (for
# neatness)
# If there is not already an outputfiles directory, rather than quitting,
# it would be most polite to simply make one and move on.
unless (-e "outputfiles") {
    mkdir("outputfiles") or die "Can't create directory for output files: $!\n";
}


while ($continue == 0) {
    unless  (defined $outputfile) {
	print "Enter name for output file: ";
	$outputfile = <STDIN>;
	chomp($outputfile);
    }
    
    $outputfile = "outputfiles/$outputfile";    
	    
    if (-e $outputfile) {
	print "\nFile $outputfile already exists. \nWhat should I do?\n\t1. overwrite old $outputfile\n\t2. Save output file under a new name.\n? ";
	$response = <STDIN>;
	chomp($response);
	if ($response eq "1" or $response eq "1.") {
	    # OK to overwrite; break out and keep going
	    $continue = 1;
	} elsif ($response eq "2" or $response eq "2.") { 
	    $outputfile = undef;	    
	    next;	    
	    
	} else {
	    print "Sorry, couldn't understand response; please try again.\n";
	}
    } else {
	# file doesn't already exist.  proceed normally.
	$continue = 1;
    }
}    

# So we can remember what conditions the simulation was run under
open (PARAMS, ">$outputfile.params") or die "Can't write to parameters file: $!\n";
printf PARAMS "GNM parameters:\n";
printf PARAMS "\tIndel cost\t$indel_cost\n";
printf PARAMS "\tFreq coefficients: A = $A_coeff, B = $B_coeff, C = $C_coeff\n";
printf PARAMS "\tFrequency added constant: $freq_boost\n";
printf PARAMS "\tP exponent:\t$p_exp";
printf PARAMS "\tD\t$D_coeff\n";
printf PARAMS "Training corpus\n";
printf PARAMS "\tSkip duplicates\t$skip_duplicates\n";
printf PARAMS "\tCollapse homophones\t$collapse_homophones\n";
printf PARAMS "\tMonosyllables only\t$monosyllables_only\n";
printf PARAMS "\tLemmas only\t$lemmas\n";
printf PARAMS "Corpus file:\t$corpusfile\n";
printf PARAMS "Similarities file:\t$simfile\n";
close(PARAMS);

# Read in the corpus
print "Reading in corpus file.\n";
open (UNIQ, ">unique.txt");

while ($line = <CORPUS>)
{
    chomp($line);
    $line =~ s/\\/\t/g;   
    if ($celex_format){
	    ($IdNum, $Cob, $Word, $Phonetic) = split ("\t", $line);
	} else {
		($Phonetic, $Cob) = split("\t", $line);
	}
    
    # CELEX has a few words in both capitalized and uncapitalized form.
    # (e.g., blimp and Blimp).   It's never clear what to do with these;
    # Bailey and Hahn's list of contributing neighbors seems not to have
    # these duplicates; I'm going to filter by putting everything in lower 
    # case
    $Word = lc($Word);    
    
    # If keeping just one of each phonological form, then we need to skip based just on that criterion
    if ($collapse_homophones and $seen_phon{$Phonetic}) {
	# We've seen something pronounced like this before.
	# We want to skip it; but if it is more frequent than its homophone, we should replace
	if ($Cob > $freq[$seen_phon{$Phonetic}]) {
	    # Need to update older frequency, but also its spelling (transcription was already same)
	    $words[$seen_words{$Word}] = $Word;	    
	    $freq[$seen_words{$Word}] = $Cob;	  
	  	# (A different option would be to add the freqs)
	}
	$number_of_skipped++;	
	next;	
    } elsif ($skip_duplicates and $seen_words{$Word} > 0 and $transcription[$seen_words{$Word}] eq $Phonetic) {
	# Two possibilities: sum them all, or take greatest
	# I don't have any clear intuition about what's best; Bailey thinks
	#    they may have taken largest (if skipping at all--which they do
	#    seem to have done) so for now I'll go with "take single greatest"
#	 $freq[$seen_words{$Word}] += $Cob;	
	if ($Cob > $freq[$seen_words{$Word}]) {
	    $freq[$seen_words{$Word}] = $Cob;	    
	}
	$number_of_skipped++;		
	next;	
    }
    
    # Store information regarding this item 
    $corpus_size++;    
    $words[$corpus_size] = $Word;
    $freq[$corpus_size] = $Cob;    
    $transcription[$corpus_size] = $Phonetic;
    
    # Remember where we stored this word, in case we need to find it again
    $seen_words{$Word} = $corpus_size;
    $seen_phon{$Phonetic} = $corpus_size;
    
    printf UNIQ "$Word\t$Phonetic\n";    
    
    # For convenience, store also a representation in which each phoneme
    # is a single character
    $phonetic[$corpus_size] = $Phonetic;    
    
    # For purposes of counting ngrams, make sure to include information about what is word-initial/final
    $Phonetic = " $Phonetic ";        
    # Finally, count the bigrams and trigrams in this word
    for (my $i = 0; $i < length($Phonetic) - 1 ; $i++) {
		if ($i > $LastBigramPos) {
		    $LastBigramPos = $i;	    
		}	
		$number_of_bigrams++;	
	
		# Store the current biphone in a hash table
		$BigramCount{substr($Phonetic, $i, 2)}++ ;
		# Also a positional count, a la Vitevitch & Luce
		$PositionalBigramCount[$i]{substr($Phonetic, $i, 2)}++ ;
		# Also, increment the count of everything starting with the current phone
		$FirstOfBigram{substr($Phonetic, $i, 1)}++;
		$PositionalFirstOfBigram[$i]{substr($Phonetic, $i, 1)}++;
    }
    for (my $i = 0; $i < length($Phonetic) - 2; $i++) {
		if ($i > $LastTrigramPos) {
		    $LastTrigramPos = $i;	    
		}
		$number_of_trigrams++;	
	
		# Store the current triphone in a hash table
		$TrigramCount{substr($Phonetic, $i, 3)}++ ;
		# Also a positional count, a la Vitevitch & Luce
		$PositionalTrigramCount[$i]{substr($Phonetic, $i, 3)}++ ;
		# Also, increment the count of everything starting with the current two phones
		$FirstOfTrigram{substr($Phonetic, $i, 2)}++;
		$PositionalFirstOfTrigram[$i]{substr($Phonetic, $i, 2)}++;
		# And also the outer two phones, to keep track of "centered" trigrams
		$TrigramWindows{substr($Phonetic, $i, 1).substr($Phonetic, $i+2, 1)}++;
    }    
}
print "\nRead $corpus_size distinct words from the corpus file ($number_of_skipped duplicates)\n";
$wait = <>;

close (CORPUS);
close (UNIQ);

print "\nCalculating biphone probabilities\n";
foreach $bigram (keys %BigramCount) {
    # Bailey and Hahn use transitional probabilities to model phonotactic restrictions
    $BigramTransitionalProb{$bigram} = $BigramCount{$bigram} / $FirstOfBigram{ substr($bigram,0,1) };      
    # They don't use overall bigram frequencies, but Vitevitch and Luce do (after a fashion)
    $BigramProb{$bigram} = $BigramCount{$bigram} / $number_of_bigrams;        
}
# Print the results to a file
# First the transitional probabilities
open (BIPHONEPROBFILE, ">outputfiles/BiphoneTransitionalProbabilities.txt") or die "Warning! Can't create biphone probabilities file: $!\n";
printf BIPHONEPROBFILE "Phon1\tPhon2\tCount\tPhon1 Count\tProb(Phon2|Phon1)\n";

foreach $biphone (sort {$BigramTransitionalProb{$b} <=> $BigramTransitionalProb{$a}} keys %BigramTransitionalProb) {
    $print_biphone = join("\t", split("",$biphone));
    printf BIPHONEPROBFILE $print_biphone. "\t$BigramCount{$biphone}\t".$FirstOfBigram{substr($biphone,0,1)}."\t$BigramTransitionalProb{$biphone}\n";        
}
close (BIPHONEPROBFILE);
# And now the plain bigram probabilities (perhaps not so useful)
open (BIPHONEPROBFILE, ">outputfiles/BiphoneProbabilities.txt") or die "Warning! Can't create biphone probabilities file: $!\n";
printf BIPHONEPROBFILE "Phon1\tPhon2\tCount\tProb(Phon1Phon2)\n";

foreach $biphone (sort {$BigramProb{$b} <=> $BigramProb{$a}} keys %BigramProb) {
    $print_biphone = join("\t", split("",$biphone));
    printf BIPHONEPROBFILE $print_biphone. "\t$BigramCount{$biphone}\t$BigramProb{$biphone}\n";        
}
close (BIPHONEPROBFILE);

$number_of_trigrams = scalar keys %TrigramCount;
foreach $trigram (keys %TrigramCount) {
    $TrigramTransitionalProb{$trigram} = $TrigramCount{$trigram} / $FirstOfTrigram{ substr($trigram,0,2) };       
	$TrigramCenteredConditionalProb{$trigram} = $TrigramCount{$trigram} / $TrigramWindows{ substr($trigram,0,1).substr($trigram,2,1) };
    $TrigramProb{$trigram} = $TrigramCount{$trigram} / $number_of_trigrams;
}
# Print the results to a file
# First the trigram transitional probabilities
open (TRIPHONEPROBFILE, ">outputfiles/TriphoneTransitionalProbabilities.txt") or die "Warning! Can't create triphone probabilties file: $!\n";
printf TRIPHONEPROBFILE "Phon1\tPhon2\tPhon3\tCount\tPhon1Phon2 Count\tProb(Phon3|Phon1Phon2)\n";
foreach $triphone (sort {$TrigramTransitionalProb{$b} <=> $TrigramTransitionalProb{$a}} keys %TrigramTransitionalProb) {
    $print_triphone = join("\t", split("",$triphone));    
    printf TRIPHONEPROBFILE $print_triphone. "\t$TrigramCount{$triphone}\t".$FirstOfTrigram{substr($triphone,0,2)}."\t$TrigramTransitionalProb{$triphone}\n";        
}
close (TRIPHONEPROBFILE);

# And now the plain trigram probabilities
open (TRIPHONEPROBFILE, ">outputfiles/TriphoneProbabilities.txt") or die "Warning! Can't create triphone probabilties file: $!\n";
printf TRIPHONEPROBFILE "Phon1\tPhon2\tPhon3\tCount\tProb(Phon1 Phon2 Phon3)\n";
foreach $triphone (sort {$TrigramProb{$b} <=> $TrigramProb{$a}} keys %TrigramProb) {
    $print_triphone = join("\t", split("",$triphone));    
    printf TRIPHONEPROBFILE $print_triphone. "\t$TrigramCount{$triphone}\t$TrigramProb{$triphone}\n";        
}
close (TRIPHONEPROBFILE);

# And now the centered trigram probabilities
open (TRIPHONEPROBFILE, ">outputfiles/TriphoneCenteredProbabilities.txt") or die "Warning! Can't create triphone probabilties file: $!\n";
printf TRIPHONEPROBFILE "Phon1\tPhon2\tPhon3\tCount\tCentered Prob(Phon2 | Phon1 ... Phon3)\n";
foreach $triphone (sort {$TrigramCenteredConditionalProb{$b} <=> $TrigramCenteredConditionalProb{$a}} keys %TrigramCenteredConditionalProb) {
    $print_triphone = join("\t", split("",$triphone));    
    printf TRIPHONEPROBFILE $print_triphone. "\t$TrigramCount{$triphone}\t$TrigramCenteredConditionalProb{$triphone}\n";        
}
close (TRIPHONEPROBFILE);

# Also write the header to the output file
open (OUTPUT, ">$outputfile") or die "Can't open output file: $!\n";
OUTPUT->autoflush(1);
printf OUTPUT "No.\tWord\tBiphone joint trans logprob\tTriphone joint trans logprob\tBiphone avg trans logprob\tTriphone avg trans logprob\tTriphone avg centered logprob\tAvg biphone prob\tAvg triphone prob\tNNB\tNNB freq\tNeighbors\tGNM sim\tGNM sim (adj.)\tNearest neighbors\n";

# Now we go through the file of test words, counting "neighborliness" for each
while ($word = <TESTWORDS>) {
    $number_of_testwords++;  
    chomp($word);    
    if ($word =~ /\s/) {
	print "Error on line $number_of_testwords of $infile: line contains spaces\n";	
    }
    # skip blank lines
    next if ($word eq "");    

    # Store this word in the @testwords array
    $testwords[$number_of_testwords] = $word;    
    $phonetic = $word;

    $phonetic_spaces = " $phonetic ";        
    # We calculate the bigram and trigram transitional probabilities using the chain rule
    $bigram_prob = 1;
    $trigram_prob = 1;    
	# and keep running sums for the average probabilities
    $total_bigram_freq = 0;
	$summed_bigram_transprob = 0;
    $total_trigram_freq = 0;  
	$summed_trigram_transprob = 0;
    $total_trigram_centered_prob = 0;
    
    for (my $i = 0; $i < length($phonetic_spaces) - 1; $i++) {
		$bigram_prob *= $BigramTransitionalProb{substr($phonetic_spaces,$i,2)};	
		$summed_bigram_transprob += $BigramTransitionalProb{substr($phonetic_spaces,$i,2)};	
		$total_bigram_freq += $BigramProb{substr($phonetic_spaces,$i,2)};	
    }
	if ($bigram_prob > 0){
		$bigram_prob = log($bigram_prob);
	} else {
		$bigram_prob = "-inf"; 
	}

	if ($total_bigram_freq > 0){
	    $avg_bigram_freq = log($total_bigram_freq / (length($phonetic_spaces) - 1));    
	} else {
		$avg_bigram_freq = "-inf"; 
	}
	if ($summed_bigram_transprob > 0){
		$avg_bigram_transprob = log($summed_bigram_transprob / (length($phonetic_spaces) - 1));
	} else {
		$avg_bigram_transprob = "-inf"; 
	}
    
    for (my $i = 0; $i < length($phonetic_spaces) - 2; $i++) {
		$trigram_prob *= $TrigramTransitionalProb{substr($phonetic_spaces,$i,3)};	
		$summed_trigram_transprob += $TrigramTransitionalProb{substr($phonetic_spaces,$i,3)};	
		$total_trigram_freq += $TrigramProb{substr($phonetic_spaces,$i,3)};	
		$total_trigram_centered_prob += $TrigramCenteredConditionalProb{substr($phonetic_spaces,$i,3)};	
    }
	if ($trigram_prob > 0){
		$trigram_prob = log($trigram_prob);
	} else {
		$trigram_prob = "-inf"; 
	}
	if ($total_trigram_freq > 0){
	    $avg_trigram_freq = log($total_trigram_freq / (length($phonetic_spaces) - 2));    
	} else {
		$avg_trigram_freq = "-inf"; 
	}
	if ($summed_bigram_transprob > 0){
		$avg_trigram_transprob = log($summed_bigram_transprob / (length($phonetic_spaces) - 2));    
	} else {
		$avg_trigram_transprob = "-inf"; 
	}
	if ($total_trigram_centered_prob > 0){
	    $avg_trigram_centered_prob = log($total_trigram_centered_prob / (length($phonetic_spaces) - 2));    
	} else {
		$avg_trigram_centered_prob = "-inf"; 
	}
    
    print "***************************************\nFinding neighbors for ".$word."\n";    
    if ($verbose_outputs) {
		# debugging: print similarities to a file
		unless (-e "outputfiles/wordbywordsims") {
		    mkdir ("outputfiles/wordbywordsims");
		}	
		open (WORDSIMSFILE, ">outputfiles/wordbywordsims/$phonetic.sim") or print "Warning-can't create temp file for saving word similaritiess\n";	
    }

    
    # First we'll construct the search string for finding the "traditional" NNB
    #  (words with that are at most one edit different from the test word)
    # Bailey and Hahn use up to 2 edits away; a desirable modification
    #  would be to add this capability
    $neighbors = "(";		
    for ($i = 0; $i < length($phonetic); $i++) {
	$neighbors .= substr($phonetic, 0, $i) . "." . substr($phonetic, $i) . "|";	    
	$neighbors .= substr($phonetic, 0, $i) . "." . substr($phonetic, $i+1) . "|";	    
	$neighbors .= substr($phonetic, 0, $i) . substr($phonetic, $i+1) . "|";	    
    }
    $neighbors .= "$phonetic.)";    
    # print "Neighbors regexp: $neighbors\n";
    $nnb[$number_of_testwords] = 0;
    $neighbor_freq[$number_of_testwords] = 0;	    
    
    # Now we go through the corpus, looking at each word.  The reason we have to do this is that the 
    #   GNM takes into account the contribution, no matter how tiny, of each word in the set.
    @closest_neighbors = undef;   
    for (my $n = 0 ; $n <= 4; $n++) {
	# set the neighbors to a nonexistent word (guaranteed to be less similar)
	$closest_neighbors[$n] = $corpus_size + 1;	
    }
    
    $word_sims = undef;    
    for (my $w = 1; $w <= $corpus_size; $w++) {
	
	# First calculate distance for the GNM
	$distance = distance($phonetic, $phonetic[$w]);
	
	# Similarity, in the Nosofsky model, is a perceptual measure based on distance
	$similarity = exp(-1 * $D_coeff * $distance);	
	# In the GNM, similarity is weighted for frequency
	$freq = log10($freq[$w] + $freq_boost);	
	$weighted_similarity = (($A_coeff * ($freq**2)) + ($B_coeff * $freq) + $C_coeff) * $similarity;	
	# remember this similarity
	$word_sims[$w] = $weighted_similarity;
	$distances[$w] = $distance;	
	
	$summed_similarity[$number_of_testwords] += $weighted_similarity;		
	
	# Handy to keep track of the n most similar words, so humans can check how reasonable it is
	# Check if this one is more similar than the worst of the top batch
	if ($closest_neighbors[4] eq undef or $weighted_similarity > $word_sims[$closest_neighbors[4]]) {
	    # If so, that one gets bumped, and this one gets added
	    $closest_neighbors[4] = $w;	    
	    # Then re-sort, so the new guy takes its proper place
	    @closest_neighbors = sort {$word_sims[$b] <=> $word_sims[$a]} @closest_neighbors;	    
	}
	
	# Then check if this is an "old-fashioned" neighbor
	if ($phonetic[$w] =~ m/^$neighbors$/) {
	    $nnb[$number_of_testwords]++;
	    $neighbors[$number_of_testwords] .= "$words[$w] [$phonetic[$w]]|";	    
	    $neighbor_freq[$number_of_testwords] += log($freq[$w] + $freq_boost);	    
	}
	if ($verbose_outputs) {
	    printf WORDSIMSFILE "$words[$w]\t$phonetic[$w]\t$similarity\t$weighted_similarity\n";	    
	}
	
    }
    # Now adjust the summed similarity to scale it according to the size of the corpus
    $adjusted_similarity[$number_of_testwords] = ($summed_similarity[$number_of_testwords] / $corpus_size);	
    $neighbors[$number_of_testwords] =~ s/\|$//;    
    $neighbors[$number_of_testwords] =~ s/\|/, /g;    
    
    print "$word\tNeighbors:\t$nnb[$number_of_testwords]\tFreq:\t$neighbor_freq[$number_of_testwords]\n\t$neighbors[$number_of_testwords]\n";    
    print "\tGNM similarity:\t$summed_similarity[$number_of_testwords]\n";    
    print "\tNearest neighbors:\n";    
    $nearest_neighbors = "";    
    for (my $n = 0; $n < 5; $n++) {
	printf "\t\t$words[$closest_neighbors[$n]]\t" . $freq[$closest_neighbors[$n]]."\t". $phonetic[$closest_neighbors[$n]] . # "\t$word_sims[$closest_neighbors[$n]]\n";
																"\t%1.5f\n", $distances[$closest_neighbors[$n]];

	$rounded_distance = round($distances[$closest_neighbors[$n]], 5);		
	$nearest_neighbors[$number_of_testwords] .= ", $words[$closest_neighbors[$n]] ($freq[$closest_neighbors[$n]], $rounded_distance)";	# was $word_sims[$closest_neighbors[$n]]
    }    
    $nearest_neighbors[$number_of_testwords] =~ s/^, //;    
    print "\n";    
    if ($verbose_outputs) {
	close WORDSIMSFILE;	
    }
#    printf OUTPUT "$number_of_testwords\t$testwords[$number_of_testwords]\t$bigram_prob\t$trigram_prob\t$avg_bigram_transprob\t$avg_trigram_transprob\t$avg_trigram_centered_prob\t$avg_bigram_freq\t$avg_trigram_freq\t$nnb[$number_of_testwords]\t$neighbor_freq[$number_of_testwords]\t$neighbors[$number_of_testwords]\t$summed_similarity[$number_of_testwords]\t$adjusted_similarity[$number_of_testwords]\t$nearest_neighbors[$number_of_testwords]\n";
    printf OUTPUT "$number_of_testwords\t$testwords[$number_of_testwords]\t$bigram_prob\t$trigram_prob\t$avg_bigram_transprob\t$avg_trigram_transprob\t$avg_trigram_centered_prob\t$avg_bigram_freq\t$avg_trigram_freq\t$nnb[$number_of_testwords]\t$neighbor_freq[$number_of_testwords]\t\t$summed_similarity[$number_of_testwords]\t$adjusted_similarity[$number_of_testwords]\t$nearest_neighbors[$number_of_testwords]\n";
}
close (TESTWORDS);
close (OUTPUT);


#######################################################################################################################
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
  $expand_class_cost = .5;  
  

    # Step 1
    my $n = @s1 ;
    my $m = @s2 ;
    
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
	    $above[$i][$j] = $matrix[$i-1][$j] + ($matrix[$i][0] - $matrix[$i-1][0]);
	    $left[$i][$j] = $matrix[$i][$j-1] + ($matrix[0][$j] - $matrix[0][$j-1]);
	    $diag[$i][$j] = $matrix[$i-1][$j-1] + $cost;

	    $matrix[$i][$j] = ($above[$i][$j] < $left[$i][$j] ?
	       ($above[$i][$j] < $diag[$i][$j] ? $above[$i][$j] : $diag[$i][$j])
	       : ($left[$i][$j] < $diag[$i][$j] ? $left[$i][$j] : $diag[$i][$j]));
	}
    }

    
#    print "Done filling out matrix.\n";        
#    print_matrix();    
    
    # the minimum distance can be read out of cell [$n][$m]
    $min_distance = $matrix[$n][$m];

    # now trace backwards to get the alignment
#    print "Going backwards:\n";    
    $generalized = traceback('', '', '', '', $n, $m,'','');
#    print "\nThe edit distance between \'$s1\' and \'$s2\' = $min_distance.\n(indel cost = $indel_cost, mismatched natural class cost = $expand_class_cost)\n";
#    return $generalized;
     return $min_distance;     
    
    #traceback subroutine within the distance subroutine
    sub traceback {
	# taken from http://www.csse.monash.edu.au/~lloyd/tildeAlgDS/Dynamic/Edit.html
	my $i = shift(@_);
	my $j = shift(@_);
	my $local_cost = 0;	
	
	my $spacing = "      ";

	if ($i > 0 and $j > 0) {
#	    print "Comparing segments s1($i) and s2($j).\n";
	    # if we did a substitution
	    if ($matrix[$i][$j] == $diag[$i][$j]) {
		# check if it was an exact match or not
		if ($s1_segs_only[$i-1] ne $s2_segs_only[$j-1]) {
		    $local_cost = 1 - similarity_table($s1[$i-1],$s2[$j-1]);
		} else {
		    $local_cost = 0;		    		    
		}
		# then peel off and trace back further
		traceback( $i-1, $j-1, $rule);
	    } elsif ($matrix[$i][$j] == $left[$i][$j]) {
		# an insertion -- add an optional element to the unification.
		$local_cost = $matrix[0][$j] - $matrix[0][$j-1];
		traceback($i, $j-1);
	    } else {
		# a deletion -- add an optional element to the unification
		$local_cost = $matrix[$i][0] - $matrix[$i-1][0];				
		traceback($i-1, $j);
	    }
	} elsif ($i > 0) {
	    # exhausted material in string2
	    $local_cost = $matrix[$i][0] - $matrix[$i-1][0];				
	    traceback($i-1, $j);
	} elsif ($j > 0) {
	    # exhausted material in string1
	    $local_cost =  $matrix[0][$j] - $matrix[0][$j-1];				
	    traceback($i, $j-1);
	} else { # i==0 and j==0
		 # We're done!
	    }	
    }

} # end of the distance subroutine
########################################################################################################################
sub similarity_table {
    my @pair = @_;
    #unfortunately, sometimes segments might have parentheses and question marks;
    # get rid of them for the purpose of computing similarity
    $pair[0] =~ s/[\(\)\[\]\?]//g;    
    $pair[1] =~ s/[\(\)\[\]\?]//g;        
    
    @pair = sort @pair;        
    my $longest = ( length($pair[0]) > length($pair[1]) ? length($pair[0]) : length($pair[1]) );    	
    
    my $pair = join('\\',@pair);

     # for now, we'll start by allowing natural classes to align with anything at all
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
	    return 1;	    
	   } else {
# 	    print "Not subsumed; $uniqed is longer than $longest chars long\n";	     	    
	    # otherwise, gotta look it up	    
	    if (exists $similarity_table{$pair}) {
		return $similarity_table{$pair};
	    } else {
#	    print "Warning! unknown pair: $pair\n";
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

########################################################################################################################
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
    print "\t\t";
    for ($j = 0; $j < @matrix[$j]; $j++) { 
	print "$s2[$j]\t";    
    }
    print "\n";    
    
    
    for ($i = 0; $i < @matrix; $i++) {
	if ($i > 0) {
	    print "$s1[$i-1]\t";	
	} else {
	    print "\t";	    	    
	}
	
	for ($j = 0; $j < @matrix[$i]; $j++) {
	    print "$matrix[$i][$j]\t";	    	    
	}	
	print "\n";		
     }
}
########################################################################################################################
sub read_similarities {
    # we'll read in the similarities in $simfile
    open (SIMFILE, "<$simfile") or die "Can't open similarities file: $!\n";        
    print "Reading in similarities.\n";        
    
    # check the first line
    $line = <SIMFILE>;
    chomp($line);        
    if ($line !~ /^(class1|seg1)\t(class2|seg2)\tshared\t(non-shared|total)\tsimilarity$/ ) {
	# uh oh, an invalid similarity file
	print "$line\n";	
	
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

    return 1;        
}
