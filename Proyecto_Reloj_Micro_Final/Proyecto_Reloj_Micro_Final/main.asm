//******************************************************************************************************************
//UNIVERSIDAD DEL VALLE DE GUATEMALA
//IE2023: PROGRAMACIÓN DE MICROCONTROLADORES
//Proyecto.asm
//AUTOR: Guillermo José Schwartz López
//Proyecto#1: Reloj
//HARDWARE: ATMEGA328P
//CREADO: 1/03/2024
//ÚLTIMA MODIFICACIÓN: 13/03/24	- 17:31
//********************************************************************************************************************
//ENCABEZADO
//********************************************************************************************************************

.INCLUDE "M328PDEF.INC"

//Configuración de Maquina de estados finitos
.DEF ESTADO = R21

//DISPLAY DE 7 SEGMENTOS (Reloj)
.equ T1VALUE = 0xE17B ; EQUIVALE A 500 MS

//Se define el contador de los segundos
.def CONTADOR = R22

; -> Se definen las etiquetas relacionadas a los registros
.def DISP_UMIN = R23		; Display de unidad de Minutos 
.def DISP_DMIN = R24		; Display de decenas de Minutos
.def DISP_UHR = R25			; Display de unidad de Horas
.def DISP_DHR = R17			; Display de decenas de Horas

// Vectores de interrupción y TIMERS
.CSEG
.ORG 0X00
	JMP MAIN		//Vector RESET

.ORG 0X0006			//Vector de ISR: PCINT0
	JMP ISR_PCINT0

.ORG 0X001A			//Vector de ISR: TIMER1_OVER
	JMP ISR_TIMER1_OVER

.org 0x0020			//Vector de ISR: TIMER0_OVER 
	jmp ISR_TIMER0_OVER

MAIN:
//********************************************************************************************************************
//STACK
//********************************************************************************************************************
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R17, HIGH(RAMEND)
	OUT SPH, R17

//********************************************************************************************************************
//TABLA DE VERDAD (Valores de los display de 7 segmentos)
//********************************************************************************************************************

T7S: .DB 0x3F, 0x06, 0x5B, 0x4F, 0X66, 0X6D, 0X7D, 0X07, 0X7F, 0X6F ;(Los valores son del 0 al 9)

//********************************************************************************************************************
//CONFIGURACUÓN
//********************************************************************************************************************
SETUP:

//Maquina de estados finitoS

; -> Entradas (Pull-UP)
	
	SBI PORTB, PB2		; Se habilita PULL_UP EN PB2			- (Boton para Aumentar las Decenas)
	CBI DDRB, PB2		; Se habilita PB2 como una entrada		

	SBI PORTB, PB3		; Se habilita PULL_UP EN PB3			- (Boton para Aumentar las Unidades)
	CBI DDRB, PB3		; Se habilita PB3 como una entrada

	SBI PORTB, PB4		; Se habilita PULL_UP EN PB4			- (Boton para cambiar los estados)
	CBI DDRB, PB4		; Se habilita PB4 como una entrada

; -> Salidas (LEDS - ESTADOS)
	SBI DDRB, PB5		; Se habilita PB5 del puerto B como salida - (Estado 0 / Reloj)
	CBI PORTB, PB5		; Se apaga el bit PB5 del puerto B

