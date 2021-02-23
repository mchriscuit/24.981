# Infrastructure for a script to learn a rule ordering that converts Italian orthography to a more `phonetic' representation. It takes a set of known rules (in random order), and tries to find a compatible ordering.
# This version does not have any search implemented
import re
import sys
# Two useful functions defined for this purpose
from transliterate import transliterate
from count_correct import count_correct

# For shuffling and random orders
import random


# An option to mark geminates with a colon
geminates_long = True

# This is supervised learning, in which the model is given both the input and the output. These are in separate files: a file with the input to convert, and a file with the answer
input_filename = "italian-words.txt"
check_filename = "italian-words.phonetic.txt"
# We are also given the rules in advance (but we should not assume that the order is correct)
rules_filename = "ItalianRules.txt"
output_rules_filename = "ItalianRules.Ordered.txt"

# First, we read in the rules
rules_file = open(rules_filename, 'r')

# A list to store the rules_file
rules = []
# Read in the rules file and store the rules to a list
for line in rules_file:
	line = line.strip("\n")
	new_rule = line.split("\t")
	# Add the new rule to the list of rules
	rules.append(new_rule)
rules_file.close()

# Now read in the input file
input_file = open(input_filename, 'r')
# We'll make a list of 'inputs' to convert
inputs = []
for line in input_file:
	line = line.strip().lower()
	words = line.split()
	# Add this list of elements to the inputs list
	inputs.extend(words)
input_file.close()

# Now read in the file of correct answers
check_file = open(check_filename, 'r')
# We'll make a list of 'answers', to compare against current predictions
answers = []
for line in check_file:
	line = line.strip().lower()
	words = line.split()
	# Add this list of elements to the inputs list
	answers.extend(words)
check_file.close()

# And open the output file where we'll store the list of ordered rules
output_file = open(output_rules_filename, 'w')


# A rule order is "consistent" if it generates the same output for all of the inputs as the given answer. That is, we want want the number of correctly generated forms to equal the total number of forms
# First, a sanity check, to make sure no user error. The number of inputs and answers should match. It not, squawk and give up.
if len(inputs) != len(answers):
	print ("Warning! different numbers of inputs (%s) and outputs (%s). Cannot continue." % (len(inputs), len(answers)))
	sys.exit()
	
# The start state is random
random.shuffle(rules)

# Start by checking how many are correct at the start state
number_correct = count_correct(inputs, answers, rules, geminates_long)

# Keep track of how many steps it takes to find a consistent order
number_of_iterations = 0;

# Now iterate: change the grammar, see if things improve.
while number_correct < len(inputs):
	# Try changing the rules somehow
	######## NOT IMPLEMENTED IN THIS SCRIPT
	
	# Now try applying the set of rules.
	# Go through the inputs and search and replace, applying the rules in order
	number_correct = count_correct(inputs, answers, rules, geminates_long)

	number_of_iterations += 1
	# Every so often, print how we're doing
	if (number_of_iterations % 100 == 0):
		print( "\tIteration%s: %s correct" % (number_of_iterations, number_correct))

# Now we've got everything right! Just print out the list of rules
print ("Consistent order found in %s iterations." % (number_of_iterations))

for rule in rules:
	output_file.write( "\t".join(rule) + "\n");



