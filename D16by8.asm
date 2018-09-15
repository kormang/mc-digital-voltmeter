$DEBUG

SHORT_DIVISION SEGMENT CODE

EXTRN DATA(DIVIDEND, DIVISOR, QUOTIENT, REMAINDER)
PUBLIC D16BY8

RSEG SHORT_DIVISION


;***************************************************************************;
;                                                                           ;
;                         D16BY8
;
;      CALCULATES  QUOTIENT  =  DIVIDEND/DIVISOR
;
;                  REMAINDER =  DIVIDEND - QUOTIENT * DIVISOR
;
;   Inputs to this routine are a 16-bit dividend and an 8-bit divisor.
;   Outputs are a 16-bit quotient and an 8-bit remainder.  Inputs and
;   outputs are unsigned integers.  Accuracy of the calculation has been
;   verified with all possible values of dividend and divisor.  Running
;   time varies from 145 to 276 usecs at 12MHz, the average being 232 usecs.
;
;
;   INPUTS: DIVIDEND    2 bytes in externally defined DATA
;              (low byte at DIVIDEND, high byte at DIVIDEND+1)
;
;           DIVISOR     1 byte in externally defined DATA
;
;
;   OUTPUTS: QUOTIENT   2 bytes in externally defined DATA
;
;            REMAINDER  1 byte in externally defined DATA
;  
;
;   VARIABLES AND REGISTERS MODIFIED:
;
;            QUOTIENT, REMAINDER
;            ACC, B, PSW, R4, R5, R6, R7 
;
;   ERROR EXIT:  Exit with OV = 1 indicates DIVISOR = 0.
;                                                                           ;
;***************************************************************************;



D16BY8:	CLR	A
	CJNE	A,DIVISOR,OK

DIVIDE_BY_ZERO:
	SETB	OV
	RET

OK:	MOV	QUOTIENT,A
	MOV	R4,#8
	MOV	R5,DIVIDEND
	MOV	R6,DIVIDEND+1
	MOV	R7,A

	MOV	A,R6
	MOV	B,DIVISOR
	DIV	AB
	MOV	QUOTIENT+1,A
	MOV	R6,B

TIMES_TWO:
	MOV	A,R5
	RLC	A
	MOV	R5,A
	MOV	A,R6
	RLC	A
	MOV	R6,A
	MOV	A,R7
	RLC	A
	MOV	R7,A

COMPARE:
	CJNE	A,#0,DONE
	MOV	A,R6
	CJNE	A,DIVISOR,DONE
	CJNE	R5,#0,DONE
DONE:	CPL	C

BUILD_QUOTIENT:
	MOV	A,QUOTIENT
	RLC	A
	MOV	QUOTIENT,A
	JNB	ACC.0,LOOP

SUBTRACT:
	MOV	A,R6
	SUBB	A,DIVISOR
	MOV	R6,A
	MOV	A,R7
	SUBB	A,#0
	MOV	R7,A

LOOP:	DJNZ	R4,TIMES_TWO

	MOV	A,DIVISOR
	MOV	B,QUOTIENT
	MUL	AB
	MOV	B,A
	MOV	A,DIVIDEND
	SUBB	A,B
	MOV	REMAINDER,A
	CLR	OV
	RET


END
