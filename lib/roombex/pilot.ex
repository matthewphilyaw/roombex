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


  def handle_cast({:do_commands, commands}, _state) do
    GenServer.cast(:roomba_pilot, :do_command)

    {:noreply, commands}
  end

  def handle_cast(:do_command, []) do
    {:noreply, []}
  end

  def handle_cast(:do_command, [%Sleep{val: value}|rest]) do
    Logger.debug fn -> "sleeping for #{value}" end

    :timer.apply_after(value, GenServer, :cast, [:roomba_pilot, :do_command])

    {:noreply, rest}
  end

  def handle_cast(:do_command, [cmd|rest]) do
    Logger.debug fn -> "sending command #{inspect cmd}" end

    Roomba.send_command(cmd)
    GenServer.cast(:roomba_pilot, :do_command)

    {:noreply, rest}
  end
end
