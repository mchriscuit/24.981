# Script to create a GUI for the SGA learning script
import tkinter as tk
import os

mainWindow = tk.Tk()
mainWindow.title('GLA')
mainWindow.config(borderwidth=20)

# This should be earlier, but it seems to be a bug of tkinter and matplotlib on the mac that you need to set up a Tk() instance first before loading matplotlib
import GLAMagri

default_input_filename = ''
default_constraints_filename = ''


def runGLA(input_file, constraints_file, initial_markedness_value, initial_faithfulness_value, initial_default_value, number_of_trials, initial_plasticity, plasticity_decrement, rankings_file_frequency ):
	GLAMagri.learn(input_filename=input_file, constraints_filename=constraints_file, initial_markedness_ranking=initial_markedness_value, initial_faithfulness_ranking=initial_faithfulness_value, initial_default_ranking=initial_default_value, number_of_learning_trials=number_of_trials, initial_plasticity=initial_plasticity, plasticity_decrement=plasticity_decrement, rankings_file_interval=rankings_file_frequency)



filesFrame = tk.LabelFrame(mainWindow,text='Files')
filesFrame.pack(side=tk.TOP, fill=tk.BOTH)
tk.Label(filesFrame, text='File of tableaus').grid(row=0,column=0)
input_filename = tk.StringVar()
inputFileField = tk.Entry(filesFrame, textvariable=input_filename, width=60).grid(row=0,column=1)


tk.Label(filesFrame, text='File of constraint types').grid(row=1,column=0)
constraints_filename = tk.StringVar()
constraintsFileField = tk.Entry(filesFrame, textvariable=constraints_filename, width=60).grid(row=1,column=1)



runFrame = tk.Frame()
runFrame.pack(side=tk.BOTTOM,fill=tk.BOTH)


valuesFrame = tk.LabelFrame(mainWindow, text='Ranking values')
valuesFrame.pack(side=tk.LEFT)

#tk.Label(valuesFrame, text='Initial values:').grid(row=0,column=0,columnspan=2)

tk.Label(valuesFrame, text='Initial Markedness value', justify=tk.LEFT).grid(row=0,column=0)
initial_markedness_value = tk.StringVar()
mvalueField = tk.Entry(valuesFrame, textvariable=initial_markedness_value, justify=tk.RIGHT).grid(row=0,column=1)

tk.Label(valuesFrame, text='Initial Faithfulness value', justify=tk.LEFT).grid(row=1,column=0)
initial_faithfulness_value = tk.StringVar()
fvalueField = tk.Entry(valuesFrame, textvariable=initial_faithfulness_value, justify=tk.RIGHT).grid(row=1,column=1)

tk.Label(valuesFrame, text='Initial default value', justify=tk.LEFT).grid(row=2,column=0)
initial_value = tk.StringVar()
valueField = tk.Entry(valuesFrame, textvariable=initial_value, justify=tk.RIGHT).grid(row=2,column=1)


learningFrame = tk.LabelFrame(mainWindow,text='Learning')
learningFrame.pack(side=tk.RIGHT)

tk.Label(learningFrame, text='Number of learning trials').grid(row=0,column=0)
number_of_learning_trials = tk.StringVar()
trialsField = tk.Entry(learningFrame, textvariable=number_of_learning_trials, justify=tk.RIGHT).grid(row=0,column=1)

tk.Label(learningFrame, text='Initial plasticity').grid(row=1,column=0)
initial_plasticity = tk.StringVar()
plasticityField = tk.Entry(learningFrame, textvariable=initial_plasticity, justify=tk.RIGHT).grid(row=1,column=1)

tk.Label(learningFrame, text='Plasticity decrement').grid(row=2,column=0)
plasticity_decrement = tk.StringVar()
plasticityDecrementField = tk.Entry(learningFrame, textvariable=plasticity_decrement, justify=tk.RIGHT).grid(row=2,column=1)


tk.Label(runFrame, text='Rankings file frequency').grid(row=0,column=0)
rankings_file_frequency = tk.StringVar()
valuesFreqField = tk.Entry(runFrame, textvariable=rankings_file_frequency,justify=tk.RIGHT).grid(row=0,column=1)

runButton = tk.Button(runFrame, text='Run',width=30,command=lambda: runGLA(input_filename.get(), constraints_filename.get(), float(initial_markedness_value.get()), float(initial_faithfulness_value.get()), float(initial_value.get()), int(number_of_learning_trials.get()), float(initial_plasticity.get()), float(plasticity_decrement.get()),  int(rankings_file_frequency.get()))).grid(row=1,column=0,columnspan=2)


initial_markedness_value.set('10')
initial_faithfulness_value.set('0')
initial_value.set('0')
number_of_learning_trials.set( '5000' )
initial_plasticity.set( '.1' )
plasticity_decrement.set( '0' )
rankings_file_frequency.set( '10' )

input_filename.set(default_input_filename)
constraints_filename.set(default_constraints_filename)


mainWindow.mainloop()


