# A script to calculate Frisch/Broe/Pierrehumbert similarity, based on a feature file
import sys
import re
import os.path
import string
from FeatureFileTools import cleanup_line

# The name of the feature file to use
if len(sys.argv) > 1:
	feature_filename = sys.argv[1]
else:
	feature_filename = input('Enter name of feature file: ')
	feature_filename = feature_filename.strip()

# Try opening the file
valid_feature_file = 0
while valid_feature_file == 0:	
	try:
		feature_file = open(feature_filename, 'r')
		valid_feature_file = 1
	except IOError as e:
		print ("Could not read features file %s: %s" % (feature_filename, e))
		feature_filename = input('Enter name of feature file: ')


# Now also the output files for the similarity table, natural classes, and similarity matrix.  
# First, find the "prefix" of the feature filename
filename_prefix = re.sub(r'\.[^\.]*$', '', feature_filename)
log_filename = filename_prefix + '.log'
similarity_table_filename = filename_prefix + '.stb'
natural_class_filename = filename_prefix + '.cls'
sim_matrix_filename = filename_prefix + '.sim'

# Try opening the files

# Check if they exist
valid_files = False
while valid_files == False:
	if os.path.isfile(similarity_table_filename) or os.path.isfile(natural_class_filename) or os.path.isfile(sim_matrix_filename):
		print( "\nFile %s, %s, or %s already exists." % (similarity_table_filename, natural_class_filename, sim_matrix_filename) )
		print( "What should I do?" )
		print( "\t1. Overwrite old files") 
		print( "\t2. Save files under a new name")
		response = input("? ")
	
		# If the response is '1', we can just go on (nothing to do)
		if response == "1" or response == "1.":
			valid_files = True
		elif response == "2" or response == "2.":
			filename_prefix = input( "Enter new prefix for filenames: " ).strip()
			# If the newly given filename prefix ends in .stb, .cls, .sim then remove it
			filename_prefix = re.sub(r'\.(stb|cls|sim)$', '', filename_prefix)
			log_filename = filename_prefix + '.log'
			similarity_table_filename = filename_prefix + '.stb'
			natural_class_filename = filename_prefix + '.cls'
			sim_matrix_filename = filename_prefix + '.sim'
	else:
		valid_files = True

try:
	log_file = open(log_filename, 'w')
	similarity_table_file = open(similarity_table_filename, 'w')
	natural_class_file = open(natural_class_filename, 'w')
	sim_matrix_file = open(sim_matrix_filename, 'w')

# Ungracefully, if there's a problem, quit (rather than giving the user another chance)
except IOerror as error:
	print("Error opening output files: %s" % error)
	sys.exit()


print('Select type of natural class descriptions to use:\n\t1. Contrastive underspecification (e.g., [u] = [+back, +high])\n\t2. Fully specified (e.g., [u] = [+back, +high, -low, +round])\n(The similarity results will be the same either way)')
valid_specification = False
while valid_specification == False:
	specification = input('? ')
	specification = specification.strip()
	if specification == '1':
		specification = 'minimal'
		valid_specification = True
	elif specification == '2':
		specification = 'maximal'
		valid_specification = True
	else:
		print("Sorry, I couldn't understand your response.  Please enter 1 or 2.")

print("\nInclude the maximal superclass? (That is, the class that includes all known segments)\n\t1. Automatically include (a la Frisch)\n\t2. Exclude if not a genuine class (a la Zuraw) \n(These options yield slightly different absolute similarity values, but the same relative similarities)")	
valid_superclass = False
while valid_superclass == False:
	superclass = input('? ')
	superclass = superclass.strip()
	if superclass == '1':
		superclass = 'include'
		valid_superclass = True
	elif superclass == '2':
		superclass = 'exclude'
		valid_superclass = True
	else:
		print("Sorry, I couldn't understand your response.  Please enter 1 or 2.")	

# Now we'll read the feature file
print ("Feature file: %s" % feature_filename)
feature_lines = feature_file.readlines()

# The first line contains the feature names
firstline = cleanup_line(feature_lines[0])
# also for some reason these often begin without tabs, but just in case
# they do have tabs
firstline = re.sub(r'^\s+', '', firstline)
features = firstline.split('\t')
number_of_features = len(features)
print("There are %s features in this file" % number_of_features)
print(firstline)

