/*

	lamento (bemessung #4), by Eduardo Moguillansky
	
	version 3.0
	
	for CsoundQt 0.9.8 or higher

  Requirements:
  
  * an audio interface with 3 free input channels
  * a midi keyboard to change presets during performance (optional)
  * three contact microphones inside covered in foam. 
  * Three active DI boxes
    
  The output is mono. It should be sent to a speaker near the tuning forks
  (on stage). 
    
  0) Connect the contact microphones via an active DI-Box to 
     three inputs in your audio interface
  1) Press play
  2) Set input channels of the tuning forks
  3) Set output channel of the mono mix
  4) Set preset via the computer keyboard (use the number keys).
     You can also use a MIDI keyboard 
     (C4=preset 1, D4=preset 2, E4=preset 3, F4=preset 4)
     
Tuning forks delivered with the material:

1) 995 Hz
2) 442 Hz
3) 258 Hz
4) 441 Hz
5) 440 Hz
6) 255 Hz
7) 128 Hz
8) 130 Hz
   
*/

<CsoundSynthesizer>
<CsOptions>
-odac -iadc 
-m 134    ; disable logging events   
-Mall     ; connect to all midi devices
</CsOptions>	

<CsInstruments>
sr     = 44100
ksmps  = 64
nchnls = 4
A4     = 442   ; do not touch this, the turntables are tuned to 442 Hz
0dbfs  = 1

; ----------------- settings ------------------
; these can be changed by experienced users

; min. aplitude (in dB) to use as a gate for unwanted noises (for each mic)
gi_gate_dB[] fillarray -80, -80, -80

; the higher this number, the longer the attack time of the gate
; default = 3
gi_gate_attack_factor = 2

; Q of the detect filter (bw = freq * q)
; default = 0.05
gi_qfactor = 0.05

; compressor attack / release times
gk_compAttack  init 0.01
gk_compRelease init 0.2

; amount of compression: 0 - no compression, 1 - maximum compression
gk_compressionAmount init 1

; ----------------- globals -------------------
massign 0, "midi"

; attack time for each microphone
gk_attack[] fillarray 0.05, 0.05, 0.05
gk_minpeakyness init 10
gk_preset init 1
gk_sendFft init -1

gk_f0gain_A init 1
gk_f0gain_B init 1
gk_f0gain_C init 1

gk_realfreq_A init 440
gk_realfreq_B init 440
gk_realfreq_C init 440

gk_detectfactor_A init 1
gk_detectfactor_B init 1
gk_detectfactor_C init 1

gk_noisefactor[] fillarray 1, 1, 0.5

gk_freq_A init 440
gk_freq_B init 600
gk_freq_C init 440


gi_midipresets[] init 128
gi_midipresets[60] = 1
gi_midipresets[62] = 2
gi_midipresets[64] = 3
gi_midipresets[65] = 4

chn_k "f0gain", 1
chn_k "distgain", 1
chn_k "noisegain", 1
chn_k "distpregain", 1
chn_k "minpeakyness", 1

chn_k "inchan_A", 1
chn_k "gain_A",   1
chn_k "noise_A",  1

chn_k "inchan_B", 1
chn_k "gain_B",   1
chn_k "noise_B",  1

chn_k "inchan_C", 1
chn_k "gain_C",   1
chn_k "noise_C",  1

chn_k "preset", 2
chn_k "meter_out_mix", 2
chn_S "info", 2

chn_k "meter_in_A", 2
chn_k "meter_out_A", 2
chn_k "realfreq_A", 2
chn_k "freq_A", 2
chn_S "note_A", 2
chn_k "detect_A", 2
chn_k "f0_gain_A", 2

chn_k "meter_in_B", 2
chn_k "meter_out_B", 2
chn_k "realfreq_B", 2
chn_k "freq_B", 2
chn_S "note_B", 2
chn_k "detect_B", 2
chn_k "f0_gain_B", 2

chn_k "meter_in_C", 2
chn_k "meter_out_C", 2
chn_k "realfreq_C", 2
chn_k "freq_C", 2
chn_S "note_C", 2
chn_k "detect_C", 2
chn_k "f0_gain_C", 2

chn_k "compamount", 1

chnset 1, "f0gain"
chnset 0.01, "distgain"
chnset 0.1, "noisegain"
chnset 1, "distpregain"
chnset 0.2, "minpeakyness"
chnset 0, "inchan_A"

chnset 0.5, "noise_A"


; -------------------------- opcodes -------------------------------

opcode filterf0, a, aki
	; filter out the fundamental, leaving only the residual part
	; of the signal 
	ain, krealfreq, inoiseq xin
	anoise = pareq(ain,    krealfreq, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq*2, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq*2, 0.0, inoiseq)
	anoise = pareq(anoise, krealfreq*3, 0.0, inoiseq)
	xout anoise
endop

opcode calcgate, k, kk
	kx, kminx xin
	kminx = max:k(kminx, 0.001)
	kthresh = kminx * 0.5
	kdx = linlin(kx, 0, 1, kthresh, kminx)
	kdx = limit:k(kdx, 0, 1)
	xout kdx
endop

opcode schmitt, k, kkk
	kin, klow, khigh xin
	klast init 0
	klast = (kin > klow ? 1 : 0) * (kin >= khigh ? 1 : klast)
	xout klast
