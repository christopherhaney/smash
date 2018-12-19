#!/bin/bash
#-------------------------------------------------------------------------------
# NAME
#   autograder.sh -- Grades the smash4 project awarding partial credit
#
# SYNOPSIS
#   backpack.sh outputFile
#
# DESCRIPTION
#   This script grades the CS253 smash4 project, awarding partial
#   credit.  The script keeps a running total of a student's score, and, after
#   a problem is encountered, attempts to grade whatever else might work.  
#
#   The script records feedback to the student in the specified file in a
#   format that can also be processed by the "backpack -g" auto-grader command
#   (which requires the file be named rubric.txt).
#
#   Most messages written by the script include the line-number of their origin:
#     [42] Foo Fi Fo Fum I smell the blood of an Englishman
#   in brackets, [42].  If you open the script in an editor, you can examine
#   around the line of their origin to investigate what is happening there.
#
# RESOURCES
#   test.in         Regression test of Smash Part1 functionality
#   test.out        Expected output from test.in
#   basicHistory.in Test data for the history command
#   zombieCheck.in  A data file to search for zombies
#
# HISTORY
#   11/28/2018 Epoch..........................................................jrc
#--------------------------------------------------------------------------------
if [ "$1" = "" ]; then
  echo "usage: $0 outputfile"
  exit 0;
fi

#Configuration variables you can easily modify
let maxscore=50                  #The maximum score allotted for this assignment
errMsg=ErrorsAndWarnings.txt     #Where to record stderr messages
EXE=smash                        #Name of the student's executable program
LIB=smashLib.a                   #Name of the required library

#Configuration that depends upon host operating system.  Note:  MacOS ships without
#the timeout utility, but gtimeout can be installed with "brew install coreutils"
#after downloading/installing MacOs brew from https://brew.sh (or just use linux)
timeout=timeout                  #Use timeout on Linux, gtimeout on MacOS

#Initialization
let letterGrade=maxscore/10      #Points in one letter-grade for this assignment
let halfLetterGrade=letterGrade/2
dest="$1"                        #The output log file of grading activity/messages
let score=$maxscore              #This student's calculated score
tmpFile=/tmp/"$USER""$$"         #Temp file sometimes used as a scratchpad

#The autograder's required data files containing test input and output
testIn=test.in                   #Test input data file
testOut=test.out                 #Test expected output file
testDir=testDir                  #A directory used as a container for some tests
historyIn=basicHistory.in        #Commands for exercising history command
pipedHistoryIn=pipedHistory.in   #Commands for exercising pipelines in history
bigIn=big.in                     #A very long illegal command followed by exit
zombieCheck=zombieCheck.in       #Shell commands to search for zombies

#---------------------------------------------------------------------------------
# Define function to log a message to the dest file, stamped with the line number
# of where the function was invoked, pointing students to where problems arose.
# Usage:  logMsg $LINENO messageText
#---------------------------------------------------------------------------------
logMsg() {
 echo "[$1] " "$2" " -- score=$score" >>$dest
}


#---------------------------------------------------------------------------------
# Define function to deduct points if the specified file exists
# Usage:  deductFileExists $LINENO filename nPoints
#---------------------------------------------------------------------------------
deductFileExists() {
 if [ -e "$2" ]; then
  deductPoints $3
  logMsg "$1" "ERROR:  Unexpected file $2"
 fi
}


#---------------------------------------------------------------------------------
# Define function to deduct points if the specified file is missing
# Usage:  deductFileMissing $LINENO filename nPoints
#---------------------------------------------------------------------------------
deductFileMissing() {
 if [ ! -e "$2" ]; then
  deductPoints $3
  logMsg "$1" "ERROR:  Missing expected file $2"
 fi
}


#---------------------------------------------------------------------------------
# Warn user if a required file is missing (sometimes someone deletes them)
# Usage:  warnFileMissing $LINENO filename
#---------------------------------------------------------------------------------
warnFileMissing() {
 if [ ! -e "$2" ]; then
  logMsg "$1" "WARNING:  Missing expected file $2 --- autograder will likely fail"
 fi
}

#---------------------------------------------------------------------------------
#Define function to deduct points if pattern is missing from a specified file
# Usage:  deductnGrep $LINENO pattern filename nPoints
#---------------------------------------------------------------------------------
deductnGrep() {
 output=$(grep -i "$2" "$3")
 if [ "$?" != 0 ]; then
  deductPoints $4
  logMsg "$1" "ERROR:  Could not grep $2 in $3"
 fi
}


