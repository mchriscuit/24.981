# File to count the number of neighbors of test words
import re

celex_filename = "CelexLemmasInTranscription-DISC.txt"
celex = open(celex_filename, 'r')

test_filenames = ["AlbrightHayes2003.DISC.txt"]
testoutput_filename = "AlbrightHayes2003.Neighbors.txt"
test_output = open(testoutput_filename, 'w')

####### First read in the corpus
# We'll make a list of all the lemmas
lemmas = []

# Now go through the celex file and get all the lemmas
for line in celex:
	lemma_id, freq, orthog, disc, phon2 = line.split("\t")
	lemmas.append(disc)
celex.close()

# In order to use regex.findall, the simplest thing is just to put the whole corpus into a long space-delimited string
lemmas_string = "\t".join(lemmas)

for test_filename in test_filenames:
	test_file = open(test_filename, 'r')
	# Aesthetic: differentiate which test forms came from which file, but label them according to the filename minus the .txt suffix
	condition = test_filename.replace(".txt","")

	for line in test_file:
		line = line.strip()
		# We assume that each line is a single word
		# We build the regex for neighbors_regex
		neighbors_regex = []
		# Go from start to end of line. (In the last position, this will harmlessly add some redundant duplicates)
		for c in range(0, len(line)+1):
			# First neighbor is the insertion
			neighbors_regex.append(line[:c] + '\S' + line[c:])
			# Then substitution and deletion
			neighbors_regex.append(line[:c] + '\S' + line[c+1:])
			neighbors_regex.append(line[:c] + '\S?' + line[c+1:])

		neighbors_regex_string = '[\b\s](' + '|'.join(neighbors_regex) + ')[\b\s]'
		
		neighbors = re.findall(neighbors_regex_string, lemmas_string)
		test_output.write(line + "\t" + str(len(neighbors)) + "\t" + "; ".join(neighbors) + "\n")
