defmodule Roombex do
  require Logger
  use GenServer
  
  @cport_name "priv_dir/roomba_port"
  
  @doc """
  Start Roomba server 
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: :roomba_server)
  end
  
  @doc """
  Used to open serial port
  """
  def open_port(port_name, baud_rate) do
    Logger.debug "opening port - name: #{port_name} baud rate: #{baud_rate}" 
    
    GenServer.call(:roomba_server, {:open, port_name, baud_rate})
  end
  
  @doc """
  Start command for roomba
  """
  def start do
    Logger.debug "start"
    
    GenServer.call(:roomba_server,
                   {:send,  << 128 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  def power do
    Logger.debug "start"
    
    GenServer.call(:roomba_server,
                   {:send,  << 133 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  def enable_control_mode do
    Logger.debug "enable user mode"
     
     
    GenServer.call(:roomba_server,
                   {:send,  << 130 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  def enable_safe_mode do
    Logger.debug "enable safe mode"
     
     
    GenServer.call(:roomba_server,
                   {:send,  << 131 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  def enable_full_mode do
    Logger.debug "enable safe mode"
     
     
    GenServer.call(:roomba_server,
                   {:send,  << 132 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  @doc """
  Drive command for roomba
  """
  def drive(speed, angle) when 
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
    
    
    GenServer.call(:roomba_server, 
                   {:send, << 137 :: size(1)-big-integer-unsigned-unit(8),
                            speed :: size(2)-big-integer-signed-unit(8),
                            angle :: size(2)-big-integer-signed-unit(8) >>})
  end
  
  # Server Call Backs ----------------------------------------------------------
  
  def init(:ok) do
    Process.flag(:trap_exit, true)
    port = Port.open({:spawn, @cport_name}, [{:packet, 2}, :binary])
    
    Logger.debug "created port"
    
    {:ok, {port, :not_ready}}
  end 
  
  def handle_call({type, _}, _, state={_, :not_ready}) when 
    is_atom(type) and type in [:send, :send_read] do
    
    msg = "serial port has not been setup, call open_port"
    
    Logger.error msg
    {:reply, {:error, msg}, state}
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
  
  def handle_call({:send, command}, _from, state={port, :ready}) do
    hexified = Hexate.encode command
    Logger.debug "sending command - #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send, command}))
    {:reply, :ok, state}
  end
  
  def handle_call({:send_read, command}, _from, state={port, :ready}) do
    hexified = Hexate.encode command
    Logger.debug "sending sensor command - #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send_read, command}))
    {:reply, :ok, state}
  end
  
  def handle_info({_port, {:data, data}} , state={_port, _}) do
    msg = :erlang.binary_to_term(data)
    Logger.debug "received - #{msg}"
    
    case msg do
      :ok -> 
        {:noreply, state}
      _ -> 
        {:stop, msg, state} 
    end
  end
  
  def handle_info(msg, state) do
    Logger.debug "recieved message - #{msg}" 
    
    {:noreply, state}
  end
  
  def handle_info({:EXIT, port, _}, state) do
    Logger.error "port exited"
    
    {:stop, "port exited", state}
  end
end