#!/bin/bash
# This script is used to invite users from one Grafana instance to another Grafana instance when you have multiple Grafana
# instances. There is no parsing API responses, which can contain errors, so you should check output of this script and 
# fix errors manually or add additional logic to this script.
# For example, curl requests with invite can return SMTP error, if you have not configured SMTP server in Grafana, and script
# will not stop, because it's not error in script, it's successful response that contain error.

set -e

credentials="admin:password"

# dictionary of source Grafana instances and their corresponding target Grafana instances
declare -A grafanas
grafanas["old-grafana-1.example.com"]="new-grafana-1.example.com"
grafanas["old-grafana-2.example.com"]="new-grafana-2.example.com"

########################################################################################################
#                               MOVING USERS FROM ONE GRAFANAS TO ANOTHER                              #
########################################################################################################

# "key : $i" "value: ${array[$i]}"
for source_host in "${!grafanas[@]}"; do
  echo -e "Source host: $source_host\n"
  echo -e "Target host: ${grafanas[$source_host]}\n"

  # Retrieve the list of users from the source Grafana instance
  users=$(curl -s -H "Content-Type: application/json" https://${credentials}@${source_host}/api/users)

  # Parse the list of users and invite each user to the target Grafana instance
  while read -r user; do
    name=$(echo $user | jq '.name')
    email=$(echo $user | jq '.email')
    id=$(echo $user | jq '.id')

    # retrieve role by id
    role=$(curl -s -H "Content-Type: application/json" "https://${credentials}@${source_host}/api/users/${id}/orgs" | jq -c '.[]' | jq '.role')

    echo -e "${name} ${email} ${role}\n"

    # Invite the user to the target Grafana instance
    if [ $email == "\"admin@localhost"\" ]; then
      echo "Skipping admin user"
  # Uncomment this if you want to change email domain to alias domain
    # elif [[ $email =~ .*not_needed_domain.com.* ]]; then
    #   echo "Changing not_needed_domain user: $email"
    #   email=$(echo "${email}" | sed 's/not_needed_domain.com/needed_domain.com/')
    #   echo "New email: $email"
    #   curl -s -X POST -H "Content-Type: application/json" -d "{\"name\":$name,\"LoginOrEmail\":$email,\"role\":$role,\"sendEmail\":true}" "https://${credentials}@${grafanas[$source_host]}/api/org/invites"
    else
      echo "Invite user $email to ${grafanas[$source_host]}"
      curl -s -X POST -H "Content-Type: application/json" -d "{\"name\":$name,\"LoginOrEmail\":$email,\"role\":$role,\"sendEmail\":true}" "https://${credentials}@${grafanas[$source_host]}/api/org/invites"
    fi
  done <<< "$(echo $users | jq -c '.[]')"
done

########################################################################################################
#                                 INVITING SPECIFIC USERS TO NEW GRAFANAS                              #
########################################################################################################

# If you want to invite specific users, if they were not presented in source grafana or just not presented in target grafanas
# but they should be presented in all target grafanas.
# NOTE: This script doesn't check existing invites, it checks only existing users.
target_emails=("alex@example.com" "andrew@example.com" "vika@example.com")
role="Admin"

# It works with above dictionary of source Grafana instances and their corresponding target Grafana instances.
# You can change it to simple array of target grafanas if needed.
for source_host in "${!grafanas[@]}"; do
  echo -e "Target host: ${grafanas[$source_host]}\n"

  emails=$(curl -s -H "Content-Type: application/json" https://${credentials}@${grafanas[$source_host]}/api/users | jq -c '.[].email')

  echo -e "$emails\n"

  for target_email in "${target_emails[@]}"; do
    if ! echo $emails | grep -q $target_email; then
      echo -e "Email $target_email not found in ${grafanas[$source_host]}\n"
      curl -s -X POST -H "Content-Type: application/json" -d "{\"LoginOrEmail\":\"$target_email\",\"role\":\"$role\",\"sendEmail\":true}" "https://${credentials}@${grafanas[$source_host]}/api/org/invites"
    else
      echo -e "Email $target_email found in ${grafanas[$source_host]}\n"
    fi
  done
done
