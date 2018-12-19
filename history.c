#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h> //For wait() API
#include <unistd.h> //For fork() API
#include "history.h" //Verifies that function prototypes are correct

//Initialize variables and structs	
	int currentIndex = 0; //Int to track current location in commandHist for add-history function
	commandHist commandHistArray[100]; //Array of commandHist Structs 

//Function to initialize dynamic array of command history
	 int init_history() {
		for(int i = 0; i < 100; i++)
			commandHistArray[i].storedCommand = malloc(4096); 
		return 0; //malloc succeeded
	}	

//Function to add current command into the history array
	void add_history(char* commandToAdd) {	
		strcpy(commandHistArray[currentIndex].storedCommand,commandToAdd);
		currentIndex++;  //Increment currentIndex so that next add call will go into the next index of commandHist
	}


//Function to free memory of history and clear the history array from memory
	void clear_history() {
		for(int j = 0; j < 100; j++)
			free(commandHistArray[j].storedCommand);
		currentIndex = 0;
	}


//Function to print current history to stdout
	void print_history() {
		for(int j = 0; j < currentIndex; j++) {
			printf("%i %s\n",j,commandHistArray[j].storedCommand);
		}
	}