#--------------------------------------------------------------------------------
# Define function to deduct points if pattern is found in the specified file
# Usage:  deductGrep $LINENO pattern filename nPoints
#--------------------------------------------------------------------------------
deductGrep() {
 output=$(grep -i "$2" "$3")
 if [ "$?" == 0 ]; then
  deductPoints $4
  logMsg "$1" "ERROR:  grep found unexpected $2 in $3"
 fi
}

#---------------------------------------------------------------------------------
# Define function to deduct points if re is missing from string ignoring case.
# Usage:  deductMissingString $LINENO string substring nPoints
#---------------------------------------------------------------------------------
deductMissingString() {
 if ! echo "$2" | grep -i -q "$3" ; then
  deductPoints $4
  logMsg "$1" " ERROR:  Substring $3 missing in string, $2"
 fi
}

#---------------------------------------------------------------------------------
# Define function to deduct points from score
# Usage:  deductPoints nPoints
#---------------------------------------------------------------------------------
deductPoints() {
 let score-=$1
 if [ $score -lt 0 ]; then
  let score=0
 fi
}


#---------------------------------------------------------------------------------
#NOTE:  Grading begins here
#---------------------------------------------------------------------------------
rm -f $dest $errMsg                                  #Remove old grading artifacts
logMsg $LINENO "NOTE:  Begin grading on `date` with temp file, $tmpFile"

#Check for missing autograder files.  Don't delete the autograder and its files!
warnFileMissing $LINENO $testIn
warnFileMissing $LINENO $historyIn
warnFileMissing $LINENO $bigIn
warnFileMissing $LINENO $zombieCheck

#Deduct points for submission of binary files-------------------------------------
#Note:  Students should do a make clean before running autograder
logMsg $LINENO "NOTE:  Checking for binary files"
deductFileExists $LINENO $EXE $halfLetterGrade
deductFileExists $LINENO smash.o $halfLetterGrade
deductFileExists $LINENO history.o $halfLetterGrade
deductFileExists $LINENO smashLib.a $halfLetterGrade

#Verify the expected Makefile
logMsg $LINENO "NOTE:  Grading the Makefile"
deductFileMissing $LINENO  Makefile $halfLetterGrade
deductnGrep $LINENO "Wall" Makefile $halfLetterGrade
deductnGrep $LINENO "c99"  Makefile $halfLetterGrade

#Manually clean old junk from previous builds and grading attempts, etc----------
rm -fr $exe $test.out *.o *.d *.a $errMsg diff.out $testDir *~

#Build the product and check for errors/warnings and missing required files------
logMsg $LINENO "Note:  Grading the build"
make 2>$tmpFile
deductGrep $LINENO error   $tmpFile $letterGrade
deductGrep $LINENO warning $tmpFile $halfLetterGrade
deductFileMissing $LINENO $EXE $maxscore
deductFileMissing $LINENO $LIB $letterGrade

#Verify program will run given no input except an EOF----------------------------
logMsg $LINENO "Note:  Grading smash exits normally with EOF input"
./$EXE </dev/null >>$errMsg 2>&1
if [ "$?" != 0 ]; then
 deductPoints $letterGrade
 logMsg $LINENO "ERROR: $EXE exited abnormally after EOF"
fi

#Verify smash supports the exit command and exits with status=0=-----------------
logMsg $LINENO "Note:  Grading the exit command"
echo exit | $timeout 5s ./$EXE >>$errMsg 2>&1
if [ "$?" != 0 ]; then
 deductPoints $letterGrade
 logMsg $LINENO "ERROR: exit command timed-out or exited with non-zero status"
fi