# Now the rest of the file, which contains the feature values
feature_matrix = {}
segments = []

for line in feature_lines[1:]:
	line = cleanup_line(line)
	seg, *values = line.split("\t")
	
	# If the segment is a dollar sign, it needs to be protected
	if seg == '$':
#		seg = '$$'
		print( "Segment $ may cause trouble.")
	# Skip lines with a blank segment
	if seg == '':
		continue
		
	# Also ignore value-less lines, process only those lines with feature values
	if len(values) > 0:
		# If the first value is nothing but digits (and is not simply a 0), or is completely empty, it's a code (assuming no scalar features!! but this script can't handle scalar features, anyway)
		if (re.match(r'^\d*$', values[0]) and values[0] != 0) or values[0] == "":
			del values[0]
		
		print('Segment %s: %s' % (seg, ','.join(values)))
		
		# Store the segments in a list of segments, for convenience
		segments.append(seg)
		
		# And remember the feature values
		feature_matrix[seg] = values
	
		# A consistency check
		if len(values) != number_of_features:
			print('Warning! segments %s has an incorrect number of features. \(%s instead of %s\)' % (seg, len(values), number_of_features))	

feature_file.close()	
# Something we could do here: print the feature matrix to the log file, to double-check that it's been read correctly

# Now construct the matrix of strings for unitary classes.
# The structure for this will be: a list with the same length as the number of features.  Each entry will itself be a list, of length two: the '-' segments and the '+' segments

# The following initializes a list of the necessary size
unitary_classes = [ [[],[]] for i in range(number_of_features)]

for seg, values in feature_matrix.items():
	for f in range(0,len(values)):
		if values[f] == '-':
			unitary_classes[f][0].append(seg)
		elif values[f] == '+':
			unitary_classes[f][1].append(seg)
		elif values[f] != '0':
			print( 'Warning! Ignoring illegal feature value, number %s, for segment %s: %s'% (f,seg,values[f]))

log_file.write('---------------------------------------------------------\nUnitary natural classes: \n')
for f in range(number_of_features):
	for val in (1,0):
		log_file.write('[')
		if val==1:
			log_file.write('+')
		else:
			log_file.write('-')
		log_file.write('%s]: %s\n' % (features[f], ' '.join(unitary_classes[f][val])))

# Now that we have the unitary classes for all features, we can check which ones are unique, add them to the list of natural classes, and iterate from there
classes = []
number_of_classes = 0

# A dictionary for how to describe each class, and how many features it takes
descs = {}
desc_lengths = {}
for f in range(len(unitary_classes)):
	# We need to consider both positive and negative values
	for val in (0,1):
		myclass = ' '.join(sorted(unitary_classes[f][val]))
		# Sort the order of the segments, so we're sure to always have the same representation for the same set of segments. Let's separate segments with spaces, so that we can have segments with transcriptions longer than one character
#		myclass = ' '.join(sorted(set(myclass)))
		# The perl version had a line here to eliminate spaces that somehow sometimes creep in; not sure how that would happen, so not including it here for now
		# If we've already discovered this class, it will have a description. If the class doesn't have a description, we need to add it
		if myclass not in descs:
			# Remember this class
			classes.append(myclass)
			number_of_classes += 1
			
			# Add the description to the dictionary of descriptions
			if val == 1:
				desc = '+' + features[f]
			else:
				desc = '-' + features[f]
			descs[myclass] = desc
			
			# The unitary classes have length 1
			desc_lengths[myclass] = 1

# Remember how many distinct unitary classes we ended up with
number_of_unitary_classes = number_of_classes


# OK, so far we have a set of natural classes that includes all of the unique unitary classes.
# The next step is to combine them to create classes with more complex descriptions.
# We'll go through the ones we already know and compare.
log_file.write( "Number of distinct unitary classes = %s\n\n" % number_of_unitary_classes)

