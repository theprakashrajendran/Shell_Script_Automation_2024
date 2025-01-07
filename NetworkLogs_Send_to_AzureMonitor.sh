#!/bin/bash
clear
start_time=$(date +%s)
IFS='_' read -r -a PARTS_ScriptFileName <<< "$0"
echo "********Script $0 Started********"
#variables
input_file_customconfig="/home/lsasz49yw/prodscripts/customconfig/computernames/computername${PARTS_ScriptFileName[1]}.json"
echo $input_file_customconfig
path_collectd="/network/var/lib/collectd"
currentyear=$(date +%Y)
TODAYDATE=$(date +"%Y-%m-%d")
#LOG_FILENAME="NetworkLogCustomOutput_$TODAYDATE.log"
LOG_FILENAME="NetworkLogCustomOutput_${PARTS_ScriptFileName[1]}.txt"
#Custom_Log_File_Path="/home/lsasz49yw/prodscripts//AzureMonitor/$LOG_FILENAME"
TempRunningCustom_Log_File_Path="/home/lsasz49yw/prodscripts/TempLogPath/$LOG_FILENAME"
#Configuration file path
CONFIG_FILE="/home/lsasz49yw/prodscripts/customconfig/logfolderdetails/log_${PARTS_ScriptFileName[1]}_config.txt"
#Load configuration file
source "$CONFIG_FILE"
echo $AzureMonitorFOLDER1


$CONFIG_FILE
#Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
	echo "Congiguration file not found: $CONFIG_FILE"
	exit 1
fi



#check if necessary variables are set in the config file
if [ -z "$AzureMonitorFOLDER1" ] || [ -z "$AzureMonitorFOLDER2" ] || [ -z "NEXT_FOLDER" ]; then
	echo "Configuration file is missing necessary settings."
	exit 1
fi

# Identify which folder to use for the current log file
if [ "$NEXT_FOLDER" -eq 1 ]; then
	Custom_Log_File_Path="$AzureMonitorFOLDER1/$LOG_FILENAME"
	NEW_NEXT_FOLDER=2
else
	Custom_Log_File_Path="$AzureMonitorFOLDER2/$LOG_FILENAME"
	NEW_NEXT_FOLDER=1
fi

echo $Custom_Log_File_Path
echo $NEXT_FOLDER

declare -i HEADERNAMECOUNT=0
HEADERCOLUMNVALUES=""
#functions
#function to get log header count
function get_log_header_column_count() {
	local slogFilePath=$1	
	declare -i sHEADERNAMECOUNT=0
	sHEADERCOLUMNVALUES="default"
	(head -n 1 "$slogFilePath") | while IFS= read -r Log_header_values; do
					IFS=',' read -r -a PARTS_LOGHEADERVALUE <<< $Log_header_values	
					for headerValue in "${PARTS_LOGHEADERVALUE[@]}"; do
					        sHEADERNAMECOUNT+=1
					done
					#echo "$sHEADERNAMECOUNT,${PARTS_LOGHEADERVALUE[1]}"
					if [[ ${sHEADERNAMECOUNT} = 2 ]]; then
						sHEADERCOLUMNVALUES="$sHEADERNAMECOUNT,${PARTS_LOGHEADERVALUE[1]}"
					elif [[ ${sHEADERNAMECOUNT} = 3 ]]; then
						sHEADERCOLUMNVALUES="$sHEADERNAMECOUNT,${PARTS_LOGHEADERVALUE[1]},${PARTS_LOGHEADERVALUE[2]}"
					fi
					  HEADERCOLUMNVALUES=$sHEADERCOLUMNVALUES
					  echo $HEADERCOLUMNVALUES
			done
	return $HEADERCOLUMNVALUES
}

function insert_last_log_entry() {
	local slog_File=$1
	local sObject_Name=$2
	local sCounter_Name=$3	
	local sInstance_Name=$4
	local sType=$5
echo "insert_last_log_entry slog_File: ${slog_File}"
echo "insert_last_log_entry sObject_Name: ${sObject_Name}"
echo "insert_last_log_entry sCounter_Name: ${sCounter_Name}"
echo "insert_last_log_entry sInstance_Name: ${sInstance_Name}"
echo "insert_last_log_entry sType: ${sType}"

	(tail -n 1 "${slog_File}") | while IFS= read -r log_values; do
    		#echo "LogValues :$log_values"
			IFS=',' read -r -a PARTS_LOGVALUE <<< $log_values
		#$OBJECTNAME,$COUNTERNAME,$INSTANCENAME,$computer_info,$LOGFILEPATH,$LOG_FILE
		#echo $(date -d @${PARTS_LOGVALUE[0]} +"%m/%d/%Y %H:%M:%S %p"),"${PARTS_LOGVALUE[1]}",$OBJECTNAME,$COUNTERNAME,$INSTANCENAME >> "$LOG_FILENAME"
		LOGFIRSTCOLUMNVALUE=""
		if [[ "${sType}" = "value" ]]; then
			LOGFIRSTCOLUMNVALUE="${PARTS_LOGVALUE[1]}"
		elif [[ "${sType}" = "rx" ]]; then
			LOGFIRSTCOLUMNVALUE="${PARTS_LOGVALUE[1]}"
		elif [[ "${sType}" = "tx" ]]; then
			LOGFIRSTCOLUMNVALUE="${PARTS_LOGVALUE[2]}"
		fi
		echo $(date -d @${PARTS_LOGVALUE[0]} +"%-m/%d/%Y %I:%M:%S %p"),"$LOGFIRSTCOLUMNVALUE","$sObject_Name","$sCounter_Name","$sInstance_Name" >> "$LOG_FILENAME"
	done
}

