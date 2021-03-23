# Script to do simple perceptron learning (stochastic gradient descent) for a maximum entropy model
# This follow's Jaeger's proposal for applying stochastic gradient ascent to learn weights for a maxent grammar
import sys
import os
import re
import random
import numpy
try:
	import matplotlib.pyplot as plt
	pyplot_installed = True
except Exception as e:
	pyplot_installed = False

# quick little function to check whether something is a number (specifically, a float).  This specific version came from: https://stackoverflow.com/questions/736043/checking-if-a-string-can-be-converted-to-float-in-python
def isfloat(value):
  try:
    float(value)
    return True
  except ValueError:
    return False

# Some parameters
number_of_learning_trials = 50000
initial_markedness_weight = 10
initial_faithfulness_weight = 0
initial_weight = 0
initial_plasticity = .1
plasticity_decrement = 0
weights_file_interval = 10

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

# Store indices of constraints so we can do "reverse look-up" on them
constraint_index = {}
for c in range(0,len(constraint_names)):
	constraint_index[constraint_names[c]] = c
# For convenience, store the number of constraints
number_of_constraints = len(constraint_names)

# Now the tableaus and constraint violations

# A list of the inputs
inputs = []
# A list of lists of candidates: each element corresponds to an input, and is a list of candidates for that input
candidates = []
# A list of lists of candidate frequencies: each element corresponds to an input, and is a list of the frequencies of each candidate
frequencies = []
# A list of total frequencies of each input. Each element corresponds to an input, and is the total of the frequencies of candidates for that input
total_freq = []
# A list of lists of lists for the violations. Each element (highest level) correspond to an input, and is a list (candidates) of lists (constraint violations).
candidate_violations = []

# Also, for learning: let's make a "corpus" that the learner can sample from, to simulate receiving data (input/output pairs) in proportion to the given frequencies
training_inputs = []
training_outputs = []


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

		# If we've already seen non-zero candidate frequencies for this input, and the current candidate also has a frequency > 0, then we have multiple winners. Maybe that's intended, but in case it's unintentional, report the situation.
		if total_freq[-1] > 0 and frequencies[-1][-1] > 0:
			print( 'Warning: multiple winners for input %s (/%s/)' % (len(inputs), inputs[-1]) )
		total_freq[-1] += frequencies[-1][-1]
		
	# Whether this is a new input or one we've already seen, if the frequency is > 0, we need to include it as part of the traininɡ data (positive evidence)
	training_inputs.extend( [len(inputs)-1] * frequencies[-1][-1] )
	training_outputs.extend( [ len(candidates[-1])-1 ] * frequencies[-1][-1] )
		
		


log_file.write('Inputs:\n%s\n\n' % inputs)
log_file.write('Candidates:\n%s\n\n' % candidates)
log_file.write('Candidate frequencies:\n%s\n\n' % frequencies)
log_file.write('Constraint violations:\n%s\n\n' % candidate_violations)
log_file.write('Length of training data: %s inputs, %s outputs\n\n' % (len(training_inputs), len(training_outputs)))

# Also, in order to determine an initial set of weights (or, impose a bias of M >> F), we need to find out what the intended weighting for each constraint is.
# We'll assume that this information is stored in a .constraints file, with the same name
initial_weights = [ '' ]*len(constraint_names)

filename_prefix = re.sub('\.[^\.]*$', '', input_filename)
constraints_filename = filename_prefix + ".constraints"
constraints_file = open(constraints_filename, 'r').read().splitlines()
for line in constraints_file:
	name, type = line.split('\t')
	if re.match('^[Mm]', type):
		type = 'M'		
	elif re.match('^[Ff]', type):
		type = 'F'
	elif re.match('^[Rr]a?nd', type):
		type = 'random'
	# Otherwise, it's not Markedness or Faithfulness. If it's a number, that's just going to be the initial weight. Otherwise, complain that it's an unknown type.
	elif not isfloat(type):
		print( "Warning: Can't understand constraint type '%s'  in constraints file %s. I will assume the default weight of %s." % (type, constraints_filename, initial_weight))
		print( "Please fix this and try again.")
		type = ''
	
	try:
		initial_weights[ constraint_index[name] ] = type
	except Exception as error:
		print( "Unknown constraint %s in constraints file: %s" % (constraint_index[name], error))

