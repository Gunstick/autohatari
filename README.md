# autohatari
a fast turnaround development tool for hatari/linux  
Less than one second between source save and running in the emulator.

## features
- Sets up the whole environment automatically
- Calls make (example Makefile included)
- moves the created TOS as PRG into AUTO folder
- then runs hatari 

## dependencies
The script checks and asks to install the following:
- hatari
- xdotool
- inotifywait (from inotify-tools)

## How the fast turnaround is achieved?
On first launch, hatari is started normally and then interrupted at the execution point of the AUTO folder.  
A savestate is created and reused for the next starts.

The script then waits for a file change.   
When a change is detected, it runs make, and copies the new executable to AUTO.  
Then hatari is restarted with this save state. 

## Usage
You need to run this from a command line to get the output and interact with the script  
Start with: 

    ./autohatari.sh example.s

It is assumed that make will create an associated &lt;source&gt;.tos i.e. 'example.tos' file. If this is not the case, then autohatari will not work correctly.

You can add multiple files (like includes) after the main source, so if an include is changed, it's taken into account:

    ./autohatari.sh example.s message.s

### using the hatari debugger
The system is running in a way that you can jump to debugger with the hot key (usually AltGr+Pause), you can redefine this key combo in hatari by pushing F12 -> Keyboard -> shortcuts -> Enter Debugger  
The debugger will then be useable in the shell where you started autohatari

You can also jump to the debugger via XBIOS Dbmsg, here is a nice macro:

    DEBUGHERE: Macro
        move.l  #0,-(sp)
        move.w  #0,-(sp)
        move.w  #5,-(sp)
        move.w #11,-(sp)   ; call hatari debugger (XBIOS Dbmsg)
        trap #14 ; xbios
        add.l   #10,sp
        EndM

More info on hatari debugger: https://hatari.tuxfamily.org/doc/debugger.html
