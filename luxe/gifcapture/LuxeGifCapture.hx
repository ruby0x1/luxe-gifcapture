package luxe.gifcapture;

import gifcapture.GifCapture;

import luxe.Color;
import luxe.Log.def;

import phoenix.Batcher;
import phoenix.RenderTexture;
import phoenix.Texture.FilterType;
import phoenix.geometry.QuadGeometry;

import snow.modules.opengl.GL;

typedef GifQuality = gif.GifEncoder.GifQuality;
typedef GifRepeat = gif.GifEncoder.GifRepeat;
typedef CaptureState = gifcapture.GifCapture.CaptureState;

typedef LuxeGifCaptureOptions = {

        /** The destination width of the GIF. default: Luxe.screen.w */
    @:optional var width: Int;
        /** The destination height of the GIF. default: Luxe.screen.h */
    @:optional var height: Int;
        /** The desired framerate of the GIF. default: 30 
            Note that timing in GIF format is clamped down to 1/100 of a second.
            That means: 
            1/60 = 0.0166s * 100 = 1.666 floored = 1;  
            1/50 = 0.02    = 2;
            1/30 = 0.0333  = 3;
            1/25 = 0.04    = 4;
            Note that time will be lost here, so the playback would look faster/wrong.
            That makes 50, 25 the most exact timing, and 30 fps a decent option. */
    @:optional var fps: Int;
        /** If not 0, the recorder will stop at (max_time * fps) frames, allowing exact length recordings.
            Useful for websites with time limited gif uploads. default: 0 (disabled) */
    @:optional var max_time: Int;
        /** Compression quality, use GifQuality (worst = 100 ... 1 = best). default: GifQuality.Worst */
    @:optional var quality: Int;
        /** Number of repeats. Use GifRepeat or an exact count. default: GifRepeat.Infinite */
    @:optional var repeat: Int;
        /** The texture filter to apply when down or up sizing to the GIF. default: FilterType.linear */
    @:optional var filter: FilterType;
        /** A callback which will give you the bytes for the GIF file, when encoding completes. */
    @:optional var oncomplete: haxe.io.Bytes->Void;

} //LuxeGifCaptureOptions

class LuxeGifCapture {

    //public 

        public var fps (default, set): Int = 30;
        public var state (get, never): CaptureState;
        public var filter (default, set): FilterType;
        public var oncomplete: haxe.io.Bytes->Void;

        public var color_busy: Color;
        public var color_paused: Color;
        public var color_recording: Color;

    //internal

        var default_fbo: GLFramebuffer;
        var source: RenderTexture;
        var dest: RenderTexture;

        var recorder: GifCapture;
        var progress_batch: Batcher;
        var dest_batch: Batcher;
        var display_batch: Batcher;
        var dest_quad: QuadGeometry;
        var display_quad: QuadGeometry;

        var mspf: Float = 1/30;
        var max_time: Float = 0.0;
        var progress: Float = 0.0;
    
    public function new(_options:LuxeGifCaptureOptions) {

        def(_options.width,     Luxe.screen.w);
        def(_options.height,    Luxe.screen.h);
        def(_options.quality,   GifQuality.Worst);
        def(_options.repeat,    GifRepeat.Infinite);

        fps = def(_options.fps, 30);
        max_time = def(_options.max_time, 0);
        oncomplete = _options.oncomplete;
        filter = def(_options.filter, FilterType.linear);

        color_busy = new Color(0, 0.602, 1, 1);
        color_paused = new Color(1, 0.493, 0.061, 1);
        color_recording = new Color(0.968, 0.134, 0.019, 1);

        //change up the render targets
        
            source = new RenderTexture({
                id: 'gifcapture_source',
                width: Luxe.screen.w,
                height: Luxe.screen.h,
                filter_min: filter,
                filter_mag: filter
            });

            dest = new RenderTexture({
                id: 'gifcapture_dest',
                width: _options.width,
                height: _options.height,
            });

            default_fbo = Luxe.renderer.default_fbo;
            Luxe.renderer.default_fbo = source.fbo;
            GL.bindFramebuffer(GL.FRAMEBUFFER, source.fbo);

        //the capturer

                recorder = new GifCapture(
                    _options.width, 
                    _options.height, 
                    fps, 
                    max_time,
                    _options.quality,
                    _options.repeat);

            recorder.onprogress = encoder_progress;
            recorder.oncomplete = encoder_complete;

        //rendering stuff

            progress_batch = Luxe.renderer.create_batcher({
                name:'gifcapture_progress',
                camera: new phoenix.Camera({ camera_name : 'gifcapture_progress_view' }),
                no_add: true,
                layer: 1000
            });

            dest_batch = Luxe.renderer.create_batcher({
                name:'gifcapture_dest',
                camera: new phoenix.Camera({ 
                    camera_name : 'gifcapture_dest_view',
                    viewport: new phoenix.Rectangle(0, 0, _options.width, _options.height)
                }),
                no_add: true,
                layer: 1000
            });

            display_batch = Luxe.renderer.create_batcher({
                name:'gifcapture_display',
                camera: new phoenix.Camera({ camera_name : 'gifcapture_display_view' }),
                no_add: true,
                layer: 1000
            });


            dest_quad = new QuadGeometry({
                batcher: dest_batch, texture: source,
                x: 0, y: 0, w: _options.width, h: _options.height
            });

            display_quad = new QuadGeometry({
                batcher: display_batch, texture: source, flipy: true,
                x: 0, y: 0, w: Luxe.screen.w, h: Luxe.screen.h
            });

        //listen for events

            Luxe.on(luxe.Ev.tickstart, ontickstart);
            Luxe.on(luxe.Ev.tickend, ontick);
            Luxe.on(luxe.Ev.update, onupdate);

    } //new

