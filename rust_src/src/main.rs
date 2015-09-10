#[macro_use]
extern crate log;
extern crate env_logger;

extern crate serial;
extern crate time;
extern crate rustc_serialize;

use std::env;
use std::io;
use std::io::prelude::*;
use rustc_serialize::json;

use time::Duration;
use serial::prelude::*;

#[derive(RustcDecodable, RustcEncodable, Debug)]
struct IncomingMessage {
    message_type: u8,
    subtype: u8,
    data: Vec<u8>
}

#[derive(RustcDecodable, RustcEncodable, Debug)]
struct OutgoingMessage {
    message_type: u8,
    subtype: u8,
    message: String,
    data: Vec<u8>
}

fn translate_baudrate(baudrate: usize) -> serial::BaudRate {
    match baudrate {
        110 => serial::Baud110,
        300 => serial::Baud300,
        600 => serial::Baud600,
        1200 => serial::Baud1200,
        2400 => serial::Baud2400,
        4800 => serial::Baud4800,
        9600 => serial::Baud9600,
        19200 => serial::Baud19200,
        38400 => serial::Baud38400,
        57600 => serial::Baud57600,
        115200 => serial::Baud115200,
        s => serial::BaudOther(s) 
    }
}

fn interact<T: SerialPort>(port: &mut T, stdin: &io::Stdin, stdout: &io::Stdout, baudrate: usize) -> io::Result<()> {
    let baudrate_translated = translate_baudrate(baudrate);
    let settings = serial::PortSettings {
        baud_rate: baudrate_translated,
        char_size: serial::Bits8,
        parity: serial::ParityNone,
        stop_bits: serial::Stop1,
        flow_control: serial::FlowNone
    };

    try!(port.configure(&settings));
    try!(port.set_timeout(Duration::milliseconds(100)));

    debug!("port is ready");

    let om = OutgoingMessage {
        message_type: 1,
        subtype: 0, 
        message: "ok".to_string(),
        data: Vec::new()
    };

    send_msg(&stdout, om);

    loop {
        let msg = match parse_msg(&stdin) {
            Ok(m) => m,
            _ => continue
        };

        // supporting only type 3 which is command at the moment
        // others are:
        // 1 -> open port (handled earlier)
        // 2 -> change baud rate
        // 4 -> sensor message
        // _ -> uknown so panic
        let outbound: OutgoingMessage = match msg.message_type {
            3 => {
                debug!("command message");
                let buf = msg.data;
                match port.write(&buf[..]) {
                    Ok(_) => OutgoingMessage {
                        message_type: 1,
                        subtype: 0,
                        message: "ok".to_string(),
                        data: Vec::new()
                    },
                    Err(_) => OutgoingMessage {
                        message_type: 2,
                        subtype: 0,
                        message: "unable to write bytes".to_string(),
                        data: Vec::new()
                    }
                }
            },
            _ => {
                error!("uknown message_type");
                panic!("uknown message type");
            }
        };

        send_msg(&stdout, outbound);
    }

    Ok(())
}

fn parse_msg(stdin: &io::Stdin) -> Result<IncomingMessage, String> {
    let mut erl_buf = &mut [0u8; 2];
    let res = stdin.lock().read(erl_buf).unwrap();

    // If we didn't get two bytes to start something went
    // wrong. Read could return less than the buffer
    if res != 2 {
        error!("expected exactly two bytes to begin message and got less");
        panic!("expected exactly two bytes to begin message and got less");
    }

    // The size of the message that erlang is sending.
    // This is taken from the C example erlang provides for ports
    let size: u16 = (erl_buf[1] as u16) | ((erl_buf[0] as u16) << 8);

    // We need a buffer to read into to hold the message
    let mut msg_buf: &mut Vec<u8> = &mut Vec::new();

    // Use take to limit the number of bytes to read
    // it produces a reader that can not go past
    // the size specified.
    //
    // don't care about return value but may need to check that...
    let _ = stdin.lock().take(size as u64).read_to_end(msg_buf);

    // Turn byte buffer into a string
    let js_string = match String::from_utf8(msg_buf.to_vec()) {
        Ok(s) => {
            debug!("received {:?}", s);
            s
        },
        Err(e) => {
            error!("unable to parse string out of buffer");
            error!("{:?}", e);

            // do I crash? 
            // If I crash erlang will get that I can I restart there...
            return Err("unable to parse string out of buffer".to_string());
        }
    };


    match json::decode::<IncomingMessage>(&js_string) {
        Ok(m) => {
            debug!("parsed message {:?}", m);
            Ok(m)
        },
        Err(e) => {
            error!("unable to parse json from string");
            error!("{:?}", e);

            // Do cotinute or do I crash yet again?
            Err("unable to parse json from string".to_string()) 
        }
    }
}

fn send_msg(stdout: &io::Stdout, msg: OutgoingMessage) {
    let js_ret_str: String = json::encode(&msg).unwrap();

    // as_str() is needed to go to &str type,
    // and from there we can as_bytes to take it to [u8]
    let js_ret_bytes = js_ret_str.into_bytes();

    let size_buf: &mut [u8] = &mut [((js_ret_bytes.len() >> 8) & 0xff) as u8,
                                    (js_ret_bytes.len() & 0xff) as u8];

    // don't care about the return value in this case
    let _ = stdout.lock().write_all(size_buf);
    let _ = stdout.lock().write_all(&js_ret_bytes);
    let _ = stdout.lock().flush(); // need to ensure the buffer is flushed
}

fn main() {
    env_logger::init().unwrap();

    let args: Vec<_> = env::args().collect();

    if args.len() < 3 { panic!("usage: roomba_port <portname> <baudrate>") }

    let port = &args[1];
    let baud = args[2].parse().unwrap();

    let stdin = io::stdin();
    let stdout = io::stdout();

    let mut port = serial::open(port).unwrap();
    let _ = interact(&mut port, &stdin, &stdout, baud);
}
