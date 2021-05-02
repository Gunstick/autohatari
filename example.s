; example code to test autohatari script
  pea       message      ; adress of string
  move.w    #9,-(sp)     ; Cconws
  trap      #1           ; GEMDOS
  addq.l    #6,sp        ; Correct stack

; wait key
  move.w    #1,-(sp)     ; Conin
  trap      #1           ; GEMDOS
  addq.l    #2,sp        ; Correct stack

  clr.w   -(sp)     ; #0 exit
  trap    #1        ; gemdos 

  data
  include "message.s"
 
