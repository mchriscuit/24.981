# RCD.py = an implementation of Tesar & Smolensky's (1996) Constraint Demotion
#   algorithm.  This is the simplest version, presented pp. 14-22 of the "short version"
# (The actual approach uses the "Comparative tableau" format of Prince 2000, 2002)

import sys
import os
import re
import random
import numpy
import rcd

input_filename = sys.argv[1]
valid_inputfilename = False
while (not valid_inputfilename):
	if input_filename == '':
		input_filename = input("Enter name of input file: ")
	
	if not os.path.isfile(input_filename):
		print("Input file %s does not exist. Please try again." % input_filename)
		# Reset so we prompt for a new filename
		input_filename = ''
	else:
		valid_inputfilename = True
try:
	input_file = open(input_filename, 'r')	
except IOError as error:
	print("Can't open one of the files: %s" % error)
	sys.exit()

# We'll look for other files, with related names
filename_prefix = re.sub(r'\.txt$', '', input_filename)

# Let's open a log file
log_filename = filename_prefix + ".log"
log_file = open(log_filename, 'w')

# And a file to output the predicted distributions
output_filename = filename_prefix + ".out"
output_file = open(output_filename, 'w')

# The first step is to read in the input data.
# For legacy/compatability reasons, we'll assume that it's in the OTSoft tableau format
input_data = input_file.read().splitlines()
input_file.close()

# The first two lines are the constraint names, and the "short" constraint names
# These lines start with three tabs, which we can remove.
constraint_names = input_data[0].strip().split('\t')
short_constraint_names = input_data[1].strip().split('\t')

# Well-formedness check: same number of full and short constraint names?
if len(constraint_names) != len(short_constraint_names):
	print("Warning! Unequal number of full and short constraint names\n\t(Perhaps there is a formatting error in the file?)")

# Now the tableaus and constraint violations

# A list of the inputs
inputs = []
# A list of lists of candidates: each element corresponds to an input, and is a list of candidates for that input
candidates = []
# A list of the winners. Each element corresponds to an input, and the value is the index of the winner, among the candidates 
winners = []
# A list of lists of candidate frequencies: each element corresponds to an input, and is a list of the frequencies of each candidate
frequencies = []
# A list of total frequencies of each input. Each element corresponds to an input, and is the total of the frequencies of candidates for that input.  We don't use the frequencies for RCD, but let's keep the info anyway.
total_freq = []
# A list of lists of lists for the violations. Each element (highest level) correspond to an input, and is a list (candidates) of lists (constraint violations).
candidate_violations = []



# The tableaus are contained in input_data[2:]
# It's tab delimited. Just make it into a big list of lists
all_tableaus = [ line.split('\t') for line in input_data[2:] ]
log_file.write('Length of tableau data: %s\n' % len(all_tableaus))

