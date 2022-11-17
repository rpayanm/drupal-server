#!/bin/bash

# This script is used to install the drupal on a VPS server.
# https://www.digitalocean.com/community/tutorials/how-to-install-drupal-with-docker-compose-es

set -eu

function copy_nginx_config() {
  if [[ ! -d "$PROJECT_PATH/nginx-conf" ]]; then
    mkdir "$PROJECT_PATH/nginx-conf"
  fi

  CONF_FILE="nginx.conf"

  if [[ -n "${1-}" ]]; then
    if [[ $1 == "ssl" ]]; then
      CONF_FILE="nginx-ssl.conf"
    fi
  fi

  cp "nginx-conf/$CONF_FILE" "$PROJECT_PATH/nginx-conf/nginx.conf"
  sed -i "s/your_domain/$DOMAIN/g" "$PROJECT_PATH/nginx-conf/nginx.conf"
}

function copy_docker_compose_config() {
  CONF_FILE="docker-compose.yml"

  if [[ -n "${1-}" ]]; then
    if [[ $1 == "ssl" ]]; then
      CONF_FILE="docker-compose-ssl.yml"
    fi
  fi

  cp "$CONF_FILE" "$PROJECT_PATH/docker-compose.yml"
  sed -i "s/sammy@your_domain/$EMAIL/g" "$PROJECT_PATH/docker-compose.yml"
  sed -i "s/your_domain/$DOMAIN/g" "$PROJECT_PATH/docker-compose.yml"
  sed -i "s|drupal-data|$PROJECT_PATH|g" "$PROJECT_PATH/docker-compose.yml"
  sed -i "s/webroot/$WEBROOT/g" "$PROJECT_PATH/docker-compose.yml"
}

# Ask for what to do.
PS3='Please enter your choice: '
options=("Create the project (first time)" "Add SSL" "Quit")
select opt in "${options[@]}"
do
    case $REPLY in
        "1")
            break
            ;;
        "2")
            break
            ;;
        "3")
            exit
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

CONFIG_FILE="/tmp/drupal-server";
if [[ -f "$CONFIG_FILE" ]]; then
  source $CONFIG_FILE
fi

DOMAIN="abcabc.com"
EMAIL="rpayanm@gmail.com"
PROJECT_PATH="/home/rpayanm/work/websites/drupal-server/drupal"
WEBROOT="web"

if [[ -z ${DOMAIN+x} && -z ${EMAIL+x} && -z ${PROJECT_PATH+x} && -z ${WEBROOT+x} ]]; then
  ASK_VARS=true
else
  while true; do
    echo "We found that you have already set the variables before:"
    cat $CONFIG_FILE;
    read -p "Do you want to use the same variables? (Y/n) " USE_SAME_VARS
    case $USE_SAME_VARS in
      [Yy]*|"")
        ASK_VARS=false;
        break
        ;;
      [Nn])
    	  ASK_VARS=true
    		break;;
    	*) printf "You entered %s " "$USE_SAME_VARS"; echo invalid response;;
    esac
  done
fi

if [ "$ASK_VARS" = true ]; then
  # Ask for the domain name.
  validate_domain="^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$"
  while true; do
    read -p "What is your domain (Do not include www)?: " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
      echo "Domain cannot be empty"
#    elif [[ ! "$DOMAIN" =~ $validate_domain ]]; then
#      echo "Domain is not valid"
    else
      break
    fi
  done

  # Ask for the email address.
  validate_email="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$"
  while true; do
    read -p "What is your email address?: " EMAIL

    if [[ -z "$EMAIL" ]]; then
      echo "Email cannot be empty"
    elif [[ ! "$EMAIL" =~ $validate_email ]]; then
      echo "Email is not valid"
    else
      break
    fi
  done

  # Ask for your project path.
  while true; do
    read -p "What is your project path?: " PROJECT_PATH

    if [[ -z "$PROJECT_PATH" ]]; then
      echo "Project path cannot be empty"
    elif [[ ! -d "$PROJECT_PATH" ]]; then
      echo "Project path ($PROJECT_PATH) does not exist"
    else
      break
    fi
  done

  # Ask for the webroot.
  while true; do
    read -p "What is your webroot path?: " WEBROOT

    if [[ -z "$WEBROOT" ]]; then
     echo "Project path cannot be empty"
    else
     break
    fi
  done

  # Save values
  echo -e "DOMAIN=$DOMAIN\nEMAIL=$EMAIL\nPROJECT_PATH=$PROJECT_PATH\nWEBROOT=$WEBROOT" > /tmp/drupal-server
fi

# Create the project.
if [[ $REPLY == "1" ]]; then
  copy_nginx_config;
  cp .env "$PROJECT_PATH/.env"
  copy_docker_compose_config;
  cd "$PROJECT_PATH" && docker-compose up -d && cd ..
fi

# Add SSL.
if [[ $REPLY == "2" ]]; then
  copy_nginx_config "ssl";
  copy_docker_compose_config "ssl";
  cp ssl_renew.sh "$PROJECT_PATH/ssl_renew.sh"
  chmod +x "$PROJECT_PATH/ssl_renew.sh"
  sed -i "s|project_path|$PROJECT_PATH|g" "$PROJECT_PATH/ssl_renew.sh"
  # Add to the crontab
  CRON_CMD="$PROJECT_PATH/ssl_renew.sh >> /var/log/cron.log 2>&1"
  CRON_JOB='* 2 * * 2 '"$CRON_CMD"
  ( crontab -l | grep -v -F "$CRON_CMD" || : ; echo "$CRON_JOB" ) | crontab -
fi