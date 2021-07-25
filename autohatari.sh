#!/bin/bash
# GPLv3 2021 by Gunstick/ULM
hatarisav=.autohatari.sav
hataricfg=.autohatari.cfg
for tool in xdotool/xdotool inotify-tools/inotifywait hatari/hatari zenity/zenity
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
  # maybe need to test this dynamically to find the best time, or use a breakpoint?
  sleep 2.7  # this is the time TOS needs to start reading AUTO 
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
createdexec="${filebase}.tos"   # somewhere here add option to also use prg as result
firstrun=1
export SDL_VIDEO_WINDOW_POS="0,0"   # this should work, but does not, thus the need for xdotool

# control loop, in background
while true
do
    firstrun=0
    result=$(make ${filebase} 2>&1)  
    if [ $? -ne 0 ]
    then
      echo "ASSEMBLER ERROR"
      echo
      result="$(
      echo "$result" |     # do a nicer job of displaying assembly errors
      awk '/vasmm68k_mot/{next}
	   /Volker Barthelmann/{next}
	   /ColdFire cpu backend/{next}
	   /motorola syntax module/{next}
	   /output module/{next}
          {print "VASM: " $0}'
      )"
      echo "$result"
      zenity --text-info --title 'VASM output' --width=800 --height=600 --filename=/dev/stdin --font=monospace <<<"$result" &
      zenityPID=$!
      sleep 0.5   # wait for zenity window to actually be there
      zWID=$(xdotool search --onlyvisible --name '^VASM output')
      killall hatari    # stop hatari as there is an error, so not displaying anything instead of "working code" which is old
      xdotool windowmove $zWID 0 0
      sleep 1
    else
      echo "$result"|grep -i -e data -e code -e bss
      ls -l ${createdexec}
      size=$(stat --printf "%s" ${createdexec})
      echo "Size minus 32 bytes header: $((size-32))"
      rm AUTO/*   # clean AUTO
      cp ${createdexec} AUTO/${filebase}.prg   # copy exec (only PRG extension is allowed in AUTO)
      xy=$(xdotool getmouselocation|sed 's/x://;s/y://;s/ screen.*$//')
      cp "$hatarisav".bak "$hatarisav"  # get the savestate back
      killall -9 hatari;   # the loop below will restart automatically
      while [ "$(xdotool getmouselocation|sed 's/x://;s/y://;s/ screen.*$//')" = "$xy" ]
      do   # wait for mouse to be moved by hatari
        sleep 0.1
      done
      sleep 0.1  # wait a little more
      xdotool mousemove $xy    # move mouse back
      WID=$(xdotool search --onlyvisible --name '^hatari v')
      if [ "$(echo "$WID" | wc -l)" -ne 1 ]
      then
        echo "Cant find window"
        echo "$WID" | while read w
        do
          xdotool getwindowname $w
        done
        exit
      fi 
      xdotool windowmove $WID 0 0    # move hatari window to top left corner
    fi
    inotifywait -e move_self -e modify -e attrib -e close_write  "$@" >/dev/null 2>&1
    inotifywaitRS=$?
    if kill -0 $zenityPID 2>/dev/null
    then
      kill -9 $zenityPID
    fi
    if [ $inotifywaitRS -eq 1 ]
    then
      echo "Problem with watching $@, exiting"
      kill -3 $$
      killall hatari
      exit
    fi
done &
BGloop=$!
# hatari main loop, in foreground, so that debugger works
trap "kill $BGloop ; killall hatari ; killall zenity ; exit" 1 2 3    # yeah, may kill other zenity on the machine...
while true
do
  echo "press CTRL-C to quit"
  hatari --bios-intercept yes -c "$hataricfg" 
  # if zenity is running, means we have an error
  while [ "$(xdotool search --onlyvisible --name '^VASM output')" != "" ]
  do
    sleep 1
  done
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