    //public 

        public function destroy() {

            Luxe.renderer.default_fbo = default_fbo;

            Luxe.off(luxe.Ev.tickstart, ontickstart);
            Luxe.off(luxe.Ev.tickend, ontick);
            Luxe.off(luxe.Ev.update, onupdate);
                
            dest.destroy();
            progress_batch.destroy();
            dest_batch.destroy();
            recorder.destroy();

            dest = null;
            recorder = null;
            progress_batch = null;
            dest_batch = null;

        } //destroy

        public function reset() {

            progress = 0;
            recorder.reset();
            #if cpp cpp.vm.Gc.enable(true); #end

        } //reset

        public function commit() {
            
            recorder.commit();
            #if cpp cpp.vm.Gc.enable(true); #end

        } //commit

        public function record() {

            #if cpp cpp.vm.Gc.enable(false); #end
            
            accum = 0;
            last_tick = Luxe.time;

            recorder.record();

        } //record

        public function pause() {

            #if cpp cpp.vm.Gc.enable(true); #end

            recorder.pause();

        } //pause

    //internal

        function grab_frame() : haxe.io.Bytes {

            //copy the source to the dest using a rendered quad

                var prev_target = Luxe.renderer.target;

                Luxe.renderer.target = dest;
                dest_batch.draw();

                Luxe.renderer.target = prev_target;

            //grab pixel data

                GL.bindFramebuffer(GL.FRAMEBUFFER, dest.fbo);

                    //place to put the pixels
                var frame_data = new snow.api.buffers.Uint8Array(dest.width * dest.height * 3);

                    //get the pixels of the dest buffer back out
                GL.readPixels(0, 0, dest.width, dest.height, GL.RGB, GL.UNSIGNED_BYTE, frame_data);

                    //reset the frame buffer state to previous
                GL.bindFramebuffer(GL.FRAMEBUFFER, Luxe.renderer.state.current_fbo);

            //convert and return

                var frame_bytes = frame_data.toBytes();

                frame_data = null;

                return frame_bytes;

        } //grab_frame

    var last_tick = 0.0;
    var accum = 0.0;

    function onupdate(_) {

        recorder.update();

    } //onupdate

    function ontickstart(_) {
        
        GL.bindFramebuffer(GL.FRAMEBUFFER, source.fbo);

    } //ontickstart

    function ontick(_) {

        var frame_delta = Luxe.time - last_tick;
        last_tick = Luxe.time;

        if(recorder.state == Recording) {

            accum += frame_delta;

            if(accum >= mspf) {

                var frame_bytes = grab_frame();
                var frame_in = haxe.io.UInt8Array.fromBytes(frame_bytes);
                
                recorder.add_frame(frame_in, mspf, false);

                frame_in = null;

                accum -= mspf;

            } //

        } //Recording

        GL.bindFramebuffer(GL.FRAMEBUFFER, default_fbo);

        display_batch.draw();

        if(progress != 0) {

            var color = switch(recorder.state) {
                case Recording: color_recording;
                case Paused:    color_paused;
                case _:         color_busy;
            }

            Luxe.draw.box({
                w: Luxe.screen.w * progress,                
                x: 0, y: 0, h: 3,
                batcher: progress_batch,
                immediate: true,
                color: color
            });

            progress_batch.draw();

        } //progress != 0

    } //tick_end


    //internal callbacks

        function encoder_complete(_bytes:haxe.io.Bytes) {

            #if cpp cpp.vm.Gc.enable(true); #end
            
            progress = 0;

            if(oncomplete != null) oncomplete(_bytes);

        } //encoder_complete

        function encoder_progress(_progress:Float) {
            
            progress = _progress;

        } //encoder_progress

    //properties

        function set_filter(_v:FilterType) {

            if(source != null) {
                source.filter_min = source.filter_mag = _v;
            }

            return filter = _v;

        } //set_filter

        function get_state() {

            return recorder.state;

        } //get_state

        function set_fps(_v:Int) {
            
            mspf = 1 / _v;
            
            return fps = _v;

        } //set_fps

} //LuxeGifCapture