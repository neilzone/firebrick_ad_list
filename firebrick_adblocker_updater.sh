#!/bin/bash

# Run this from bash, not sh
# Does not work in macOS at the moment — problem with SSL

# Add in your FireBrick credentials

firebrick=Your FireBrick's hostname or IP
firebrickpath=https://Your FireBrick's hostname or IP/config/config
firebrickuser=FireBrick user with write permission
firebrickpassword=FireBrick user's password

adlist=pgl.yoyo.org/adservers/serverlist.php

function make_ads_file () {
		# create a file for next comparison
		cp ads.txt previous_ads.txt
		cp ads.txt ads2.txt
		sed -i.bak 's/^/*./' ads2.txt
		echo "Prepared list"
		cat ads2.txt >> ads.txt
		echo "Combined list"
		rm ads2.txt ads2.txt.bak
		awk -v ORS=" " '1' ads.txt > new.txt
		echo "Added FireBrick mark-up"
		echo '<block name="' > output.txt
		cat new.txt >> output.txt
		echo '" ttl="1" comment="auto_adlist"/>' >> output.txt
		tr -d '\n' < output.txt > ads_new.txt
		echo "Ad list file created"
		rm ads.txt new.txt output.txt
}

# check if there are any new ad servers / trackers — if not, abort. Avoids unnecessary writes to FireBrick's flash

function check_if_updated () {
		if [ -f previous_ads.txt ]; then
			echo "Starting comparison with previous ad list"
			if ! cmp -s "previous_ads.txt" "ads.txt"; then
				make_ads_file
			else
				echo "No updates"
				rm ads.txt
				exit
			fi
		else
			echo "No files to compare"
			make_ads_file
		fi
}


if [[ ! -f ads.txt && ! -f ads2.txt && ! -f output.txt ]]; then
	if curl --output /dev/null --silent --head --fail "$adlist"; then
		echo "Able to reach $adlist."
			if curl -sL --fail "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=0&mimetype=plaintext" -o ads.txt; then
				echo "Downloaded ad list"
				check_if_updated
			else
				echo "Error: cannot download ad list from $adlist"
				exit
			fi
	else
		echo "Error: cannot reach $adlist"
  		exit
	fi
else
	echo "Error: ads.txt, ads2.txt, or output.txt already exists. Remove them if you want to continue. Once removed, re-run this script."
	exit
fi

if [ ! -f firebrick_config.txt ]; then
	if curl --output /dev/null --silent --head --fail "$firebrick"; then
		curl --silent $firebrickpath --user "$firebrickuser:$firebrickpassword" --output config.txt
		echo "Downloaded FireBrick config"
		# work out line number of last line of adblocklist config
		LINENUMBER=$(grep -n 'auto_adlist' config.txt|cut -f1 -d:)

		# line count (N): 
		N=$(wc -l < config.txt)

		# length of the bottom file:
		L=$(( $N - $LINENUMBER ))
		
		#But we don't want to include the actual block text, so cut above that. (-3 because three lines: the domains, the ttl, and the comment):
		
		CUTHERE=$(( $LINENUMBER - 3 ))

		# length of the bottom file (below the block text):
		L=$(( $N - $LINENUMBER ))

		# create the top of file: 
		head -n $CUTHERE config.txt > top_firebrick_config.txt

		# create bottom of file: 
		tail -n $L config.txt > bottom_firebrick_config.txt
		
		#Reassemble
		
		cat top_firebrick_config.txt > new_config.txt
		cat ads_new.txt >> new_config.txt
		cat bottom_firebrick_config.txt >> new_config.txt
		
		#Tidy up
		
		rm ads_new.txt config.txt top_firebrick_config.txt bottom_firebrick_config.txt

	else	
		echo "Error: cannot reach $firebrick"
		exit
	fi
else
	echo "Error: firebrick_config.txt already exists"
	exit
fi

if curl -sL --fail $firebrickpath --user "$firebrickuser:$firebrickpassword" --form config="@new_config.txt" | grep -q "Config loaded"; then
	echo "Config installed"
	rm new_config.txt
else
	echo "Error: upload failed"
	exit
fi
