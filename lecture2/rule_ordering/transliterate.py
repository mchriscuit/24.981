import re
def transliterate(word, rules, geminates_long=False):
	for rule in rules:	
		# Apply them but substituting the left side for the right side
		word = re.sub(rule[0], rule[1], word)

	# If desired, represent geminate consonants as C:
	if geminates_long:
		word = re.sub(r"([^aeiou])\1", r"\1ː", word)
	
	return word