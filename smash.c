#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h> //For wait() API
#include <unistd.h>
#include "history.h" //Custom header file for history command
#include <sys/types.h> //For open API
#include <sys/stat.h> //For open API
#include <fcntl.h> //For open API
#include <signal.h> //To prevent CTRL+C from terminating smash
#include <pthread.h> //To create a thread to wait for child process
#include "smash.h" //Function prototypes for smash.c

#define MAXLINE 4096 //Maximum length of stdin to prevent buffer overflow attack

//Variable Initialization
char* token; //Char pointer to pass line through strtok function
char* tokenArray[MAXLINE]; //Pointer to an array containing each separated token
char line[MAXLINE]; //Unformatted array of chars of all arguments passed into stdin
char printstr[MAXLINE]; //Formatted string of all arguments passed into stdin
char histstr[MAXLINE]; //String to be passed into add_history
char formattedArg[MAXLINE] = {0}; //Arg to be concatenated into string str
int totalTokens; //Track total tokens in line for parser functions
char* segArray[10][10]; //2D array to segment tokenArray

int main(void)
{
	/*Ignore SIGINT so CTRL+C doesn't exit the shell
	signal(SIGINT,SIG_IGN);
	signal(SIGTERM,SIG_IGN);
	signal(SIGQUIT,SIG_IGN);
	*/	
	
	if(init_history() == 1) {
		fprintf(stderr,"History buffer wasn't properly initialized, or it was not cleared of previous data.");
		return 1;
	}	
	while(fgets(line,MAXLINE,stdin)) {
		if(strlen(line) > MAXLINE) //Check if buffer is exceeded
			return 0;
		lineParser(); 
		segParser();
		for(int a = 0; a < 3; a++)
			for(int b = 0; b < 10; b++) {
				//printf("segArray[%i][%i]: %s\n",a,b,segArray[a][b]);
				segArray[a][b] = '\0';
			} 
	}	 
	return 0;
}

void lineParser() {
	line[strlen(line) - 1] = '\0'; //replace newline with NUL
	token = strtok(line, " ");
	totalTokens = 0;
	while(token != NULL) {
		tokenArray[totalTokens] = token;
		sprintf(formattedArg,"[%i] %s\n",totalTokens,token); 
		strcat(printstr,formattedArg);
		sprintf(formattedArg,"%s ",token); //Now use formattedArg to append token using the format for print_history
		strcat(histstr,formattedArg); //Concatenate formattedArg to the histstr
		totalTokens++;
		token = strtok(NULL, " "); //Blank out token string then go through the loop again
	}
	add_history(histstr); 
	strcpy(histstr,""); //Blank out histstr for the next line
}

void segParser() {
	int currentSegment = 0; int currentCommand = 0; int currentToken = 0; 
	while(currentToken < totalTokens + 1) {
		if (tokenArray[currentToken] != NULL && strcmp((const char*)tokenArray[currentToken],"|") == 0) {
			executeCommand(currentSegment);
			currentSegment++;
			currentCommand = 0;
			currentToken++;
		}
		else if (tokenArray[currentToken] == NULL) {
			executeCommand(currentSegment);
			currentSegment = 0; currentCommand = 0; currentToken = 0;
			break;
		}
		else {
			segArray[currentSegment][currentCommand] = tokenArray[currentToken];
			currentCommand++;
			currentToken++; 
		}
	}
}

void executeCommand(int currentSegment) {	
	//Check if exit was called
	exitCommand();
		
	//Call cdCommand if arg1 is "cd"
	if(strcmp((const char*)segArray[currentSegment][0],"cd") == 0) {
		if((const char*)segArray[currentSegment][2] != NULL) {
			fprintf(stderr,"Error cd only accepts two arguments: cd directory/path\n");
		}
		cdCommand((const char*)segArray[currentSegment][1]);
	}
	else if(strcmp((const char*)segArray[currentSegment][0],"history") == 0) {
	print_history();
	}
	
	//Otherwise it must be an external command
	else {
		executeExtCommand(currentSegment);	
	}
}	

void cdCommand(const char* filepath) {	
	if(chdir(filepath) != 0) {
		fprintf(stderr,"Error %s returned a nonzero result\n",filepath);
	}
	else {	
		char* cwd = 0;
		printf("%s\n",getcwd(cwd,MAXLINE));
		}
}

void exitCommand() { 
	//printf("Start of exitCommand, Line is: %s\n",line);
	if(strncmp((const char*)segArray[0][0],"exit",4) == 0) {
		printf("%s",printstr); //Once commands are finished being entered, print all formatted args
		clear_history(); 
		exit(0); 
	} 
}

void executeExtCommand(int currentSegment) {			
	int pid = fork(); //Fork the process
	
	//If this is the child process...
	if(pid == 0) {
		char* argv[10];
		int j = 0;
		int k = 0;
		char* inputFileString = "";
		int inputFilePresent = 0;
		char* outputFileString = "";
		int outputFilePresent = 0;
		const char inputFileChar = '<';
		const char outputFileChar = '>'; 
		while(segArray[currentSegment][j] != NULL) {
			if(strchr(segArray[currentSegment][j],inputFileChar) != NULL) {
				inputFileString = tokenArray[j] + 1;
				inputFilePresent = 1;	
				j++;
			}
			else if(strchr(segArray[currentSegment][j],outputFileChar) != NULL) {
				outputFileString = tokenArray[j] + 1;
				outputFilePresent = 1;
				j++;
			}
			else {
				argv[k] = tokenArray[j];
				k++;
				j++;
			}
		}
		argv[k] = NULL;
		//Redirect input if necessary
		if(inputFilePresent == 1) {	
			//Open fileIn
			int fileIn = open(inputFileString,O_RDONLY);
			//Redirect stdin
			close(0); //Close stdin
			dup2(fileIn,0); //Duplicate stdin into new file descriptor
		}
		//Redirect output if necessary
		if(outputFilePresent == 1) {
			//Open fileOut
			int fileOut = open(outputFileString,O_WRONLY);
			//Redirect stdout
			close(1); //Close stdout	
			dup2(fileOut,1); //Duplicate stdout into new file descriptor
		}	
		//Now execve the command using above arrays
		execvp((const char*)segArray[currentSegment][0],(char* const*)argv);
		//If execvp fails, it will fail and cause the exit procedure below
		perror("execvpe");   
		exit(EXIT_FAILURE);	
	}
	
	//If this is the parent process...
	else if(pid > 0) { 
		pthread_t posixThreadId;
		int result = pthread_create(&posixThreadId, NULL, reaperThread, NULL);
		if (result != 0) printf("pthread_create failed, error%d\n",result);
	}
}

void *reaperThread(void *arg) {
	int exitStatus;
	wait(&exitStatus);
	printf("PID %i exited, status = %i\n",getpid(),exitStatus);
	pthread_exit((void *) 0);
}
