
/* flute and electronics- electronics */

//////////////////////////////////////// PREP ////////////////////////////////////////
/********* make sure the directory of sound file is correct *********/
/********* select audio interface *********/
/********* may need to change input and output bus number *********/

// RUN
(
{
	/* start up file */
	Server.local.options.numOutputBusChannels = 12;    // may need to change number of input and output channels
	Server.local.options.numInputBusChannels = 1;
	Server.internal.options.numOutputBusChannels = 12;
	Server.internal.options.numInputBusChannels = 1;
	//Server.local.options.device = "MOTU 896mk3 Hybrid"; // audio interface

	{s.meter;}.defer; // make sure it has 0-7 channels
	MIDIClient.init;
	MIDIIn.connectAll;

	s.waitForBoot {

		"buffers".postln;

		/* allocate buffers */
		~bufLength = 13;
		~buf = Buffer.alloc(s, 44100 * ~bufLength, 1); // allocate buffer to record for 13 seconds for rec 1
		s.sync;
		~bufWenRec = Buffer.read(s, "/Volumes/Audio HD/sl2047/cut1.wav"); // load soundfile
		s.sync;
		~bufWenRec2 = Buffer.read(s, "/Volumes/Audio HD/sl2047/cut2.wav");
		s.sync;
		~bufWenRec3 = Buffer.read(s, "/Volumes/Audio HD/sl2047/cut3.wav");
		s.sync;
		~bufWenRec4 = Buffer.read(s, "/Volumes/Audio HD/sl2047/cut4.wav");
		s.sync;
		"buffers done".postln;

		/* pick up mic signal, modify amplitude etc for output */
		~inNdef = {
			Ndef.ar(\micIn, 1); // 1 input from 1 mic
			//Ndef(\micIn, { Compander.ar(SoundIn.ar(0), 0, 0.7, 0.5, 0.9, 0.01, 0.1, 0.5) }); // this line contains compressor
			Ndef(\micIn, { SoundIn.ar(0)});
		}; // mic signal to channel 0
		~inNdef.(); // run SounIn ~inNdef globally

		/* record flute signal into a buffer in bar 2 */
		SynthDef(\SoundIn, {
			var input, rec, bufnum = 0, recLevel = 1, preLevel = 0;
			input = SoundIn.ar(0);
			rec = RecordBuf.ar(input, bufnum, 0, recLevel, preLevel, loop: 0, doneAction: 0);
		}).add;

		/* granularize 1 in bar 6 */
		// granularize Wen Lee live recording from bar 2 to 5
		SynthDef(\grainFl, {
			arg out, gate = 1, amp = 0.5, numChannels, trigger, dur, sndbuf, rate, pos, interp, pan, envbufnum, maxGrains, vol=1;
			var env, signal;
			// controls for grain
			numChannels = 4; // 4 channels for 3, 4, 5, 6 speakers
			trigger = Impulse.ar(XLine.kr(800));
			dur = 1;
			rate = LFNoise1.kr.range(0.5, 2) * -1; // playbackwards
			pos = SinOsc.ar(LFNoise1.kr(100));
			interp = 1;
			pan = SinOsc.kr(400);
			envbufnum = -1;
			maxGrains = 512;
			env = EnvGen.kr(Env.adsr, gate, levelScale: amp, doneAction: 2);
			signal = GrainBuf.ar(numChannels, trigger, dur, sndbuf, rate, pos, interp, pan, envbufnum, maxGrains) * env;
			Out.ar(4, signal*vol); // output thru 3, 4, 5, 6 speakers, start from bus 4
		}).add;

		/* granularize 2 in bar 6 */
		// granularize Wen Lee live recording from bar 2 to 5
		SynthDef(\grainFl2, {
			arg out, gate = 1, amp = 0.5, numChannels, trigger, dur, sndbuf, rate, pos, interp, pan, envbufnum, maxGrains, vol= 1;
			var env, signal;
			// controls for grain
			numChannels = 4; // 4 channels for 3, 4, 5, 6 speakers
			trigger = Impulse.ar(XLine.kr(1000));
			dur = 0.08;
			rate = LFNoise1.kr.range(0.8, 2) * 1; // play forward
			pos = LFNoise2.kr(0.1).range(0, 1);
			interp = 1;
			pan = LFSaw.kr(exprand(1, 8));
			envbufnum = -1;
			maxGrains = 512;
			env = EnvGen.kr(Env.adsr, gate, levelScale: amp, doneAction: 2);
			signal = GrainBuf.ar(numChannels, trigger, dur, sndbuf, rate, pos, interp, pan, envbufnum, maxGrains) * env;
			Out.ar(4, signal*vol);
		}).add;

		/* function to be used in bar 1 */
		~bar1Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol=1;
			var input, numc, numa, temp, env;
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			Out.ar([4,5,6,7,8,9], ((0.2 * temp) ! 1) * env * vol);
		};
		/* function for granular synth in bar 6 */
		~bar6wenRecGran = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 30 / trate;
			clk = Impulse.kr(trate);
			pos = 1;
			pan = WhiteNoise.kr(0.5);
			amp = 0.1;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(2, clk, ~bufWenRec, 2 ** WhiteNoise.kr(2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4,8], signal * vol);
		};
		/* function for rev and panning in bar 2 */
		~bar2RevPan = {
			arg out = 0, mix = 1, room = 0.9, damp = 1, gate = 1, vol = 1;
			var input, signal, amp, env;
			env = EnvGen.kr(Env.cutoff(-1), gate, doneAction: 2);
			amp = 0.8;
			input = Ndef.ar(\micIn, 1);
			signal = FreeVerb.ar(input, mix, room, damp) * amp; // mind the amplitude
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * vol);
		};
		/* function for bar 7: output aeolian sound through 1, 2, 7, 8 speakers with reverb */
		~bar7Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4, 6, 7, 9], ((0.2 * temp) ! 1) * env * vol); // output to bus 2 to 9; 2 = 1st speaker; 1;
		};
		/* function for bar 13: output delay + rev through 2-4-6-8-7-5-3-1 */
		~bar13DelayRev = {
			arg out, gate = 1, vol = 1;
			var in, amp, signal, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.8;
			in = Ndef.ar(\micIn, 1);
			signal = (FreeVerb.ar(FreeVerb.ar(Resonz.ar(CombN.ar(PanAz.ar(8, in, LFSaw.kr(exprand(1, 10)), 0.8, 3, 0.5), 0.8, 0.5, 6), 440, 1, 0.8), 0.3, 0.5, 1, 1), 0.3, 0.5, 1, 1) * amp * env);
			Out.ar(4, signal * vol); // start from bus 0 = speaker 1
		};
		/* function for bar 16: spectral filter to playback 'modulated' flute result; output each result onto randomly picked speaker */
		~bar16spec = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			in1 = Saw.ar(rrand(100, 1000),0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 16: another spectral filter to double, through all speakers */
		~bar16spec2 = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			in1 = Saw.ar(rrand(100, 1000),0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 16: low freq spec through speaker 1, 2, 7 and 8 with flute on stage */
		~bar16spec3 = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2, amp;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.1;
			in1 = Saw.ar(100, 0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1 * amp;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4, 6, 7, 9], (PanAz.ar(1, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 16: granularize Wen's performance recording cut 2*/
		~bar16wenRecGran2 = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 200 / trate;
			clk = Dust.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(200);
			amp = 0.5;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(6, clk, ~bufWenRec2, 2 ** WhiteNoise.kr(2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4], signal * vol);
		};
		/* function for bar 21: output through 3, 4, 5, 6 speakers with long delay */
		~bar21Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4, 5, 8, 9], ((0.2 * temp) ! 1) * env * vol);
		};
		/* function for bar 26: spectral filter 1 through all speakers */
		~bar26spec = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			in1 = Saw.ar(rrand(100, 1000),0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 26: spectral filter 2 through all speakers*/
		~bar26spec2 = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			in1 = Saw.ar(rrand(100, 1000),0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 26: spectral filter 3 low freq spec through speaker 7 and 8 with flute on stage */
		~bar26spec3 = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2, amp;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.01;
			in1 = SinOsc.ar(70, 0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1 * amp;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 1, 1);
			Out.ar([6], (PanAz.ar(2, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 26: output delay + rev through 2-4-6-8-7-5-3-1 */
		~bar26delayRev = {
			arg out, gate = 1, vol = 1;
			var in, amp, signal, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.8;
			in = Ndef.ar(\micIn, 1);
			signal = (FreeVerb.ar(FreeVerb.ar(Resonz.ar(CombN.ar(PanAz.ar(6, in, LFSaw.kr(exprand(1, 10)), 0.8, 3, 0.5), 0.8, 0.5, 6), 440, 1, 0.8), 0.3, 0.5, 1, 1), 0.3, 0.5, 1, 1) * amp * env);
			Out.ar(4, signal * vol); // start from bus 2 = speaker 1
		};
		/* fuction for bar 26: more reverb through speakers 1 and 2 */
		~bar26Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4, 9], ((0.2 * temp) ! 1) * env * vol);
		};
		/* function for bar 32: output through 1, 2, 7, 8 rev */
		~bar32Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4; // number of comb delays
			numa = 6; // number of allpass delays
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4,6, 7, 9], ((0.2 * temp) ! 1) * env * vol);
		};
		/* function for bar 32: granularize wen lee rec through 3, 4, 5, 6; low density to high and cut abruptly */
		~bar32wenRecGran3 = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 30 / trate;
			clk = Impulse.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(1);
			amp = 0.9;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(2, clk, ~bufWenRec3, 2 ** WhiteNoise.kr(2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4,5,8,9], signal * vol);
		};
		/* function for bar 33: output through all */
		~bar33Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4; // number of comb delays
			numa = 6; // number of allpass delays
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4,5,6,7,8,9], ((0.2 * temp) ! 1) * env * vol); // output to bus 2 to 9; 2 = 1st speaker
		};
		/* function for bar 33: granularize wen lee rec through 3, 4, 5, 6, 7, 8; low density to high and cut abruptly */
		~bar33WenRecGran4 = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 30 / trate;
			clk = Impulse.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(1);
			amp = 0.9;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(6, clk, ~bufWenRec3, 2 ** WhiteNoise.kr(2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4], signal * vol);
		};
		/* function for bar 34: output delay + rev */
		~bar34delayRev = {
			arg out, gate = 1, vol = 1;
			var in, amp, signal, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.8;
			in = Ndef.ar(\micIn, 1);
			signal = (FreeVerb.ar(FreeVerb.ar(Resonz.ar(CombN.ar(PanAz.ar(6, in, LFSaw.kr(exprand(1, 10)), 0.8, 3, 0.5), 0.8, 0.5, 6), 440, 1, 0.8), 0.3, 0.5, 1, 1), 0.3, 0.5, 1, 1) * amp * env);
			Out.ar([4,5,6,7,8,9], signal * vol);
		};
		/* function for bar 34: more rev */
		~bar34Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4,5,6,7,8,9], ((0.2 * temp) ! 1) * env * vol);
		};
		/* function for bar 35: granularize wen lee rec through 3, 4, 5, 6; low density to high and cut abruptly */
		~bar35WenRecGran5 = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 20 / trate;
			clk = Impulse.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(1);
			amp = 0.5;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(2, clk, ~bufWenRec3, 2 ** WhiteNoise.kr(2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4,8], signal * vol);
		};
		/* function for bar 37: key click output through all speakers, random amplitude of each output with long delay, clear clicks */
		~bar37RevPan = {
			arg out = 0, mix = 1, room = 0.9, damp = 1, gate = 1, vol = 1;
			var input, signal, amp, env;
			env = EnvGen.kr(Env.cutoff(-1), gate, doneAction: 2);
			amp = 0.95;
			input = Ndef.ar(\micIn, 1);
			signal = FreeVerb.ar(input, mix, room, damp) * amp; // mind the amplitude
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * vol); // bus 2 to speaker 1 etc.
		};
		/* function for bar 37: key click output through all speakers, random amplitude of each output with long delay, clear clicks */
		~bar37keyClick = {
			arg out = 0, mix = 1, room = 0.9, damp = 1, gate = 1, vol = 1;
			var input, signal, amp, env;
			env = EnvGen.kr(Env.cutoff(0), gate, doneAction: 2);
			amp = 0.95;
			input = Ndef.ar(\micIn, 1);
			signal = input * amp * env;
			Out.ar([4,5,6,7,8,9], (PanAz.ar(6, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * vol);
		};
		/* function for bar 37: granularize rec 1 */
		~bar37granRec = {
			arg gate = 1, vol = 1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 10 / trate;
			clk = Impulse.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(1);
			amp = 0.5;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			signal = TGrains.ar(6, clk, ~buf, 2 ** WhiteNoise.kr(0.2), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4,5,6,7,8,9], signal * vol);
		};
		/* function for bar 44: output flute through all speakers with delay */
		~bar44delayRev = {
			arg out, gate = 1, vol = 1;
			var in, amp, signal, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.7;
			in = Ndef.ar(\micIn, 1);
			signal = (FreeVerb.ar(FreeVerb.ar(Resonz.ar(CombN.ar(PanAz.ar(6, in, LFSaw.kr(exprand(1, 10)), 0.8, 3, 0.5), 0.8, 0.5, 6), 440, 1, 0.8), 0.3, 0.5, 1, 1), 0.3, 0.5, 1, 1) * amp * env);
			Out.ar([4], signal * vol);
		};
		/* function for bar 44: output flute through 1, 2, 7, 8 with reverb */
		~bar44Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env, amp;
			amp = 0.2;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4,6, 7, 9], ((0.2 * temp) ! 1) * env * amp * vol); // output to bus 2 to 9; 2 = 1st speaker
		};
		/* function for bar 44: spectral filter through 1, 2, 7, 8 */
		~bar44spec1 = {
			arg gate = 1, vol = 1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2, amp;
			amp = 0.2;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			in1 = Saw.ar(rrand(100, 1000),0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 0.9, 0.8);
			Out.ar([4, 6,7,9], (PanAz.ar(2, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * amp * vol);
		};
		/* function for bar 44: low freq spec through speaker 7, 8 with flute on stage */
		~bar44spec2 = {
			arg gate = 1, vol =1;
			var in1, in2, chain1, chain2, copychain, signal, fftSig, env1, env2, amp;
			env1 = Env.dadsr(0.1, sustainLevel:1).kr;
			env2 = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.1;
			in1 = SinOsc.ar(70, 0.8);
			in2 = Ndef.ar(\micIn, 1);
			chain1 = FFT(LocalBuf(1024), in1);
			chain2 = FFT(LocalBuf(1024), in2);
			copychain= PV_Copy(chain2, LocalBuf(1024));
			chain1 = PV_MagMul(chain1, chain2);
			copychain = PV_MagFreeze(copychain, LFNoise0.kr(100));
			fftSig = [0.8 * IFFT(chain1), IFFT(copychain)] * env1 * amp;
			signal = FreeVerb.ar(fftSig, 0.5, 0.5, 1, 1);
			Out.ar([7,9], (PanAz.ar(2, signal, LFSaw.kr(exprand(1, 8)), 0.5, 3, 0.5)) * env2 * vol);
		};
		/* function for bar 44: gran wen rec backward through 3, 4, 5, 6 */
		~bar44WenRecGran6 = {
			arg gate = 1, vol =1;
			var trate, dur, clk, pos, pan, amp, signal, env;
			trate = rrand(0.99, 3.6);
			dur = 3;
			clk = Impulse.kr(trate);
			pos = -1;
			pan = WhiteNoise.kr(100);
			amp = 0.3;
			env = EnvGen.kr(Env.cutoff(1), gate, doneAction: 2);
			signal = TGrains.ar(2, clk, ~bufWenRec4, 2 ** WhiteNoise.kr(1), pos, dur, pan, 0.1) * amp * env;
			Out.ar([4,8], signal * vol);
		};
		/* function for bar 57: output through all speakers with reverb and delay */
		~bar57delayRev = {
			arg out, gate = 1, vol = 1;
			var in, amp, signal, env;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			amp = 0.95;
			in = Ndef.ar(\micIn, 1);
			signal = (FreeVerb.ar(FreeVerb.ar(Resonz.ar(CombN.ar(PanAz.ar(6, in, LFSaw.kr(exprand(1, 10)), 0.8, 3, 0.5), 0.8, 0.5, 6), 440, 1, 0.8), 0.3, 0.5, 1, 1), 0.3, 0.5, 1, 1) * amp * env);
			Out.ar([4], signal * vol);
		};
		/* function for bar 57: more reverb through all speakers */
		~bar57Rev = {
			arg delaytime = 0.01, decaytime = 1, gate = 1, vol = 1;
			var input, numc, numa, temp, env, amp;
			amp = 0.9;
			env = EnvGen.kr(Env.cutoff(0.5), gate, doneAction: 2);
			input = Ndef.ar(\micIn, 1);
			numc = 4;
			numa = 6;
			temp = DelayN.ar(input, 0.048, 0.048);
			temp = Mix.fill(numc, {CombL.ar(temp, 0.1, rrand(0.01, 0.1), 5) } );
			numa.do( {temp = AllpassN.ar(temp, 0.051, [rrand(0.01, 0.05), rrand(0.01, 0.05)], 1) } );
			Out.ar([4,5,6,7,8,9], ((0.2 * temp) ! 1) * env * amp * vol);
		};

		"func and def done".postln;

		/* get midi controller IDs */
		MIDIClient.sources.do{|item|
			if(item.name == "APC MINI", {~apcID = item.uid}); }; // pad controller
		MIDIClient.destinations.do{|item|
			if(item.name == "APC MINI", {~apcOutID = item.uid}); }; // pad controller

		/* set midi outputs */
		m = MIDIOut(0, ~apcOutID);
		n = MIDIOut(0, ~apcOutID);
		"MIDIOut done".postln;

		/* midi slider controls */
		/* slider 1 */
		MIDIdef.cc(\slider1_button1, {
			arg num, id, chan, src;
			Ndef(\bar1Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 48, srcID: ~apcID);
		MIDIdef.cc(\slider1_button9, {
			arg num, id, chan, src;
			Ndef(\bar32Rev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar32wenRecGran3).set(\vol, num.linlin(0,127, 0, 1));
		}, 48, srcID: ~apcID);

		/* slider 2 */
		MIDIdef.cc(\slider2_button2_1, {
			arg num, id, chan, src;
			Ndef(\bar2RevPan).set(\vol, num.linlin(0,127, 0, 1));
		}, 49, srcID: ~apcID);
		MIDIdef.cc(\slider2_button10, {
			arg num, id, chan, src;
			Ndef(\bar33Rev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar33WenRecGran4).set(\vol, num.linlin(0,127, 0, 1));
		}, 49, srcID: ~apcID);

		/* slider 3 */
		MIDIdef.cc(\slider3_button3, {
			arg num, id, chan, src;
			Ndef(\bar6wenRecGran).set(\vol, num.linlin(0,127, 0, 1));
			// control granularized recording which was recorded at previous bar
			if(~bar6GrainFl.notNil, {
				~bar6GrainFl.set(\vol, num.linlin(0,127, 0, 1));
			});
			if(~bar6GrainFl2.notNil, {
				~bar6GrainFl2.set(\vol, num.linlin(0,127, 0, 1));
			});
		}, 50, srcID: ~apcID);
		MIDIdef.cc(\slider3_button11, {
			arg num, id, chan, src;
			Ndef(\bar34delayRev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar34Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 50, srcID: ~apcID);

		/* slider 4 */
		MIDIdef.cc(\slider4_button4, {
			arg num, id, chan, src;
			Ndef(\bar7Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 51, srcID: ~apcID);
		MIDIdef.cc(\slider4_button12, {
			arg num, id, chan, src;
			Ndef(\bar35WenRecGran5).set(\vol, num.linlin(0,127, 0, 1));
		}, 51, srcID: ~apcID);

		/* slider 5 */
		MIDIdef.cc(\slider5_button5, {
			arg num, id, chan, src;
			Ndef(\bar13delayRev).set(\vol, num.linlin(0,127, 0, 1));
		}, 52, srcID: ~apcID);
		MIDIdef.cc(\slider5_button13, {
			arg num, id, chan, src;
			Ndef(\bar37RevPan).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar37keyClick).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar37granRec).set(\vol, num.linlin(0,127, 0, 1));
		}, 52, srcID: ~apcID);

		/* slider 6 */
		MIDIdef.cc(\slider6_button6, {
			arg num, id, chan, src;
			Ndef(\bar16spec).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar16spec2).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar16spec3).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar16wenRecGran2).set(\vol, num.linlin(0,127, 0, 1));
		}, 53, srcID: ~apcID);
		MIDIdef.cc(\slider6_button14, {
			arg num, id, chan, src;
			Ndef(\bar44delayRev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar44Rev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar44spec1).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar44spec2).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar44WenRecGran6).set(\vol, num.linlin(0,127, 0, 1));
		}, 53, srcID: ~apcID);

		/* slider 7 */
		MIDIdef.cc(\slider7_button7, {
			arg num, id, chan, src;
			Ndef(\bar21Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 54, srcID: ~apcID);
		MIDIdef.cc(\slider7_button15, {
			arg num, id, chan, src;
			Ndef(\bar57delayRev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar57Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 54, srcID: ~apcID);

		/* slider 8 */
		MIDIdef.cc(\slider8_button8, {
			arg num, id, chan, src;
			Ndef(\bar26spec).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar26spec2).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar26spec3).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar26delayRev).set(\vol, num.linlin(0,127, 0, 1));
			Ndef(\bar26Rev).set(\vol, num.linlin(0,127, 0, 1));
		}, 55, srcID: ~apcID);


		//////////////////////////////////////// BEGIN /////////////////////////////////////////
		~midiMap2 = {arg button = 0, onFunc, offFunc;
			var countS = 0;

			MIDIdef.noteOn(("noteOnS" ++ button).asSymbol, {
				arg vel, nn, chan, src;
				//////////////////// STOP BUTTON //////////////////// button S
				if (button == 89, {
					if (countS == 0, {
						n.noteOn(0, button, 01); // stop button light on
						~turnLightOff.(); // turn all triggered button lights off
						Ndef.all.do{|item| item.release(2) }; //all ndefs off including recording ~inNdef
						~updateCountToZero.(); // update counts in ~midiMap, ready to be triggered again
						~recRout.stop; // stop routine for sanity
						~recStop.(); // to stop recording, free buffer and allocate buffer for recoring again
						~bar6GrainFl.set(\gate, 0); // close synth gate
						~bar6GrainFl = nil; // no more synth
						~bar6GrainFl2.set(\gate, 0);
						~bar6GrainFl2 = nil;
						countS = 1; // update count to auto turn light off in Task below
						onFunc.();
						if (countS == 1, {
							t = Task ({
								1.wait; // wait for 1 second before turn light off
								n.noteOn(0, button, 0); // light off
								~inNdef.(); // receive mic signal, ready for button trigger
								countS = 0;
							}).play;
						});
					});
				});
			}, button, srcID: ~apcID);
		};

		/* function to turn all lights off after STOP BUTTON is pressed */
		~turnLightOff = {
			var buttonNum = 0; // begin from button 56 (top of pad) for testing
			62.do {
				m.noteOn(0, buttonNum, 0); //light off
				buttonNum = buttonNum + 1;
			};
		};

		/* function to update all counts to 0 after the stop button is pressed */
		~updateCountToZero = {
			~count = 0;
			~count2_1 = 0;
			~count2_2 = 0;
			~count3 = 0;
			~count4 = 0;
			~count5 = 0;
			~count6 = 0;
			~count7 = 0;
			~count8 = 0;
			~count9 = 0;
			~count10 = 0;
			~count11 = 0;
			~count12 = 0;
			~count13 = 0;
			~count14 = 0;
			~count15 = 0;
			~countFt = 0;
			~countFt2 = 0;
		};

		/* trigger sound */
		~midiMap = {arg button=0, onFunc, offFunc, offFuncAll;
			~count = 0;
			~count2_1 = 0;
			~count2_2 = 0;
			~count3 = 0;
			~count4 = 0;
			~count5 = 0;
			~count6 = 0;
			~count7 = 0;
			~count8 = 0;
			~count9 = 0;
			~count10 = 0;
			~count11 = 0;
			~count12 = 0;
			~count13 = 0;
			~count14 = 0;
			~count15 = 0;

			MIDIdef.noteOn(("noteOn" ++ button).asSymbol, {
				arg vel, nn, chan, src;
				//("button: " ++ button.asString).postln;

				//////////////////// bar 1 //////////////////// button 1
				/* output through 8 speakers with reverb */
				if (button == 56, {
					if (~count == 0, {
						m.noteOn(0, button, 01); //light on
						/* call function for reverberation */
						~bar1 = Ndef(\bar1Rev, ~bar1Rev);
						~count = 1;
						onFunc.();
					}, {
						//////////////////// bar 1 stop //////////////////// button 1 press again OFF
						m.noteOn(0, button, 0); //light off
						~bar1.release(2);
						~count = 0;
						offFunc.();
					});
				});

				//////////////////// bar 2 //////////////////// button 2-1
				if (button == 57, {
					if (~count2_1 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output flute sound through randomly selected speakers/ panning, no additional pitch modification, only reverberation */
						~bar2 = Ndef(\bar2RevPan, ~bar2RevPan);
						~count2_1 = 1;
						onFunc.();
					}, {
						//////////////////// bar 2 stop rev pan //////////////////// button 2-1 press again OFF
						m.noteOn(0, button, 0); //light off
						/* fade out bar 2 reverberation */
						~bar2.release(2); // fade out before next comes in
						~count2_1 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 2 //////////////////// button 2-2
				/* start recording into buffer */
				~recStart = {
					m.noteOn(0, button, 03);
					/* record 1 */
					~bar2Rec = Synth(\SoundIn, [\buffer, ~buf]); //start recording (no playback)
					~count2_2 = 1;
					onFunc.();
					~recording = true;
				};
				/* stop recording and free buffer */
				~recStop = {
					~bar2Rec.free; // stop synth for recording
					~buf.free; // free buffer
					~recording = false;
					// realocate buffer to be recorded into again
					~waitForBufferReallocation = Routine {
						~buf = Buffer.alloc(s, 44100 * ~bufLength, 1); // allocate buffer to record for 13 seconds for rec 1
						s.sync;
					}.value;
					~count2_2 = 0;
					offFunc.();
				};
				/* function to turn light off after recording */
				~recCompleteLightOff = {
					m.noteOn(0, 49, 0);
					~recording = false;
					~count2_2 = 0;
					offFunc.();
				};
				/* button press for button 2-2 */
				if (button == 49, {
					if (~count2_2 == 0, {
						// routine to start recording and turn light off after recording is completed
						~recRout = {
							~recStart.();
							~bufLength.yield; // time when recording into buffer
							if(~recording, {
								"recording complete".postln;
								~recCompleteLightOff.();
							});
						}.fork;
					}, {
						//////////////////// bar 2 stop in the middle of recording and reallocate buffer for recording again // button 2 press again OFF
						if (~count2_2 == 1, {
							~recRout.stop; // stop routine for sanity
							~recStop.(); // call to stop recording and free buffer
							m.noteOn(0, button, 0); //light off
						});
					});
				});

				//////////////////// bar 6 //////////////////// button 3
				if (button == 58, {
					if (~count3 == 0, {
						m.noteOn(0, button, 01); //light on
						/* granuarlize Wen Lee recording (prepared) after I trigger the above */
						~bar6 = Ndef(\bar6wenRecGran, ~bar6wenRecGran);
						// granularize wen lee live record from bar 2 to 5; stored in ~buf 1
						~bar6GrainFl = Synth(\grainFl, [\sndbuf, ~buf]);
						~bar6GrainFl2 = Synth(\grainFl2, [\sndbuf, ~buf]);
						~count3 = 1;
						onFunc.();
					}, {
						//////////////////// bar 6 off 1 //////////////////// button 3 press again to close gate
						if (~count3 == 1, {
							m.noteOn(0, button, 02); // blink
							/* fade bar 6 gran ~buf */
							~bar6GrainFl.set(\gate, 0);
							~bar6GrainFl = nil;
							~bar6GrainFl2.set(\gate, 0);
							~bar6GrainFl2 = nil;
							~count3 = 2;
							offFunc.();
						}, {
							//////////////////// bar 6 stop //////////////////// button 3 press again OFF
							m.noteOn(0, button, 0); //light off
							/* fade wen rec gran at bar 6 */
							~bar6.release(6);
							~count3 = 0;
							offFuncAll.(); // send message to confirm some thread stopped
						});
					});
				});

				//////////////////// bar 7 //////////////////// button 4
				if (button == 59, {
					if (~count4 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output aeolian sound through 1, 2, 7, 8 speakers with reverb */
						~bar7 = Ndef(\bar7Rev, ~bar7Rev);
						~count4 = 1;
						onFunc.();
					}, {
						//////////////////// bar 7 stop //////////////////// button 4 press again OFF
						m.noteOn(0, button, 0); //light off
						~bar7.release(7);
						~count4 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 13 //////////////////// button 5
				if (button == 60, {
					if (~count5 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output delay + rev through 2-4-6-8-7-5-3-1 */
						~bar13 = Ndef (\bar13delayRev, ~bar13DelayRev );
						~count5 = 1;
						onFunc.();
					}, {
						//////////////////// bar 13 stop //////////////////// button 5 press again OFF
						m.noteOn(0, button, 0); //light off
						~bar13.release(4);
						~count5 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 16 //////////////////// button 6
				if (button == 61, {
					if (~count6 == 0, {
						m.noteOn(0, button, 01); //light on
						/* spectral filter to playback 'modulated' flute result; output each result onto randomly picked speaker */
						~bar16_1 = Ndef(\bar16spec, ~bar16spec);
						/* another spectral filter to double, through all speakers */
						~bar16_2 = Ndef(\bar16spec2, ~bar16spec2);
						/* low freq spec through speaker 1, 2, 7 and 8 with flute on stage */
						~bar16_3 = Ndef(\bar16spec3, ~bar16spec3);
						/* granularize Wen's performance recording cut 2*/
						//through speakers 3,4,5,6,7,8; Rymer 4,5,6,7,8,9
						~bar16_4 = Ndef(\bar16wenRecGran2, ~bar16wenRecGran2);
						~count6 = 1;
						onFunc.();
					}, {
						//////////////////// bar 16 off 1 //////////////////// button 6 off 1 release partial threads
						if (~count6 == 1, {
							m.noteOn(0, button, 02); // blink
							/* fade out spec filters in bar 16 */
							~bar16_1.release(4);
							~bar16_2.release(4);
							~bar16_3.release(4);
							~count6 = 2;
							offFunc.();
						}, {
							//////////////////// bar 16 stop //////////////////// button 6 press again OFF
							m.noteOn(0, button, 0); //light off
							/* fade out wen gran 2 */
							~bar16_4.release(8);
							~count6 = 0;
							offFuncAll.();
						});
					});
				});

				//////////////////// bar 21 //////////////////// button 7
				if (button == 62, {
					if (~count7 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output through 3, 4, 5, 6 speakers with long delay */
						~bar21 = Ndef(\bar21Rev, ~bar21Rev);
						~count7 = 1;
						onFunc.();
					}, {
						//////////////////// bar 21 stop //////////////////// button 7 press again OFF
						m.noteOn(0, button, 0); //light off
						/* fade out bar 21 */
						~bar21.release(2);
						~count7 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 26 //////////////////// button 8
				if (button == 63, {
					if (~count8 == 0, {
						m.noteOn(0, button, 01); //light on
						/* spectral filter 1 through all speakers */
						~bar26_1 = Ndef(\bar26spec, ~bar26spec);
						/* spectral filter 2 through all speakers*/
						~bar26_2 = Ndef(\bar26spec2, ~bar26spec2);
						/* spectral filter 3 low freq spec through speaker 7 and 8 with flute on stage */
						~bar26_3 = Ndef(\bar26spec3, ~bar26spec3);
						/* output delay + rev through 2-4-6-8-7-5-3-1 */
						~bar26_4 = Ndef (\bar26delayRev, ~bar26delayRev);
						/* more reverb through speakers 1 and 2 */
						// Rymer 4, 9
						~bar26_5 = Ndef(\bar26Rev, ~bar26Rev);
						~count8 = 1;
						onFunc.();
					}, {
						//////////////////// bar 26 stop //////////////////// button 8 press again OFF
						m.noteOn(0, button, 0); //light off
						/* fade out bar 26 here */
						~bar26_1.release(2);
						~bar26_2.release(2);
						~bar26_3.release(2);
						~bar26_4.release(4);
						~bar26_5.release(2);
						~count8 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 32 //////////////////// button 9
				if (button == 40, {
					if (~count9 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output through 1, 2, 7, 8 rev */
						~bar32_1 = Ndef(\bar32Rev, ~bar32Rev);
						/* granularize wen lee rec through 3, 4, 5, 6; low density to high and cut abruptly (.clear to release node immediately) */
						~bar32_2 = Ndef(\bar32wenRecGran3, ~bar32wenRecGran3);
						~count9 = 1;
						onFunc.();
					}, {
						//////////////////// bar 32 stop //////////////////// button 9 press again OFF
						m.noteOn(0, button, 0); //light off
						/* abrupt cut on the 5th beat */
						~bar32_1.release(0);
						~bar32_2.release(0);
						~count9 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 33 //////////////////// button 10
				if (button == 41, {
					if (~count10 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output through all */
						~bar33_1 = Ndef(\bar33Rev, ~bar33Rev);
						/* granularize wen lee rec through 3, 4, 5, 6, 7, 8; low density to high and cut abruptly (.clear to release node immediately) */
						~bar33_2 = Ndef(\bar33WenRecGran4, ~bar33WenRecGran4);
						~count10 = 1;
						onFunc.();
					}, {
						//////////////////// bar 33 stop //////////////////// button 10 press again OFF
						m.noteOn(0, button, 0); //light off
						/* abrupt cut */
						~bar33_1.release(0);
						~bar33_2.release(0);
						~count10 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 34 //////////////////// button 11
				if (button == 42, {
					if (~count11 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output delay + rev */
						~bar34_1 = Ndef (\bar34delayRev, ~bar34delayRev);
						~bar34_2 = Ndef(\bar34Rev, ~bar34Rev);
						~count11 = 1;
						onFunc.();
					}, {
						//////////////////// bar 34 stop //////////////////// button 11 press again OFF
						m.noteOn(0, button, 0); //light off
						/* fade out bar 34 rev and delay */
						~bar34_1.release(4);
						~bar34_2.release(4);
						~count11 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 35 //////////////////// button 12
				if (button == 43, {
					if (~count12 == 0, {
						m.noteOn(0, button, 1); //light on
						/* granularize wen lee rec through 3, 4, 5, 6; low density to high and cut abruptly */
						~bar35 = Ndef(\bar35WenRecGran5, ~bar35WenRecGran5);
						~count12 = 1;
						onFunc.();
					}, {
						//////////////////// bar 35 stop //////////////////// button 12 press again OFF
						m.noteOn(0, button, 0); //light off
						/* release wen rec gran4 */
						~bar35.release(3);
						~count12 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 37 //////////////////// button 13
				if (button == 44, {
					if (~count13 == 0, {
						m.noteOn(0, button, 01); //light on
						/* key click output through all speakers, random amplitude of each output with long delay, clear clicks */
						~bar37_1 = Ndef(\bar37RevPan, ~bar37RevPan);
						/* key click output through all speakers, random amplitude of each output with long delay, clear clicks */
						~bar37_2 = Ndef(\bar37keyClick, ~bar37keyClick);
						/* granularize rec 1 */
						~bar37_3 = Ndef(\bar37granRec, ~bar37granRec);
						~count13 = 1;
						onFunc.();
					}, {
						//////////////////// bar 37 stop //////////////////// button 13 press again OFF
						m.noteOn(0, button, 0); //light off
						/* release bar 37 */
						~bar37_1.release(8);
						~bar37_2.release(4);
						~bar37_3.release(12);
						~count13 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 44 //////////////////// button 14
				if (button == 45, {
					if (~count14 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output flute through all speakers with delay */
						~bar44_1 = Ndef (\bar44delayRev, ~bar44delayRev);
						/* output flute through 1, 2, 7, 8 with reverb */
						~bar44_2 = Ndef(\bar44Rev, ~bar44Rev);
						/* spectral filter through 1, 2, 7, 8 */
						~bar44_3 = Ndef(\bar44spec1, ~bar44spec1);
						/* low freq spec through speaker 7, 8 with flute on stage */
						~bar44_4 = Ndef(\bar44spec2, ~bar44spec2);
						/* gran wen rec backward through 3, 4, 5, 6 */
						~bar44_5 = Ndef(\bar44WenRecGran6, ~bar44WenRecGran6);
						~count14 = 1;
						onFunc.();
					}, {
						//////////////////// bar 44 stop //////////////////// button 14 press again OFF
						m.noteOn(0, button, 0); //light off
						/* release bar 44 */
						~bar44_1.release(3);
						~bar44_2.release(3);
						~bar44_3.release(0);
						~bar44_4.release(0);
						~bar44_5.release(3);
						~count14 = 0;
						offFunc.();
					});
				});

				//////////////////// bar 57 //////////////////// button 15
				if (button == 46, {
					if (~count15 == 0, {
						m.noteOn(0, button, 01); //light on
						/* output through all speakers with reverb and delay */
						~bar57_1 = Ndef (\bar57delayRev, ~bar57delayRev);
						/* more reverb through all speakers */
						~bar57_2 = Ndef(\bar57Rev, ~bar57Rev);
						~count15 = 1;
						onFunc.();
					}, {
						//////////////////// bar 57 stop //////////////////// button 15 press again OFF
						m.noteOn(0, button, 0); //light off
						/* release bar 57 to end the piece */
						~bar57_1.release(3);
						~bar57_2.release(3);
						~count15 = 0;
						offFunc.();
					});
				});

			}, button, srcID: ~apcID);
		};

		// messages when button pressed and released
		~midiMap.(56, {"on 56 button 1".postln}, {"off 56 button 1".postln});
		~midiMap.(57, {"on 57 button 2_1".postln}, {"off 57 button 2_1".postln});
		~midiMap.(49, {"on 49 button 2_2".postln}, {"off 49 button 2_2".postln});
		~midiMap.(58, {"on 58 button 3".postln}, {"some threads released 58 button 3".postln}, {"off 58 button 3".postln});
		~midiMap.(59, {"on 59 button 4".postln}, {"off 59 button 4".postln});
		~midiMap.(60, {"on 60 button 5".postln}, {"off 60 button 5".postln});
		~midiMap.(61, {"on 61 button 6".postln}, {"some threads released 61 button 6".postln}, {"off 61 button 6".postln});
		~midiMap.(62, {"on 62 button 7".postln}, {"off 62 button 7".postln});
		~midiMap.(63, {"on 63 button 8".postln}, {"off 63 button 8".postln});
		~midiMap.(40, {"on 40 button 9".postln}, {"off 40 button 9".postln});
		~midiMap.(41, {"on 41 button 10".postln}, {"off 41 button 10".postln});
		~midiMap.(42, {"on 42 button 11".postln}, {"off 42 button 11".postln});
		~midiMap.(43, {"on 43 button 12".postln}, {"off 43 button 12".postln});
		~midiMap.(44, {"on 44 button 13".postln}, {"off 44 button 13".postln});
		~midiMap.(45, {"on 45 button 14".postln}, {"off 45 button 14".postln});
		~midiMap.(46, {"on 46 button 15".postln}, {"off 46 button 15".postln});
		~midiMap2.(89, {"89 S button: STOP ALL THREADS".postln}, {"89 S button: ALL THREADS STOPPED".postln});
		"midiMap done".postln;

		"done!".postln;
	};
}.fork

)

//////////////////////////////////////// END ////////////////////////////////////////






