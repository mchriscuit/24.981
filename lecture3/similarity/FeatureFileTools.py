import re
def cleanup_line (line):
	line = line.strip()
	#Kie's version of these files has fields in quotes and with commas, "X,"
	line = re.sub(r'\"([^\"]*),\"', r'\1', line)
	line = re.sub(r',(\s|$)', r'\1', line)
	
	# Get rid of syntactic elements like "No more features" or "EndOfLine"
	line = re.sub(r'(\"?NoMoreFeatures\"?|NoMoreSegments|EndOfLine)', '', line)
	
	# Also, sometimes there are extra white spaces at the ends of lines
	line = re.sub(r'\s+$', '', line)
	return line

