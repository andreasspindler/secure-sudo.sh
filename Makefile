.PHONY: all

NAME=secure-sudo.sh

all:
	@bash -n *.sh
	@chmod +x $(NAME)
	./$(NAME)
	@ps u | grep 'bash .*/$(NAME)$$' && echo 'WARNING: sudo heartbeat still running' || true

