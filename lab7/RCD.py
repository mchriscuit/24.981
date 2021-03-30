import numpy as np
import re
import argparse

## helper function to make tableau look pretty
def print_tableau(data, p):
    lens = [max(map(len, col)) for col in zip(*data)] # get length of largest element per column in the list of lists
    fmt = '\t'.join('{{:{}}}'.format(x) for x in lens) # generate list of formats consisting of x spaces for the characters each row of that column to occupy
    table = [fmt.format(*row) for row in data] # note that {{}} is necessary as the initial { must be escaped first (akin to '\\')

    ## print data
    fill = '=' * (len(p)+5)
    print()
    print(fill, p, fill, sep='\n')
    print('\n'.join(table))
    print()

## argparse to get filename from command line
parser = argparse.ArgumentParser(description='Perform RCD on some dataset.')
parser.add_argument('data', type=str, nargs='?', help='name of the data (.csv)')
parser.add_argument('bias', type=bool, default=False, nargs='?', help='use markedness over faithfulness bias?')
parser.add_argument('ur', type=bool, default=False, nargs='?', help='perform UR learning?')
args = parser.parse_args()
FILENAME = args.data

## Load file from FILENAME
with open(FILENAME, 'r') as file:
    data = file.readlines()

## clean up data
data = [r.strip().split(',') for r in data]
data = [ ['-' if x == '' else x for x in r] for r in data ]

## formatting data for printing
p = 'Data drawn from \'{}\':'.format(FILENAME)
print_tableau(data, p)

## ============================================================
##                  Computing W and L
## ============================================================

## some information we need
data = np.array(data)
CONSTRAINTS = data[0][2:]
ORDER = []
iteration = 1

