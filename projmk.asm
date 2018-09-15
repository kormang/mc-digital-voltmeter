
RS EQU p0.2
E EQU p0.3
D4 EQU p0.4
D5 EQU p0.5
D6 EQU p0.6
D7 EQU p0.7
LCDATA EQU p0
CLK EQU p1.7
DIN EQU p1.5
DOUT EQU p1.6
CS EQU p3.5
; rezervacija registara za primanje vrijednosti iz konvertora
Pv EQU 28h ; dva bajta
RECMASK EQU 2ah

;0.01V predstavljen sa 12 bita
Csdv EQU 8
;rezervacija mjesta za broj stotih djelova volta, idu dva bajta, ovde ide nizi
Bsdv EQU 2bh

;rezervacija mejsta za cifra koje ce se prikazati na displeju
Dig EQU 02fh ; Dig-0 = 2fh, Dig-1 = 2eh, Dig-2 = 2dh


;rezervacija registara za djeljenje
DIVIDEND EQU 18h
DIVISOR EQU 1ah
QUOTIENT EQU 1bh
REMAINDER EQU 1dh

;broj desetaka milisekundi
BDMS EQU r2


; ---------------- KODNI SEGMENT --------------------------------------

CSEG
org 0000h
	jmp main
org 0003h
	reti
org 000bh
	call timer_isr
org 0013h
	reti
org 001bh
	reti
org 0023h
	reti
org 003bh
	reti	
	
	
	
org 0030h
main:

	mov tmod, #01h ; timer 0 u modu 1
	mov ie, #82h ; dozvoljavam prekid samo za tajmer0
	; inicajlizujem pocetne podatke
	mov BDMS, #100
	mov th0, #0D8h
	mov tl0, #0F0h ; D8F0h je 55536, tj. svakih 10 000 mikrosekundi (masinskih ciklusa sa taktom od 12MHz)
			
	call initdys
	setb tr0 ; startam tajmer
	
	
forever:
	jmp forever
	
;-------------- timer ISR ---------------------------------------
timer_isr:
	mov th0, #0D8h
	mov tl0, #0F0h
	
	djnz BDMS, timer_isr_reti
	call readadc
	
	mov DIVIDEND, Pv
	mov DIVIDEND+1, Pv+1
	mov DIVISOR, #Csdv
	call D16BY8 ; djelim Pv/Csdv
	mov Bsdv, QUOTIENT ; cuvam broj stotih djelova volta
	mov Bsdv+1, QUOTIENT+1 ;
	
	
	mov a, Bsdv+1
	cjne a, #0, gt256 ; ako je gornji bajt veci od nula onda je racunanje malo komplikovanije
	
	mov a, Bsdv
	mov b, #10
	div ab
	mov Dig-2, b ; cuvam cifru na poziciji -2, drugu decimalu
	
	jmp druge_dve_cifre
	
gt256:              ; ako je Bsdv < 256 racunanje ide jednostavnije, jer je broj predstavljen sa 8 bita, sad moram koristiti D16BY8
			; ali samo za prvu cifru - kada ga jednom podjelim stace u 8 bita sigurno
	mov DIVIDEND, Bsdv
	mov DIVIDEND+1, Bsdv+1
	mov DIVISOR, #10
	call D16BY8
	
	mov a, REMAINDER
	mov Dig-2, a
	mov a, QUOTIENT ; dio koda poslije labele druge_dve_cifre ocekuje da u a bude Bsdv/10
	
druge_dve_cifre:

	mov b, #10
	div ab
	mov Dig-1, b
	
	mov b, #10
	div ab
	mov Dig, b
	
	; sad trebam cifre povecati za 30h kako bi postale ASCII cife
todys:

	mov a, Dig ; -0
	add a, #30h
	mov Dig, a
	
	mov a, Dig-1
	add a, #30h
	mov Dig-1, a
	
	mov a, Dig-2
	add a, #30h
	mov Dig-2, a
	
	call cleardys
	
	mov a, Dig
	call write_char
	
	mov a, #2ch ; ','
	call write_char
	
	mov a, Dig-1
	call write_char
	
	mov a, Dig-2
	call write_char
	
	mov a, #56h ; 'V'
	call write_char
	

	mov BDMS, #100 ;vracam brojac
timer_isr_reti:
	reti

