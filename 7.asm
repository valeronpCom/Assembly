.model tiny
.code
org 100h

start:

_print      macro str  
        push ax
        push dx
        lea dx, str
        mov ah, 09h
        int 21h
        pop dx
        pop ax 
endm

_realloc macro
    push ax
    push bx
    mov sp, programLength + 100h + 200h
    mov ax, programLength + 100h + 200h
    shr ax, 4
    inc ax
    mov bx, ax
    mov ah, 4Ah
    int 21h
    pop bx
    pop ax
endm

    call CmdParse
    jc incorrectArgsErrorIndicate

    call ArgumentsParse
    jc incorrectArgsErrorIndicate

    _realloc
    jc reallocErrorIndicate

init_EPB:
    mov ax, cs
    mov word ptr EPB + 4, ax
    mov word ptr EPB + 8, ax
    mov word ptr EPB + 0Ch, ax
    
    mov ax, 04B00h
    mov dx, offset execProgName
    mov bx, offset EPB
    int 21h
    jc errorProgExecIndicate
    jmp endOfProgram

incorrectArgsErrorIndicate:
    _print incorrectArgsError
    jmp endOfProgram

reallocErrorIndicate:
    _print reallocError
    jmp endOfProgram
    
errorProgExecIndicate:
    _print programExecError    
        
    
endOfProgram:
    mov ah, 4ch
    int 21h

EPB                 dw 0000
                    dw offset cmdSize, 0
                    dw 005Ch, 006Ch
                    dd ?                   
cmdSize             db 0
cmdText             db 126 dup (?) 

programLength       equ $ - start 

maxPathSize             equ     126
flag                    db      ?
oversizeFlag            db      ?
buffer                  db      ?
;execProgName            db      "5.exe", 0 
execProgName            db     "program.exe", 0 
textFilePath            db      maxPathSize dup(0), 0
                                                                   
openingFileError            db    0dh, 0ah, "Error opening file.", 0dh, 0ah, '$'
emptyFileError              db    0dh, 0ah, "Error: file is empty.", 0dh, 0ah, '$' 
oversizeError               db    0dh, 0ah, "Error: arguments name are too large.", 0dh, 0ah, '$'
incorrectArgsError          db    0dh, 0ah, "Error: incorrect cmd arguments format.", 0dh, 0ah, '$'
reallocError                db    0dh, 0ah, "Error reallocation memory.", 0dh, 0ah, '$'
programExecError            db    0dh, 0ah, "Program execution error.", 0dh, 0ah, '$'                                                                   

CmdParse proc
    push bx
    push cx
    xor ah, ah
    mov al, byte ptr ds:[80h]
    cmp al, 0
    je cmdParseError

    xor ch, ch
    mov cl, al
    mov di, 81h
    call FileNameParse
    jc cmdParseError

    jmp cmdParseEnd
    
    cmdParseError:
    stc      
    
    cmdParseEnd:
    pop cx
    pop bx
    ret
endp

FileNameParse proc; 
    push ax
    push si
    mov al, ' '
    repe scasb
    cmp cx, 0
    je fileNameParseEmptyError
    dec di
    inc cx
    push di
    mov si, di
    mov di, offset textFilePath
    rep movsb
    jmp fileNameParseEnd
    
    fileNameParseEmptyError:
    push di    
    
    fileNameParseError:
    stc 
    
    fileNameParseEnd:
    pop di
    pop si
    pop ax
    ret
endp

CharCheck proc
    push ax
    mov al, buffer
    
    cmp al, 0Dh
    je charCheckEnd
    
    cmp al, 09h
    je charCheckEnd
    
    cmp al, ' '
    jne checkNeededSpace 
    
    mov flag, 1
    jmp charCheckEnd

    checkNeededSpace:
        cmp flag, 0
        je  dontNeedSpace
        mov al, ' '
        stosb
        inc cmdSize
        mov al, buffer
        mov flag, 0 
        dontNeedSpace:
                stosb
                mov al, 0Dh
                stosb
                inc cmdSize
                dec di
                cmp di, maxPathSize
                jne charCheckEnd
                stc
                jmp charCheckEnd

    charCheckEnd:
    pop ax
    ret
endp

LineProcessing proc
    push ax
    push dx
    push cx
    push bx
    push si

    mov oversizeFlag, 0
    
    mov al, 00h
    mov ah, 3Dh
    mov dx, offset textFilePath
    int 21h
    jc openingFileErrorIndicate
  
    mov flag, 1 
    
    mov si, cx
    dec si        
    mov bx, ax
    mov cx, 1
    mov ah, 3Fh
    mov dx, offset buffer
    
    cmp si, 0
    je processCurrentLine    

    lineApproach:
        mov ah, 3Fh
        int 21h 
        
        cmp ax, 0
        je emptyFileErrorIndicate  
        
        cmp buffer, 0Ah
        jne lineApproach
        
        dec si
        cmp si, 0
        je processCurrentLine
        jmp lineApproach
    
    processCurrentLine:
        mov ah, 3Fh
        int 21h
        
        cmp ax, 0
        je endOfLineReached 
        
        cmp buffer, 0Dh
        je endOfLineReached 
        
        cmp buffer, 0Ah
        je endOfLineReached 

        call CharCheck
        jc oversizeErrorIndicate
        jmp processCurrentLine

    endOfLineReached:
        jmp parseWithoutErrors

    emptyFileErrorIndicate: 
        jmp closeFileWithErrors
        
    openingFileErrorIndicate:
        _print openingFileError
        jmp catchAnyError
        

    oversizeErrorIndicate:
        mov oversizeFlag, 1
        _print oversizeError
        jmp catchAnyError

    catchAnyError:
        stc
        jmp closeFileWithErrors

    closeFileWithErrors:
        mov ah, 3Eh
        int 21h
        stc
        jmp endAfterCloseFile 
        
    parseWithoutErrors:
         mov ah, 3Eh
         int 21h   
         
    endAfterCloseFile:
        pop si
        pop bx
        pop cx
        pop dx
        pop ax
        ret
endp

ArgumentsParse proc; 
    push cx
    push di

    mov cx, 1
    mov di, offset cmdText

    argumentsParseLoop:
        call LineProcessing
        jc argumentsParseError
        inc cx
        jmp argumentsParseLoop

    argumentsParseError:
        cmp oversizeFlag, 1
        je endOfParse
        clc

    endOfParse:
        pop di
        pop cx
        ret
endp

end start