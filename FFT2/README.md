### How to setup.

All you need to do is copy&paste your solution code from Lessons 3 and 4:
* `async_fifo.v`           (Lesson 4)
* `fft_find_peak.sv`       (Lesson 4)
* `fft_input_buffer.sv`    (Lesson 4)
* `fft_mag_sq.sv`          (Lesson 4)
* `low_pass_conv.sv`       (Lesson 4) (For decimation filter)
* `mic/mic_load.sv`        (Lesson 3)
* `mic/i2c_master.sv`      (Lesson 3)

HW DSP Pipeline - fft_pitch_detect.sv
═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
 audio_clk domain (3.072 MHz)                                                                           fft_clk domain (18.432 MHz, *adc_clk*)
 ┌───────────────────────────────────────────────────────────────────┐ ║ ┌─────────────────────────────────────────────────────────────────┐
 │                           decimated_data    windowed_data         │ ║ │  di_re[W-1:0]  do_re/do_im      mag_sq[W*2:0]                   │
 │                     ┌───────────┐ │ ┌──────────┐ │ ┌────────────────────┐ │  ┌─────────┐ │  ┌──────────┐ │  ┌─────────────┐             │
 │audio_input[W-1:0]──►│ DECIMATE  ├──►│  WINDOW  ├──►│  FFT INPUT BUFFER  ├───►│   FFT   ├───►│   MAG²   ├───►│  FIND PEAK  ├──► pitch    │
 │    (from mic)       │   x4      │   │Rectangle │   │    (1024 samples)  │    │ 1024-pt │    │  |X|²    │    │   k-index   │    output   │
 │                     │48kHz→12kHz│   │          │   │  (FIFO CDC Cross)  │    │         │    │          │    │peak detector│    (k-index)│
 │                     └───────────┘   └──────────┘   └────────────────────┘    └─────────┘    └──────────┘    └─────────────┘    [9:0]    │
 │                     decimate.sv   window_function.sv   fft_input_buffer.sv      FFT.v      fft_mag_sq.sv    fft_find_peak.sv            │
 │                                                                   │ ║ │                          │                                      │
 │                                                                   │ ║ │                          │mag_sq[W*2:0]                         │
 │                                                                   │ ║ │                          │                                      │
 │                                                                   │ ║ │                          ▼                                      │
 │                                                                   │ ║ │                     ┌──────────┐                                │
 │                                                                   │ ║ │                     │  OUTPUT  │ (for SignalTap Debugging)      │
 │                                                                   │ ║ │                     │  BUFFER  │                                │
 │                                                                   │ ║ │                     └──────────┘ fft_output_buffer.sv           │
 └───────────────────────────────────────────────────────────────────┘ ║ └─────────────────────────────────────────────────────────────────┘
                                                       Clock Domain Crossing (audio_clk → fft_clk)
Top-Level System Architecture - top_level.sv
═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     ┌─────────┐                                           ┌───────────────────────────────────────┐                                      │
│     │ i2c_pll ├──► i2c_clk (20 kHz)                       │   WM8731 Audio Codec (External chip)  │                                      │
│     └─────────┘         │                                 │                                       │                                      │
│                         ▼                                 │  ┌──────────────────────────────┐     │                                      │
│                    ┌─────────────────────┐                │  │   AUD_ADCDAT  (mic data)     ──────│─────┐                                │
│                    │  set_audio_encoder  │                │  │   AUD_ADCLRCK (L/R clock)    ──────│──┐  │                                │
│                    │  (I2C Config Setup) ├────────────────│──►   I2C_SCLK/I2C_SDAT (config) │     │  │  │                                │
│                    │   - DE1: FPGA_I2C_* │                │  │   AUD_BCLK (3.072 MHz)       ──────│──┼──┼──► audio_clk (3.072 MHz)       │
│                    │   - DE2: I2C_*      │             ┌──│──►   AUD_XCK  (18.432 MHz)      │     │  │  │      │                         │
│                    └─────────────────────┘             │  │  └──────────────────────────────┘     │  │  │      │                         │
│                                                        │  └───────────────────────────────────────┘  │  │      │                         │
│     ┌─────────┐                                        │                                             │  │      │                         │
│     │ adc_pll ├──► adc_clk (18.432 MHz) ───────────────┘                                             │  │      │                         │
│     └─────────┘         │                                                                            │  │      │                         │
│                         │                                                                            ▼  ▼      ▼                         │
│                         │                                                                    ┌───────────────────┐                       │
│                         │                                                                    │     mic_load      │                       │
│                         │                                                                    │  (Deserializer)   │                       │
│                         │                                                                    └──────┬────────────┘                       │
│                         │                                                                           │audio_input_data[15:0]              │
│                         │                                                                           │audio_input_valid                   │
│                         │                                                                           ▼                                    │
│                         │                                                            ┌─────────────────────────────┐                     │
│                         └────────────────────────────────────────────────────────────┤    fft_pitch_detect         │                     │
│                                                        fft_clk (18.432 MHz) ────────►│  (DSP Pipeline Module)      │                     │
│                                                       audio_clk (3.072 MHz) ────────►│  See detailed diagram above │                     │
│                                                                                      └──────────────┬──────────────┘                     │
│                                                                                                     │pitch_output_data[9:0]              │
│                                                                                                     ▼                                    │
│                                                                                            ┌──────────────────┐      ┌─────────────────┐ │
│                                                                                            │     display      │      │ HEX0,HEX1,HEX2, │ │
│                                                                                            │  (7-seg decode)  ├─────►│     HEX3        │ │
│  KEY[0] ───► ~reset                                                                        └──────────────────┘      └─────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 Clock Domains:  audio_clk (3.072 MHz from WM8731), adc_clk & fft_clk (18.432 MHz), i2c_clk (20 kHz)