#Verify smash can change to user's home directory---------------------------------
logMsg $LINENO "Note:  Grading the cd command"
result=$( echo "cd $HOME" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "$HOME" $letterGrade

#Verify smash emits an error message for cd to a non-existent directory-----------
logMsg $LINENO "Note:  Grading stderr message for cd to a non-existent directory"
echo "cd non-existent-directory" | $timeout 5s ./$EXE >$tmpFile 2>&1
deductnGrep $LINENO "Error" $tmpFile $letterGrade

#Verify that smash can execute a trivial external command given complete path-----
logMsg $LINENO "Note:  Grading execution of /usr/bin/ls command"
result=$( echo "/usr/bin/ls" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "smash" $letterGrade*2

#Verify that smash is searching the PATH for the trivial external command---------
logMsg $LINENO "Note:  Grading execution of ls command using PATH environ variable"
result=$( echo "ls" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "smash" $letterGrade

#Verify that smash can pass an argument to an external command--------------------
logMsg $LINENO "Note:  Grading an argument to an external command"
result=$( echo "cat $testIn" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "hello" $letterGrade

#If nothing above has failed, then smash is executing internal and external-------
#commands with and without arguments.

#Verify smash can cd into a real directory and execute a command there------------
logMsg $LINENO "Note:  Grading cd into $testDir and executing a command there"
mkdir $testDir                        #Build the directory
echo "foo" >$testDir/foo              #Build file foo in that directory
echo "cd $testDir"          >$tmpFile
echo "rm foo"              >>$tmpFile
$timeout 5s ./$EXE <$tmpFile           #Ask smash to cd there and rm file foo
savedStatus="$?"
deductFileExists $LINENO $testDir/foo $letterGrade
if [ $savedStatus == 0 ]; then
 rm -fr $testDir                       #Clean-up the directory and its files
fi

#Verify that smash can redirect stdin for a simple command-----------------------
logMsg $LINENO "Note:  Verifying redirection of stdin in a simple command"
result=$(echo "fgrep main <smash.c" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "int" $letterGrade

#Verify that smash can redirect stdout for a simple command---------------------
logMsg $LINENO "Note:  Verifying redirection of stdout in a simple command"
echo "fgrep main smash.c >$tmpFile" | $timeout 5s ./$EXE
deductnGrep $LINENO "main" $tmpFile $letterGrade

#Verify smash can construct a pipe between two command segments-----------------
logMsg $LINENO "Note:  Verifying smash can construct a pipe between two cmds"
result=$(echo "cat smash.c | fgrep main >$tmpFile" | $timeout 5s ./$EXE )
deductnGrep $LINENO "main" $tmpFile $letterGrade

#Verify operation of a complex command------------------------------------------
logMsg $LINENO "Note:  Verifying smash can execute a complex command"
result=$(echo "cat <smash.c | grep main | grep int | wc -l" | $timeout 5s ./$EXE )
deductMissingString $LINENO "$result" "1" $letterGrade

#Verify the basic functionality of the smash history command----------------------
logMsg $LINENO "Note:  Grading history command"
timeout 5s ./$EXE <basicHistory.in >$tmpFile 2>>$errMsg
deductnGrep $LINENO "ls"      $tmpFile $halfLetterGrade
deductnGrep $LINENO "cd"      $tmpFile $halfLetterGrade
deductnGrep $LINENO "pwd"     $tmpFile $halfLetterGrade
deductnGrep $LINENO "history" $tmpFile $halfLetterGrade

#Verify pipelines appearing in history-------------------------------------------
logMsg $LINENO "Note:  Grading a pipeline in the history"
timeout 5s ./$EXE <pipedHistory.in >$tmpFile 2>>$errMsg
deductnGrep $LINENO "cat.*sed.*wc" $tmpFile $letterGrade

#Hunt for zombies, the undead children of a neglegent shell----------------------
logMsg $LINENO "Note:  Hunting for zombies"
timeout 5s ./$EXE <zombieCheck.in >$tmpFile 2>>$errMsg
deductGrep $LINENO "defunct" $tmpFile $letterGrade

#Verify that valgrind finds nothing of extreme significance-----------------------
logMsg $LINENO "Note:  Grading valgrind results"
which valgrind
if [ "$?" != 0 ]; then
 logMsg $LINENO "WARNING:  valgrind not installed/found on this computer"
fi
timeout 10s valgrind ./$EXE <basicHistory.in >$tmpFile 2>&1
deductGrep $LINENO "Invalid\\s*write"         $tmpFile $letterGrade
deductGrep $LINENO "definitely lost\\s*[1-8]" $tmpFile $letterGrade

#Grade make clean-----------------------------------------------------------------
logMsg $LINENO "Note:  Grading make clean"
make clean
if [ "$?" != 0 ]; then
 deductPoints $letterGrade
 logMsg $LINENO "ERROR: make clean did not exit normally"
fi
deductFileExists $LINENO smash     $halfLetterGrade
deductFileExists $LINENO smash.o   $halfLetterGrade
deductFileExists $LINENO history.o $halfLetterGrade
deductFileExists $LINENO $LIB      $halfLetterGrade

#Record the score and output to console-------------------------------------------
logMsg $LINENO "NOTE:  Finished grading"
echo "Grade:  $score" >>$dest                          #backpack -e needs this
echo "Grading finished.  Results are in file, $dest"