log_file.write( "Constraint types: %s\n\n" %  initial_weights)


# Initialize the weights to their initial values
weights = [ 0 ] *len(constraint_names)
for c in range(0, len(constraint_names)):
	try:
		if isfloat(initial_weights[ c ]):
			weights[c] = initial_weights[ c ]
		elif initial_weights[ c ] == 'F':
			weights[c] = initial_faithfulness_weight
		elif initial_weights[ c ] == 'M':
			weights[c] = initial_markedness_weight
		elif initial_weights[ c ] == 'random':
			weights[c] = random.random()
		else:
			weights[c] = initial_weight
	except Exception as error:
		print( "Constraint %s has no given constraint type: %s" % (c, error) )
log_file.write( 'Initial weights: %s\n\n' % weights)

# Now for learning
# Let's keep track of the empirical sampled frequencies of each candidate for each input. The following is inefficient, but easy to read.
sampled_freq = [  ] 
for i in range(0,len(inputs)):
	sampled_freq.append([ ])
	for c in range(0,len(candidates[i])):
		sampled_freq[i].append(0)


# The file for the weights during learning
weights_filename = filename_prefix + ".weights"
weights_file = open(weights_filename, 'w')
weights_file.write( 'Time\t%s\n' % '\t'.join(constraint_names))
weights_file.write( '0\t%s\n' % ( '\t'.join([ str(x) for x in weights])) )
weights_history = []
weights_history.append(weights[:])
weights_history_intervals = [0]

# Start with the initial plasticity
current_plasticity = initial_plasticity
for t in range(0, number_of_learning_trials):
	# Plasticity decrements: there are various options, but the simplest is to just scale a little
	if current_plasticity > 0:
		current_plasticity *= (1-plasticity_decrement)
	

	# a trial starts with an (input,output) pair sampled randomly from the training corpus	
	sample_input = random.randint(0,len(training_inputs)-1)
	try:
		datum_input = training_inputs[sample_input]
		datum_output = training_outputs[sample_input]
	except Exception as e:
		print('Sampling error: %s' % sample_input)
	# Remember what we've sampled, so we can report the trained frequencies at the end
	sampled_freq[datum_input][datum_output] += 1
	
	# Now we check what output we would actually produce given these weights
	# The input is inputs[datum_input]
	# The candidates are candidates[datum_input]
	# The number of candidates is len(candidates[datum_input]) 
		
	# The probability of each candidate is determined by taking its 'maxent score' (exp(-weighted sum of violations)) and dividing it by the sum of all scores (normalization term)
	#	(The 'negative sum' is assuming positive violation values; Jaeger assumes negative, so omits the minus sign)
	
	# Since the grammar produces a probability distribution, and not a unique output, on each learning trial, we simply sample from that distribution to see what the grammar feels like producing for this input at this moment
	# We calculate the maxent scores, given the current weights, for all candidates
	maxent_scores = []
	for c in range(len(candidates[datum_input])):
		weighted_violations = [ v*w for v,w in zip(candidate_violations[datum_input][c] , weights) ]
		maxent_scores.append( numpy.exp(-sum(weighted_violations)))		
	current_probs = [ score/sum(maxent_scores) for score in maxent_scores ]
	
	# Now we sample from that distribution.
	# One inefficient, but workable way of doing that is to make a long list, in which each candidate is represented in proportion to its predicted probability. Then we choose a random element from that list
	predicted_distribution = []
	for c in range(len(candidates[datum_input])):
		predicted_distribution.extend( [c]*int(current_probs[c]*1000) )

	sample_output = predicted_distribution[random.randint(0,len(predicted_distribution)-1)]

	# Error-driven learning: if the predicted output is the same as the sampled output, we had the right answer, and we don't need to adjust the grammar
	# Learning happens when the predicted output does not equal the given output
	if sample_output != datum_output:
