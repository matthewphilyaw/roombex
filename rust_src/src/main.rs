#[macro_use]
extern crate log;
extern crate env_logger;
extern crate serial;
extern crate time;

use std::env;
use std::io;
use std::io::prelude::*;
use time::Duration;
use serial::prelude::*;

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

fn interact<T: SerialPort>(port: &mut T, stdin: &io::Stdin, stdout: &io::Stdout, baudrate: usize) {
    let baudrate_translated = translate_baudrate(baudrate);
    let settings = serial::PortSettings {
        baud_rate: baudrate_translated,
        char_size: serial::Bits8,
        parity: serial::ParityNone,
        stop_bits: serial::Stop1,
        flow_control: serial::FlowNone
    };

    let _ = port.configure(&settings);
    let _ = port.set_timeout(Duration::milliseconds(100));

    debug!("port is ready");

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
        //        match port.write(&buf[..]) {
        let _ = match msg[0] {
            0x01 => port.write(&msg[1..]),
            _ => continue
        };
    };
}

fn parse_msg(stdin: &io::Stdin) -> Result<Vec<u8>, String> {
    let mut erl_buf = &mut [0u8; 2];
    let res = stdin.lock().read(erl_buf).unwrap();

    // If we didn't get two bytes to start something went
    // wrong. Read could return less than the buffer
    if res != 2 {
        error!("expected exactly two bytes to begin message and got less");
        panic!("expected exactly two bytes to begin message and got less");
    }

    let size: usize = (erl_buf[1] as usize) | ((erl_buf[0] as usize) << 8);

    let mut msg_buf: &mut Vec<u8> = &mut Vec::new();
    let bytes_read = stdin.lock().take(size as u64).read_to_end(msg_buf).unwrap();

    match bytes_read == size {
        true => Ok(msg_buf.to_owned()),
        _ => Err("something went wrong, the size of the message doesn't match the actual bytes read".to_string())
    }
}

fn main() {
    env_logger::init().unwrap();

    let args: Vec<_> = env::args().collect();

    if args.len() < 3 { panic!("usage: roomba_port <portname> <baudrate>") }

    let port_name = &args[1];
    let baud = args[2].parse().unwrap();

    let stdin = io::stdin();
    let stdout = io::stdout();

    let mut port = serial::open(port_name).unwrap();
    interact(&mut port, &stdin, &stdout, baud);
}