endop


opcode compressorRatio, k, a
	ain xin
	kampin = rms(ain)
	if kampin < ampdb:i(-120) then
		kratio = 1
		kgoto end
	endif
	kdbin = dbamp(kampin)
	kdbout = bpf(kdbin, 
		-120, -120,
		-90, -90,
		-60, -45,
		-40, -20,
		-20, -15,
		-10, -10,
		-1,  -1,
		10,  1)
	
	kratio = ampdb(kdbout) / kampin
end:
	kratio = sc_lagud(kratio, gk_compAttack, gk_compRelease)
	xout kratio
endop
	

opcode tuningfork, ak, iakkkkkkk
	idx, ain, krealfreq, kfreq, ksingain, knoisegain, kdistgain, kdistpregain, kdetectfactor xin
	kband = krealfreq * gi_qfactor
	inoiseq = 2.5
	
	; remove the synthesized freq, to prevent feedback
	ain pareq ain, kfreq, 0.0, 3 
	
	adetect1   butterbp ain, krealfreq, kband
	adetect1   butterbp adetect1, krealfreq, kband*4
	ifreqdiff = 0.4
	kcmpfreq  = krealfreq * (1-ifreqdiff)
	kcmpfreq2 = krealfreq * (1+ifreqdiff)
	
	adetect2   butterbp ain,      kcmpfreq, kcmpfreq * 0.01
	adetect2	 butterbp adetect2, kcmpfreq, kcmpfreq * 0.01
	
	adetect3   butterbp ain,      kcmpfreq2, kcmpfreq * 0.01
	adetect3   butterbp adetect3, kcmpfreq2, kcmpfreq * 0.01
	
	anoise = filterf0(ain, krealfreq, inoiseq)
	
	kattack = gk_attack[idx]
	aenv  follow2 adetect1, kattack, kattack * 3
	
	ienvcutoff = 30
	aenv  butterlp aenv, ienvcutoff
	aenv  butterlp aenv, ienvcutoff
	iatt = 0.005
	irel = 0.005
	asidepeaks = 0.5*(follow2(adetect2, iatt, irel) + follow2(adetect3, iatt, irel))
	
	apeakyness = divz:a(follow2(adetect1, iatt, irel), asidepeaks, 1)
	kpeakyness = downsamp(apeakyness, 0.01) * kdetectfactor
	
	kgate = calcgate(kpeakyness, gk_minpeakyness)
	; kgate = schmitt(kpeakyness, gk_minpeakyness*0.6, gk_minpeakyness)
	kporttime = 1/krealfreq * gi_gate_attack_factor
	kgate portk kgate, kporttime
	agate interp kgate
	aenv *= agate
	
	asin  oscili aenv, kfreq

	adist distort1 asin, kdistpregain, 1/kdistpregain, 1, 1, 1
	knoisegain *= gk_noisefactor[idx]
	aout = asin*ksingain + anoise*knoisegain + adist * kdistgain
	
	kcomprat = compressorRatio(aout)
	; scale factor by copression amount
	kcomprat = linlin(gk_compressionAmount, 1, kcomprat, 0, 1) ; 1 + gk_compressionAmount * (kcomprat-1)
	aout *= interp(kcomprat)
	kdbpre = dbamp(rms:k(aout))
	
	/*
	if idx == 1 && metro(10) == 1 then
		println "compamount: %.2f, kdbpre %d, factor %.3f", gk_compressionAmount, kdbpre, kcomprat
	endif
	*/
	
	; soft limiter
	icompratio = 50
	igatedB = gi_gate_dB[idx]
	aout compress2 aout, aout, igatedB, -12, -4, icompratio, 0.001, 0.01, 0.001
	
	xout aout, kpeakyness
	
endop

opcode disprms, k, a
	ain xin
	; k_amp = (max(-90, dbamp(rms:k(ain))) + 90) / 90
	kdb = max(-90, dbamp(rms:k(ain, 5)))
	kdb sc_lagud kdb, 0.01, 0.1
	xout kdb 
endop

opcode setpreset, 0, k
	kpreset xin
	if kpreset == gk_preset goto exit
	gk_preset = kpreset
	if kpreset == 1 then
		event "i", 60, 0, -1
	elseif kpreset == 2 then
		event "i", 62, 0, -1
	elseif kpreset == 3 then
		event "i", 64, 0, -1
	elseif kpreset == 4 then
		event "i", 65, 0, -1
	endif
exit:
endop 

opcode hp, a, ak
	a0, kfreq xin
	iq = 0.7
	a0 pareq a0, kfreq, 0.01, iq, 1  ; low shelving
	a0 pareq a0, kfreq, 0.01, iq, 1
	a0 buthp a0, kfreq*0.5
	xout a0
endop

opcode setforkA,0,iipp
	irealfreq, ifreq, if0gain, idetectfactor xin
	gk_realfreq_A = irealfreq
	gk_freq_A = ifreq
	gk_f0gain_A = if0gain
	gk_detectfactor_A = idetectfactor
	Snote mton ftom:i(ifreq)
	
	chnset irealfreq, "realfreq_A"
	chnset ifreq, "freq_A"
	chnset Snote, "note_A"
	chnset if0gain, "f0_gain_A"
	
endop

