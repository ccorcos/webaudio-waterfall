
Template.main.rendered = ->
  Spectogram('waterfall')
  # Spectogram('waterfall', 50, 380, 1024)

# problem with smaller frequency ranges is the FFT window is huge.

# 440 -> 102
# 1000 -> 232
# 2000 -> 463
# 3000 -> 595
# 4000 -> 929
# 4300 -> 998
# 4.306640625

# 1 (E)	329.63 Hz	E4
# 2 (B)	246.94 Hz	B3
# 3 (G)	196.00 Hz	G3
# 4 (D)	146.83 Hz	D3
# 5 (A)	110.00 Hz	A2
# 6 (E)	82.41 Hz	E2
# drop d 73.42




# navigator.getUserMedia = navigator.getUserMedia or
#                          navigator.webkitGetUserMedia or
#                          navigator.mozGetUserMedia or
#                          navigator.msGetUserMedia

# window.requestAnimationFrame = window.requestAnimationFrame or
#                          window.webkitRequestAnimationFrame or
#                          window.mozRequestAnimationFrame or
#                          window.msRequestAnimationFrame


navigator.getUserMedia = navigator.mozGetUserMedia
window.requestAnimationFrame = window.mozRequestAnimationFrame

Spectogram = (canvasId, minFreq=0, maxFreq=4410, fftSize=2048) ->

  console.log "init spectogram"

  # fft across 2048 samples creating 1024 frequency bins
  # max fft size is 2048?
  # fft size the window size. so this is the tradeoff between frequency
  # resolution and temporal resolution
  # fftSize = 512 #1024 #2048
  fftFreqBins = fftSize/2
  fftSizeDouble = fftSize*2

  # some global scoped variables
  context = null             # audio context
  sourceNode = null          # microphone input node
  filterNode = null          # low pass filtered node
  fft = null                 # compiled fft function

  # windowing function to reduce high frequency noise
  # Many options:
  #   DSP.HAMMING, DSP.HAN, DSP.BARTLETT, DSP.BARTLETTHANN, DSP.BLACKMAN
  #   DSP.COSINE, DSP.GAUSS, DSP.LANCZOS, DSP.RECTANGULAR, DSP.TRIANGULAR
  fftWindow = DSP.HAMMING    #

  # moving average smoothing. set to 1 for no smoothing
  movingAverage = 1
  # a buffer that keeps the last frew spectra to perform a moving average
  spectrumbuffer = []

  # gain and floor for the frequency visualization
  gain = 35#90#60#20#30#45
  floor = 40#20#60#40

  # height of the canvas.
  height = 256

  # Creates a spectogram visualizer for microphone input. This
  # requires a call to getUserMedia which is currently only
  # available in Chrome and Firefox.

  # We get 44100 Hz input from the microphone. So we'll want to subsample
  # to compute the specific frequency range we're interested in. We'll have
  # to round to the closest integer subsample rate. Also note the Nyquist
  # frequency requires a factor of two when sampling.
  inputSampleRate = 44100
  subsampleFactor = Math.floor(44100/maxFreq/2) # 5
  resampleRate = inputSampleRate/subsampleFactor # 8820
  resampleMaxFreq = resampleRate/2 # 4410

  # Compute the frequency / pixel resolution. Note that we must calculate
  # all frequencies down to zero so raising the minFreq doesn't change the
  # resolution
  pixelResolution = resampleMaxFreq/fftFreqBins

  # Given the frequency range we want to display, we need to calculate
  # the index of the 1024 element array we want to display.
  maxFreqIndex = Math.round(maxFreq/pixelResolution)
  minFreqIndex = Math.round(minFreq/pixelResolution)

  # compute the width of the canvas to display all these frequencies
  width = maxFreqIndex - minFreqIndex


  freq2index = (hz) ->
    Math.round(hz/pixelResolution)

  index2freq = (index) ->
    pixelResolution*index


  # get the context from the canvas to draw on
  $canvas = $("#" + canvasId)
  $overlay = $("#" + canvasId + "-overlay")

  # get the context of the canvas element
  canvas = document.getElementById(canvasId)
  ctx = canvas.getContext("2d")

  # create another canvas to use for copying
  tempCanvas = document.createElement("canvas")
  tempCtx = tempCanvas.getContext("2d")

  canvas.width = width
  canvas.height=height
  tempCanvas.width = width
  tempCanvas.height=height


  initAudio = (stream) ->
    console.log "init audio"
    context = new AudioContext()
    fft = new FFT(fftSize, resampleRate)

    # Create an AudioNode from the input stream
    sourceNode = context.createMediaStreamSource(stream)

    # Filter the audio to limit bandwidth to before resampling to prevent
    # aliasing using a Biquad Filter.
    filterNode = context.createBiquadFilter()
    filterNode.type = filterNode.LOWPASS
    filterNode.frequency.value = 0.95*maxFreq
    filterNode.Q.value = 1.5
    filterNode.gain.value = 0

    # pass the sourceNode into the filterNode
    sourceNode.connect(filterNode)

    # Create an audio resampler. Resample, Window, FFT, smooth, and draw
    resamplerNode = context.createScriptProcessor(fftSizeDouble,1,1)
    rss = new Resampler(44100, resampleRate, 1, fftSizeDouble, true)
    ring = new Float32Array(fftSizeDouble)
    fftbuffer = new Float32Array(fftSize)
    idx = 0
    spectrumidx = 0
    dspwindow = new WindowFunction(fftWindow)

    resamplerNode.onaudioprocess = (event) ->
      console.log "draw"
      inp = event.inputBuffer.getChannelData(0)
      out = event.outputBuffer.getChannelData(0)
      l = rss.resampler(inp)

      # keep a circular buffer of the output
      for i in [0...l]
        ring[(i+idx)%fftSizeDouble] = rss.outputBuffer[i]

      # copy the oldest 2048 bytes from ring buffer to the output channel
      for i in [0...fftSize]
        fftbuffer[i] = ring[(idx+i+fftSize)%fftSizeDouble]

      idx = (idx+l)%fftSizeDouble

      # Before doing our FFT, we apply a window to attenuate frequency artifacts,
      # otherwise the spectrum will bleed all over the place.
      dspwindow.process(fftbuffer)
      fft.forward(fftbuffer)

      # keep track of the previous spectra and introduce a new one with which
      # we can compute a moving average
      spectrumbuffer[spectrumidx] = new Float32Array(fft.spectrum)
      spectrumidx = (spectrumidx+1)%movingAverage

      # draw the spectogram!
      requestAnimationFrame(drawSpectrogram)

    # connect the audio.
    filterNode.connect(resamplerNode)
    resamplerNode.connect(context.destination)


  hot = chroma.scale ['#000000', '#0B16B5', '#FFF782', '#EB1250'],
                     [0,          0.4,       0.68,          0.85]
          .mode 'rgb'
          .domain [0, 300]

  drawSpectrogram = ->
    tempCtx.drawImage(canvas, 0, 0, width, height)

    for i in [minFreqIndex...(width+minFreqIndex)]
        # draw each pixel with the specific color
        sp = 0
        for j in [0...movingAverage]
          sp += spectrumbuffer[j][i]

        value = height + gain*Math.log(sp/movingAverage*floor)
        # console.log value
        # draw the line on top of the canvas
        ctx.fillStyle = hot(value).hex()
        ctx.fillRect(i-minFreqIndex, 1, 1, 1)

    # draw the copied image
    ctx.drawImage(tempCanvas, 0, 0, width, height, 0, 1, width, height);


  started = false
  microphoneError = (event) ->
    console.log event
    if event.name is "PermissionDeniedError"
      alert "This app requires a microphone as input. Please adjust your privacy settings."

  microphoneSuccess = (stream) ->
    started = true
    $overlay.css 'opacity', '0'
    initAudio(stream)

  paused = false
  $canvas.on 'click', (e) ->
    if started
      if paused
        console.log "unpause"
        sourceNode.connect filterNode
        $overlay.css 'opacity', '0'
        paused = false
      else
        console.log "pause"
        sourceNode.disconnect()
        $overlay.css 'opacity', '1'
        paused = true
    else
      if navigator.getUserMedia
        console.log "get microphone"
        navigator.getUserMedia {audio: true}, microphoneSuccess, microphoneError
      else
        alert "Please try using Firefox."
