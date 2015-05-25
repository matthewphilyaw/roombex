defmodule Roombex.Pilot do
  require Logger
  use GenServer
  alias Roombex.Roomba

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: :roomba_pilot) 
  end

  def do_commands([]) do
    :ok
  end

  def do_commands(commands) when is_list(commands) do
    GenServer.cast(:roomba_pilot, {:do_commands, commands})
    :ok
  end

  # --- callbacks

  def init(:ok) do
    {:ok, []}
  end 

  def handle_cast({:do_commands, commands}, state) do
    case get_command commands do
      :ok -> 
        {:noreply, state}
      {:ok, {:sleep, value}, rest} ->
        Logger.debug "sleeping for #{value}"
        :timer.apply_after(value, GenServer, :cast, [:roomba_pilot,
                                                    {:do_commands, rest}])
        {:noreply, state}
      {:ok, cmd, rest} ->
        Roomba.send_command(cmd)
        GenServer.cast(:roomba_pilot, {:do_commands, rest})

        {:noreply, state}
    end
  end

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
    
    {:ok, << 128 :: size(1)-big-integer-unsigned-unit(8) >>}
  end
  
  defp create_command(:power) do
    Logger.debug "start"

    {:ok, << 133 :: size(1)-big-integer-unsigned-unit(8) >>}
  end
  
  defp create_command(:enable_control_mode) do
    Logger.debug "enable user mode"
     
    {:ok, << 130 :: size(1)-big-integer-unsigned-unit(8) >>}
  end
  
  defp create_command(:enable_safe_mode) do
    Logger.debug "enable safe mode"
     
    {:ok, << 131 :: size(1)-big-integer-unsigned-unit(8) >>}
  end
  
  defp create_command(:enable_full_mode) do
    Logger.debug "enable safe mode"
     
    {:ok, << 132 :: size(1)-big-integer-unsigned-unit(8) >>}
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
    
    
    {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
             speed :: size(2)-big-integer-signed-unit(8),
             angle :: size(2)-big-integer-signed-unit(8) >>}
  end

end