opcode setforkB,0,iipp
	irealfreq, ifreq, if0gain, idetectfactor xin
	gk_realfreq_B = irealfreq
	gk_freq_B = ifreq
	gk_f0gain_B = if0gain
	gk_detectfactor_B = idetectfactor
	Snote mton ftom:i(ifreq)
	
	chnset irealfreq, "realfreq_B"
	chnset ifreq, "freq_B"
	chnset Snote, "note_B"
	chnset if0gain, "f0_gain_B"

endop

opcode setforkC,0,iipp
	irealfreq, ifreq, if0gain, idetectfactor xin
	gk_realfreq_C = irealfreq
	gk_freq_C = ifreq
	gk_f0gain_C = if0gain
	gk_detectfactor_C = idetectfactor
	Snote mton ftom:i(ifreq)

	chnset irealfreq, "realfreq_C"
	chnset ifreq, "freq_C"
	chnset Snote, "note_C"
	chnset if0gain, "f0_gain_C"

endop

opcode setfork,0,iiSpp
	iwhich, irealfreq, Snote, if0gain, idetectfactor xin
	ifreq = mtof:i(ntom:i(Snote))
	if iwhich == 1 then
		setforkA irealfreq, ifreq, if0gain, idetectfactor
	elseif iwhich == 2 then
		setforkB irealfreq, ifreq, if0gain, idetectfactor
	elseif iwhich == 3 then
		setforkC irealfreq, ifreq, if0gain, idetectfactor
	endif
endop

instr exit
	iexitcode = p4
	prints "exitcode.txt: %d\n", iexitcode
	fprints "exitcode.txt", "%d", iexitcode
	exitnow
endin

; ------------------------------- main ---------------------------------
instr main
	kdata[] init 10

	kinch_A   = limit:k(chnget:k("inchan_A")+1, 1, nchnls)
	kinch_B   = limit:k(chnget:k("inchan_B")+1, 1, nchnls)
	kinch_C   = limit:k(chnget:k("inchan_C")+1, 1, nchnls)
	kgain_A    chnget "gain_A"
	kgain_B    chnget "gain_B"
	kgain_C	   chnget "gain_C"
	gk_noisefactor[0] chnget "noise_A"
	gk_noisefactor[1] chnget "noise_B"
	gk_noisefactor[2] chnget "noise_C"
	
	gk_compressionAmount chnget "compamount"
	
	koutch_mix = limit:k(chnget:k("outchan_mix")+1, 1, nchnls)
	kf0gain    chnget "f0gain"
	knoisegain chnget "noisegain"
	kdistgain  chnget "distgain"
	gk_minpeakyness chnget "minpeakyness"
	kdistpregain = limit:k(chnget:k("distpregain"), 1, 100)
	
	a0pre inch kinch_A
  a0pre hp a0pre, gk_realfreq_A * 0.4
  if gk_sendFft == 0 then
		ga_dispfft += a0pre
	endif
	a0, kdetectA tuningfork 0, a0pre, gk_realfreq_A, gk_freq_A, \
	                        kf0gain * gk_f0gain_A, knoisegain, kdistgain, kdistpregain, gk_detectfactor_A
	a0 *= kgain_A
	
	a1pre inch kinch_B
	a1pre hp a1pre, gk_realfreq_B * 0.4
	if gk_sendFft == 1 then
		ga_dispfft += a1pre
	endif
	
	
	a1, kdetectB tuningfork 1, a1pre, gk_realfreq_B, gk_freq_B, \
	                        kf0gain * gk_f0gain_B, knoisegain, kdistgain, kdistpregain, gk_detectfactor_B
	a1 *= kgain_B
	
	a2pre inch kinch_C
	a2pre hp a2pre, gk_realfreq_C * 0.4
	if gk_sendFft == 2 then
		ga_dispfft += a2pre
	endif
	
	a2, kdetectC tuningfork 2, a2pre, gk_realfreq_C, gk_freq_C, \
	                        kf0gain * gk_f0gain_C, knoisegain, kdistgain, kdistpregain, gk_detectfactor_C
	a2 *= kgain_C
	
	amix sum a0, a1, a2
	; master limiter
	amix compress2 amix, amix, -120, -6, -3, 50, 0.001, 0.01, 0.005
	outch koutch_mix, amix
	
	; gui
	kguitrig metro 15
	kguitrig_slow metro 8
	
	krmspre_A = disprms(a0pre)
	krmspost_A = disprms(a0)
	krmspre_B = disprms(a1pre)
	krmspost_B = disprms(a1)
	krmspre_C = disprms(a2pre)
	krmspost_C = disprms(a2)
	krmsout = disprms(amix)
	; kdetectC = sc_lag(kdetectC, 0.5, 1)
	
	if (kguitrig == 1) then
		chnset krmspre_A, "meter_in_A"
		chnset krmspost_A, "meter_out_A"
		chnset krmspre_B, "meter_in_B"
		chnset krmspost_B, "meter_out_B"
		chnset krmspre_C, "meter_in_C"
		chnset krmspost_C, "meter_out_C"
		chnset krmsout, "meter_out_mix"
	endif
	
	if (kguitrig_slow == 1) then
		chnset int(kdetectA), "detect_A"
		chnset int(kdetectB), "detect_B"	
		chnset int(kdetectC), "detect_C"	
	endif

	kres sensekey
	if (kres >= 49 && kres <= 52) then
		setpreset kres - 48
	endif
		
