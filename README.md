# luxe-gifcapture
A luxe wrapper over the gifcapture library to simplify capturing realtime gifs from in game.

### Requirements

- [gif](https://github.com/snowkit/gif)
- [gifcapture](https://github.com/snowkit/gifcapture)
- [linc_dialogs](https://github.com/snowkit/linc_dialogs)

Requires cpp targets, and currently makes the assumption of desktop GL availability (glBlitFramebuffer specifically) This means it won't run on mobile right now as is. The blit handles the downsizing of the gif.

### Install

If you need the dependencies:   
`haxelib git gif https://github.com/snowkit/gif`   
`haxelib git gifcapture https://github.com/snowkit/gifcapture`   
`haxelib git linc_dialogs https://github.com/snowkit/linc_dialogs`   

Then setup this library:
`haxelib git luxe_gifcapture https://github.com/underscorediscovery/luxe-gifcapture`

Add all of them to your flow file:

```js
build : {
  dependencies : {
    luxe : '*',
    gif : '*',
    linc_dialogs : '*',
    gifcapture : '*',
    luxe_gifcapture : '*',
  }
},
```

### Usage

See `tests/test_luxe/`

Create a capture instance:

```haxe
 capture = new LuxeGifCapture(
    Std.int(Luxe.screen.w/4),   //
    Std.int(Luxe.screen.h/4),   //
    30,                         // 30 frames per second
    5,                          // 5 seconds, use 0 to disable max time
    GifQuality.Worst,           // quality
    GifRepeat.Infinite          // repeat count
);
```

Toggle recording:
(Note, you can record and pause as many times as you wish before committing the frames)

```haxe
if(keycode == Key.space) {

    if(capture.state == Paused) {
        capture.record();
        trace('recording: active');
    } else if(capture.state == Recording) {
        capture.pause();
        trace('recording: paused');
    }

}
```

When done recording, call commit and then the save dialog will pop up when it's finished encoding. It will display a colored progress bar while it's busy encoding in the background.

### Notes

This library listens to the `tick_end` event - the very end of the luxe frame.

Then it switches to the default framebuffer (use `force_default_fbo` to use the active FBO instead) and then calls `glBlitFramebuffer` to copy the pixels to a internal render texture of the output size. 

It then sends the pixels to the gifcapture library for encoding.
When the encoding is complete it automatically opens a save file dialog, this is not configurable right now but soon will be.