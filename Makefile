#------Configure compiler and headers
CFLAGS = -Wall -std=c99 -pthread
HDRS = history.h
OBJS = smash.o history.o 

#------Run gcc anytime the header files or this Makefile changes
%.o: %.c $(HDRS) Makefile
	$(CC) -c -o $@ $(CFLAGS) $<

#------Build everything
all: smash

#------Build a debug version
debug: CFLAGS += -DDEBUG -g
debug: smash

#------Build smash without any debugging features
smash: smash.o history.o smashLib.a
	gcc $(CFLAGS) $^ -o $@

#Define a rule for building library smashLib.a
smashLib.a : $(OBJS)
	ar r $@ $?

#------Build a debug version and execute under valgrind
valgrind: debug
	valgrind --leak-check=yes --leak-check=full --show-leak-kinds=all smash

#------Clean up build artifacts
clean:
	-rm -f *.o *.a smash

#------Clean up backpack.sh artifacts
c: clean
	-rm ErrorsAndWarnings.txt
#	rm diff.out
	-rm test

#------RUN AUTOGRADER
x: 
	./backpack.sh test
