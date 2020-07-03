<CsoundSynthesizer>
<CsOptions>
-odac -iadc -d -m 0
--daemon
</CsOptions>	

<CsInstruments>
sr     = 44100
ksmps  = 64
nchnls = 4
A4     = 442   ; do not touch this
0dbfs  = 1

/*

	lamento (bemessung #4), by Eduardo Moguillansky
	
	this .csd file should be run under csoundqt

  Requirements:
  
  * an audio interface with 3 free input channels
  * a midi keyboard to change presets during performance 
  * three contact microhones. If the contact microphones have 
    a dedicated preamp, use that; otherwise, connect them via
    an active DI box (do not connect them directly)
    
	0) Connect the contact microphones via an active DI-Box to 
     three inputs in your audio interface
  1) Setup your midi keyboard (menu Edit/Configuration and then General/Realtime Midi)
  2) Press play
  3) Set input channels of the tuning forks
  4) Set output channel of the mono mix
  5) Set preset via a midi keyboard (C4=preset 1, D4=preset 2, E4=preset 3, F4=preset 4)
     or manually using the number keys (1=preset 1, etc)
   
*/

; ----------------- settings ------------------
; these can be changed by experiences users

; min. aplitude (in dB) to use as a gate for unwanted noises
gi_gate_dB = -80


; ----------------- globals -------------------
massign 0, "midi"

gi_qfactor = 0.05
gi_attack  = 0.05
gi_rel     = 0.01

gk_minpeakyness init 10
gk_preset init 1

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


opcode chndef, 0, Sip
	Sname, idefault, itype xin
	chn_k Sname, itype
	chnset idefault, Sname
endop

chndef "f0gain", 1
chndef "noisegain", 0.1
chndef "distgain", 0.01
chndef "distpregain", 1
chndef "minpeakyness", 0.2

chn_k "preset", 2
chn_k "meter_out_mix", 2
chn_S "info", 2

; tuning fork A
chndef "inchan_A", 0
chndef "gain_A", 1
chndef "noise_A", 0.5
chn_k "meter_in_A", 2
chn_k "meter_out_A", 2
chn_k "realfreq_A", 2
chn_k "freq_A", 2
chn_S "note_A", 2
chn_k "detect_A", 2
chn_k "f0_gain_A", 2

; tuning fork B
chndef "inchan_B", 1
chndef "gain_B", 1
chndef "noise_B", 0.5
chn_k "meter_in_B", 2
chn_k "meter_out_B", 2
chn_k "realfreq_B", 2
chn_k "freq_B", 2
chn_S "note_B", 2
chn_k "detect_B", 2
chn_k "f0_gain_B", 2

; tuning fork C
chndef "inchan_C", 1
chndef "gain_C", 1
chndef "noise_C", 0.5
chn_k "meter_in_C", 2
chn_k "meter_out_C", 2
chn_k "realfreq_C", 2
chn_k "freq_C", 2
chn_S "note_C", 2
chn_k "detect_C", 2
chn_k "f0_gain_C", 2


;; -------------------------- opcodes -------------------------------

opcode filterf0, a, aki
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
	kthresh = kminx * 0.5
	kdx = linlin(kx, 0, 1, kthresh, kminx)
	kdx = limit:k(kdx, 0, 1)
	xout kdx
endop

opcode tuningfork, ak, iakkkkkkk
	idx, ain, krealfreq, kfreq, ksingain, knoisegain, kdistgain, kdistpregain, kdetectfactor xin
	kband = krealfreq * gi_qfactor
	inoiseq = 2.5
	
	adetect1   butterbp ain, krealfreq, kband
	adetect1   butterbp adetect1, krealfreq, kband*4
	ifreqdiff = 0.4
	kcmpfreq = krealfreq * (1-ifreqdiff)
	kcmpfreq2 = krealfreq * (1+ifreqdiff)
	
	adetect2	  butterbp ain, kcmpfreq, kcmpfreq * 0.01
	adetect2	  butterbp adetect2, kcmpfreq, kcmpfreq * 0.01
	
	adetect3   butterbp ain, kcmpfreq2, kcmpfreq * 0.01
	adetect3   butterbp adetect3, kcmpfreq2, kcmpfreq * 0.01
	
	anoise = filterf0(ain, krealfreq, inoiseq)
	
	aenv  follow2 adetect1, gi_attack, gi_rel
	ienvcutoff = 30
	aenv  butterlp aenv, ienvcutoff
	aenv  butterlp aenv, ienvcutoff
	iatt = 0.005
	irel = 0.005
	apeakyness = follow2(adetect1, iatt, irel) / (0.5*(follow2(adetect2, iatt, irel) + follow2(adetect3, iatt, irel)))
	kpeakyness = downsamp(apeakyness, 0.01) * kdetectfactor
	
	kgate = calcgate(kpeakyness, gk_minpeakyness)
	kporttime = 1/krealfreq * 2
	kgate portk kgate, kporttime
	agate interp kgate
	aenv *= agate
	
	asin  oscili aenv, kfreq

	adist distort1 asin, kdistpregain, 1/kdistpregain, 1, 1, 1
	knoisegain *= gk_noisefactor[idx]
	aout = asin*ksingain + anoise*knoisegain + adist * kdistgain
	icompratio = 100
	aout compress2 aout, aout, gi_gate_dB, -20, -6, icompratio, 0.001, 0.01, 0.001
	xout aout, kpeakyness
	
