#!/bin/bash

source ~/scripts/bg_music/bg_music.cfg

declare -a musicFiles

in=/dev/shm/mpg123-in.fifo
out=/dev/shm/mpg123-out.txt


function log ()
# Prints messages of different severeties to a logfile
# Each message will look something like this:
# <TIMESTAMP>	<SEVERITY>	<CALLING_FUNCTION>	<MESSAGE>
# needs a set variable $logLevel
#	-1 > No logging at all
#	0 > prints ERRORS only
#	1 > prints ERRORS and WARNINGS
#	2 > prints ERRORS, WARNINGS and INFO
#	3 > prints ERRORS, WARNINGS, INFO and DEBUGGING
# needs a set variable $log pointing to a file
# Usage
# log 0 "This is an ERROR Message"
# log 1 "This is a WARNING"
# log 2 "This is just an INFO"
# log 3 "This is a DEBUG message"
{
	severity=$1
	message=$2
	
	if (( ${severity} <= ${logLevel} ))
	then
		case ${severity} in
			0) level="ERROR"  ;;
			1) level="WARNING"  ;;
			2) level="INFO"  ;;
			3) level="DEBUG"  ;;
		esac
		
		printf "$(date +%FT%T%:z):\t${level}\t$$\t${0##*/}\t${FUNCNAME[1]}\t${message}\n" >> ${log} 
	fi
}


function getMusicFiles ()
# creates an array of all music files in $mainDir
{
	log 3 "()"
	# define sortString
	case "${playOrder}" in
		"seq") sortString="-k 1,1" ;;
		"rnd") sortString="-R" ;;
	esac

	while read file
	do
		musicFiles+=("${file}")
	done <<< $(find ${mainDir} -iname "*.mp3" | sort ${sortString})
	
	log 3 "Found Files: ${#musicFiles[@]}"
}

function startBGM ()
# start the background music
{
	startMPG123
	setVolume "${startVolume}"
	getMusicFiles
	if [ "${firstFile}" != "n/a" ]
	then
		play "${firstFile}"
	else
		play "${musicFiles[0]}"
	fi
	
	nohup ./bg_music.sh "waitForEndOfTrack" > /dev/null 2>&1 &
	log 3 "WaitLoop PID $!"
}

function startMPG123 ()
# starts MPG123 with a FIFO input file
{
	log 3 "()"
	if [ "$(pgrep mpg123)" == "" ]
	then
		nohup mpg123 --remote --fifo "${in}" > "${out}" 2>&1 &
		log 2 "Started MPG123, PID $!"
	else
		log 2 "Found a running instance with PID $(pgrep mpg123)"
	fi
	silence
}

function command ()
# send a command to a running MPG123 instance using FIFO
{
	sleep 0.1
	echo "$1" > "${in}"
}

function play ()
# play a file
{
	log 3 "($1) "
	command "load $1"
}

function setVolume ()
# set the volume
{
	log 3 "($1) "
	command "volume $1"
}

function pause ()
# pause / unpause
{
	log 3 "()"
	command "pause"
}

function stop ()
# stop playback
{
	command "stop"
}

function quit ()
# quit
{
	log 3 "()"
	command "quit"
	
	rm "${in}"
	rm "${out}"
}

function help ()
{
	log 3 "()"
	command "help"
}

function silence ()
# suppresses frame messages
{
	command "silence"
}

function fadeOut ()
# fade out from $startVolume to 0 in $fadeInOut seconds
{
	log 3 "()"
	
	integer=$(( ${fadeInOut} / ${startVolume} ))
	decimal=$(tail -c 3 <<< "00$(tail -c 3 <<< $(( ${fadeInOut}00 / ${startVolume} )))")
	step=${integer}.${decimal}
	log 2 "FadeOut from ${startVolume} to 0 in ${fadeInOut} seconds, ${step}"
	
	volume=${startVolume}
	while [[ ${volume} -gt 0 ]]
	do
		(( volume=volume - 1 ))
		echo "volume ${volume}" > "${in}"
		sleep ${step}
	done
}

function fadeIn ()
{
	log 3 "()"
	
	integer=$(( ${fadeInOut} / ${startVolume} ))
	decimal=$(tail -c 3 <<< "00$(tail -c 3 <<< $(( ${fadeInOut}00 / ${startVolume} )))")
	step=${integer}.${decimal}
	log 2 "FadeIn from 0 to ${startVolume} in ${fadeInOut} seconds, ${step}"
	
	volume=0
	while [[ ${volume} -lt ${startVolume} ]]
	do
		(( volume=volume + 1 ))
		echo "volume ${volume}" > "${in}"
		sleep ${step}
	done
}

function waitForEndOfTrack()
# waits for the end of the currently playing track
{
	log 3 "()"
	
	while [ true ]
	do
		sleep 1
		
		# wait for string "@P 0" in $out
		if [[ $(grep -c "@P 0" ${out}) -gt 0 ]]
		then
			log 3 "End of Track detected"
			truncate --size 0 "${out}"
			break
		fi
		
		# exit if fifo-file does no longer exist --> player has been quit
		if [ ! -p "${in}" ]
		then 
			log 3 "Exit"
			exit
		fi
	done
	
	getMusicFiles
	play "${musicFiles[0]}"
	
	nohup ./bg_music.sh "waitForEndOfTrack" 2>&1 &
	log 3 "WaitLoop PID $!"
}




function test ()
{
	startBGM
	sleep 10

	fadeOut
	pause

	sleep 15

	pause
	fadeIn

	sleep 20
	quit
}


########
# MAIN #
########

# no parameter given, start BGM
if [ "$1" == "" ]; then startBGM; fi

if [ "$1" == "waitForEndOfTrack" ]; then waitForEndOfTrack; fi

if [ "$1" == "UnpauseAndFadeIn" ]; then pause; fadeIn; fi
if [ "$1" == "fadeOutAndPause" ]; then fadeOut; pause; fi

if [ "$1" == "pause" ]; then pause; fi
if [ "$1" == "quit" ]; then quit; fi

if [ "$1" == "help" ]; then help; fi
if [ "$1" == "silence" ]; then silence; fi



