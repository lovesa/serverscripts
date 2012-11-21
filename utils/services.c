#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char *argv[]){
	char cmd[30]="/etc/init.d/";
	if (argc != 3)
	{
		printf("Please provide a service and a command");
		return 1;
	}
	strcat(cmd, argv[1]);
	strcat(cmd, " ");
	strcat(cmd, argv[2]);
	
	printf("Running: %s\n", cmd);
	setuid(0);
	system(cmd);
	return 0;
}