number_considered = 0
for c1 in range(number_of_unitary_classes):
	old_number_of_classes = number_of_classes
	for c2 in range(c1+1,number_of_classes):
		number_considered += 1
		
		# The perl script has some code for estimating how many more classes there are to consider, to give the user an estimate of progress. Skip this for now
		# We find the candidate class, which is the intersection of the two classes
		candidate_class = ' '.join(sorted(set(classes[c1].split(' ')).intersection(classes[c2].split(' '))))
		
	# proceed only if intersection is > 0
		if len(candidate_class) > 0:
			candidate_desc = descs[classes[c1]] + ", " + descs[classes[c2]]
			# When using "overspecification", sometimes the two classes being merged will redundantly have a feature specification in common. We need to check for duplicates and weed them out.  It would be harmless to run the code below if we're using underspecified descriptions, but it would just take a little longer.
			candidate_desc_set = set(candidate_desc.split(', '))
			candidate_desc = ', '.join(candidate_desc_set)

			candidate_length = len(candidate_desc_set)
			
			# If this is a new class, we need to add it
			if candidate_class not in classes:
				classes.append(candidate_class)
				number_of_classes += 1
				descs[candidate_class] = candidate_desc
				desc_lengths[candidate_class] = candidate_length
			else:
			# If we've already seen this class, we don't need to add it, but we might want to replace its description with a new one, if there's a more compact way to describe the set
				if specification == 'minimal':
					if desc_lengths[candidate_class] > candidate_length:
					# If this is true, the new description is shorter than the previously seen description. Since we want underspecification, let's keep it
						descs[candidate_class] = candidate_desc
						desc_lengths[candidate_class] = candidate_length
				else:
					if desc_lengths[candidate_class] < candidate_length:
					# If this is true, the new description is longer than the previously seen description. Since we want maximal specification, let's keep it.
						descs[candidate_class] = candidate_desc
						desc_lengths[candidate_class] = candidate_length
						

# Now, if desired, add the "null description" class, which contains all of the segments
if superclass == 'include':
	totalclass = ' '.join(sorted(segments))
	if totalclass not in classes:
		classes.append(totalclass)
		number_of_classes += 1
		descs[totalclass] = ''
		# Should the 'length' of this description be 1, or 0?  It probably does not matter, if we add it after the unitary classes, so that "actual" featural descriptions get priority
		desc_lengths[totalclass] = 0


# Now that we have the full list of classes, it's intuitive to sort them by the length of the description.  (The perl script sorted by the number of segments in the class, but that's less intuitive)
classes = sorted(classes, key=lambda x: desc_lengths[x])

log_file.write("---------------------------------------------------------\nAll natural classes:\n")
for c in classes:
	log_file.write("\t%s\t%s\t%s\n" % (c,desc_lengths[c], descs[c]))
	natural_class_file.write("%s\t%s\t%s\n" % (c,desc_lengths[c], descs[c]))

# Generally, one would like their feature system to provide a unique description for each segment in the inventory; but with privative features, this can sometimes be tricky (it's easy to accidentally distinguish a phoneme with a privative feature, and leave it's "unmarked" counterpart undescribable.
# So, we perform a check to make sure that all segments are describable.
log_file.write("\n---------------------------------------------------------\nClass keys:\n\t%s\n" % "\n\t".join(descs.keys()))
log_file.write("\n---------------------------------------------------------\nOptimal descriptions of each phoneme using features:\n")
for seg in segments:
	log_file.write(seg + '\t')
	try:
		log_file.write(descs[seg] + '\n')
	except KeyError as error:
#		print('Warning: segment [%s] is not uniquely describable using this feature set.' % seg)
		print('Warning: %s is not uniquely describable' % error)
		# Tell the user at least one segment that it cannot be distinguished from. In order to do this, find the shortest (smallest) class containing the segment.
#		containing_classes = filter(seg, sorted(classes, key= lambda x: len(classes[x]), reverse = True))# xxx
#		print('\tSegment does not contrast with {%s}\n\tFeatures: %s\n' % containing_classes[0], descs[containing_classes[0]])

########### Now moving on to calculating similarities
# One approach is to search all of the classes using a string representation, that we'll use to search. We assume that a tab is not an actual character in any transcription
all_classes = '\t'+'\t'.join(classes)+'\t'
#log_file.write("\nString of all classes:\n%s\n\n" % all_classes)

# Let's do pairwise segmental similarities for now.
# First, a header row for the similarity table file
similarity_table_file.write('Seg1\tSeg2\tShared\tTotal\tSimilarity\tShared classes\tSeg1 only\tSeg2 only\n')
# And also a header row for the similarity matrix file
sim_matrix_file.write('\t%s\n' % '\t'.join(segments))

