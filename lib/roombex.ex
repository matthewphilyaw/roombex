defmodule Roombex do
  def init() do
    Process.flag(:trap_exit, true)
    port = Port.open({:spawn, "priv_dir/serial"}, [{:packet, 2}, :binary])
    IO.puts "Opened port"

    Port.command(port, :erlang.term_to_binary({"open", "/dev/pts/2", 115200}))

    IO.puts "Sent data"
    receive do
      {port, {:data, data}} -> 
        IO.puts :erlang.binary_to_term(data) 
    end

    Port.command(port, :erlang.term_to_binary({"send", << "Hello, World!" >>}))

    IO.puts "Sent data"
    receive do
      {port, {:data, data}} -> 
        IO.puts :erlang.binary_to_term(data) 
    end

    IO.puts :done
  end
end
