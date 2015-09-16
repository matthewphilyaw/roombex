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


    port = Port.open({:spawn_executable, @cport_name},
                     [{:packet, 2},
                      {:args, [port_name, baud_rate]}])

    Logger.debug fn -> "created port" end

    {:ok, port}
  end

  def handle_cast({:send, command}, port) do
    Port.command port, command

    {:noreply, port}
  end

  def handle_info({port, {:data, data}}, port) do
    Logger.debug fn -> "received - #{data}" end

    {:noreply, port}
  end

  def handle_info({:EXIT, _port, reason}, state) do
    Logger.error fn -> "port exited #{reason}" end

    {:stop, "port exited", state}
  end

  def handle_info(msg, state) do
    Logger.debug fn -> "recieved message - #{msg}" end

    {:noreply, state}
  end
end