endin

instr midi
	mididefault 60, p3
	midinoteonkey p4, p5
	ikey = p4
	ivel = p5
	ipreset = gi_midipresets[ikey]
	if (ipreset > 0) then
		schedule(ikey, 0, -1)
	else
		prints "?????????????????????? key: %d \n", ikey, ivel
	endif
	turnoff 
endin


; ------------- Presets ----------------


; The instr number corresponds to the midinote

opcode notify_preset, 0, iS
	ipreset, Smsg xin
	gk_preset = ipreset
	chnset Smsg, "info"
	chnset ipreset, "preset"
endop
	

; detectfactor: peakyness of a tuning fork will be multiplied by this factor
;     increasing it makes it more likely that  

instr 60
	prints ">>>>> Preset 1: C4 \n"
	notify_preset 1, "Tuning Forks\nA: 1, B: 2, C: 3"  
	;          freq   note  f0gain  detectfactor
  setfork 1, 995, "6Eb",   2.5
	setfork 2, 440, "4F" ,   1
	setfork 3, 256, "4E+33", 1
	gk_attack fillarray 0.1, 0.05, 0.05
	turnoff
	
endin

instr 62
  prints ">>>>> Preset 2: D4 \n"
  notify_preset 2, "Tuning Forks\nA: 1, B: 2, C: 3"
	;          freq  note   f0gain=1
	setfork 2, 440, "7E+13"
	setfork 3, 440, "7E-2"
	gk_attack fillarray 0.05, 0.05, 0.05
	turnoff
endin

instr 64
  prints ">>>>> Preset 3: E4 \n"
	notify_preset 3, " "
  
  ;          freq  note   f0gain
  setfork 1, 440, "4Eb+12"
	setfork 2, 256, "4D+50"
	setfork 3, 256, "4C#+50"
	gk_attack fillarray 0.05, 0.05, 0.05
	turnoff
endin

instr 65
  prints ">>>>> Preset 4: F4 \n"
  notify_preset 4, " "
  ;          freq note      f0gain  detectfactor
  setfork 1, 256, "3Bb"
	setfork 2, 256, "3A"
	setfork 3, 125, "3G#+20", 1,      2
	gk_attack fillarray 0.05, 0.05, 0.05
	turnoff
endin

instr spectrum
	kchanidx invalue "dispfftchan"
	gk_sendFft = kchanidx
	
	dispfft ga_dispfft, 1/12, 4096
	ga_dispfft = 0
endin


; ---------------- init ---------------------

; this instr is called at the beginning of the performance, and should
; setup the initial state
instr init
	schedule(60, 0, -1)
	outvalue "spectrum", "@find fft ga_dispfft"
	turnoff 
endin

</CsInstruments>

<CsScore>
i "main" 0 -1
i "init" 0.1 -1
f0 360000

