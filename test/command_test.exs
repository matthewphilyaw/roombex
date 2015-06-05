defmodule CommandTest do
  use ExUnit.Case
  alias Roombex.Command
  
  test ":start translates to 128 single unsigned byte" do
    expect = {:ok, << 128 :: size(1)-big-integer-unsigned-unit(8) >>}
    result = Command.transform(:start)

    assert result == expect
  end

  test ":control_mode transforms to 130 single unsigned byte" do
    expect = {:ok, << 130 :: size(1)-big-integer-unsigned-unit(8) >>}
    result = Command.transform(:control_mode)

    assert result == expect
  end

  test ":safe_mode transforms to 131 single unsigned byte" do
    expect = {:ok, << 131 :: size(1)-big-integer-unsigned-unit(8) >>}
    result = Command.transform(:safe_mode)

    assert result == expect
  end

  test ":full_mode transforms to 132 single unsigned byte" do
    expect = {:ok, << 132 :: size(1)-big-integer-unsigned-unit(8) >>}
    result = Command.transform(:full_mode)

    assert result == expect
  end
  
  test ":power transforms to 133 single unsigned byte"do
    expect = {:ok, << 133 :: size(1)-big-integer-unsigned-unit(8) >>}
    result = Command.transform(:power)

    assert result == expect
  end

  test "anything else transforms to error"do
    {result, _} = Command.transform(:foobar)

    assert result == :error
  end

  test "Drive struct defaults produce resulting command with 0 speed and angle :straight" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
                      0 :: size(2)-big-integer-signed-unit(8),
                      0x8000 :: size(2)-big-integer-signed-unit(8) >>}

    result = Command.transform(%Drive{})
    assert result == expect
  end

  test "drive with speed equal to max succeeds -- value used 500" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              500 :: size(2)-big-integer-signed-unit(8),
              0x8000 :: size(2)-big-integer-signed-unit(8) >>}

    result  = Command.transform(%Drive{speed: 500})
    assert result == expect
  end 

  test "drive with speed equal to max succeeds -- value used -500" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              -500 :: size(2)-big-integer-signed-unit(8),
              0x8000 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{speed: -500})
    assert result == expect
  end 

  test "drive with angle equal to max succeeds -- value used -2000" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              0 :: size(2)-big-integer-signed-unit(8),
              -2000 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{angle: -2000})
    assert result == expect
  end 

  test "drive with angle equal to max succeeds -- value used 2000" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              0 :: size(2)-big-integer-signed-unit(8),
              2000 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{angle: 2000})
    assert result == expect
  end 

  test "drive with angle equal to :straight succeeds" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              0 :: size(2)-big-integer-signed-unit(8),
              0x8000 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{angle: :straight})
    assert result == expect
  end 

  test "drive with angle equal to :clockwise succeeds" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              0 :: size(2)-big-integer-signed-unit(8),
              -1 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{angle: :clockwise})
    assert result == expect
  end 

  test "drive with angle equal to :counter_clockwise succeeds" do
    expect = {:ok, << 137 :: size(1)-big-integer-unsigned-unit(8),
              0 :: size(2)-big-integer-signed-unit(8),
              1 :: size(2)-big-integer-signed-unit(8) >>}
 
    result  = Command.transform(%Drive{angle: :counter_clockwise})
    assert result == expect
  end 

  test "Drive with speed greater than 500 fails -- value used 501" do
    {result, _} = Command.transform(%Drive{speed: 501})
    assert result == :error
  end

  test "Drive with speed less than -500 fails -- value used -501" do
    {result, _} = Command.transform(%Drive{speed: -501})
    assert result == :error
  end

  test "Drive with angle less than -2000 fails -- value used -2001" do
    {result, _} = Command.transform(%Drive{angle: -2001})
    assert result == :error
  end

  test "Drive with angle more than 2000 fails -- value used 2001" do
    {result, _} = Command.transform(%Drive{angle: 2001})
    assert result == :error
  end

  test "Drive with angle with atom not equal to :straight, :clockwise, :counter_clockwise fails -- value used :foobar" do
    {result, _} = Command.transform(%Drive{angle: :foobar})
    assert result == :error
  end

  test "Sleep returns an error, because it doesn't implement the Roombex.Command protocol" do
    {result, _} = Command.transform(%Sleep{})
    assert result == :error
  end
end
