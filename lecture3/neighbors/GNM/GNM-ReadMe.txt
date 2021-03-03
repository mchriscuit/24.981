****************************
README file for GNM.pl
by Adam Albright, albright@mit.edu
Last updated 12 Aug, 2005

This script performs the neighborhood similarity calculations described in 
Bailey and Hahn (2001).  In particular, it calculates wordlikeness scores 
based on two methods: 
	(1) "traditional" number of neighbors (defined as words that can be gotten 
	with one edit)
	(2) B&H's "Generalized Neighborhood Model", based on Nosofsky's GCM

For "traditional" neighborhood density, Bailey and Hahn found it necessary 
to go to a distance of two edits; this program only does the more 
traditional distance of 1 edit (but could be easily modified to accommodate 
more)

In order to calculate similarity to existing words, the program needs a 
set of similarity values for segments, using the same transcription system 
as the corpus and test words.  Some default files for English are included
in the 'similarity' directory.

The features files are the .txt files, designed for use with the perl file
SimilarityCalculator.pl
   They produce the output files .stb, .cls, etc.
   The transcription scheme is the Celex DISC-bet (see the excel file for details)

If you want to use the program for a language other than English (or create new
values for English), you can do this by creating a new features file with 
phonological feature specifications for the inventory of segments that occur in the 
training corpus. (Note that each phoneme must be a single character--e.g., 
'C' instead of 'tS')   See the file EnglishFeatures.txt for an example (the
quotes and commas are not required).  Then, run the file SimilarityCalculator.pl
to generate similarity values, using the shared/unshared natural classes
method of Frisch, Pierrehumbert & Broe (2004).   More details on running the
program can be found in the ReadMe file of the SimilarityCalculator.zip archive.  

For problems or questions, please contact me: albright@mit.edu


****************************
USAGE:

perl EnglishNeighbors.pl [testwordsfile]

	example: perl EnglishNeighbors.pl TestWords.txt

When invoked, the program will ask you for the name of a similarity file 
(simply hitting enter will call up the default EnglishFeatures.stb, 
provided).  You will then be prompted for the name of the output file.
If all goes well, the program will then start calculating similarities and 
finding best neighbors.
Caveat: since this requires aligning every test word with every word in the 
corpus, independently, it can take *quite* a while.  It takes a really 
long time on my computer (hours)

The output file has the following fields:

Biphone prob: phonotactic likelihood, based on conditional probability of biphones
Triphone prob: same, but for triphones
NNB: number of neighbors (by the traditional one-edit definition)
NNB freq:  combined frequency of these neighbors
GNM sim: the similarity value from Bailey and Hahn's GNM
GNM sim (adj): the similarity value, adjusted by dividing by the size of 
	the corpus (to permit comparison across corpora of different sizes)
Nearest neighbors: the five most similar words in the calculation

****************************
PARAMETERS:
There are some parameters which are set at the top of the script; these can 
be edited manually to try different parameter settings.  In particular:

	$indel_cost: the cost of insertions and deletions in alignments
		(Bailey & Hahn say .6 to 1 all work, .7 is best)

	$A_coeff, $B_coeff, $C_coeff: these are for frequency weighting.
		(B&H try to give mid-freq words priority with a quadratic
		 equation: A*freq^2 + B*freq + C.  They don't say what values, 
		 so I assumed 1 for all.)
		 To turn off frequency weighting, set A and B to 0, C to 1.

	$p_exp: an exponent, must be 1 or 2 in Nosofsky's GCM.
		Albright & Hayes (2003) found that 1 worked better; B&H omit
		it altogether.  So, I set it to 1, but left it as a variable
		to permit future exploration.

	$D_coeff: this is related to Nosofsky's "s" parameter, which models
		sensitivity (how quickly the influence of less similar words drops
		off).  In Nosofsky's formulation, "s" is a denominator (distance 
		is divided by it).  B&H multiply by a coefficient D instead.
		They don't say what they used (maybe 1?).  Albright & Hayes found
		that .4 was best for s, which would translate to D = 2.5
		A good default value might be 2, equivalent to s of .5
		The value of D will greatly affect the range of GNM sim values.

	$freq_boost: to avoid zero's, B&H add a constant to frequencies.
		For some reason, they add 2, so I stick with that.  
		(.5 or 1 would be more usual)
****************************
