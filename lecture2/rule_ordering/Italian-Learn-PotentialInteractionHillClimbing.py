# Script to learn a rule ordering that converts Italian orthography to a more `phonetic' representation. It takes a set of known rules (in random order), and tries to find a compatible ordering.
# This version does a random walk, changing just one relative ordering of two randomly selected (possibly non-adjacent) rules at a time.
import re
import sys
# We'll use "shuffle" and "randint" to randomly change the rule order
import random

# Two useful functions defined for this purpose
from transliterate import transliterate
from count_correct import count_correct

# Some options for hill-climbing
accept_better = 1
accept_equal = 1
accept_worse = 0

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
	# Try changing the rules somehow.  
	# In this script, we swap the order of a pair of adjacent rules.  Keep searching until we find two we can swap.  Since it's hill climbing, the swap is a proposal, which we'll do on a copy
	new_rules = rules
	
	successful_swap = False
	
	while successful_swap == False:
		# Pick a random rule 
		i = random.randint(0,len(new_rules)-1)
		# Now pick another random rule, with the stipulation that it be a distinct rule (don't swap a rule with itself)
		j = i
		while (j == i):
			j = random.randint(0,len(new_rules)-1)
		# Now check whether the rules could interact. 
		# A rough heuristic: Check if rule 2's struc desc contains any of the segments in rule 1's struc desc
		# The segments in rule 2's struc desc:
		rule1_strucdesc = new_rules[i][0]
		rule1_strucdesc = "[" + re.sub(r'[^\w]', '',rule1_strucdesc) + "]"
		rule2_strucdesc = new_rules[j][0]
		# The check
		if re.compile(rule1_strucdesc).match(rule2_strucdesc):
#			print( "Potential interaction:\t%s\t%s" % (rule1_strucdesc, rule2_strucdesc))
			new_rules[i], new_rules[j] = new_rules[j], new_rules[i]
			successful_swap = True

	# Now try applying the set of rules.
	# Go through the inputs and search and replace, applying the rules in order
	new_number_correct = count_correct(inputs, answers, new_rules, geminates_long)
	
	# Keep the new rule order if it's better than the old order
	if new_number_correct > number_correct and random.random() >= 1-accept_better:
		rules = new_rules
		number_correct = new_number_correct
	# If it's equal, keep it at a predetermined probability
	elif new_number_correct == number_correct and random.random() >= 1-accept_equal:
		rules = new_rules
		number_correct = new_number_correct
	# Otherwise, with some very small probability accept it anyway
	elif random.random() > 1-accept_worse:
		rules = new_rules
		number_correct = new_number_correct


	number_of_iterations += 1
	# Every so often, print how we're doing
	if (number_of_iterations % 100 == 0):
		print( "\tIteration %s: %s correct" % (number_of_iterations, number_correct))

# Now we've got everything right! Just print out the list of rules
print ("Consistent order found in %s iterations." % (number_of_iterations))

for rule in rules:
	output_file.write( "\t".join(rule) + "\n");