endop

opcode disprms, k, a
	ain xin
	k_amp = (max(-90, dbamp(rms:k(ain))) + 90) / 90
	xout k_amp 
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
	a0 pareq a0, kfreq, 0.01, 0.7, 1
	a0 pareq a0, kfreq, 0.01, 0.7, 1
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

;; ------------------------------- main ---------------------------------
instr main
	kinch_A   = limit:k(chnget:k("inchan_A")+1, 1, nchnls)
	kinch_B   = limit:k(chnget:k("inchan_B")+1, 1, nchnls)
	kinch_C   = limit:k(chnget:k("inchan_C")+1, 1, nchnls)
	
	koutch_mix = limit:k(chnget:k("outchan_mix")+1, 1, nchnls)
	kf0gain    chnget "f0gain"
	knoisegain chnget "noisegain"
	kdistgain  chnget "distgain"
	kgain_A    chnget "gain_A"
	kgain_B		chnget "gain_B"
	kgain_C		chnget "gain_C"
	gk_noisefactor[0] chnget "noise_A"
	gk_noisefactor[1] chnget "noise_B"
	gk_noisefactor[2] chnget "noise_C"
	
	gk_minpeakyness chnget "minpeakyness"
	kdistpregain = limit:k(chnget:k("distpregain"), 1, 100)
	
	a0pre inch kinch_A
	a0pre hp a0pre, gk_realfreq_A * 0.4
	a0, kdetectA tuningfork 0, a0pre, gk_realfreq_A, gk_freq_A, \
	                        kf0gain * gk_f0gain_A, knoisegain, kdistgain, kdistpregain, gk_detectfactor_A
	a0 *= kgain_A
	
	a1pre inch kinch_B
	a1pre hp a1pre, gk_realfreq_B * 0.4
	a1, kdetectB tuningfork 1, a1pre, gk_realfreq_B, gk_freq_B, \
	                        kf0gain * gk_f0gain_B, knoisegain, kdistgain, kdistpregain, gk_detectfactor_B
	a1 *= kgain_B
	
	a2pre inch kinch_C
	a2pre hp a2pre, gk_realfreq_C * 0.4
	a2, kdetectC tuningfork 2, a2pre, gk_realfreq_C, gk_freq_C, \
	                        kf0gain * gk_f0gain_C, knoisegain, kdistgain, kdistpregain, gk_detectfactor_C
	a2 *= kgain_C
	
	amix sum a0, a1, a2
	outch koutch_mix, amix
	
	; gui
	kguitrig metro 20
	kguitrig_slow metro 10
	
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
		event_i "i", ikey, 0, -1
	else
		prints "?????????????????????? key: %d \n", ikey, ivel
	endif
	turnoff 
endin


;; ------------- Presets ----------------


;; The instr number corresponds to the midinote

instr 60
	prints ">>>>> Preset 1: C4 \n"
	chnset "Tuning Forks\nA: 1, B: 2, C: 3", "info"
	gk_preset = 1
	setfork 1, 1024, "6Eb", 2.5
	setfork 2, 440, "4F"
	setfork 3, 256, "4E+33"
	chnset 1, "preset"
	turnoff
endin

instr 62
  prints ">>>>> Preset 2: D4 \n"
  chnset "Tuning Forks\nA: 1, B: 2, C: 3", "info"
  gk_preset = 2
	chnset 2, "preset"
	setfork 2, 440, "7E+13"
	setfork 3, 440, "7E-2"
	turnoff
