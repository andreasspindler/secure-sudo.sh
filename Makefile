.PHONY: all

# runs secure-sudo.sh test script 
all:
	bash -n *.sh
	chmod +x secure-sudo.sh
	./secure-sudo.sh
	ps u