#		log_file.write('\nTrial %s: Learning is required, for input %s /%s/.\n' % (t, datum_input, inputs[datum_input]))
#		log_file.write('\tMom said: [%s]\n' % (candidates[datum_input][datum_output]))
#		log_file.write('\tI would have said [%s], and I thought that [%s] only had a probability of %s \n' % (candidates[datum_input][sample_output], candidates[datum_input][datum_output], current_probs[datum_output]))

	# Adjust the weights in proportion to the discrepancy (this is stochastic gradient ascent)
		for c in range(len(weights)):
			# The Jaeger update rule 
			try:
				weights[c] = weights[c] + current_plasticity*(float(candidate_violations[datum_input][sample_output][c]) - candidate_violations[datum_input][datum_output][c] )
			except Exception as e:
				print('%s: %s, %s (%s, %s)' % (e, datum_input, sample_output, candidate_violations[datum_input][sample_output][c], candidate_violations[datum_input][datum_output][c]))
		
			# A constraint: weights never go negative
			if weights[c] < 0:
				weights[c] = 0

	# Save the current weight vector at pre-specified intervals
	if t % weights_file_interval == 0:
		weights_file.write( '%s\t%s\n' % (t, '\t'.join([ str(x) for x in weights])) )
		weights_history_intervals.append(t)
		weights_history.append(weights[:])


	
####### Done with learning, let's report the weights and test the grammar	
# First, report the weights to the weights file, and the console
weights_file.write( '%s\t%s\n' % (number_of_learning_trials, '\t'.join([ str(x) for x in weights])) )
weights_history_intervals.append(number_of_learning_trials)
weights_history.append(weights[:])

print("\nWeights after learning:")
log_file.write("Weights after learning:\n")
for c in sorted(range(0,len(constraint_names)), key=lambda x: weights[x], reverse=True):
	print('\t%s\t%s' % (constraint_names[c], weights[c]))
	log_file.write('\t%s\t%s\n' % (constraint_names[c], weights[c]))

#  Now test the grammar on what it derives for the words in the input file.  This means test it on what it would produce for each attested word, and possibly any wug words (which are entered by including URs and candidates, but not marking a freq > 0 by any of the candidates)
log_file.write('\nTesting the final grammar. (See .out file for results)\n')
output_file.write('Input\tOutput\tHarmony\tMaxEnt Score\tPredicted Prob\tGiven Prob\tTrained Freq\n')

for i in range(0,len(inputs)):
	input = inputs[i]
	summed_violations = []
	maxent_scores = []
	# For each input, we'll go through all the candidates and calculate the weighted sum of violations.  We need the sum in order to calculate probabilities, so the simplest thing to do is to go through the candidates for each input twice (once to calculate weighted violations, and once to calculate probabilities and print them out)
	for c in range(0,len(candidates[i])):
		weighted_violations = [ v*w for v,w in zip(candidate_violations[i][c] , weights) ]
		summed_violations.append(sum(weighted_violations))
		maxent_scores.append( numpy.exp(-sum(weighted_violations)))

	# Now that we've calculated the sums for all candidates, we can calculate maxent probabilities and print the results
	for c in range(0,len(candidates[i])):	
		candidate = candidates[i][c]
		output_file.write( '/%s/\t[%s]\t%s\t%s\t%s\t%s\t%s\n' % (input, candidate,  summed_violations[c], maxent_scores[c], (maxent_scores[c]/numpy.sum(maxent_scores)), (frequencies[i][c]/numpy.sum(frequencies[i])), sampled_freq[i][c] ) )
		
# Close the output files
weights_file.close()
log_file.close()
output_file.close()

# Now let's make a plot, if we can:
if pyplot_installed:
	for c in range(len(weights)):
		plt.plot(weights_history_intervals, [row[c] for row in weights_history], label=short_constraint_names[c] )
	plt.xlabel('Time')
	plt.ylabel('Weight')
	plt.legend(loc=0)
	# savefig() must come before show()
	plt.savefig(filename_prefix+'.pdf', format='pdf')
	plt.show()