</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>701</width>
 <height>637</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="background">
  <r>21</r>
  <g>21</g>
  <b>21</b>
 </bgcolor>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>7</y>
  <width>620</width>
  <height>116</height>
  <uuid>{f9044dff-76b1-4ac5-8f78-ae6320ee9776}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label/>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>68</r>
   <g>68</g>
   <b>68</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>true</bordermode>
  <borderradius>9</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>255</y>
  <width>620</width>
  <height>116</height>
  <uuid>{4216e81a-37ac-4cbd-9eab-9d956efc4bb0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label/>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>68</r>
   <g>68</g>
   <b>68</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>true</bordermode>
  <borderradius>9</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>131</y>
  <width>620</width>
  <height>116</height>
  <uuid>{43f1a7b9-5d9e-47a9-942a-2fdc30b017d0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label/>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>68</r>
   <g>68</g>
   <b>68</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>true</bordermode>
  <borderradius>9</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>55</y>
  <width>80</width>
  <height>30</height>
  <uuid>{18f850d2-e823-4926-b813-fc84f62fa34d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>chan mic</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>223</r>
   <g>225</g>
   <b>227</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>noisegain</objectName>
  <x>640</x>
  <y>315</y>
  <width>64</width>
  <height>64</height>
  <uuid>{d583553f-af06-4a90-9317-d2acbeebce25}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Master gain for residual noise</description>
  <minimum>0.00000000</minimum>
  <maximum>2.00000000</maximum>
  <value>0.38120000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f47c00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>640</x>
  <y>275</y>
  <width>65</width>
  <height>39</height>
  <uuid>{b05afb8a-7017-4741-bd80-b4d722a2e8ab}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Master gain for residual noise</description>
  <label>residuum</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>outchan_mix</objectName>
  <x>640</x>
  <y>120</y>
  <width>60</width>
  <height>29</height>
  <uuid>{02a37efc-bde5-4a9b-89ef-72f32fccc209}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Output Channel</description>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>1</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>2</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>3</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>4</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>5</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>6</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>7</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>8</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>630</x>
  <y>145</y>
  <width>81</width>
  <height>27</height>
  <uuid>{6343f1db-1f38-4067-939e-a757a9472cd3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>out chan mix</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>227</r>
   <g>228</g>
   <b>230</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName/>
  <x>665</x>
  <y>15</y>
  <width>10</width>
  <height>100</height>
  <uuid>{f46470b4-fdb3-4f3c-b88f-f7da5307b496}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Output meter for master mix</description>
  <objectName2>meter_out_mix</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>-90.00000000</yMin>
  <yMax>0.00000000</yMax>
  <xValue>0.22083869</xValue>
  <yValue>-39.84016015</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#72cef8</borderColor>
  <color>
   <r>115</r>
   <g>209</g>
   <b>251</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>distgain</objectName>
  <x>215</x>
  <y>420</y>
  <width>64</width>
  <height>64</height>
  <uuid>{2e3bfd2b-6c40-4e04-b555-f2c5211033d6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description/>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.25990000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f37b00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>215</x>
  <y>395</y>
  <width>65</width>
  <height>25</height>
  <uuid>{2ba75e52-849a-4810-b819-39af940b1f6d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>distortion</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>222</r>
   <g>224</g>
   <b>226</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>f0gain</objectName>
  <x>640</x>
  <y>210</y>
  <width>64</width>
  <height>64</height>
  <uuid>{009560cf-63ad-429d-8ac6-2cc344e3f6cf}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Master gain for tuning fork (f0) </description>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>1.71800000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f37b00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>640</x>
  <y>186</y>
  <width>64</width>
  <height>25</height>
  <uuid>{cef65f7b-ffa2-44ce-a9ba-6a60b2d3c181}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>gain</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>226</g>
   <b>228</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>315</x>
  <y>395</y>
  <width>68</width>
  <height>38</height>
  <uuid>{987ad07a-8214-418b-b53a-a5fd0c927983}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>distortion pregain</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>realfreq_A</objectName>
  <x>360</x>
  <y>15</y>
  <width>60</width>
  <height>32</height>
  <uuid>{4bcab27e-50f7-424a-a239-5b4068401452}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Freq. of the tuning fork</description>
  <label>995</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>191</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>freq_A</objectName>
  <x>360</x>
  <y>50</y>
  <width>60</width>
  <height>32</height>
  <uuid>{ef3bd7aa-8942-48c0-ab65-e70b1201355b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Transposed frequency</description>
  <label>1250</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>note_A</objectName>
  <x>418</x>
  <y>50</y>
  <width>59</width>
  <height>32</height>
  <uuid>{87227e55-80fa-42df-9e77-306f588c9a50}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Resulting note</description>
  <label>6D#</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>gain_A</objectName>
  <x>160</x>
  <y>44</y>
  <width>64</width>
  <height>64</height>
  <uuid>{beca8188-31df-4062-9118-422e3bbd6e96}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Gain A</description>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f37b00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>160</x>
  <y>15</y>
  <width>64</width>
  <height>25</height>
  <uuid>{d603b75e-b481-45c9-87dc-7d205c1be6f9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>gain</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>390</x>
  <y>395</y>
  <width>81</width>
  <height>38</height>
  <uuid>{57363231-48fd-44a3-91fd-db4507a56d30}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>detect threshold</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>259</x>
  <y>17</y>
  <width>101</width>
  <height>27</height>
  <uuid>{794d2e5e-cec2-4f00-8877-d5e942ba530a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>259</x>
  <y>52</y>
  <width>101</width>
  <height>27</height>
  <uuid>{609fbc5a-fcb6-40c5-a93a-6bcddbfb6a8f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>15</x>
  <y>375</y>
  <width>80</width>
  <height>35</height>
  <uuid>{65b6abc9-b156-44f2-a703-d85edd5f5b93}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>Preset</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>24</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>181</g>
   <b>252</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>detect_A</objectName>
  <x>505</x>
  <y>35</y>
  <width>36</width>
  <height>20</height>
  <uuid>{15cfeac3-6a88-4a69-bf62-5c7eaba5e631}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Peakyness for signal at A</description>
  <label>1</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="background">
   <r>59</r>
   <g>59</g>
   <b>59</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>505</x>
  <y>265</y>
  <width>35</width>
  <height>22</height>
  <uuid>{c7e4f437-f002-40c6-be3f-382ae0db2b1c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>detect</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>225</r>
   <g>227</g>
   <b>228</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>f0_gain_A</objectName>
  <x>362</x>
  <y>87</y>
  <width>46</width>
  <height>25</height>
  <uuid>{19cba5c3-6c1f-4c21-8c4b-7ae0f872e5e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Gain multiplier for the tuning fork in this preset</description>
  <label>2.50</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>2</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>296</x>
  <y>87</y>
  <width>64</width>
  <height>25</height>
  <uuid>{79732849-4e17-4863-8a40-9513dcbcbe9d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>inchan_B</objectName>
  <x>90</x>
  <y>180</y>
  <width>60</width>
  <height>30</height>
  <uuid>{5fea5c24-8492-4b07-891b-004c19ee1999}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Input Channel for Mic B</description>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>1</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>2</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>3</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>4</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>5</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>6</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>7</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>8</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>1</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>180</y>
  <width>80</width>
  <height>30</height>
  <uuid>{841ab78e-1eea-49f8-8eab-284293be2ff4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>chan mic</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>222</r>
   <g>224</g>
   <b>226</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>realfreq_B</objectName>
  <x>360</x>
  <y>140</y>
  <width>60</width>
  <height>32</height>
  <uuid>{ee90f9b9-758e-4138-8a52-69178eb95c27}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Freq. of the tuning fork</description>
  <label>440</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>freq_B</objectName>
  <x>360</x>
  <y>175</y>
  <width>60</width>
  <height>32</height>
  <uuid>{4413af8d-1209-4ef0-ba58-a727c3ac7723}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Transposed frequency</description>
  <label>351</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>note_B</objectName>
  <x>418</x>
  <y>175</y>
  <width>59</width>
  <height>32</height>
  <uuid>{ade4f050-6b52-4592-99c3-2d085c0fbb92}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Resulting note</description>
  <label>4F</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>gain_B</objectName>
  <x>160</x>
  <y>169</y>
  <width>64</width>
  <height>64</height>
  <uuid>{7fed22eb-fd88-496b-b3da-93aee9901076}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Gain B</description>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f17a00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>160</x>
  <y>140</y>
  <width>64</width>
  <height>25</height>
  <uuid>{f6268c70-7168-47f0-974d-a67f38777432}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>gain</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>225</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>258</x>
  <y>142</y>
  <width>101</width>
  <height>27</height>
  <uuid>{f1abb270-92b5-4518-a36e-06701a53cbd0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>258</x>
  <y>177</y>
  <width>101</width>
  <height>27</height>
  <uuid>{dd337426-4015-4008-a9d6-6dd9d527c117}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>226</g>
   <b>228</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>f0_gain_B</objectName>
  <x>362</x>
  <y>212</y>
  <width>46</width>
  <height>25</height>
  <uuid>{dcbd8b1f-6168-4edc-8413-e5ae070d59de}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Gain multiplier for the tuning fork in this preset</description>
  <label>1.00</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>2</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>295</x>
  <y>212</y>
  <width>64</width>
  <height>25</height>
  <uuid>{92fc8945-70bf-4759-9ab3-55017c552870}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>225</g>
   <b>227</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>detect_B</objectName>
  <x>505</x>
  <y>160</y>
  <width>36</width>
  <height>20</height>
  <uuid>{8dcfb866-324b-4b0e-8b43-79db7b222d41}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Peakyness for signal at B</description>
  <label>19</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="background">
   <r>59</r>
   <g>59</g>
   <b>59</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>detect_C</objectName>
  <x>505</x>
  <y>285</y>
  <width>35</width>
  <height>20</height>
  <uuid>{03f1684a-27e3-4b41-b336-02330ae1e3d9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Peakyness for signal at C</description>
  <label>1</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="background">
   <r>59</r>
   <g>59</g>
   <b>59</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>inchan_C</objectName>
  <x>90</x>
  <y>305</y>
  <width>60</width>
  <height>30</height>
  <uuid>{d9b1ff16-b487-40c2-abff-6a685eadf088}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Input channel for mic C</description>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>1</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>2</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>3</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>4</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>5</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>6</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>7</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>8</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>2</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>305</y>
  <width>80</width>
  <height>30</height>
  <uuid>{ac604d0e-febe-4fe0-9038-75b050316cb8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>chan mic</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>226</g>
   <b>227</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>realfreq_C</objectName>
  <x>360</x>
  <y>264</y>
  <width>60</width>
  <height>32</height>
  <uuid>{0d5b0dd9-8a3c-4d98-afb5-dcd264b9501e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Freq of the tuning fork</description>
  <label>256</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>freq_C</objectName>
  <x>360</x>
  <y>300</y>
  <width>60</width>
  <height>32</height>
  <uuid>{dad92162-9fe1-4b3f-adff-282da74affd7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Transposed frequency</description>
  <label>337</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>0</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>note_C</objectName>
  <x>418</x>
  <y>300</y>
  <width>68</width>
  <height>32</height>
  <uuid>{ea35e9d2-76aa-499f-b342-687a3ca22754}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Resulting note</description>
  <label>4E+33</label>
  <alignment>left</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>18</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>gain_C</objectName>
  <x>160</x>
  <y>294</y>
  <width>64</width>
  <height>64</height>
  <uuid>{987ee0b4-f257-478d-9d0a-3b496f265a5a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description/>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>245</r>
   <g>124</g>
   <b>0</b>
  </color>
  <textcolor>#f17a00</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>160</x>
  <y>265</y>
  <width>64</width>
  <height>25</height>
  <uuid>{ceb9904a-2f7f-4cc0-9df5-2c636f44fc79}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>gain</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>222</r>
   <g>224</g>
   <b>226</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>257</x>
  <y>267</y>
  <width>101</width>
  <height>27</height>
  <uuid>{8bda7c50-db38-4247-b41a-f320366b89ec}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>257</x>
  <y>302</y>
  <width>101</width>
  <height>27</height>
  <uuid>{d234e449-5218-462f-8c1c-8f95e7ec6b5c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>225</g>
   <b>227</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>f0_gain_C</objectName>
  <x>362</x>
  <y>337</y>
  <width>46</width>
  <height>25</height>
  <uuid>{83f2bdd0-b078-44b9-a481-264dd99d7030}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Gain multiplier for the tuning fork in this preset</description>
  <label>1.00</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>2</precision>
  <color>
   <r>0</r>
   <g>196</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>294</x>
  <y>337</y>
  <width>64</width>
  <height>25</height>
  <uuid>{790f4b14-5196-4aa9-9c06-ab544bd2f387}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>224</r>
   <g>225</g>
   <b>227</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBScrollNumber" version="2">
  <objectName>preset</objectName>
  <x>15</x>
  <y>410</y>
  <width>80</width>
  <height>80</height>
  <uuid>{9851ac4a-76f5-4ed5-8483-92d8ec5328c2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Press the preset key (1, 2, 3, 4) to set prese manually</description>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>64</fontsize>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>0</r>
   <g>94</g>
   <b>134</b>
  </bgcolor>
  <value>1.00000000</value>
  <resolution>1.00000000</resolution>
  <minimum>-999999999999.00000000</minimum>
  <maximum>999999999999.00000000</maximum>
  <bordermode>false</bordermode>
  <borderradius>8</borderradius>
  <borderwidth>0</borderwidth>
  <randomizable group="0">false</randomizable>
  <mouseControl act=""/>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>560</x>
  <y>25</y>
  <width>53</width>
  <height>25</height>
  <uuid>{478d016d-3534-4bb3-8306-22a647dc4f24}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>noise</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>228</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>info</objectName>
  <x>480</x>
  <y>400</y>
  <width>148</width>
  <height>69</height>
  <uuid>{5c527fc4-d375-4624-bd1a-7c1ca332d6e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>Tuning Forks
A: 1, B: 2, C: 3</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>225</r>
   <g>227</g>
   <b>229</b>
  </color>
  <bgcolor mode="background">
   <r>59</r>
   <g>59</g>
   <b>59</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>5</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>noise_A</objectName>
  <x>555</x>
  <y>45</y>
  <width>60</width>
  <height>60</height>
  <uuid>{a985cea0-1689-48bd-904a-b732b56ddae1}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Noise through gain</description>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>0.50000000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>0</r>
   <g>255</g>
   <b>255</b>
  </color>
  <textcolor>#00ffff</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>560</x>
  <y>150</y>
  <width>53</width>
  <height>25</height>
  <uuid>{508b9346-a093-4d4c-b096-810391b49b3d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>noise</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>228</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>noise_B</objectName>
  <x>555</x>
  <y>170</y>
  <width>60</width>
  <height>60</height>
  <uuid>{2cb9a27e-2086-4be7-a69c-07fd9b41e71a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Noise through gain</description>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>0.50000000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>0</r>
   <g>255</g>
   <b>255</b>
  </color>
  <textcolor>#00ffff</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>560</x>
  <y>275</y>
  <width>53</width>
  <height>25</height>
  <uuid>{89b8fbe2-a3c0-45de-aa95-c6d6b713c429}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>noise</label>
  <alignment>center</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>226</r>
   <g>228</g>
   <b>229</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>noise_C</objectName>
  <x>555</x>
  <y>295</y>
  <width>60</width>
  <height>60</height>
  <uuid>{45de6977-a28f-4c26-b64b-5592c51d85d4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Noise through gain</description>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>0.16300000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>0</r>
   <g>255</g>
   <b>255</b>
  </color>
  <textcolor>#00ffff</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>505</x>
  <y>140</y>
  <width>35</width>
  <height>22</height>
  <uuid>{1546c629-f9d4-4a3f-a97c-073f891bee4c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>detect</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>225</r>
   <g>227</g>
   <b>228</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>505</x>
  <y>15</y>
  <width>35</width>
  <height>22</height>
  <uuid>{f700bb19-47bb-42e3-a000-4aa8ea966e97}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>detect</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>225</r>
   <g>227</g>
   <b>228</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>10</x>
  <y>15</y>
  <width>28</width>
  <height>30</height>
  <uuid>{b5c850ba-0b00-4c32-9720-87a16f104595}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>A</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>251</r>
   <g>253</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>10</x>
  <y>140</y>
  <width>28</width>
  <height>30</height>
  <uuid>{f82a005b-57a5-4c63-ada1-bfb51f05b1d2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>B</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>251</r>
   <g>253</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>10</x>
  <y>265</y>
  <width>28</width>
  <height>30</height>
  <uuid>{8d8e6e21-bbcd-4a9b-8d8c-f5d8835f9d17}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>C</label>
  <alignment>left</alignment>
  <valignment>top</valignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>251</r>
   <g>253</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBScrollNumber" version="2">
  <objectName>minpeakyness</objectName>
  <x>405</x>
  <y>435</y>
  <width>50</width>
  <height>30</height>
  <uuid>{1b103b10-a8e1-4dc1-be6d-9086449bd006}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>13</fontsize>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>0</r>
   <g>77</g>
   <b>77</b>
  </bgcolor>
  <value>27.00000000</value>
  <resolution>1.00000000</resolution>
  <minimum>2.00000000</minimum>
  <maximum>300.00000000</maximum>
  <bordermode>false</bordermode>
  <borderradius>5</borderradius>
  <borderwidth>0</borderwidth>
  <randomizable group="0">false</randomizable>
  <mouseControl act=""/>
 </bsbObject>
 <bsbObject type="BSBScrollNumber" version="2">
  <objectName>distpregain</objectName>
  <x>325</x>
  <y>435</y>
  <width>50</width>
  <height>30</height>
  <uuid>{4aba9f4e-ab86-4eac-a36f-3f1bf40310c6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>13</fontsize>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>0</r>
   <g>77</g>
   <b>77</b>
  </bgcolor>
  <value>1.00000000</value>
  <resolution>0.25000000</resolution>
  <minimum>1.00000000</minimum>
  <maximum>999.00000000</maximum>
  <bordermode>false</bordermode>
  <borderradius>5</borderradius>
  <borderwidth>0</borderwidth>
  <randomizable group="0">false</randomizable>
  <mouseControl act=""/>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>inchan_A</objectName>
  <x>90</x>
  <y>55</y>
  <width>60</width>
  <height>30</height>
  <uuid>{454ed774-ffd5-439f-a952-330087251044}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description>Input channel for mic A</description>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>1</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>2</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>3</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>4</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>5</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>6</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>7</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>8</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>meter_in_A</objectName>
  <x>20</x>
  <y>88</y>
  <width>29</width>
  <height>21</height>
  <uuid>{e00bea69-f6d5-42a9-b5d8-109439d96059}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>-39</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>0</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>compamount</objectName>
  <x>135</x>
  <y>420</y>
  <width>64</width>
  <height>64</height>
  <uuid>{031d526e-abef-4fd8-9389-dcad795b3ae8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Amount of compression</description>
  <minimum>0.00000000</minimum>
  <maximum>2.00000000</maximum>
  <value>0.81240000</value>
  <mode>lin</mode>
  <mouseControl act="">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
  <color>
   <r>243</r>
   <g>138</g>
   <b>252</b>
  </color>
  <textcolor>#f68aff</textcolor>
  <border>0</border>
  <borderColor>#512900</borderColor>
  <showvalue>true</showvalue>
  <flatstyle>true</flatstyle>
  <integerMode>false</integerMode>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>125</x>
  <y>380</y>
  <width>85</width>
  <height>40</height>
  <uuid>{c0de3857-9eac-430b-adcc-023e2c51a373}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>Compression Amount</label>
  <alignment>center</alignment>
  <valignment>bottom</valignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>222</r>
   <g>224</g>
   <b>226</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>meter_in_B</objectName>
  <x>20</x>
  <y>213</y>
  <width>29</width>
  <height>21</height>
  <uuid>{998e9ea8-7c9e-4301-bf0e-cacbb8e8140b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>-45</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>0</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>meter_in_C</objectName>
  <x>20</x>
  <y>341</y>
  <width>29</width>
  <height>21</height>
  <uuid>{9abe5f03-b32e-46fc-8359-7a1654e216c8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <description/>
  <label>-90</label>
  <alignment>right</alignment>
  <valignment>center</valignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>0</precision>
  <color>
   <r>239</r>
   <g>240</g>
   <b>241</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>false</bordermode>
  <borderradius>0</borderradius>
  <borderwidth>0</borderwidth>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName>meter_in_A</objectName>
  <x>50</x>
  <y>95</y>
  <width>100</width>
  <height>10</height>
  <uuid>{72aa632b-d020-43a1-82a7-f490bc48386e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Input Meater A</description>
  <objectName2/>
  <xMin>-90.00000000</xMin>
  <xMax>0.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>-39.22261756</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#79b746</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName>meter_in_B</objectName>
  <x>50</x>
  <y>220</y>
  <width>100</width>
  <height>10</height>
  <uuid>{88f37fef-faf8-4f60-b2b0-3b9bd73b2a0b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Input Meter B</description>
  <objectName2/>
  <xMin>-90.00000000</xMin>
  <xMax>0.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>-45.44443643</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#76b244</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName>meter_in_C</objectName>
  <x>50</x>
  <y>348</y>
  <width>100</width>
  <height>10</height>
  <uuid>{c0ff28f4-8451-4c75-a3e4-b498eaf8b99b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Input Meter C</description>
  <objectName2/>
  <xMin>-90.00000000</xMin>
  <xMax>0.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>-90.00000000</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#77b445</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName/>
  <x>236</x>
  <y>265</y>
  <width>10</width>
  <height>100</height>
  <uuid>{4b1ceb4f-3fe4-4794-8b59-cfcfe3b181b6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Output for tuning fork at C</description>
  <objectName2>meter_out_C</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>-90.00000000</yMin>
  <yMax>0.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>-90.00000000</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#a6fc61</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName/>
  <x>236</x>
  <y>139</y>
  <width>10</width>
  <height>100</height>
  <uuid>{5f7ac59c-098f-4a0f-9288-ee4c378292a4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Output for tuning fork at B</description>
  <objectName2>meter_out_B</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>-90.00000000</yMin>
  <yMax>0.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>-51.49580477</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#a4fa60</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
 <bsbObject type="BSBController" version="2">
  <objectName/>
  <x>236</x>
  <y>13</y>
  <width>10</width>
  <height>100</height>
  <uuid>{d9400926-9537-4a48-ab15-107e497b692e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <description>Output for tuning fork at A</description>
  <objectName2>meter_out_A</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>-90.00000000</yMin>
  <yMax>0.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>-39.64981300</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <bordermode>border</bordermode>
  <borderColor>#a7ff61</borderColor>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable group="0" mode="both">false</randomizable>
  <bgcolor>
   <r>22</r>
   <g>22</g>
   <b>22</b>
  </bgcolor>
  <bgcolormode>true</bgcolormode>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>
