# Web Audio API Waterfall Plot ([demo](http://webaudio-waterfall.meteor.com))

This app uses the [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API) and [DSP.js](https://github.com/corbanbrook/dsp.js/) to display a real-time waterfall plot of the audio spectrum from a mircophone right in your web browser!

This app only runs on Firefox right now. Check out the [demo](http://webaudio-waterfall.meteor.com)! Try whistling or listening to music and you'll see the frequencies light up. Now try speaking some sentences. Software like Siri tries to determine what you are saying from audio. Pretty cool right? I thought so.

Here's a screenshot from listing to [GRiZ - The Future Is Now](https://www.youtube.com/watch?v=tPqLfsmL0bM).

![](public/screenshot.png)

## Getting Started

This app uses Meteor for convenience, but you could easily convert the coffeescript to javascript and paste into your own app.

    curl https://install.meteor.com/ | sh

Then clone this repo and run it with `meteor` from inside the project directory.

Also, make sure your turn off ambient noise reduction!

![](http://i.stack.imgur.com/Bvg1x.jpg)
