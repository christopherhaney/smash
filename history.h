#ifndef HISTORY_H_
#define HISTORY_H_ //Include guards to prevent double declaration
//Data Types
	typedef struct commandHist {
		char* storedCommand;
	} commandHist;
	
//Function prototypes
	int init_history();
	void add_history(char* commandToAdd);
	void clear_history();
	void print_history();

#endif // HISTORY_H_