for s1 in range(len(segments)):
	seg1 = segments[s1]
	
	sim_matrix_file.write(seg1 + '\t'*s1)
	
	for s2 in range(s1,len(segments)):
		seg2 = segments[s2]

		# We'll search for clases that contain both seg1 and seg2. For consistency, we've listed all classes in alphabetical order.  So, start by putting these in alphabetical order
		segs = sorted( seg1+seg2 )
		# A class contains just seg1 to the exclusion of seg2 if it contains seg1, and otherwise, from edge to edge (where edge is a boundary or a tab), it is composed of material that is not seg2.  A class contains both if it contains the two, in that order, with possibly other material on either side.
		
		seg1_regex = r'(?<=[\t])((((?:(?!' + segs[0] + '))[^\t ]* )*)' + segs[1] + '( (?:(?!' + segs[0] + ')[^\t ]*))*)(?=[\t])'
		seg2_regex = r'(?<=[\t])((((?:(?!' + segs[1] + '))[^\t ]* )*)' + segs[0] + '( (?:(?!' + segs[1] + ')[^\t ]*))*)(?=[\t])'
#		seg1_regex = '(?<=[\t])' + '[^\t'+ segs[1] +']*'+ segs[0] + '[^\t'+ segs[1] +']*' + '(?=[\t])'
#		seg2_regex = '(?<=[\t])' + '[^\t'+ segs[0] +']*'+ segs[1] + '[^\t'+ segs[0] +']*' + '(?=[\t])'

		shared_regex = r'(?<=[\t])(([^\t ]* )*(' + segs[0] + ' )([^\t ]* )*(' + segs[1] + ')( [^\t ]*)*)(?=[\t])'

#		shared_regex  = '(?<=[\t])' + '[^\t]*'+ segs[0] + '[^\t]*' + segs[1] + '[^\t]*' + '(?=[\t])'

		shared = re.findall(shared_regex, all_classes)
		seg1_classes = re.findall(seg1_regex, all_classes)
		seg2_classes = re.findall(seg2_regex, all_classes)
		
		# If seg1 and seg2 are the same, then the unshared are actually nil (both lists are identical)
		if seg1 == seg2:
			# The right regex to use in this case is just the one character one
			# Maybe we could have done this more efficiently by doing just one search in the first place
			shared = seg1_classes.copy()
			seg1_classes = []
			seg2_classes = []

		total = len(shared) + len(seg1_classes) + len(seg2_classes)
		if total == 0:
			print( 'Warning! %s and %s have %s shared, %s,%s unshared. Total of zero.' % (seg1, seg2, len(shared), len(seg1_classes), len(seg2_classes)) )
		else:
			similarity = float(len(shared)) / total

#		similarity_table_file.write('%s\t%s\t%s\t%s\t%s\n' % (seg1, seg2, len(shared), total , similarity))

		# In order to print out the list of shared and unshared classes, it's convenient to get the lists into strings, rather than the tuples of captures returned by re.findall.
		shared_list = [''.join(item[0]) for item in shared]
		shared_list_descs = [ descs[x] for x in shared_list ]
		shared_list_descs = [ '[' + x + ']' for x in shared_list_descs ]
		shared_list = [ '{' + x + '}' for x in shared_list]

		seg1_classes_list = [''.join(item[0]) for item in seg1_classes]
		seg1_classes_list_descs = [ descs[x] for x in seg1_classes_list ]
		seg1_classes_list_descs = [ '[' + x + ']' for x in seg1_classes_list_descs ]
		seg1_classes_list = [ '{' + x + '}' for x in seg1_classes_list]

		seg2_classes_list = [''.join(item[0]) for item in seg2_classes]
		seg2_classes_list_descs = [ descs[x] for x in seg2_classes_list ]
		seg2_classes_list_descs = [ '[' + x + ']' for x in seg2_classes_list_descs ]
		seg2_classes_list = [ '{' + x + '}' for x in seg2_classes_list]

		similarity_table_file.write( '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' % (seg1, seg2, len(shared), total , similarity, ', '.join(shared_list_descs),  ', '.join(seg1_classes_list_descs), ','.join(seg2_classes_list_descs), ))
		
		sim_matrix_file.write('\t%s' % similarity)

	# At the end of each seg1 segment, start a new line in the similarity matrix file
	sim_matrix_file.write('\n')


log_file.close()
similarity_table_file.close()
natural_class_file.close()
sim_matrix_file.close()
