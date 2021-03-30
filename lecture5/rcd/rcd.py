# Script that performs Recursive Constraint Demotion.  It takes a set of unexplained mark data pairs and unranked constraints and returns 
def rank(mdps, unranked, strata):
	
	# We divide constraints in 'unranked' into those that must be demoted (have L's for some active mdps), and those that can be installed or ranked (have only W's and e's)
	ranked = []
	demoted = []
	
	unexplained = list(range(0,len(mdps)))
	
	for con in unranked:
		print('Constraint %s' % con)
		demote = False
		
		# List of mdp's that would be explained by this constraint, if it's successfully installed in the current stratum
		potentially_explained = []
		
		for mdp in range(0,len(mdps)):
			print('\tmdp %s' % mdp)
			if mdps[mdp][con] == 'L':
				demote = True
				print('\t Demoting constraint %s' % con)
				break
			elif mdps[mdp][con] == 'W':
				potentially_explained.append(mdp)
		
		if not demote:
			ranked.append(con)
			print('Potentially explained: %s' % potentially_explained)
			# This constraint doesn't need to be demoted, so all of the mdp's that it could potentially explain are now actually explained.
			for mdp in potentially_explained:
				try:
					unexplained.remove(mdp)
					print("Removing mdp %s, since it's explained by constraint %s" % (mdp, con) )
				except ValueError:
					print("Couldn't remove mdp %s (ValueError)" % mdp)
					pass			
		else:
			demoted.append(con)
	
	if len(demoted) == 0:
		strata.append(ranked)

	elif len(ranked) == 0:
		ranked = unranked.copy()
		ranked.append(-1)
		strata.append(ranked)
	
	else:
		strata.append(ranked)
		remaining_mdps = [ mdps[i] for i in unexplained ]
		rank(remaining_mdps, demoted, strata)
	
	return strata