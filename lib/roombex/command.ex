defprotocol Roombex.Command do
  @fallback_to_any true
  def transform(command)
end

defimpl Roombex.Command, for: Any do
  def transform(_), do: {:error, "no impl defined"}
end

defimpl Roombex.Command, for: Atom do
  def transform(:start) do
    {:ok, << 128 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  def transform(:control_mode) do
    {:ok, << 130 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  def transform(:safe_mode) do
    {:ok, << 131 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  def transform(:full_mode) do
    {:ok, << 132 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  def transform(:power_off) do
    {:ok, << 133 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  @doc """
    doesn't exist in the SCI protocol, but the roomba_port
    recognizes the 0x01 and if supported on the platform
    will pull the device line low to turn on roomba. 

    Currently only the raspberry pi has support
  """
  def transform(:power_on) do
    {:ok, << 0x01 :: size(1)-big-integer-unsigned-unit(8) >>}
  end

  def transform(_) do
    {:error, "no impl defined"}
  end
end

defmodule Drive do
  defstruct speed: 0, angle: :straight

  defimpl Roombex.Command do
    def transform(%Drive{speed: s}) when is_integer(s) and s < -500 do
      {:error,
       "speed must be greater than or equal to -500. #{s} was supplied"}
    end

    def transform(%Drive{speed: s}) when is_integer(s) and s > 500 do
      {:error,
       "speed must be less than or equal to 500. #{s} was supplied"}
    end

    def transform(%Drive{angle: a}) when is_integer(a) and a < -2000 do
      {:error,
       "angle must be greater than or equal to 2000. #{a} was supplied"}
    end

    def transform(%Drive{angle: a}) when is_integer(a) and a > 2000 do
      {:error,
       "angle must be less than or equal to 2000. #{a} was supplied"}
    end

    def transform(%Drive{angle: a}) when
      is_atom(a) and not (a in [:straight, :clockwise, :counter_clockwise]) do
      {:error,
       "atom must be :straight, :clockwise, or :counter_clockwise. #{a} was supplied"}
    end

    def transform(%Drive{speed: s, angle: a}) do
      a = case a do
        :straight -> 0x8000
        :clockwise -> -1
        :counter_clockwise -> 1
        _ -> a
      end

      {:ok, 
        << 137 :: size(1)-big-integer-unsigned-unit(8),
           s :: size(2)-big-integer-signed-unit(8),
           a :: size(2)-big-integer-signed-unit(8) >>}
    end
  end
end

defmodule Sleep do
  defstruct val: 0

  defimpl Roombex.Command do
    def transform(sleep = %Sleep{ val: t }) when t > 0 do
      {:ok, sleep}
    end

    def transform(_), do: {:error, "sleep val must be greater than 0"}
  end
end