; -> Leds de estado y multiplexación
	LDI R16, 0b0011_1111	; Se habilitan 6 bits
	OUT DDRC, R16			; Se habilitan los primeros 6 bits del puerto C como salidas - (Estados y Multiplexación)
	
	;-> (PC2 - PC5 // Transistores - Multiplexación)	---- (PC0 - PC1 // LEDS ESTADOS)

	CLR R16					; Se limpia el registro R16

	// Se configura la interrupción PCINT0
	LDI R16, (1 << PCINT4)	; PB4 como indicador de los estados
	STS PCMSK0, R16			; Se emplean las interrupciones para el pin PB4

	LDI R16, (1 << PCIE0)	//Se habilitan las interrupciones del puerto B (Se deben de configurar)
	STS PCICR, R16			;Se habilita la ISR PCINT[7:0]
	 
// Se limpian los registros establecidos para que inicien desde 0

	CLR ESTADO
	CLR CONTADOR
	CLR R26					; Registro encargado de contar que hayan pasado 59 segundos

// COnfiuración Reloj

//Habilitar los OUTPUTS que se trabajaran

	LDI	R16, 0x00			
	STS	UCSR0B, R16				; Habilitar TX Y RX como pines (PD0 Y PD1)

; -> Configuración display de 7 segmentos

	; LEDS de 500ms
	SBI DDRB, PB0				; Habilitar PB0 del PORTB como salida
	CBI PORTB, PB0				; Apagar el bit PB0 del PORTB

	CLR R16						; Se limpia el registro R16

	;-> Puertos de salida para los display
	LDI R16, 0b1111_1111	   
	OUT DDRD, R16			; Se activa el PORTD (PD0 - PD6) como OUTPUT

	; -> Configuración inicial de los  Displays (Contadores)
	LDI R18, 0			; DIsplay unidades de Minutos
	LDI R19, 0			; Display decenas de MINUTOS
	LDI R20, 0			; Display Unidades de HORAS
	LDI R27, 0			; Display DECENAS de HORAS

	; - Banderas del Display de 7 segmentos
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R18
	lpm R18, Z

	;- Contadores de DISPLAY - Valores Iniciales
	LDI DISP_UMIN, 9		; Unidades de Minuto	
	LDI DISP_DMIN, 5		; Decenas de Minutos
	LDI DISP_UHR, 3			; Unidades de Hora
	LDI DISP_DHR, 2			; Decenas de Horas

//Se llaman a los TIMERS
	CALL Init_TIMER0
	CALL Init_TIMER1		; Inicializar Timer1

	SEI						; Se habilitan las interrupciones Goblases SEI


LOOP:										//LOOP PRINCIPAL
; -> Se llama a los displays
	CALL DISPLAY_SEG_MINUTOS_UNIDADES		; Se llama al display de Unidades de Minutos
	CALL DISPLAY_SEG_MINUTOS_DECENAS		; Se llama al display de Decenas de Minutos
	CALL DISPLAY_SEG_HORA_UNIDADES			; Se llama al display de Unidades de Horas
	CALL DISPLAY_SEG_HORAS_DECENAS			; Se llama al display de Decenas de Horas
	
	CPI ESTADO, 0				; Verifica si el Estado es igual a 0 // Reloj
	BREQ ESTADOP0				; (BREQ) Ejecuta la instrunción si el registro y la cosntante con iguales -Estado 0 = 0 => Estado 0

	CPI ESTADO, 1				; Verifica si el Estado es igual a 1 // configuración de Reloj (Unidades y decenas de minutos)
	BREQ ESTADOP1				; (BREQ) Ejecuta la instrunción si el registro y la cosntante con iguales - Estado 1 = 1 => Estado 1

	CPI ESTADO, 2				; Verifica si el Estado es igual a 2 // configuración de Reloj (Unidades y decenas de minutos)
	BREQ ESTADOP2				; (BREQ) Ejecuta la instrunción si el registro y la cosntante con iguales - Estado 2 = 2 => Estado 2

	CPI ESTADO, 3				; Verifica si el Estado es igual a 3 // Calendario
	BREQ ESTADOP3				; (BREQ) Ejecuta la instrunción si el registro y la cosntante con iguales - Estado 3 = 3 => Estado 3

	CPI ESTADO, 4				; Verifica si el Estado es igual a 4 // Alarma
	BREQ ESTADOP4				; (BREQ) Ejecuta la instrunción si el registro y la cosntante con iguales - Estado 4 = 4 => Estado 4


// Subrutina de minutos
CONTADOR_60_SEG:				; Incrementa el contador para alcanzar los 59 segundos (1 minuto)
	INC R26						; Incrementa el registro R26
	JMP LOOP					; Bucle principal



; ---> Puentes <--- ; Sirven como atajos y evitan que se genere un "OUT OF BRANCH"
ESTADOP0:
JMP ESTADO0			; Salta al Estado0 (Reloj)

ESTADOP1:
JMP ESTADO1			; Salta al Estado1 (Configuración/Reloj- Unidades y Decenas de Minutos)

ESTADOP2:
JMP ESTADO2			; Salta al Estado2 (Configuración/Reloj- Unidades y Decenas de Horas)

ESTADOP3:
JMP ESTADO3			; Salta al Estado3 (Calendario)

ESTADOP4:
JMP ESTADO4			; Salta al Estado4 (Alarma)


//********************************************************************************************************************
// -> ESTADOS
//********************************************************************************************************************

ESTADO0:					//RESTADO DEL RELOJ

	SBI PORTB, PB5			;Se apaga el pin PD2
	CBI PORTC, PC0			;Se enciende el pin PD3
	CBI PORTC, PC1			;Se apaga el pin PD4

	CPI CONTADOR, 100			; Comprueba que haya pasado 1 segundo
	BRNE LOOP
	LDI CONTADOR, 0

	; Comprobar Minutos
	CPI R26, 59				; Comprueba que haya pasado 1 minuto
	BRNE CONTADOR_60_SEG	; Se dirigue a la rutina de segundos
	CLR R26					; Limpia el registro R26

	RJMP RELOJ				; Salta a la rutina de RELOJ

ESTADO1:					//Display_Unidades de Minutos

	SBI PORTB, PB5			; Se enciende el pin PC5
	SBI PORTC, PC0			; Se enceinde el pin PC0
	CBI PORTC, PC1			; Se apaga el pin PC1	

	CPI CONTADOR, 50		; Antirrebote de 500MS - Se emplea el contador del TIMER0
	BRNE LOOP				; Salta al bucle principal de no cumplirse la condición
	LDI CONTADOR, 0			; Limpia el Anirrebote - Contador

	in R16, PINB			; R16 lee PORTB
	sbrs R16, PB2			; Verifica si el boton de PB2 ha sido precionado
	CALL CONFIGURAR_U_M		; Llama a la rutina para incremnetar las unidades de minutos
	CLR R16					; Limpia R16

	in R16, PINB			; R16 lee PORTB	
	sbrs R16, PB3			; Verifica si el boton de PB3 ha sido precionado
	CALL CONFIGURAR_D_M		; Llama a la rutina para incremnetar las decenas de minutos
	CLR R16					; Limpia R16

	JMP LOOP				;Regresa al bucle principal infinito

ESTADO2:

	SBI PORTB, PB5			; Se enciende el pin PB5	
	CBI PORTC, PC0			; Se apaga el pin Pc0
	SBI PORTC, PC1			; Se enciende el pin PC1

	CPI CONTADOR, 50		; Antirrebote de 500MS - Se emplea el contador del TIMER0
	BRNE LOOP				; Salta al bucle principal de no cumplirse la condición
	LDI CONTADOR, 0			; Limpia el Anirrebote - Contador

	in R16, PINB			; R16 lee PORTB
	sbrs R16, PB2			; Verifica si el boton de PB2 ha sido precionado
	CALL CONFIGURAR_U_H		; Llama a la rutina para incremnetar las unidades de Horas
	CLR R16					; Limpia R16

	in R16, PINB			; R16 lee PORTB	
	sbrs R16, PB3			; Verifica si el boton de PB3 ha sido precionado
	CALL CONFIGURAR_D_H		; Llama a la rutina para incremnetar las decenas de Horas
	CLR R16					; Limpia R16

	JMP LOOP				; Regresa al bucle principal infinito

ESTADO3:						// Calendario
	CBI PORTB, PB5				; Se apaga el pin PB5
	SBI PORTC, PC0				; Se enciende el pin PC0
	CBI PORTC, PC1				; Se apaga el pin PC1

	JMP LOOP

ESTADO4:						// Alarma
	CBI PORTB, PB5				; Se apaga el pin PB5
	SBI PORTC, PC0				; Se enciende el pin PC0
	SBI PORTC, PC1				; Se enceinde el pin PC1

	JMP LOOP

// Configuraciones de Reloj

// -> DESARROLLO DE SUBRUTINAS - Reloj - Modo(CONFIGURACIÓN)

;- Configurar Unidades de Minutos
CONFIGURAR_U_M:
	CPI DISP_UMIN, 9			; Compara si el registro "DISP_UMIN" es igual a 9
	BRNE AUMENTAR_U_M			; Si "AUMENTAR_U_M" no es igual a 9, entonces se lee la instrucción				
	LDI DISP_UMIN, 0			; Se limpia "AUMENTAR_U_M"
	RJMP LOOP					; Regresa al bucle principal infinito

;- Configurar decenas de Minutos
CONFIGURAR_D_M:
	CPI DISP_DMIN, 5			; Compara si el registro "DISP_DMIN" es igual a 5
	BRNE AUMENTAR_D_M			; Si "AUMENTAR_D_M" no es igual a 5, entonces se lee la instrucción			
	LDI DISP_DMIN, 0			; Se limpia "AUMENTAR_D_M"
	RJMP LOOP					; Regresa al bucle principal infinito

;- Configurar Unidades y Decenas de horas
CONFIGURAR_U_H:
	CPI DISP_DHR, 2				; Comprueba si han pasado 2 horas
	BRNE CONFIGURAR_U_H_20A		; Si no han pasado 2 horas, sata a esta subrutina

	CPI DISP_UHR, 3				; Compara si el registro "DISP_UHR" es igual a LA COSNTANTE 3
	BRNE AUMENTAR_U_H			; Si "AUMENTAR_U_H" no es igual a 3, entonces se lee la instrucción		
	LDI DISP_UHR, 0				; Se limpia "AUMENTAR_U_H" 
	RJMP LOOP					; Bucle principal

CONFIGURAR_D_H:
	;--> Unidades de Horas
	CPI DISP_DHR, 2				; Compara si el registro "DISP_DHR" es igual a 2
	BRNE AUMENTAR_D_H			; Compara si el registro "DISP_DHR" no es es igual a 2, entonces lee esta intrucción
	CLR DISP_DHR				; Se limpia el registro
	JMP LOOP					; Bucle principal

CONFIGURAR_U_H_20A:				; Rutina que configura las unidades de Horas antes de que hayan pasado 20 horas (ESTADO2)
	CPI DISP_UHR, 9				; Compara si el registro "DISP_UHR" es igual a LA COSNTANTE 3
	BRNE AUMENTAR_U_H			; Si "AUMENTAR_U_H" no es igual a 3, entonces se lee la instrucción		
	LDI DISP_UHR, 0				; Si "AUMENTAR_U_H" = 3, se salta a esta instrucción
	RJMP LOOP


	;--> Unidades de Horas
	CPI DISP_DHR, 2				; Compara si el registro "DISP_DHR" es igual a 2
	BRNE AUMENTAR_D_H			; Si "AUMENTAR_D_H" no es igual a 2, entonces se lee la instrucción	
	CLR DISP_DHR				; Si "AUMENTAR_D_H" no es igual a 2, entonces se lee la instrucción				
	JMP LOOP					; Salta al bucle principal Infinito

//********************************************************************************************************************
// Rutina de Reloj
//********************************************************************************************************************
RELOJ:							//RUTINA - ESTADO0
	// Asegurarse que haya pasado 1 minuto
;--> Unidades de Minutos
	CPI DISP_UMIN, 9			; Compara si el registro "DISP_UMIN" es igual a 9
	BRNE AUMENTAR_U_M			; Si "AUMENTAR_U_M" no es igual a 9, entonces se lee la instrucción				
	LDI DISP_UMIN, 0			; Se limpia "AUMENTAR_U_M"

;--> Decenas de Minutos
	CPI DISP_DMIN, 5			; Compara si el registro "DISP_DMIN" es igual a 5
	BRNE AUMENTAR_D_M			; Si "AUMENTAR_D_M" no es igual a 5, entonces se lee la instrucción			
	LDI DISP_DMIN, 0			; Se limpia "AUMENTAR_D_M"

	//Comprobar Horas
	CPI DISP_DHR, 2				; Comprueba que hayan pasado 20 horas
	BRNE AUMENTAR_Horas_A20		; Si no han pasado 20 horas (DECENAS DE HORAS = 2), se lee esta instrucción

	; --> Unidades de Horas despues de haber pasado 20 horas

	CPI DISP_UHR, 3				; Compara si el registro "DISP_UHR" es igual a LA COSNTANTE 3
	BRNE AUMENTAR_U_H			; Si "AUMENTAR_U_H" no es igual a 3, entonces se lee la instrucción		
	LDI DISP_UHR, 0				; Si "AUMENTAR_U_H" = 3, se salta a esta instrucción

	; --> Decenas de Horas
	CPI DISP_DHR, 2				; Compara si el registro "DISP_DHR" es igual a 2
	BRNE AUMENTAR_D_H			; Si "AUMENTAR_D_H" no es igual a 2, entonces se lee la instrucción	
	CLR DISP_DHR				; Si "AUMENTAR_D_H" no es igual a 2, entonces se lee la instrucción				

	JMP LOOP					;Regresa al bucle principal infinito

// -> DESARROLLO DE SUBRUTINAS - Reloj - Modo(Hora)
AUMENTAR_U_M:					//Unidades de minutos (Estado 0)
	INC DISP_UMIN				; Aumenta el contador de Unidadades de Minutos
	RJMP LOOP

AUMENTAR_D_M:					//Decenas de minutos (Estado 0)
	INC DISP_DMIN				; Aumenta el contador de Decenas de Minutos
	RJMP LOOP

AUMENTAR_U_H:					//Unidades de Horas (Estado 0)
	INC DISP_UHR				; Aumenta el contador de Unidadades de Horas
	RJMP LOOP

AUMENTAR_D_H:					//Decenas de Horas (Estado 0)
	INC DISP_DHR				; Aumenta el contador de Decenas de Horas
	RJMP LOOP

//Reloj - (Antes de las 20 horas)
AUMENTAR_Horas_A20:				; Rutina que configura las unidades de Horas antes de que hayan pasado 20 horas (ESTADO0)
	;--> Unidades de Horas
	CPI DISP_UHR, 9				; Compara si el registro "DISP_UHR" es igual a 9
	BRNE AUMENTAR_U_H			; Si "AUMENTAR_U_H" no es igual a 9, entonces se lee la instrucción		
	LDI DISP_UHR, 0				; Si "AUMENTAR_U_H" = 9, se salta a esta instrucción

//********************************************************************************************************************
//DISPLAYS_DE_7_SEGMENTOS_Minutos_y_Horas
//********************************************************************************************************************
; ---> Displays de 7 segmentos - Unidades de Minuto
DISPLAY_SEG_MINUTOS_UNIDADES:
	
	cbi PORTC, PC5				; Inhabilitar display de Decenas de Horas  (Multiplexación / Transistor)
	cbi PORTC, PC4				; Inhabilitar display de Unidades de Horas   (Multiplexación / Transistor)
	cbi PORTC, PC3				; Inhabilitar display de Decenas de Minutos (Multiplexación / Transistor)

	mov R18, DISP_UMIN			; para llamar la lista
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R18
	lpm R18, Z					; almacenar el valor de la lista

	out PORTD, R18				; El valor del registro se muestra en el display

	sbi PORTC, PC2				; Habilitar display de Unidades de minutos  (Multiplexación / Transistor)
	ret

//*************************************************************************
; ---> Displays de 7 segmentos - Decenas de Minuto
DISPLAY_SEG_MINUTOS_DECENAS:
	cbi PORTC, PC5				; Inhabilitar display de Decenas de Horas  (Multiplexación / Transistor)		
	cbi PORTC, PC4				; Inhabilitar display de Unidades de Horas  (Multiplexación / Transistor)
	cbi PORTC, PC2				; Inhabilitar display de Unidades de Minutos  (Multiplexación / Transistor)

	mov R19, DISP_DMIN			; para llamar la lista
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R19
	lpm R19, Z

	out PORTD, R19				; mostrar en el display	

	sbi PORTC, PC3				; Habilitar display de Decenas de Minutos (Multiplexación / Transistor)
	ret

//*************************************************************************
; ---> Displays de 7 segmentos - Unidades de Hora
DISPLAY_SEG_HORA_UNIDADES:
	cbi PORTC, PC5				; Inhabilitar display de Decenas de Horas  (Multiplexación / Transistor)		
	cbi PORTC, PC3				; Inhabilitar display de Decenas de Minutos  (Multiplexación / Transistor)
	cbi PORTC, PC2				; Inhabilitar display de Unidades de Minutos  (Multiplexación / Transistor)

	mov R20, DISP_UHR			; para llamar la lista
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R20
	lpm R20, Z					; almacenar el valor de la lista

	out PORTD, R20				; mostrar en el display


	sbi PORTC, PC4				; Habilitar display de Unidades de Horas  (Multiplexación / Transistor)
	ret


//*************************************************************************
; ---> Displays de 7 segmentos - Decenas de HORAS
DISPLAY_SEG_HORAS_DECENAS:
	cbi PORTC, PC4				; Inhabilitar display de Unidades de Horas  (Multiplexación / Transistor)	
	cbi PORTC, PC3				; Inhabilitar display de Decenas de Minutos  (Multiplexación / Transistor)
	cbi PORTC, PC2				; Inhabilitar display de Unidades de Minutos  (Multiplexación / Transistor)


	mov R27, DISP_DHR			; para llamar la lista
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R27
	lpm R27, Z					; almacenar el valor de la lista

	out PORTD, R27				; mostrar en el display

	sbi PORTC, PC5				; Habilitar display de Decenas de Horas  (Multiplexación / Transistor)
	
	ret

;	-> TIMERS 0 Y 1
//***************************************************************************
// TIMER0
//***************************************************************************
Init_TIMER0:
	CLI									; Se apagan las interrupciones Globales
	ldi R16, (1 << CS02)|(1 << CS00)	; Se configura prescaler de 1024
	out TCCR0B, R16						; Se configura el Registro B
	ldi R16, 100						; Se carga el valor de desbordamiento - 99.75 (100 aproximado)
	out TCNT0, R16						; Se configura el valor inicial del Contador
	ldi R16, (1 << TOIE0)
	sts TIMSK0, R16
	SEI									; Se encienden las interrupciones Globales				
	ret

//***************************************************************************
// ISR Timer 0 Overflow
//***************************************************************************
ISR_TIMER0_OVER:
	push R16				; Se guarda en pila R16
	in R16, sreg
	push R16				;Se guardar en pila SREG

	ldi R16, 100				; Se carga el valor de desbordamiento - 99.75 (100 aproximado)
	out TCNT0, R16				; Se configura el valor inicial del Contador
	sbi TIFR0, TOV0				; Se borra la bandera TOV0
	inc CONTADOR				; Se incrementa el contador cada 10 ms		(1000 ms = 1 seg) -> COMPARACIÓN ESTADO 0

	pop R16						; Se ontiene el valor antiguo de SREG
	out sreg, R16				; Restaurar valor antiguo SREG
	pop R16						; Obtener valor R16
	reti

// -------> Subrutinas de TIMER1
//********************************************************************************************************************
//SUBRUTINA PARA INICIALIZAR EL TIMER1
//********************************************************************************************************************
Init_TIMER1:
	//TCNT1 = 0xE17B para tener un desbordamiento cada 500ms

	LDI R16, HIGH(T1VALUE)				; Cargar el valor de desbordameinto
	STS TCNT1H, R16						; Cargar el valor inical del contador 
	LDI R16, LOW(T1VALUE)				; Cargar el valor de desbordameinto
	STS TCNT1L, R16						; Cargar el valor inical del contador 

	CLR R16
	STS TCCR1A, R16						; Configurar el timer en el registro A

	LDI R16, (1 << CS12)|(1 << CS10)	; Configurar el prescaler a 1024 para un reloj de 16 bits
	STS TCCR1B, R16						; Los bits habilitados se cargan en el registro B

	LDI R16, (1 << TOIE1)
	STS TIMSK1, R16						; Se habilita la interrupción del Timer1 por overflow

	RET									; Se retorna



//********************************************************************************************************************
//SUBRUTINA de ISR TIMER1 OVERFLOW
//********************************************************************************************************************	
ISR_TIMER1_OVER:
	PUSH R16							; Se guarda en pila el registro R16
	IN R16, SREG
	PUSH R16							; Se guarda en la pila el registro R16 	

	LDI R16, HIGH(T1VALUE)				; Cargar el valor de desbordameinto
	STS TCNT1H, R16						; Cargar el valor inical del contador 
	LDI R16, LOW(T1VALUE)				; Cargar el valor de desbordameinto
	STS TCNT1L, R16						; Cargar el valor inical del contador or 

	SBI TIFR1, TOV1						; Se borra la bandera de TOV1 (Borrar la bandera de OVERFLOW)

	//Encender y apagar los LEDS cada 500ms

	SBI PINB, PB0			; Se hace toggle de PB0

	POP R16					; Obtener el valor de SREG
	OUT SREG, R16			; Restaurar los antiguos valores de SREG
	POP R16					; Obtener el valor de R16
	RETI

//********************************************************************************************************************
//Subrutina de ISR PCINT0
//********************************************************************************************************************
ISR_PCINT0:
	PUSH R16			; Se guarda en pila el registro R16
	IN R16, SREG		; Se lee el registro de SREG
	PUSH R16	   		; Se guarda en la pila el registro SREG

	IN R16, PINB		; Se lee el PORTB

	SBRS R16, PB4		; Verifica si el boton PB4 ha sido precionado
	RJMP MODO_ESTADO	; De no haber sido precionado, salta a esta rutina
	RJMP ISR_POP

//Aumentar estados
MODO_ESTADO:
	CPI ESTADO, 4				; Verifica si el estado es igual a 4
	BREQ INICIALIZAR_ESTADO		; Si es igual a 4, salta a esta rutina
	INC ESTADO					; De no ser igual a 4, se incrementa el estado
	JMP ISR_POP

//Se limpia es Estado
INICIALIZAR_ESTADO:				; ESTADO igual a 4
	CLR ESTADO					; Se limpia el registro de "ESTADO"

ISR_POP:
	SBI PCIFR, PCIF0	;Se apaga la bandera de ISR PCINT0
	POP R16				;Obtener el valor de SREG
	OUT SREG, R16		;Restaurar los antiguos valores de R16
	POP  R16			;Obtener el valor de R16
	RETI				;Retornamos de la ISR
//********************************************************************************************************************