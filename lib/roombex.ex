defmodule Roombex do
  use Application

  # see http://elixir-lang.org/docs/stable/elixir/application.html
  # for more information on otp applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # define workers and child supervisors to be supervised
      worker(Roombex.Roomba, [<<"/dev/pts/1">>, <<"115200">>]),
      worker(Roombex.Pilot, [])
    ]

    # see http://elixir-lang.org/docs/stable/elixir/supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Roombex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