; ------------- citanje vrijednosti iz A/D konvertera, rezultat smjesta u Pv i Pv+1 -------------
readadc:
	setb CS ; za pocetak stavlja CS na visok nivo
	setb CLK ; postavljam takt na visok nivo
	setb DIN ; stavljam start bit, sve je spremno
	clr CS ; zapocinjem
	clr CLK ; okidam prvu opadajucu ivicu
	
	nop
	
	setb CLK ; dizem takt da postavim SGL bit
	setb DIN ; SGL = '1' znaci single ended rezim
	clr CLK ; okidam donju ivicu da konverter procita SGL
	
	mov r3, #3

chsel:
	setb CLK
	clr DIN ; channel 0
	clr CLK
	
	djnz r3, chsel ; tri puta saljem nulu
	
	setb CLK ; pocitnje konverzija
	nop
	clr CLK
	nop
	setb CLK
	nop
	clr CLK ; zavrsena konverzija i konvertor izsiftava null bit
	
	mov r3, #0 ; ovde cu smjesiti najvisa 4 bita
	mov a, #08h ; maska u kojoj se nalazi jedna '1' koja ce se pomjerati u lijevo i ako sam primio '1' onda ce se na tu poziciju postaviti '1' u prihvatnom registru
			; maska ima '1' na poziciji sa tezinom 3 zato sto sad primam najvisa 4 od 12 bita. 4 visa bita u prihvatnom registru ce biti nule.
			; Nizih osam bita cu ucitati kasnije
	setb CLK
	
rechbits:
	clr CLK ; konv. izsiftava bit
	mov c, DOUT ; citam bit
	jnc rechbits_jmp ; ako je DOUT = '0' nista ne treba raditi
	mov RECMASK, a ; sacuvam masku, jer mi akumulator treba za druge operacije
	orl a, r3 ; postavim '1' na poziciju na koju pokazuje maska
	mov r3, a ; sacuvam rezultat u r2
	mov a, RECMASK ; vratim masku nazad u akumulator
rechbits_jmp:
	rr a ; pomjeram bit u masci da predje na sledecu poziciju
	setb CLK
	cjne a, #80h, rechbits ; ako ga je zarotirao skroz da se jedinica vrati na prvu poziciju onda je to kraj
	
	mov Pv+1, r3 ; sacuvam najvisa 4 bita
	
	;;;;;;;;;;;;;;  primanje nizih 8 bita od konvertora ;;;;;;;;;;;;;;;;
	
	mov r3, #0 ; ovde cu sad smjesiti niza 4 bita
	mov a, #80h ; maska, sad ide skroz od najviseg bita
reclbits:
	clr CLK ; konv. izsiftava bit
	mov c, DOUT ; citam bit
	jnc reclbits_jmp ; ako je DOUT = '0' nista ne treba raditi
	mov RECMASK, a ; sacuvam masku, jer mi akumulator treba za druge operacije
	orl a, r3 ; postavim '1' na poziciju na koju pokazuje maska
	mov r3, a ; sacuvam rezultat u r2
	mov a, RECMASK ; vratim masku nazad u akumulator
reclbits_jmp:
	rr a ; pomjeram bit u masci da predje na sledecu poziciju
	setb CLK
	cjne a, #80h, reclbits ; ako ga je zarotirao skroz da se jedinica vrati na prvu poziciju onda je to kraj
	
	mov Pv, r3 ; sacuvam niza 4 bita


	ret
	
	
	
;--------------- inicijalizacija displeja ----------
initdys:
	clr RS
	setb E
	
	mov LCDATa, #28h ; paljenje displeja u 4-bitnom modu
	clr E
	call kasnjenje
	setb E
	
	mov a, #28h ; paljnje displeja u 4-bitnom modu, po drugi put
	call write_instruction
	
	mov a, #0ch ; ukljucivanje displeja bez kursora
	call write_instruction
	
	mov a, #06h ; automatsko pomjeranje kursora u desno kad se upise znak
	call write_instruction
	
	call cleardys
	
	ret
	
; ------------ brisanje displeja --------------------
cleardys:
	mov a, #01h ; brisanje displeja
	call write_instruction
	ret

;--- funkcija za slanje znaka, setuje RS i poziva write_byte. Vrijednost je potrebno ostaviti u akumulatoru, koji nece zadrzati datu vrijednost.
write_char:
	setb RS ; znakovi
	call write_byte
	ret
	