def RCD(data=data, ORDER=ORDER, CONSTRAINTS=CONSTRAINTS, iteration=iteration):
    ## record the indices of the rows containing URs: /UR/
    UR_idx = np.argwhere([re.search('/', r[0]) for r in data])
    if UR_idx.ndim > 1: UR_idx = UR_idx.squeeze(-1)

    ## convert matrix to correspond to the number of * in each cell of the matrix
    t = np.array([[len(re.findall(r'\*', cell)) for cell in r] for r in data])

    ## generate a vector denoting where the winners are
    w_idx = np.argwhere(data[:,1] == '1')
    if w_idx.ndim > 1: w_idx = w_idx.squeeze(-1)

    ## compile a matrix of winner violations over all tableaux
    n_winners = len(w_idx)
    if t[w_idx].ndim < 2: winner_violations = np.reshape(t[w_idx], (1,-1))[:,2:]
    else: winner_violations = t[w_idx][:,2:]

    ## compile a matrix of loser violations for each tableau
    loser_violations = []
    for i in range(0, len(UR_idx)):
        if i == len(UR_idx)-1: prev, nxt = UR_idx[i], t.shape[0]
        else:                  prev, nxt = UR_idx[i], UR_idx[i+1]
        loser_violations.append(np.delete(t, w_idx[i], 0)[prev:nxt-1][1:,2:])

    ## generate the comparative tableau
    ## positive numbers are winner-preferred; negative is loser-preferred
    comparative_tableau = [loser_violations[i] - winner_violations[i] for i in range(n_winners)]
    # print(comparative_tableau)

    ## see which columns contain only positive or 0 violations
    wp = [np.argwhere(c > 0).squeeze(-1) for ct in comparative_tableau for c in ct]
    wp, n_wp = np.unique(np.hstack(wp), return_counts = True)
    even = [np.argwhere(c >= 0).squeeze(-1) for ct in comparative_tableau for c in ct]
    even, n_even = np.unique(np.hstack(even), return_counts = True)

    ## pick out the constraints that are at least uninformative (even)
    pwp = np.argwhere(n_even == np.vstack(loser_violations).shape[0])

    ## if that constraint has at least one actual violation mark, then it is
    ## a winner-preferring constraint
    if len(pwp) >= 0:
        wp = [even[c] for c in pwp if even[c] in wp]
    if len(wp) == 0:
        raise ValueError("Unable to find any loser-preferring constraints; is there more than one winner?")

    ## fix dimensions
    if len(wp) > 1: wp = np.unique(np.hstack(wp))
    else: wp = np.array(wp).squeeze(-1)

    ## for the constraints, check to see which ones are markedness constraints and which are faithfulness
    ## if bias == True, then rank within that stratum all the markedness constraints above the faithfulness ones
    ranked_constraints = data[0,wp+2]
    if args.bias == True:
        M = [c for c in ranked_constraints if re.search(r'\*', c)]
        F = [c for c in ranked_constraints if c not in M]
        print("M >> F active: ranking {} above {}".format(', '.join(M), ', '.join(F)))
        if len(M) > 0: ORDER.append(M)
        if len(F) > 0: ORDER.append(F)
    else: ORDER.append(data[0,wp+2])

    ## for these indices, see which candidates are explained and remove them
    # record the indices of the candidates with violations of the loser constraints
    contains_violation = np.array([ [bool(re.search(r'\*$', cell)) for cell in r] for r in data[:,wp+2] ])
    explained_candidates = np.argwhere(np.sum(contains_violation, axis=1)).squeeze() # recall that we removed the first two columns
    new_data = np.delete(data, explained_candidates, axis=0)
    new_data = np.delete(new_data, wp+2, axis=1)
    print('Constraints that are winner-preferring: {}'.format(', '.join(data[0,wp+2])))
    print('Candidates that are explained: {}\n'.format(', '.join(data[explained_candidates,0])))
    CONSTRAINTS = new_data[0,2:]

    ## also remove winners that no longer have any competitors
    satisfied = []
    candidates = new_data[:,0]
    for i in range(1,len(candidates)):
        if i == len(candidates)-1:
            if re.search(r'/', candidates[i-1]): satisfied += [i-1, i]
            elif re.search(r'/', candidates[i]): satisfied += [i]
        elif re.search(r'/', candidates[i-1]) and re.search(r'/', candidates[i+1]): satisfied += [i-1, i]
    satisfied = np.array(satisfied)

    ## If all of the winners still have competitors, continue as usual
    if len(satisfied) > 0:
        new_data = np.delete(new_data, satisfied, axis=0)

    ## check if the matrix is empty; if so, learning is done
    if len(new_data) == 0:
        p = 'Learning complete; no more competitors'
        fill = '=' * (len(p) + 5)
        print(fill, p, fill, sep='\n')
        print()
        ranked_constraints = CONSTRAINTS
        if args.bias == True:
            M = [c for c in ranked_constraints if re.search(r'\*', c)]
            F = [c for c in ranked_constraints if c not in M]
            print("The remaining constraints are not rankable: {}".format(', '.join(ranked_constraints)))
            if len(M) > 0 and len(F) > 0:
                ORDER.append(M)
                ORDER.append(F)
                print("M >> F active: ranking {} above {}\n".format(', '.join(M), ', '.join(F)))
            elif len(F) > 0:
                ORDER.append(F)
                print("M >> F active: {}\n".format(', '.join(F)))
            elif len(M) > 0:
                ORDER.append(M)
                print("M >> F active: {}\n".format(', '.join(M)))
            else:
                print("No more constraints to rank")
        else: ORDER.append(CONSTRAINTS)
        return

    ## formatting data for printing
    p = 'Tableau at iteration {}'.format(iteration)
    print_tableau(new_data, p)

    ## iterate
    iteration += 1

    ## undergo recursion
    RCD(data=new_data, ORDER=ORDER, CONSTRAINTS=CONSTRAINTS, iteration=iteration)

## perform RCD
RCD()

## ============================================================
##                  Printing the Final Output
## ============================================================
p = 'Final Constraint Ranking:'
fill = '=' * (len(p) + 5)
print(fill, p, fill, sep='\n')
print(' >> '.join(', '.join(c) for c in ORDER))
print()

# reorder columns by ORDER_idx
ORDER_idx = [[np.argwhere(data[0,:] == c).squeeze() for c in constraints] for constraints in ORDER]
ORDER_idx_flattened = [np.argwhere(data[0,:] == c).squeeze() for constraints in ORDER for c in constraints]
organized_data = np.hstack( (data[:,:2], data[:,ORDER_idx_flattened]) )

## insert strict rankings based on the ranking generated
ranking = np.full((organized_data.shape[0], 1), '|')
UR = np.argwhere(list(bool(re.search(r'/', c)) for c in organized_data[:,0])).squeeze()
ranking[UR] = '='

# insert a line break at the beginning of the tableau
inset = 2
organized_data = np.hstack((organized_data[:,:inset], ranking, organized_data[:,inset:]))

# insert a line break at the designated points
for idx in range(len(ORDER_idx)):
    inset += 1 + len(ORDER_idx[idx])
    organized_data = np.hstack((organized_data[:,:inset], ranking, organized_data[:,inset:]))

## print out the full tableaux with the rankings
p = 'Final Tableau'
print_tableau(organized_data, p)