# There's probably a more efficient way to do this, but let's just go through the list of lists and find all the inputs and candidates
for line in range(0,len(all_tableaus)):
	# Check if this line contains a new input. New inputs are listed in the first column.
	if all_tableaus[line][0] != '':
		# We have a new input. Remember it.
		inputs.append(all_tableaus[line][0])
		# And remember the candidate associated with it
		candidates.append( [ all_tableaus[line][1] ] )
		# And remember the frequency associated with this candidate
		if all_tableaus[line][2] == '':
			frequencies.append( [ 0 ] )
		else:
			frequencies.append( [ int(all_tableaus[line][2]) ])

		# Keep track of the total frequency of this input, as well. Append a new entry to the total_freq list, which is equal to whatever we just recorded as the frequency of this candidate
		total_freq.append(frequencies[-1][-1])
			
		# We want the violations to be integers.  We assume that if it's not a number, then it's 0, which is blank. (This could be dangerous)
		candidate_violations.append( [[ int(x or 0) for x in all_tableaus[line][3:]]] )
		
	else:
		# This is an additional candidate for the previous current input. Remember the candidate
		candidates[-1].append( all_tableaus[line][1])
		
		# Remember the frequency
		if all_tableaus[line][2] == '':
			frequencies[-1].append(0)
		else:
			frequencies[-1].append( int(all_tableaus[line][2]))
		
		# Remember the constraint violations
		candidate_violations[-1].append([ int(x or 0) for x in all_tableaus[line][3:]])  	

		# If we've already seen non-zero candidate frequencies for this input, and the current candidate also has a frequency > 0, then we have multiple winners. That makes this tableau non-OT compatible.  We could just quit and tell the user to fix it.  Another option would be to assume that the candidate with the highest frequency is the "winner", though I don't know if that's really a sensible assumption to make
		if total_freq[-1] > 0 and frequencies[-1][-1] > 0:
			print( 'Warning: multiple winners for input %s (/%s/)' % (len(inputs), inputs[-1]) )
			print( 'RCD cannot handle free variation; please fix this and try again.' )
			sys.exit()
		total_freq[-1] += frequencies[-1][-1]
		
	if frequencies[-1][-1] > 0:
		print('Winning form for input /%s/: %s' % (inputs[-1],candidates[-1][-1]))
		winners.append(len(candidates[-1])-1)

# Now we construct the set of mdp's, in comparative tableau format.
mdps = []
for i in range(0,len(inputs)):
	for cand in range(0,len(candidates[i])):
		if cand != winners[i]:
			print("MDP for input %s, candidate %s" % (i,cand))
			mdp = []
			for con in range(0,len(constraint_names)):
				if candidate_violations[i][cand][con] > candidate_violations[i][winners[i]][con]:
					mdp.append('W')
				elif candidate_violations[i][cand][con] < candidate_violations[i][winners[i]][con]:
					mdp.append('L')
				else:
					mdp.append('')
			print(mdp)
			mdps.append(mdp)

# Now we apply RCD.  applyrcd() takes a list of unexplained mdp's, and a list of the constraints remaining to be ranked, and a list of existing strata.  All of the mdp's are initially unexplained, so we pass the entire set of mdp's. All of the constraints are initially unranked, so we also pass a list of all constraints, and an empty list of strata.
unranked = list(range(0,len(constraint_names)))

ranking = rcd.rank(mdps, unranked, [])
print('Resulting ranking:\n%s\n' % ranking)

# Report the results. Let's write them to the console, and to the output file
output_file.write('Results of applying RCD to the file %s\n' % input_filename )
print('\nResults of applying RCD to the file %s' % input_filename )
# Check if the ranking was successful or not.
if ranking[-1][-1] == -1:
	output_file.write('****A ranking contradiction prevented RCD from arriving at a working ranking. The data is not OT-consistent.\n')
	print('****A ranking contradiction prevented RCD from arriving at a working ranking. The data is not OT-consistent.')
	
for s in range(0,len(ranking)):
	output_file.write("\nStratum %s:\n" % (s+1))
	print("\nStratum %s:" % (s+1))
	stratum = ranking[s]
	
	for constraint in stratum:
		if constraint == -1:
			output_file.write('***** Ranking paradox *****\n')		
			print('***** Ranking paradox *****')
		else:
			output_file.write('\t%s\n' % (constraint_names[constraint]))
			print('\t%s' % (constraint_names[constraint]))

log_file.write('Inputs:\n%s\n\n' % inputs)
log_file.write('Candidates:\n%s\n\n' % candidates)
log_file.write('Candidate frequencies:\n%s\n\n' % frequencies)
log_file.write('Winners:\n%s\n\n' % winners)
log_file.write('Constraint violations:\n%s\n\n' % candidate_violations)
log_file.write('Mark data pairs:\n%s\n\n' % mdps)
log_file.write('Ranking:\n%s\n\n' % ranking)


# Close the output files
log_file.close()
output_file.close()