endin

instr 64
  prints ">>>>> Preset 3: E4 \n"
  gk_preset = 3
	chnset 3, "preset"
	setfork 1, 440, "4Eb+12"
	setfork 2, 256, "4D+50"
	setfork 3, 256, "4C#+50"
	turnoff
endin

instr 65
  prints ">>>>> Preset 4: F4 \n"
  gk_preset = 4
	chnset 4, "preset"
	setfork 1, 256, "3Bb"
	setfork 2, 256, "3A"
	setfork 3, 125, "3G#+20", 1, 2
	turnoff
endin


;; ---------------- init ---------------------

;; this instr is called at the beginning of the performance, and should
;; setup the initial state
instr init
	event_i "i", 60, 0, -1
	turnoff 
endin

</CsInstruments>

<CsScore>
i "main" 0 -1
i "init" 0.1 -1

</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>776</width>
 <height>567</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>14</x>
  <y>9</y>
  <width>620</width>
  <height>116</height>
  <uuid>{f9044dff-76b1-4ac5-8f78-ae6320ee9776}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>140</r>
   <g>140</g>
   <b>140</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>12</x>
  <y>260</y>
  <width>620</width>
  <height>116</height>
  <uuid>{4216e81a-37ac-4cbd-9eab-9d956efc4bb0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>140</r>
   <g>140</g>
   <b>140</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>13</x>
  <y>133</y>
  <width>620</width>
  <height>116</height>
  <uuid>{43f1a7b9-5d9e-47a9-942a-2fdc30b017d0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>140</r>
   <g>140</g>
   <b>140</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDropdown">
  <objectName>inchan_A</objectName>
  <x>113</x>
  <y>55</y>
  <width>43</width>
  <height>32</height>
  <uuid>{b1897c04-50d7-434e-aa81-13579d340334}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>32</x>
  <y>59</y>
  <width>80</width>
  <height>25</height>
  <uuid>{18f850d2-e823-4926-b813-fc84f62fa34d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>chan mic A</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>noisegain</objectName>
  <x>87</x>
  <y>427</y>
  <width>64</width>
  <height>64</height>
  <uuid>{d583553f-af06-4a90-9317-d2acbeebce25}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>2.00000000</maximum>
  <value>0.38000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>86</x>
  <y>390</y>
  <width>65</width>
  <height>39</height>
  <uuid>{b05afb8a-7017-4741-bd80-b4d722a2e8ab}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>noise master</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>noisegain</objectName>
  <x>87</x>
  <y>490</y>
  <width>64</width>
  <height>25</height>
  <uuid>{c0cf199c-71ba-4234-9e02-3d036a5ea095}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>0.380</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDropdown">
  <objectName>outchan_mix</objectName>
  <x>665</x>
  <y>103</y>
  <width>80</width>
  <height>30</height>
  <uuid>{02a37efc-bde5-4a9b-89ef-72f32fccc209}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>665</x>
  <y>79</y>
  <width>80</width>
  <height>25</height>
  <uuid>{6343f1db-1f38-4067-939e-a757a9472cd3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>out chan mix</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName>meter_in_A</objectName>
  <x>49</x>
  <y>97</y>
  <width>100</width>
  <height>8</height>
  <uuid>{72aa632b-d020-43a1-82a7-f490bc48386e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2/>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.69608991</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName/>
  <x>751</x>
  <y>58</y>
  <width>10</width>
  <height>100</height>
  <uuid>{f46470b4-fdb3-4f3c-b88f-f7da5307b496}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2>meter_out_mix</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.22083869</xValue>
  <yValue>0.55759724</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>115</r>
   <g>209</g>
   <b>251</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>distgain</objectName>
  <x>156</x>
  <y>427</y>
  <width>64</width>
  <height>64</height>
  <uuid>{2e3bfd2b-6c40-4e04-b555-f2c5211033d6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.37000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>156</x>
  <y>403</y>
  <width>64</width>
  <height>25</height>
  <uuid>{2ba75e52-849a-4810-b819-39af940b1f6d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>distortion</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>distgain</objectName>
  <x>156</x>
  <y>489</y>
  <width>64</width>
  <height>25</height>
  <uuid>{01599131-9221-4f5c-9a42-292b7baddc48}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>0.370</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>f0gain</objectName>
  <x>18</x>
  <y>427</y>
  <width>64</width>
  <height>64</height>
  <uuid>{009560cf-63ad-429d-8ac6-2cc344e3f6cf}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>3.70000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>18</x>
  <y>403</y>
  <width>64</width>
  <height>25</height>
  <uuid>{cef65f7b-ffa2-44ce-a9ba-6a60b2d3c181}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>f0gain</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>f0gain</objectName>
  <x>18</x>
  <y>490</y>
  <width>64</width>
  <height>25</height>
  <uuid>{f3d73bd3-3248-4298-a87a-d09cf2272659}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>3.700</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBSpinBox">
  <objectName>distpregain</objectName>
  <x>231</x>
  <y>440</y>
  <width>64</width>
  <height>34</height>
  <uuid>{063c17ef-0a2d-428c-8c11-7df8deb55d18}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <resolution>0.25000000</resolution>
  <minimum>1</minimum>
  <maximum>999</maximum>
  <randomizable group="0">false</randomizable>
  <value>1.75</value>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>229</x>
  <y>403</y>
  <width>68</width>
  <height>38</height>
  <uuid>{987ad07a-8214-418b-b53a-a5fd0c927983}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>distortion pregain</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>realfreq_A</objectName>
  <x>371</x>
  <y>17</y>
  <width>80</width>
  <height>32</height>
  <uuid>{4bcab27e-50f7-424a-a239-5b4068401452}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1024.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>freq_A</objectName>
  <x>371</x>
  <y>52</y>
  <width>80</width>
  <height>32</height>
  <uuid>{ef3bd7aa-8942-48c0-ab65-e70b1201355b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1250.165</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>note_A</objectName>
  <x>449</x>
  <y>52</y>
  <width>59</width>
  <height>32</height>
  <uuid>{87227e55-80fa-42df-9e77-306f588c9a50}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>6D#</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName/>
  <x>244</x>
  <y>17</y>
  <width>10</width>
  <height>100</height>
  <uuid>{d9400926-9537-4a48-ab15-107e497b692e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2>meter_out_A</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>0.53208796</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>gain_A</objectName>
  <x>171</x>
  <y>49</y>
  <width>64</width>
  <height>64</height>
  <uuid>{beca8188-31df-4062-9118-422e3bbd6e96}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>171</x>
  <y>26</y>
  <width>64</width>
  <height>25</height>
  <uuid>{d603b75e-b481-45c9-87dc-7d205c1be6f9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>gainA</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>gain_A</objectName>
  <x>171</x>
  <y>70</y>
  <width>64</width>
  <height>21</height>
  <uuid>{2d7b604b-f5a6-42ae-b627-b70ce96c3b98}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBSpinBox">
  <objectName>minpeakyness</objectName>
  <x>309</x>
  <y>440</y>
  <width>67</width>
  <height>34</height>
  <uuid>{9708f2e2-b3a1-481e-912c-165af465c306}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <resolution>1.00000000</resolution>
  <minimum>2</minimum>
  <maximum>200</maximum>
  <randomizable group="0">false</randomizable>
  <value>100</value>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>303</x>
  <y>402</y>
  <width>81</width>
  <height>38</height>
  <uuid>{57363231-48fd-44a3-91fd-db4507a56d30}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>detect threshold</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>267</x>
  <y>19</y>
  <width>101</width>
  <height>27</height>
  <uuid>{794d2e5e-cec2-4f00-8877-d5e942ba530a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>267</x>
  <y>54</y>
  <width>101</width>
  <height>27</height>
  <uuid>{609fbc5a-fcb6-40c5-a93a-6bcddbfb6a8f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>664</x>
  <y>183</y>
  <width>85</width>
  <height>34</height>
  <uuid>{65b6abc9-b156-44f2-a703-d85edd5f5b93}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>Preset</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>24</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>detect_A</objectName>
  <x>73</x>
  <y>541</y>
  <width>36</width>
  <height>25</height>
  <uuid>{15cfeac3-6a88-4a69-bf62-5c7eaba5e631}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>4.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>17</x>
  <y>541</y>
  <width>57</width>
  <height>26</height>
  <uuid>{c7e4f437-f002-40c6-be3f-382ae0db2b1c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>detect</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>f0_gain_A</objectName>
  <x>371</x>
  <y>90</y>
  <width>46</width>
  <height>25</height>
  <uuid>{19cba5c3-6c1f-4c21-8c4b-7ae0f872e5e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>2.500</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>304</x>
  <y>89</y>
  <width>64</width>
  <height>25</height>
  <uuid>{79732849-4e17-4863-8a40-9513dcbcbe9d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDropdown">
  <objectName>inchan_B</objectName>
  <x>112</x>
  <y>180</y>
  <width>43</width>
  <height>32</height>
  <uuid>{5fea5c24-8492-4b07-891b-004c19ee1999}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>31</x>
  <y>184</y>
  <width>80</width>
  <height>25</height>
  <uuid>{841ab78e-1eea-49f8-8eab-284293be2ff4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>chan mic B</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName>meter_in_B</objectName>
  <x>48</x>
  <y>222</y>
  <width>100</width>
  <height>8</height>
  <uuid>{88f37fef-faf8-4f60-b2b0-3b9bd73b2a0b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2/>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.69475062</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>realfreq_B</objectName>
  <x>370</x>
  <y>142</y>
  <width>80</width>
  <height>32</height>
  <uuid>{ee90f9b9-758e-4138-8a52-69178eb95c27}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>440.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>freq_B</objectName>
  <x>370</x>
  <y>177</y>
  <width>80</width>
  <height>32</height>
  <uuid>{4413af8d-1209-4ef0-ba58-a727c3ac7723}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>350.816</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>note_B</objectName>
  <x>448</x>
  <y>177</y>
  <width>59</width>
  <height>32</height>
  <uuid>{ade4f050-6b52-4592-99c3-2d085c0fbb92}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>4F</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName/>
  <x>243</x>
  <y>142</y>
  <width>10</width>
  <height>100</height>
  <uuid>{5f7ac59c-098f-4a0f-9288-ee4c378292a4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2>meter_out_B</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>0.52797464</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>gain_B</objectName>
  <x>170</x>
  <y>174</y>
  <width>64</width>
  <height>64</height>
  <uuid>{7fed22eb-fd88-496b-b3da-93aee9901076}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>170</x>
  <y>151</y>
  <width>64</width>
  <height>25</height>
  <uuid>{f6268c70-7168-47f0-974d-a67f38777432}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>gainB</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>gain_B</objectName>
  <x>170</x>
  <y>195</y>
  <width>64</width>
  <height>21</height>
  <uuid>{a8c877d8-1795-4217-88ea-c05127db2f3e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>266</x>
  <y>144</y>
  <width>101</width>
  <height>27</height>
  <uuid>{f1abb270-92b5-4518-a36e-06701a53cbd0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>266</x>
  <y>179</y>
  <width>101</width>
  <height>27</height>
  <uuid>{dd337426-4015-4008-a9d6-6dd9d527c117}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>f0_gain_B</objectName>
  <x>370</x>
  <y>215</y>
  <width>46</width>
  <height>25</height>
  <uuid>{dcbd8b1f-6168-4edc-8413-e5ae070d59de}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>303</x>
  <y>214</y>
  <width>64</width>
  <height>25</height>
  <uuid>{92fc8945-70bf-4759-9ab3-55017c552870}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>detect_B</objectName>
  <x>108</x>
  <y>541</y>
  <width>36</width>
  <height>25</height>
  <uuid>{8dcfb866-324b-4b0e-8b43-79db7b222d41}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>15.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>detect_C</objectName>
  <x>142</x>
  <y>541</y>
  <width>35</width>
  <height>25</height>
  <uuid>{03f1684a-27e3-4b41-b336-02330ae1e3d9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>21.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDropdown">
  <objectName>inchan_C</objectName>
  <x>113</x>
  <y>310</y>
  <width>43</width>
  <height>32</height>
  <uuid>{d9b1ff16-b487-40c2-abff-6a685eadf088}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
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
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>32</x>
  <y>314</y>
  <width>80</width>
  <height>25</height>
  <uuid>{ac604d0e-febe-4fe0-9038-75b050316cb8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>chan mic C</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName>meter_in_C</objectName>
  <x>49</x>
  <y>352</y>
  <width>100</width>
  <height>8</height>
  <uuid>{c0ff28f4-8451-4c75-a3e4-b498eaf8b99b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2/>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.55625955</xValue>
  <yValue>0.15178571</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>realfreq_C</objectName>
  <x>369</x>
  <y>269</y>
  <width>80</width>
  <height>32</height>
  <uuid>{0d5b0dd9-8a3c-4d98-afb5-dcd264b9501e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>256.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>freq_C</objectName>
  <x>369</x>
  <y>304</y>
  <width>80</width>
  <height>32</height>
  <uuid>{dad92162-9fe1-4b3f-adff-282da74affd7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>337.498</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>note_C</objectName>
  <x>447</x>
  <y>304</y>
  <width>68</width>
  <height>32</height>
  <uuid>{ea35e9d2-76aa-499f-b342-687a3ca22754}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>4E+33</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>130</g>
   <b>187</b>
  </color>
  <bgcolor mode="nobackground">
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBController">
  <objectName/>
  <x>242</x>
  <y>269</y>
  <width>10</width>
  <height>100</height>
  <uuid>{4b1ceb4f-3fe4-4794-8b59-cfcfe3b181b6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <objectName2>meter_out_C</objectName2>
  <xMin>0.00000000</xMin>
  <xMax>1.00000000</xMax>
  <yMin>0.00000000</yMin>
  <yMax>1.00000000</yMax>
  <xValue>0.06720727</xValue>
  <yValue>0.39187906</yValue>
  <type>fill</type>
  <pointsize>1</pointsize>
  <fadeSpeed>0.00000000</fadeSpeed>
  <mouseControl act="press">jump</mouseControl>
  <color>
   <r>167</r>
   <g>255</g>
   <b>97</b>
  </color>
  <randomizable mode="both" group="0">false</randomizable>
  <bgcolor>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </bgcolor>
 </bsbObject>
 <bsbObject version="2" type="BSBKnob">
  <objectName>gain_C</objectName>
  <x>169</x>
  <y>301</y>
  <width>64</width>
  <height>64</height>
  <uuid>{987ee0b4-f257-478d-9d0a-3b496f265a5a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>169</x>
  <y>278</y>
  <width>64</width>
  <height>25</height>
  <uuid>{ceb9904a-2f7f-4cc0-9df5-2c636f44fc79}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>gainC</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>gain_C</objectName>
  <x>169</x>
  <y>322</y>
  <width>64</width>
  <height>21</height>
  <uuid>{5862c849-b218-4c34-9740-58408ac81a6c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>265</x>
  <y>271</y>
  <width>101</width>
  <height>27</height>
  <uuid>{8bda7c50-db38-4247-b41a-f320366b89ec}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>tuning fork freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>265</x>
  <y>306</y>
  <width>101</width>
  <height>27</height>
  <uuid>{d234e449-5218-462f-8c1c-8f95e7ec6b5c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>transposed freq</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>f0_gain_C</objectName>
  <x>369</x>
  <y>342</y>
  <width>46</width>
  <height>25</height>
  <uuid>{83f2bdd0-b078-44b9-a481-264dd99d7030}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>1.000</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>178</g>
   <b>255</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>302</x>
  <y>341</y>
  <width>64</width>
  <height>25</height>
  <uuid>{790f4b14-5196-4aa9-9c06-ab544bd2f387}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>f0 gain A</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>639</x>
  <y>306</y>
  <width>137</width>
  <height>65</height>
  <uuid>{c4c25e66-493d-410b-a73f-3f4a899dcdf7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>Press the preset key (1, 2, 3, 4) to set it manually (otherwise use midi keyboard)</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>11</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>17</x>
  <y>580</y>
  <width>214</width>
  <height>144</height>
  <uuid>{5efe8c45-aa0b-4987-81e3-5a45151bcd64}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>Instructions:

1) Setup your midi keyboard
2) Press play
3) Set input channels of the tuning forks
4) Set output channel of the mono mix
5) Set preset via a midi keyboard (C4=preset 1, D4=preset 2, E4=preset 3, F4=preset 4) or manually using the number keys (1=preset 1, etc)</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>11</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBScrollNumber">
  <objectName>preset</objectName>
  <x>666</x>
  <y>218</y>
  <width>80</width>
  <height>80</height>
  <uuid>{9851ac4a-76f5-4ed5-8483-92d8ec5328c2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>64</fontsize>
  <color>
   <r>0</r>
   <g>94</g>
   <b>135</b>
  </color>
  <bgcolor mode="background">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <value>1.00000000</value>
  <resolution>1.00000000</resolution>
  <minimum>-999999999999.00000000</minimum>
  <maximum>999999999999.00000000</maximum>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
  <randomizable group="0">false</randomizable>
  <mouseControl act=""/>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>508</x>
  <y>20</y>
  <width>53</width>
  <height>25</height>
  <uuid>{478d016d-3534-4bb3-8306-22a647dc4f24}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>noise</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBSpinBox">
  <objectName>noise_A</objectName>
  <x>560</x>
  <y>16</y>
  <width>64</width>
  <height>32</height>
  <uuid>{c79dd85c-0422-4c4d-a177-2216887ec334}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <color>
   <r>0</r>
   <g>112</g>
   <b>161</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>0.10000000</resolution>
  <minimum>0</minimum>
  <maximum>10</maximum>
  <randomizable group="0">false</randomizable>
  <value>0.5</value>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>509</x>
  <y>145</y>
  <width>53</width>
  <height>25</height>
  <uuid>{319f76b8-5c6d-44ff-9f56-ded811443264}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>noise</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBSpinBox">
  <objectName>noise_B</objectName>
  <x>560</x>
  <y>141</y>
  <width>64</width>
  <height>32</height>
  <uuid>{91b54491-1bee-4bfb-a1fc-59676f01d2ca}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <color>
   <r>0</r>
   <g>112</g>
   <b>161</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>0.10000000</resolution>
  <minimum>0</minimum>
  <maximum>10</maximum>
  <randomizable group="0">false</randomizable>
  <value>0.5</value>
 </bsbObject>
 <bsbObject version="2" type="BSBLabel">
  <objectName/>
  <x>507</x>
  <y>273</y>
  <width>53</width>
  <height>25</height>
  <uuid>{c5c45b72-929e-48a2-a303-efae5ddb71f7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>noise</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBSpinBox">
  <objectName>noise_C</objectName>
  <x>559</x>
  <y>269</y>
  <width>64</width>
  <height>32</height>
  <uuid>{7715f2b6-450d-45ce-80b8-665a0f8ce54f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>12</fontsize>
  <color>
   <r>0</r>
   <g>112</g>
   <b>161</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>0.10000000</resolution>
  <minimum>0</minimum>
  <maximum>10</maximum>
  <randomizable group="0">false</randomizable>
  <value>0.5</value>
 </bsbObject>
 <bsbObject version="2" type="BSBDisplay">
  <objectName>info</objectName>
  <x>232</x>
  <y>483</y>
  <width>237</width>
  <height>60</height>
  <uuid>{5c527fc4-d375-4624-bd1a-7c1ca332d6e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <label>Tuning Forks
A: 1, B: 2, C: 3</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <precision>3</precision>
  <color>
   <r>55</r>
   <g>55</g>
   <b>55</b>
  </color>
  <bgcolor mode="background">
   <r>233</r>
   <g>233</g>
   <b>233</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>2</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>Preset 1</objectName>
  <x>405</x>
  <y>381</y>
  <width>101</width>
  <height>95</height>
  <uuid>{e754c55f-f14c-47ba-bf2b-48fe3ac053f7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Preset 1</text>
  <image>/</image>
  <eventLine>i60 0 -1</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>Preset 1</objectName>
  <x>405</x>
  <y>381</y>
  <width>101</width>
  <height>95</height>
  <uuid>{7fee35d1-9bae-4918-8203-5134a88c2162}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Preset 1</text>
  <image>/</image>
  <eventLine>i60 0 -1</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>Preset 2</objectName>
  <x>509</x>
  <y>381</y>
  <width>101</width>
  <height>95</height>
  <uuid>{1b62436b-cec0-441e-8200-3a44c63cf4f5}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Preset 2</text>
  <image>/</image>
  <eventLine>i62 0 -1</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>Preset 2</objectName>
  <x>612</x>
  <y>381</y>
  <width>101</width>
  <height>95</height>
  <uuid>{0e1a3856-4259-449b-90ab-775ab9304ab2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Preset 3</text>
  <image>/</image>
  <eventLine>i64 0 -1</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject version="2" type="BSBButton">
  <objectName>Preset 2</objectName>
  <x>715</x>
  <y>380</y>
  <width>101</width>
  <height>95</height>
  <uuid>{a9dd205b-7d04-45d7-afd6-f8c86c8b264c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Preset 4</text>
  <image>/</image>
  <eventLine>i65 0 -1</eventLine>
  <latch>false</latch>
  <latched>false</latched>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>
