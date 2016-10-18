
import luxe.Input;
import phoenix.geometry.QuadGeometry;
import luxe.gifcapture.LuxeGifCapture;
import dialogs.Dialogs;

class Main extends luxe.Game {

    var boxGeom: QuadGeometry;
    var capture: LuxeGifCapture;

    override function ready() {

        boxGeom = Luxe.draw.box( {
           w:50,
           h:50,
           x:100,
           y:100
        });

        capture = new LuxeGifCapture({
            width: Std.int(Luxe.screen.w/4),
            height: Std.int(Luxe.screen.h/4),
            fps: 50, 
            max_time: 5,
            quality: GifQuality.Worst,
            repeat: GifRepeat.Infinite,
            oncomplete: function(_bytes:haxe.io.Bytes) {

                var path = Dialogs.save('Save GIF');
                if(path != '') {
                    sys.io.File.saveBytes(path, _bytes);
                } else {
                    trace('No path chosen, file not saved!');
                }

            }
        });

    } //ready

    override function ondestroy() {

        capture.destroy();
        capture = null;

    } //ondestroy

    override function onkeyup(e:KeyEvent) {

	    if (e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override public function onkeydown(event:KeyEvent) {
        
        switch(event.keycode) {

            case Key.space:

                if(capture.state == CaptureState.Paused) {
                    capture.record();
                    trace('recording: active');
                } else if(capture.state == CaptureState.Recording) {
                    capture.pause();
                    trace('recording: paused');
                }

            case Key.key_r:
                capture.reset();
                trace('recording: reset');

            case Key.key_3:
                trace('recording: committed');
                capture.commit();

        } //switch

    } //onkeydown

    override function onrender() {

        Luxe.draw.text({
            immediate: true,
            pos: new luxe.Vector(10, 10),
            point_size: 14,
            text: '${Luxe.time}'
        });

    }

    override function update(dt:Float) {        

        if (Luxe.input.keydown(Key.key_a)) {
            boxGeom.transform.pos.x -= 200 * dt;
        }
        else if (Luxe.input.keydown(Key.key_d)) {
           boxGeom.transform.pos.x += 200 * dt;
        }

        if (Luxe.input.keydown(Key.key_w)) {
           boxGeom.transform.pos.y -= 200 * dt;
        }
        else if (Luxe.input.keydown(Key.key_s)) {
           boxGeom.transform.pos.y += 200 * dt;
        }
    }

}
