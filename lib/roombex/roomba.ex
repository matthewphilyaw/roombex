defmodule Roomba do
  require Logger
  use GenServer
  
  @doc """
  Start Roomba server 
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
  
  def open_port(pid, port_name, baud_rate) do
    Logger.debug "opening port - name: #{port_name} baud rate: #{baud_rate}" 
    
    GenServer.call(pid, {:open, port_name, baud_rate})
  end
  
  def start(pid) do
    Logger.debug "start"
    
    GenServer.call(pid, 
                   {:send,  << 128 :: size(1)-big-integer-unsigned-unit(8) >>}) 
  end
  
  def drive(pid, speed, angle) when 
    is_integer(speed) and speed >= -500 and speed <= 500 and
    (is_atom(angle) and angle in [:straight, :clock_wise, :counter_clockwise]) or
    (is_integer(angle) and angle >= -2000 and angle <= 2000) do
         
    angle = case angle do
      :straight -> 0x8000
      :clock_wise -> -1
      :counter_clockwise -> 1
    end
    
    Logger.debug "drive - speed: #{speed} angle: #{angle}"
    
    GenServer.call(pid, {:send, << 137 :: size(1)-big-integer-unsigned-unit(8),
                                 speed :: size(2)-big-integer-signed-unit(8),
                                 angle :: size(2)-big-integer-signed-unit(8) >>})
  end
  
  # Server Call Backs ----------------------------------------------------------
  
  def init(:ok) do
    Process.flag(:trap_exit, true)
    port = Port.open({:spawn, "priv_dir/serial"}, [{:packet, 2}, :binary])
    
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
    Logger.debug "sending command: #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send, command}))
    {:reply, :ok, state}
  end
  
  def handle_call({:send_read, command}, _from, state={port, :ready}) do
    hexified = Hexate.encode command
    Logger.debug "sending sensor command: #{hexified}"
    
    Port.command(port, :erlang.term_to_binary({:send_read, command}))
    {:reply, :ok, state}
  end
  
  def handle_info({_, {:data, data}} , state) do
    msg = :erlang.binary_to_term(data)
    
    Logger.debug "received - #{msg}"
    {:noreply, state} 
  end
end