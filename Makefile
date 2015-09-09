all:
	(cd rust_src && cross64 build && cp target/arm-unknown-linux-gnueabihf/debug/roomba_port ../priv_dir/roomba_port)

clean:
	(cd rust_src && cargo clean)
	rm -f priv_dir/roomba_port
