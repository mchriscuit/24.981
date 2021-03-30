import GLABoersma

input_file = "SaShiAllophonic.txt"
constraints_file = "SaShiAllophonic.constraints"
initial_markedness_value = 10
initial_faithfulness_value = 0
initial_default_value = 10
number_of_trials = 100
initial_plasticity = .1
plasticity_decrement = 0
rankings_file_frequency = 10

GLABoersma.learn(input_filename=input_file, constraints_filename=constraints_file, initial_markedness_ranking=initial_markedness_value, initial_faithfulness_ranking=initial_faithfulness_value, initial_default_ranking=initial_default_value, number_of_learning_trials=number_of_trials, initial_plasticity=initial_plasticity, plasticity_decrement=plasticity_decrement, rankings_file_interval=rankings_file_frequency)
