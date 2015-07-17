#!/usr/bin/python

#
#	Utility script for mass git operatiosn on geppetto repos listed in ./config.json
#
#	Usage:
# 	gitall branches: print current branch of each repo
#
#	gitall checkout <branch> : checkout <branch> on each repo
#
#	gitall pull <remote> <branch> : execute git pull on each repo
#
#	gitall fetch <remote> <branch> : execute git fetch on each repo
#
#

import os, sys, getopt, subprocess, json
from subprocess import call
config = json.loads(open(os.path.join(os.path.dirname(__file__), 'config.json')).read())

def incorrectInput(argv, msg):
	print msg
	sys.exit()

def main(argv):

	command = []
	if(len(argv) == 0):
		incorrectInput(argv, 'Too few paramaters')

	elif(argv[0] == 'push'):
		command = ['git','push',argv[1],argv[2]]

	elif(argv[0] == 'add'):
		command = ['git','add',argv[1]]

	elif(argv[0] == 'commit'):
		command = ['git','commit',argv[1],argv[2]]

	elif(argv[0] == 'branches'):
		command = ['git','rev-parse','--abbrev-ref','HEAD']

	elif(argv[0] == 'reset'):
        	command = ['git','reset','--hard','HEAD']

	elif(argv[0] == 'remote'):
		for repo in config['repos']:
			print repo['name']+'  '+subprocess.check_output(['git','remote','add','mlolson','https://github.com/mlolson/'+repo['name']+'.git'], cwd = os.path.join(config['sourcesdir'], repo['name']))
		return

	elif(argv[0] == 'checkout'):
		if(len(argv) == 2):
			command = ['git','checkout',argv[1]]
		elif(len(argv) == 3):
			command = ['git','checkout',argv[1],argv[2]]
		else:
			incorrectInput(argv, 'Expected <=3 paramaters')


	elif(argv[0] == 'pull' or argv[0] == 'fetch'):
		if(len(argv) == 1):
			command = ['git',argv[0]]
		elif(len(argv) ==2):
			command = ['git',argv[0],argv[1]]
		elif(len(argv) ==3):
			command = ['git',argv[0],argv[1],argv[2]]
		else:
			incorrectInput(argv, 'Too many paramaters')

	else:
		incorrectInput(argv, 'Unrecognized command')

	for repo in config['repos']:
		print repo['name']+'  '+subprocess.check_output(command, cwd = os.path.join(config['sourcesdir'], repo['name']))

if __name__ == "__main__":
	main(sys.argv[1:])
