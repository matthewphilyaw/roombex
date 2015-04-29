defmodule Roombex do
  def init() do
    {:ok, pid} = Roomba.start_link
    Roomba.open_port pid, "/dev/pts/6", 57600
    Roomba.start pid 
    Roomba.drive pid, 500, :straight
    Roomba.drive pid, 500, :clockwise
    Roomba.drive pid, 500, :counter_clockwise
    Roomba.drive pid, 500, -550
  end
end