;----- vrijedi isto sto i za write_char, samo sto ova funkicija salje instrukciju displeju	
write_instruction:
	clr RS ; instrukcije
	call write_byte
	ret
	
	
;---------------- funkcija za upisivanje bajta na LCDa (nije bitno da li je instrukcija ili znak) ----------------
; Vrijednost je potrebno proslijediti u akumulatoru, koji nece zadrzati datu vrijednost
write_byte:
	orl LCDATa, #0f0h ;stavljam  '1' na gornja 4 bita, tu ce ici jedan nibl, ne diram donja 4, jer su to kontrolni signali
	mov r4, a ; sacuvam a zabog nizeg nibla
	
	orl a, #0fh ; 4 nize bita na '1' da bi prilikom and-ovanja kontrolni signali ostali isti, visa 4 su nibl koji treba poslati
	anl LCDATa, a ; upisujem visi nibl
	
	clr E ; iniciram slanje
	call kasnjenje
	setb E
	
	orl LCDATa, #0f0h ; stavljam '1' na gornja 4 bita
	mov a, r4 ; uzimam originalni bajt nazad
	swap a ; sad radim sve isto, ali sa nizim niblom, zato mjenjam mjesta niblima
	
	orl a, #0fh
	anl LCDATa, a
	
	clr E
	call kasnjenje
	setb E
		
	ret


kasnjenje:
	
	mov 	r7	,	#1

kasnjenje3:

	mov 	r6	,	#100

kasnjenje2:
	
	mov 	r5	,	#255

kasnjenje1:
	
	djnz 	r5	,	kasnjenje1
	
	djnz 	r6	,	kasnjenje2
	
	djnz 	r7	,	kasnjenje3
	
	ret


;procedura djeli dvobajtni podatak sa lokacije DIVIDEND i DIVIDEND+1, djelitelj treba da se upise na lokaciju DIVISOR,
;kolicnik vraca na lokaciji QOUTIENT, QOUTIENT+1, a ostatak na lokaciji REMAINDER. Ako se dijeli sa nulom OV bit ce biti postaljen.

D16BY8:	clr	a
	cjne	a,DIVISOR,OK

DIVIDE_BY_ZERO:
	setb	OV
	ret

OK:	mov	QUOTIENT,a
	mov	r4,#9 ; brojac, 9 puta treba proci
	mov	r5,DIVIDEND
	mov	r6,DIVIDEND+1
	mov	r7,a

	
	jmp D_poc
D_loop:
	;siftujem djeljenik u lijevo
	mov	a,r5
	rlc	a
	mov	r5,a
	mov	a,r6
	rlc	a
	mov	r6,a
	mov	a,r7
	rlc	a
	mov	r7,a
	;siftujem rezultat u lijevo, Carry bi uvijek ovde trebao biti nula
	mov	a,QUOTIENT
	rlc	a
	mov	QUOTIENT,a
	mov	a, QUOTIENT+1
	rlc	a
	mov	QUOTIENT+1,a
	
D_poc:
	;prodjenje, da li je gornji bajt djeljenika zajedno sa C(r7) veci od djelioca
	mov	ACC, r7
	jb	ACC.0,D_if_proso
	mov	a,r6
	subb	a,DIVISOR ; carry bi trebao biti 0, jer sam prethodno siftao rezultat kroz njega, a rezultat uvijek ima vodecih nula
	jnc	D_if_proso ; ako je carry nula onda je godnji bajt djeljenika veci od djelioca
	jmp	D_END_IF ; ako nije prosao ni jedan od prethodnih uslova onda nijeprosao IF r7r6 > DIVISOR THEN
D_if_proso:
	mov	ACC,QUOTIENT
	setb	ACC.0
	mov	QUOTIENT,ACC
	;oduzimama djelioca r7r6, i na taj nacin ostavljam ostatak pri djeljenu u  r6
	mov	a,r6
	subb	a,DIVISOR
	mov	r6,a
	mov	ACC,r7
	clr	ACC.0
D_END_IF:
	djnz	r4,D_loop

	mov REMAINDER,r6

	ret

END
	
	; koristio sam r7, r6, r5 za kasnjenje i pri djeljenu
	; r4 za razmjenu podataka sa LCDom i pri djeljenu
	; r3 kao privremenu promjenjivu kod komunikacije sa konvertorom
	; r2 broj desetaka milisekundi