if [ -f "$Custom_Log_File_Path" ]; then
	rm "$Custom_Log_File_Path"
	echo "Existing Log File has been removed."
else
	echo "Existing Log File does not exist."
fi

if [ -f "$TempRunningCustom_Log_File_Path" ]; then
	rm "$TempRunningCustom_Log_File_Path"
	echo "Existing Log File has been removed from Temp Folder"
else
	echo "Existing Log File does not exist in Temp Folder"
fi

jq -r '.computernamelists[] | "\(.computername)"' "$input_file_customconfig" |
while IFS= read -r computer_info; do
    	#echo "Company Info:$computer_info"
   	COMPUTERNAMEDIRECTORYS="$path_collectd/csv/$computer_info"
       #Iterate over each folder in the computer directory	
    	for COMPUTERNAMEPATH in "$COMPUTERNAMEDIRECTORYS"/*
	do
	        for LOGFILEPATH in "$COMPUTERNAMEPATH"
        	do
			BASENAME_LFPN=$(basename "$LOGFILEPATH")
                	#echo "Base Name : ${BASENAME_LFPN}"
               		IFS='-' read -r -a PARTS_LFPN <<< "$BASENAME_LFPN"
                	INSTANCENAME="${PARTS_LFPN[1]}"
			TEST="${PARTS_LFPN[2]}"
			#if[$TEST != null]; then
				if [[ "${PARTS_LFPN[2]}" != "" ]]; then
					INSTANCENAME="${PARTS_LFPN[1]}-${PARTS_LFPN[2]}"
					if [[ "${PARTS_LFPN[3]}" != "" ]]; then
						INSTANCENAME="$INSTANCENAME-${PARTS_LFPN[3]}"
					fi
				fi
			#fi
			#echo "Instance Name : $INSTANCENAME"
			#echo "$computer_info Log Fle Path : ${LOGFILEPATH}"
			#TODAYDATE="2024-08-05"
		
			#echo $LOGFILEPATH
			#find "$LOGFILEPATH" -mmin +700 -type f -newermt "$TODAYDATE" ! -newermt "$TODAYDATE +1 day" | while read -r LOG_FILE; do
			find "$LOGFILEPATH" -type f -newermt "+1 mins ago" | while read -r LOG_FILE; do
			 	#echo "Today's log files: $LOG_FILE"
				BASENAME_LFN=$(basename "$LOG_FILE")
                        	IFS='-' read -r -a PARTS_LFN <<< "$BASENAME_LFN"
                        	#echo "Object Name : ${PARTS_LFN[0]}"
				OBJECTNAME=${PARTS_LFN[0]}
				COUNTERNAME=${PARTS_LFN[1]}
             			nHEADERCOLUMNVALUES=$(get_log_header_column_count "$LOG_FILE")
     				echo "Log Header Columns Count: ${nHEADERCOLUMNVALUES}, Computer Name : $computer_info"
				IFS=',' read -r -a PARTS_HCV <<< "$nHEADERCOLUMNVALUES"
				if [[ "${PARTS_HCV[0]}" = "2" ]]; then
					if [[ "${PARTS_LFN[1]}" != "${currentyear}" ]]; then
						#.value
						#COUNTERNAME="${PARTS_LFN[1]}-${PARTS_LFN[2]}.${PARTS_HCV[1]}"
						CONSTRUCTFILENAME=""
						REMOVENOTREQUIREDVALUE=""	
						for item in "${PARTS_LFN[@]}"; do
							if [[ $CONSTRUCTFILENAME == "" ]]; then
								if [[ $item != $OBJECTNAME ]]; then
									CONSTRUCTFILENAME="$item"
								fi
							else
								if [[ $item == $currentyear ]]; then
									REMOVENOTREQUIREDVALUE="Yes"
								fi

								if [[ $REMOVENOTREQUIREDVALUE == "" ]]; then
									CONSTRUCTFILENAME+="-$item"
								fi
							fi
						done
					 COUNTERNAME="${CONSTRUCTFILENAME}.${PARTS_HCV[1]}"
						if [[ ${PARTS_LFN[3]} == "Controlled" || ${PARTS_LFN[3]} == "Uncontrolled" ]]; then
							COUNTERNAME="${PARTS_LFN[1]}-${PARTS_LFN[2]}-${PARTS_LFN[3]}.${PARTS_HCV[1]}"
						  	INSTANCENAME="${PARTS_LFPN[1]}--${PARTS_LFN[3]}"						
						fi
					else
						COUNTERNAME="${PARTS_HCV[1]}"
					fi
						#insert_last_log_entry $LOG_FILE "$OBJECTNAME" "$COUNTERNAME" "$INSTANCENAME" "value"
					(tail -n 1 "$LOG_FILE") | while IFS= read -r log_values; do
    						#echo "LogValues :$log_values"
						IFS=',' read -r -a PARTS_LOGVALUE <<< $log_values
							#,"$computer_info", $COMPUTERNAMEPATH","$LOGFILEPATH","$LOG_FILE"
						if [[ $INSTANCENAME == "" ]]; then
							INSTANCENAME="_Total"
						fi
		echo $(date -d @${PARTS_LOGVALUE[0]} +"%-m/%d/%Y %I:%M:%S %p"),"${PARTS_LOGVALUE[1]}",$computer_info,$OBJECTNAME,$COUNTERNAME,$INSTANCENAME >> "$TempRunningCustom_Log_File_Path"
						done

			elif [[ "${PARTS_HCV[0]}" = "3" ]]; then
					#rx
					if [[ "${PARTS_LFN[1]}" != "${currentyear}" ]] && [[ "${PARTS_HCV[1]}" != "rx" ]]; then
						#.rx
						COUNTERNAME="${PARTS_LFN[1]}-${PARTS_LFN[2]}.${PARTS_HCV[1]}"
					elif [ "${PARTS_HCV[1]}" == "rx"  ]; then
						COUNTERNAME="${PARTS_LFN[1]}.${PARTS_HCV[1]}"
					else
						COUNTERNAME="${PARTS_HCV[1]}"
					fi
						#insert_last_log_entry $LOG_FILE "$OBJECTNAME" "$COUNTERNAME" $INSTANCENAME "rx"
					(tail -n 1 "$LOG_FILE") | while IFS= read -r log_values; do
    						#echo "LogValues :$log_values"
						IFS=',' read -r -a PARTS_LOGVALUE <<< $log_values
						if [[ $INSTANCENAME == "" ]]; then
							INSTANCENAME="_Total"
						fi
		echo $(date -d @${PARTS_LOGVALUE[0]} +"%-m/%d/%Y %I:%M:%S %p"),"${PARTS_LOGVALUE[1]}",$computer_info,$OBJECTNAME,$COUNTERNAME,$INSTANCENAME,$computer_info,$LOGFILEPATH,$LOG_FILE
 >> "$TempRunningCustom_Log_File_Path"
						done

					#tx
					if [[ "${PARTS_LFN[1]}" != "${currentyear}" ]] && [[ "${PARTS_HCV[2]}" != "tx" ]]; then
						#.tx
						COUNTERNAME="${PARTS_LFN[1]}-${PARTS_LFN[2]}.${PARTS_HCV[2]}"
					elif [ "${PARTS_HCV[2]}" == "tx"  ]; then
						COUNTERNAME="${PARTS_LFN[1]}.${PARTS_HCV[2]}"
					else
						COUNTERNAME="${PARTS_HCV[2]}"
					fi
						#insert_last_log_entry $LOG_FILE "$OBJECTNAME" "$COUNTERNAME" "$INSTANCENAME" "tx"
						(tail -n 1 "$LOG_FILE") | while IFS= read -r log_values; do
    						#echo "LogValues :$log_values"
						IFS=',' read -r -a PARTS_LOGVALUE <<< $log_values
						if [[ $INSTANCENAME == "" ]]; then
							INSTANCENAME="_Total"
						fi
		echo $(date -d @${PARTS_LOGVALUE[0]} +"%-m/%d/%Y %I:%M:%S %p"),"${PARTS_LOGVALUE[2]}",$computer_info,$OBJECTNAME,$COUNTERNAME,$INSTANCENAME >> "$TempRunningCustom_Log_File_Path"
						done
				fi		
                        done		
		done
	done
done

if [ -f "$TempRunningCustom_Log_File_Path" ]; then
	mv "$TempRunningCustom_Log_File_Path" "$Custom_Log_File_Path"
	echo "Latest Log File has been moved"
else
	echo "Log File does not exist in Temp Folder"
fi

#update the configuration file for the next execution
sed -i "s/^NEXT_FOLDER=.*/NEXT_FOLDER=${NEW_NEXT_FOLDER}/" "$CONFIG_FILE"

end_time=$(date +%s)

script_execution_time=$((end_time - start_time))

hours=$((script_execution_time / 3600))
minutes=$(((script_execution_time % 3600) / 60))
seconds=$((script_execution_time % 60))


echo "Script execution time : $hours hours, $minutes minutes and $seconds seconds"
exit