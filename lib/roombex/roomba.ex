defmodule Roombex.Roomba do
  require Logger
  use GenServer

  alias Roombex.Command

  @cport_name "priv_dir/roomba_port"
  
  def start_link(port_name, baud_rate) do
    GenServer.start_link(__MODULE__, {port_name, baud_rate}, name: :roomba_server)
  end

  def send_command(command) do
    GenServer.cast(:roomba_server, {:send, command})
  end

  # --- call backs

  def init({port_name, baud_rate}) do
    Process.flag(:trap_exit, true)

    port_arg = "-D" <> port_name
    baud_arg = "-b" <> baud_rate

    port = Port.open({:spawn_executable, @cport_name}, 
                     [{:packet, 2}, 
                      :binary,
                      {:args, [port_arg, baud_arg]}])
    
    Logger.debug "created port"
    
    {:ok, port}
  end 

  def handle_cast({:send, command}, port) do
    cmd = Command.transform(command)

    Port.command(port, :erlang.term_to_binary({:command, cmd}))

    {:noreply, port}
  end
  
  def handle_cast({:send_read, command}, port) do
    cmd = Command.transform(command)
    
    Port.command(port, :erlang.term_to_binary({:sensor, cmd}))

    {:noreply, port}
  end

  def handle_info({port, {:data, data}}, port) do
    msg = :erlang.binary_to_term(data)
    Logger.debug "received - #{msg}"
    
    case msg do
      :ok -> 
        {:noreply, port}
      _ -> 
        {:stop, msg, port} 
    end
  end
  
  def handle_info({:EXIT, _port, reason}, state) do
    Logger.error "port exited #{reason}"
    
    {:stop, "port exited", state}
  end

  def handle_info(msg, state) do
    Logger.debug "recieved message - #{msg}" 
    
    {:noreply, state}
  end
end
