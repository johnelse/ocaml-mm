(* TODO: use optimized version for files. *)
class virtual reader =
  let chans = Mad.wav_output_channels in
object (self)
  inherit IO.helper

  method virtual private stream_close : unit

  method channels = chans
  (* TODO *)
  method duration : int = raise Not_found
  method duration_time : float = raise Not_found
  method sample_rate = 44100

  val rb = Audio.Ringbuffer_ext.create chans 0

  val mutable mf = None

  method private mf =
    match mf with Some mf -> mf | _ -> assert false

  initializer
    mf <- Some
      (Mad.openstream
	 (fun n ->
           let s = String.create n in
           let n = self#stream_read s 0 n in
           s, n))

  method private decode = Mad.decode_frame_float self#mf

  method close = self#stream_close

  method read buf ofs len =
    let r = ref (-1) in
    while !r <> 0 && Audio.Ringbuffer_ext.read_space rb < len do
      let data =
        try
          self#decode
        with
          | Mad.End_of_stream -> Audio.create (self#channels) 0
      in
      r := Audio.duration data;
      Audio.Ringbuffer_ext.write rb data 0 !r
    done;
    let maxlen = Audio.Ringbuffer_ext.read_space rb in
    let len = min maxlen len in
    Audio.Ringbuffer_ext.read rb buf ofs len;
    len

  (* TODO *)
  method seek (n:int) : unit = assert false
end

class reader_of_file fname =
object (self)
  inherit IO.Unix.rw ~read:true fname
  inherit reader
end