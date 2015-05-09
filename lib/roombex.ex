defmodule Roombex do
  require Logger
  use GenServer
  
  @cport_name "priv_dir/roomba_port"
  
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: :roomba_server)
  end
  
  def open_port(port_name, baud_rate) do
    Logger.debug "opening port - name: #{port_name} baud rate: #{baud_rate}" 
    
    GenServer.call(:roomba_server, {:open, port_name, baud_rate})
  end

  def do_commands([]) do
    :ok
  end

  def do_commands(commands) when is_list(commands) do
    GenServer.cast(:roomba_server, {:do_commands, commands})
    :ok
  end
  
  # Server Call Backs ----------------------------------------------------------
  
  def init(:ok) do
    Process.flag(:trap_exit, true)
    port = Port.open({:spawn, @cport_name}, [{:packet, 2}, :binary])
    
    Logger.debug "created port"
    
    {:ok, {port, :not_ready}}
  end 

  @doc """
    do_commands takes a list of commands like
    [{:drive, 100, :straight}, {:sleep, 1000}, {:drive, 0, :straight}]

    walks the list trasnforming taking the head of the list, transforming it
    into the form needed to send to the roomba then call do_commands until the
    list is empty. 

    sleep is a special case where we don't have to call out to the roomba
    instead we use apply_after below to continue with the next item in the list
    after timout value. So the in example above you drive straight for 1 second
    and then stop. 
  """
  def handle_cast({:do_commands, commands}, state) do
    case get_command commands do
      :ok -> 
        {:noreply, state}
      {:ok, {:sleep, value}, rest} ->
        Logger.debug "sleeping for #{value}"
        :timer.apply_after(value, GenServer, :cast, [:roomba_server,
                                                    {:do_commands, rest}])
        {:noreply, state}
      {:ok, cmd, rest} ->
        GenServer.cast(:roomba_server, cmd)
        GenServer.cast(:roomba_server, {:do_commands, rest})

        {:noreply, state}
    end
  end

  @doc """
    Both send and send_read send message to the c port that talks
    to the serial port. only distinguished by the atom :send/:send_read
    which tells the port that it should either just send the data down the wire
    and return or, send and read back the bytes sent from the roomba. 

    Roomba only sends back information when a sensor command was sent to it.
  """
  def handle_cast({:send, command}, state={port, :ready}) do
    hexified = Hexate.encode command
    Logger.debug "sending command - #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send, command}))
    {:noreply, state}
  end
  
  def handle_cast({:send_read, command}, state={port, :ready}) do
    hexified = Hexate.encode command
    Logger.debug "sending sensor command - #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send_read, command}))
    {:noreply, state}
  end
  
  def handle_cast({type, _}, state={_, :not_ready}) when 
    is_atom(type) and type in [:send, :send_read] do
    
    msg = "serial port has not been setup, call open_port"
    
    Logger.error msg
    {:noreply, state}
  end
  
  def handle_call({:open, _, _}, _from, state={_, :ready}) do
    msg = "port is already open" 
    
    Logger.error msg
    {:reply, {:error, msg}, state}
  end
  
  def handle_call({:open, port_name, baud_rate}, _from, {port, :not_ready}) do
    Logger.debug "opening serial port"
    
    Port.command(port, :erlang.term_to_binary({:open, port_name, baud_rate}))
    
    {:reply, :ok, {port, :ready}}
  end
  
  def handle_info({port, {:data, data}} , state={port, _}) do
    msg = :erlang.binary_to_term(data)
    Logger.debug "received - #{msg}"
    
    case msg do
      :ok -> 
        {:noreply, state}
      _ -> 
        {:stop, msg, state} 
    end
  end
  
  def handle_info({:EXIT, _port, _}, state) do
    Logger.error "port exited"
    
    {:stop, "port exited", state}
  end

  def handle_info(msg, state) do
    Logger.debug "recieved message - #{msg}" 
    
    {:noreply, state}
  end

  # private 
  #----------------------------------------------------------------------------

  defp get_command([]) do
    :ok
  end

  defp get_command([cmd={:sleep, _}|rest]) do
    {:ok, cmd, rest}
  end

  defp get_command([h|rest]) do
    {:ok, cmd} = create_command(h)
    {:ok, cmd, rest}
  end

  defp create_command(:start) do
    Logger.debug "start"
    
    {:ok, {:send,  << 128 :: size(1)-big-integer-unsigned-unit(8) >>}}
  end
  
  defp create_command(:power) do
    Logger.debug "start"

    {:ok, {:send,  << 133 :: size(1)-big-integer-unsigned-unit(8) >>}}
  end
  
  defp create_command(:enable_control_mode) do
    Logger.debug "enable user mode"
     
    {:ok, {:send,  << 130 :: size(1)-big-integer-unsigned-unit(8) >>}}
  end
  
  defp create_command(:enable_safe_mode) do
    Logger.debug "enable safe mode"
     
    {:ok, {:send,  << 131 :: size(1)-big-integer-unsigned-unit(8) >>}}
  end
  
  defp create_command(:enable_full_mode) do
    Logger.debug "enable safe mode"
     
    {:ok, {:send,  << 132 :: size(1)-big-integer-unsigned-unit(8) >>}}
  end
  
  defp create_command({:drive, speed, angle}) when 
    is_integer(speed) and speed >= -500 and speed <= 500 and
    ((is_atom(angle) and angle in [:straight, :clockwise, :counter_clockwise]) or
    (is_integer(angle) and angle >= -2000 and angle <= 2000)) do
         
    # log original values, the output of the command from the handle_call
    # will show more detail.
    Logger.debug "drive - speed: #{speed} angle: #{angle}"
    
    # We know we have valide angle
    # now lets transform the few special cases
    # the actual values roomba needs
    angle = case angle do
      :straight -> 0x8000
      :clockwise -> -1
      :counter_clockwise -> 1
      _ -> angle
    end
    
    
    {:ok,  {:send, << 137 :: size(1)-big-integer-unsigned-unit(8),
                      speed :: size(2)-big-integer-signed-unit(8),
                      angle :: size(2)-big-integer-signed-unit(8) >>}}
  end

end
