README FILE for alignment.pl
Last modified 4/13/2003
Adam Albright, albright@ucsc.edu

This archive contains the script alignment.pl, which aligns the segments in two words according to their phonetic similarity.  When you run it, it asks for the words to compare, and prints out their optimal alignment.

EXECUTING THE PROGRAM:
You must have a working Perl installation (www.perl.com).  If you are
using Unix or Mac OS X, you already have this; if you are using Mac OS
9 or earlier, you will need to download MacPerl
(http://www.macperl.com/).  If you are using Windows, ActiveState Perl
is recommended (http://www.activestate.com/Products/ActivePerl/).

To invoke the script, simply run alignment.pl, as you would any other perl script.  (Either by typing `perl alignment.pl' at the prompt, by selecting 'run' from the menu, etc.)

There is an optional argument, which is the weighted cost of performing an insertion or a deletion.  This weight is typically between 0 and 1; the smaller the indel value, the more likely the program is to consider mismatches as insertions and deletions, rather than forcing dissimilar segments to be aligned with one another.  The default is set to .6, which seems to yield intuitive alignments in a large number of cases. This program requires similarity tables, as written by SimilarityCalculator.pl (Available for download from http://ling.ucsc.edu/~albright).  I have included some default files for English (English.stb, English.cls, and English.sim).  If you want to use these default similarity files, just hit <RETURN> when prompted for a similarity file.  The alphabet of symbols used for English phonemes is described in the text file English-key.txt   (The symbols are not always incredibly intuitive, and might be bit hard to type at a command prompt on some platforms.  They were designed to correspond as much as possible to the correct IPA symbols in the SIL IPA fonts; if you are not aiming to paste your results into a document using these fonts, you may find it easier to go back to SimilarityCalculator.pl, reassign the symbols in the features file, and rerun the similarity calculator to yield new .stb and .cls files with the symbols you want.)

Once you have told the program what similarity files to use, it will prompt you for pairs of strings to compare.  It will ask for two strings, print out their optimal alignment, ask for two more strings, etc.  To exit, just press <RETURN> when prompted for the first string.

The heart of the program is the distance(string1,string2) subroutine; It would be useful to extend this script by allowing it to read in a file of a bunch of words, and letting it automatically calculate their relative similarity.   (Or, let the user enter a word and have it return the k most similar words.  Ideally, it would also be a Perl module, rather than a  stand-alone script. For details of string edit distance, see Kruskal (1988)    Kruskal (1983) An overview of sequence comparison.  In Sankoff, D. and           J. Kruskal (Eds.) (1999). Time warps, string edits, and           macromolecules. Stanford, CA: CSLI Publications.For details of phonetic similarity, see Frisch, Broe, and Pierrehumbert (1997):    Frisch, Stefan, Michael Broe, and Janet Pierrehumbert (1997) Similarity           and Phonotactics in Arabic.  Available for download from           http://roa.rutgers.edu/view.php3?roa=223

Questions? comments?  Write to me at: albright@ucsc.edu