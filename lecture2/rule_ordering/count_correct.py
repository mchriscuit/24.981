from transliterate import transliterate
def count_correct(inputs, answers, rules, geminates_long):
	number_correct = 0;
	for i in range(0,len(inputs)):
		word = transliterate(inputs[i], rules, geminates_long)
		answer = answers[i]

		if (word == answer):
			number_correct += 1
#			print( "[%s] == [%s]" % (word, answer))
#		else:
#			print( "[%s] != [%s]" % (word, answer))

#	wait = input("Press <ENTER> to continue")
	return number_correct