#!/bin/bash
# GPLv3 2021 by Gunstick/ULM
hatarisav=.autohatari.sav
hataricfg=.autohatari.cfg
for tool in xdotool/xdotool inotify-tools/inotifywait hatari/hatari
do
  pkg="$(echo "$tool" | cut -d/ -f1)"
  cmd="$(echo "$tool" | cut -d/ -f2)"
  if [ "$(which "$cmd")" = "" ]
  then
    echo "ERROR: please install $pkg"
    set ""
  fi
done
if [ "$1" = "" ] || [ ! -f "$1" ]
then
  echo "usage: $0 source-filename [dependencies...]"
  echo "dependencies are other files to check for changes which will trigger the make"
  exit 1
fi
if [ ! -f "$hatarisav" ]
then
  rm "$hatarisav"
  awk -v ahs="$hatarisav" -v pwd="$PWD" '
       /bAutoSave =/{$3="FALSE"}
       /szMemoryCaptureFileName =/{$3=ahs}
       /szAutoSaveFileName =/{$3=ahs}
       /szHardDiskDirectory =/ {$3=pwd}
       /EnableDriveA =/{$3="FALSE"}
       /EnableDriveB =/{$3="FALSE"}
       {print}' ~/.hatari/hatari.cfg > "$hataricfg"
  hatari --drive-a off --drive-b off -c "$hataricfg" &
  sleep 2.8  # this is the time TOS needs to start reading AUTO 
  xdotool key ISO_Level3_Shift+k 
  sleep 1
  kill -9 $!
  # now we have a nice save file
  # tell hatari to use it at each start
  sed -i 's/bAutoSave = FALSE/bAutoSave = TRUE/' "$hataricfg"
  cp "$hatarisav" "$hatarisav".bak   # save it for each use
  mkdir AUTO
fi

filebase="${1%.*}"
firstrun=1
export SDL_VIDEO_WINDOW_POS="0,0"

# control loop, in background
while true
do
    firstrun=0
    result=$(make ${filebase} 2>&1)  
    if [ $? -ne 0 ]
    then
      echo "ASSEMBLER ERROR"
      echo
      echo "$result" |
      awk '/vasmm68k_mot/{next}
	   /Volker Barthelmann/{next}
	   /ColdFire cpu backend/{next}
	   /motorola syntax module/{next}
	   /output module/{next}
          {print "VASM: " $0}'
      sleep 1
    else
      echo "$result"|grep -i -e data -e code -e bss
      ls -l ${filebase}.tos
      size=$(stat --printf "%s" ${filebase}.tos)
      echo "Size minus 32 bytes header: $((size-32))"
      rm AUTO/*   # clean AUTO
      cp ${filebase}.tos AUTO/${filebase}.prg   # copy exec
      xy=$(xdotool getmouselocation|sed 's/x://;s/y://;s/ screen.*$//')
#      hatari --drive-a off --drive-b off ${filebase}.tos 2>&1| 
      cp "$hatarisav".bak "$hatarisav"  # get the savestate back
      killall -9 hatari;   # the loop below will restart automatically
      while [ "$(xdotool getmouselocation|sed 's/x://;s/y://;s/ screen.*$//')" = "$xy" ]
      do   # wait for mouse to be moved by hatari
        sleep 0.1
      done
      sleep 0.1  # wait a little more
      xdotool mousemove $xy    # move mouse back
      WID=$(xdotool search --onlyvisible --name '^hatari')
      xdotool windowmove $WID 0 0    # move hatari window to top left corner
    fi
    inotifywait -e move_self -e modify -e attrib -e close_write  "$@" >/dev/null 2>&1
    if [ $? -eq 1 ]
    then
      echo "Problem with watching $@, exiting"
      kill -3 $$
      killall hatari
      exit
    fi
done &
BGloop=$!
# hatari main loop, in foreground, so that debugger works
trap "kill $BGloop ; exit" 1 2 3
while true
do
  echo "press CTRL-C to quit"
  hatari --bios-intercept yes -c "$hataricfg" 
  #echo "hatari return code: $?"
  # bios-intercept allows to jump to debugger
  # example macro to call debugger from program:
  date +%s%N
  echo "
DEBUGHERE: Macro
        move.l  #0,-(sp)
        move.w  #0,-(sp)
        move.w  #5,-(sp)
        move.w #11,-(sp)   ; call hatari debugger (XBIOS Dbmsg)
        trap #14 ; xbios
        add.l   #10,sp

        EndM
  " >/dev/null
  # after quitting hatari manually, check if we wait
  waitingPID="$(ps -edf| awk -v pid=$BGloop '$3==pid && /inotifywait/{print $2}' )"
  # echo "waiting PID=$waitingPID"
  if [ "$waitingPID" != "" ]
  then
    kill "$waitingPID"
    sleep 0.5
  fi
#  echo "sleeping for debugging"
#  sleep 10
done
