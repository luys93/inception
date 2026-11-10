DATA_DIR = /home/lluciani/data

all:
	@mkdir -p $(DATA_DIR)/wordpress
	@mkdir -p $(DATA_DIR)/mariadb
	@docker compose -f ./srcs/docker-compose.yml up -d --build
down: 
	@docker compose -f ./srcs/docker-compose.yml down
start:
	@docker compose -f ./srcs/docker-compose.yml start
stop:
	@docker compose -f ./srcs/docker-compose.yml stop
ps:
	@docker compose -f ./srcs/docker-compose.yml ps

re: down all

clean: down
	@sudo rm -rf $(DATA_DIR)/wordpress/*
	@sudo rm -rf $(DATA_DIR)/mariadb/*

fclean: clean
	@docker compose -f ./srcs/docker-compose.yml down -v --rmi all
	@sudo rm -rf $(DATA_DIR)

.PHONY: all down start stop ps re clean fclean
